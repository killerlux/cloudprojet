#!/bin/bash

set -euxo pipefail # Arrête le script en cas d'erreur

KUBERNETES_VERSION="1.28" # Doit correspondre à la version du master
CRI_SOCKET="unix:///var/run/containerd/containerd.sock"

echo "[TASK 1] Mises à jour du système et installation des paquets prérequis"
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg software-properties-common

echo "[TASK 2] Désactivation du swap"
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "[TASK 3] Configuration des modules kernel et sysctl pour Kubernetes"
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

echo "[TASK 4] Installation de Containerd (runtime de conteneur)"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --batch --yes --dearmor -o docker.gpg
sudo mv docker.gpg /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y containerd.io

echo "[TASK 5] Configuration de Containerd pour utiliser systemd cgroup"
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "[TASK 6] Installation de kubeadm et kubelet"
# kubectl n'est pas requis sur les workers, mais peut être utile pour le débogage.
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION}/deb/Release.key | gpg --batch --yes --dearmor -o kubernetes-apt-keyring.gpg
sudo mv kubernetes-apt-keyring.gpg /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
# Trouvez une version spécifique si besoin, ex: KUBE_VERSION_SPECIFIC="1.28.8-1.1"
# sudo apt-get install -y kubelet=${KUBE_VERSION_SPECIFIC} kubeadm=${KUBE_VERSION_SPECIFIC}
sudo apt-get install -y kubelet kubeadm # Installe la dernière patch de la version ${KUBERNETES_VERSION}
sudo apt-mark hold kubelet kubeadm

echo "[TASK 7] Joindre le nœud au cluster Kubernetes"
echo "---"
echo "IMPORTANT:"
echo "Ce script ne joint PAS automatiquement le worker au master."
echo "Vous devez récupérer la commande 'kubeadm join ...' depuis le master."
echo "Le master l'affiche à la fin de son provisionnement et la sauvegarde dans /join_command.sh."
echo "Exemple pour récupérer la commande join depuis votre machine hôte:"
echo "  vagrant ssh k8s-master -c \"cat /join_command.sh\""
echo "OU pour en générer une nouvelle :"
echo "  vagrant ssh k8s-master -c \"sudo kubeadm token create --print-join-command\""
echo ""
echo "Ensuite, exécutez cette commande join sur CE nœud worker (k8s-worker01) avec sudo :"
echo "  vagrant ssh k8s-worker01 -c \"sudo <coller_la_commande_join_ici> --cri-socket=${CRI_SOCKET}\""
echo "Assurez-vous d'ajouter '--cri-socket=${CRI_SOCKET}' si elle n'est pas déjà incluse par 'kubeadm token create'."
echo "Normalement, 'kubeadm join' détecte le socket CRI automatiquement s'il est standard et configuré."
echo "---"

echo "[TASK 8] Création manuelle du répertoire pour PersistentVolume PostgreSQL (RAPPEL)"
echo "N'oubliez pas de créer le répertoire pour le PV PostgreSQL sur CE worker, si ce n'est pas déjà fait :"
echo "  vagrant ssh k8s-worker01 -c \"sudo mkdir -p /mnt/data-postgres-pv && sudo chmod -R 777 /mnt/data-postgres-pv\""
echo "Cela doit être fait AVANT de déployer les manifestes Kubernetes pour Odoo/PostgreSQL."
echo "---"

echo "Installation du worker terminée. Attente de la commande 'kubeadm join'." 