#!/bin/bash

set -euxo pipefail # Arrête le script en cas d'erreur

KUBERNETES_VERSION="1.28" # Version majeure.mineure de Kubernetes
CRI_SOCKET="unix:///var/run/containerd/containerd.sock"
POD_NETWORK_CIDR="10.244.0.0/16" # CIDR pour le réseau des pods Flannel

echo "[TASK 1] Mises à jour du système et installation des paquets prérequis"
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg software-properties-common

echo "[TASK 2] Désactivation du swap"
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "[TASK 3] Configuration des modules kernel et sysctl pour Kubernetes"
# Activation des modules overlay et br_netfilter
sudo modprobe overlay
sudo modprobe br_netfilter

# Configuration sysctl pour la persistance des modules et le forwarding IP
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
# Ajout de la clé GPG de Docker (pour containerd.io)
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --batch --yes --dearmor -o docker.gpg
sudo mv docker.gpg /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Ajout du dépôt Docker
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

echo "[TASK 6] Installation de kubeadm, kubelet et kubectl"
# Ajout de la clé GPG de Kubernetes
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION}/deb/Release.key | gpg --batch --yes --dearmor -o kubernetes-apt-keyring.gpg
sudo mv kubernetes-apt-keyring.gpg /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Ajout du dépôt Kubernetes
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
# Trouvez une version spécifique si besoin, ex: KUBE_VERSION_SPECIFIC="1.28.8-1.1"
# sudo apt-get install -y kubelet=${KUBE_VERSION_SPECIFIC} kubeadm=${KUBE_VERSION_SPECIFIC} kubectl=${KUBE_VERSION_SPECIFIC}
sudo apt-get install -y kubelet kubeadm kubectl # Installe la dernière patch de la version ${KUBERNETES_VERSION}
sudo apt-mark hold kubelet kubeadm kubectl # Empêche les mises à jour automatiques

echo "[TASK 7] Initialisation du cluster Kubernetes avec kubeadm"
# Le --cri-socket est important si plusieurs runtimes sont présents ou si le défaut n'est pas celui attendu
# Le --apiserver-advertise-address peut être omis si la VM a une seule IP sur le réseau par défaut, sinon à spécifier
# Kubeadm détectera automatiquement l'IP à partir de la route par défaut
sudo kubeadm init --pod-network-cidr=${POD_NETWORK_CIDR} --cri-socket=${CRI_SOCKET} --kubernetes-version=v1.28.15

echo "[TASK 8] Configuration de kubectl pour l'utilisateur vagrant"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config # S'assure que kubectl fonctionne immédiatement dans le script

echo "[TASK 9] Installation du plugin CNI Flannel pour le réseau des pods"
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

echo "[TASK 10] Génération de la commande pour joindre les workers"
echo "La commande pour joindre les nœuds workers est :"
sudo kubeadm token create --print-join-command > /join_command.sh
cat /join_command.sh
echo "Cette commande a été sauvegardée dans /join_command.sh sur le master."
echo "Vous pouvez aussi la régénérer avec : vagrant ssh k8s-master -c \"sudo kubeadm token create --print-join-command\""

echo "[TASK 11] (Optionnel) Autoriser le scheduling de pods sur le master"
# kubectl taint nodes --all node-role.kubernetes.io/control-plane-

echo "Installation du master terminée."
echo "Vérifiez l'état des nœuds avec: kubectl get nodes -o wide"
echo "Vérifiez l'état des pods système avec: kubectl get pods -A" 