# TP Intégration Cloud Computing avec Kubernetes pour Clay Technology

<!-- Optionnel: Badges (exemples, à adapter si vous utilisez des services CI/CD, etc.) -->
<!--
[![Build Status](https://travis-ci.org/username/repo.svg?branch=master)](https://travis-ci.org/username/repo)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
-->

Ce projet simule la migration de l'infrastructure de l'entreprise "Clay Technology" vers une solution Cloud basée sur Kubernetes. L'objectif est de mettre en place un cluster Kubernetes localement avec Vagrant, de déployer des applications clés (Nginx, Odoo avec PostgreSQL) et de documenter l'ensemble du processus.

## Table des Matières

- [Objectif du Projet](#objectif-du-projet)
- [Structure du Projet](#structure-du-projet)
- [Prérequis](#prérequis)
- [Mise en Place et Déploiement](#mise-en-place-et-déploiement)
  - [1. Cloner le Dépôt](#1-cloner-le-dépôt)
  - [2. Préparation du PersistentVolume PostgreSQL](#2-préparation-du-persistentvolume-postgresql)
  - [3. Démarrage de l'Infrastructure Kubernetes](#3-démarrage-de-linfrastructure-kubernetes)
  - [4. Jonction du Nœud Worker au Cluster](#4-jonction-du-nœud-worker-au-cluster)
  - [5. Vérification de l'État du Cluster](#5-vérification-de-létat-du-cluster)
  - [6. Déploiement des Applications](#6-déploiement-des-applications)
  - [7. Vérification des Déploiements Applicatifs](#7-vérification-des-déploiements-applicatifs)
  - [8. Accès aux Applications](#8-accès-aux-applications)
- [Tests de l'Infrastructure (Optionnel mais Recommandé)](#tests-de-linfrastructure-optionnel-mais-recommandé)
- [Nettoyage de l'Environnement](#nettoyage-de-lenvironnement)
- [Rapport Technique](#rapport-technique)
- [Contribuer](#contribuer)
- [Licence](#licence)

## Objectif du Projet

Ce projet simule la migration de l'infrastructure de l'entreprise "Clay Technology" vers une solution Cloud basée sur Kubernetes. L'objectif est de mettre en place un cluster Kubernetes localement avec Vagrant, de déployer des applications clés (Nginx, Odoo avec PostgreSQL) et de documenter l'ensemble du processus.

## Structure du Projet

Le projet est organisé comme suit :

```
.
├── infrastructure-setup/
│   ├── Vagrantfile
│   └── setup-scripts/
│       ├── master-setup.sh
│       └── worker-setup.sh
├── kubernetes-manifests/
│   ├── 00-namespace.yaml
│   ├── app-nginx/
│   │   └── nginx-deployment-svc.yaml
│   └── app-odoo-postgres/
│       └── odoo-postgres-full.yaml
├── rapport/
│   └── Rapport_Integration_Cloud_Kubernetes.md
└── README.md
```

-   **`README.md`**: Ce fichier.
-   **`infrastructure-setup/`**: Scripts et configuration Vagrant pour monter le cluster Kubernetes.
    -   `Vagrantfile`: Définit les VMs (1 master `k8s-master`, 1 worker `k8s-worker01`).
    -   `setup-scripts/`: Contient les scripts de provisionnement (`master-setup.sh`, `worker-setup.sh`).
-   **`kubernetes-manifests/`**: Manifestes YAML pour les applications.
    -   `00-namespace.yaml`: Namespace `clay-technology-prod`.
    -   `app-nginx/nginx-deployment-svc.yaml`: Déploiement et Service Nginx.
    -   `app-odoo-postgres/odoo-postgres-full.yaml`: Configurations complètes pour Odoo et PostgreSQL.
-   **`rapport/`**:
    -   `Rapport_Integration_Cloud_Kubernetes.md`: Documentation détaillée du projet.

## Prérequis

Avant de commencer, assurez-vous d'avoir installé les outils suivants :

-   [Vagrant](https://www.vagrantup.com/downloads.html) (dernière version stable recommandée)
-   [VirtualBox](https://www.virtualbox.org/wiki/Downloads) (dernière version stable recommandée) ou un autre [fournisseur Vagrant](https://www.vagrantup.com/docs/providers) compatible.
-   `kubectl` (client Kubernetes) installé localement (optionnel, pour interagir avec le cluster depuis la machine hôte de manière plus directe). Instructions d'installation disponibles sur le [site officiel de Kubernetes](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/).
-   Git (pour cloner le dépôt).

## Mise en Place et Déploiement

Suivez ces étapes pour mettre en place l'environnement et déployer les applications.

### 1. Cloner le Dépôt

Si vous n'avez pas encore les fichiers du projet, clonez ce dépôt (remplacez `<URL_DU_DEPOT_GIT>` par l'URL réelle si applicable) :
```bash
git clone <URL_DU_DEPOT_GIT>
cd <NOM_DU_REPERTOIRE_PROJET>
```

Si vous avez déjà les fichiers, assurez-vous d'être à la racine du projet pour exécuter les commandes suivantes.

### 2. Préparation du PersistentVolume PostgreSQL

Avant de démarrer les machines virtuelles ou juste après leur démarrage (mais avant d'appliquer les manifestes Kubernetes pour Odoo/PostgreSQL), le répertoire pour le PersistentVolume de PostgreSQL doit être créé manuellement sur le nœud worker k8s-worker01.

Exécutez la commande suivante depuis votre machine hôte (depuis la racine du projet) :

```bash
# Si les VMs ne sont pas encore démarrées, cette commande échouera.
# Il est préférable de l'exécuter après 'vagrant up' et avant d'appliquer les manifestes Kubernetes.
# Assurez-vous que la VM k8s-worker01 est accessible.
(cd infrastructure-setup && vagrant ssh k8s-worker01 -c "sudo mkdir -p /mnt/data-postgres-pv && sudo chmod -R 777 /mnt/data-postgres-pv")
```

Note : L'utilisation de chmod 777 est une simplification pour ce TP. En environnement de production, des permissions plus restrictives et une gestion des propriétaires/groupes (potentiellement via un initContainer ou des securityContext dans la définition du pod PostgreSQL) seraient impératives.

### 3. Démarrage de l'Infrastructure Kubernetes

Naviguez vers le répertoire infrastructure-setup/ et lancez Vagrant pour créer et provisionner les VMs :

```bash
cd infrastructure-setup
vagrant up
```

Ce processus peut prendre plusieurs minutes. Il va :

- Télécharger l'image de base Ubuntu 22.04 (si ce n'est pas déjà en cache).
- Créer et configurer les VMs k8s-master et k8s-worker01.
- Exécuter les scripts master-setup.sh et worker-setup.sh pour installer Kubernetes et ses dépendances.

À la fin du provisionnement du master (k8s-master), une commande kubeadm join ... sera affichée dans la console. Copiez cette commande soigneusement, elle est nécessaire pour l'étape suivante. Elle est également sauvegardée dans /join_command.sh sur le master.

### 4. Jonction du Nœud Worker au Cluster

Le script worker-setup.sh prépare le nœud worker mais ne le joint pas automatiquement au cluster. Utilisez la commande kubeadm join que vous avez copiée :

```bash
# Remplacez <coller_la_commande_kubeadm_join_ici> par la commande obtenue du master.
# L'option --cri-socket=unix:///var/run/containerd/containerd.sock est généralement incluse
# ou détectée automatiquement par kubeadm join sur des installations récentes.
vagrant ssh k8s-worker01 -c "sudo <coller_la_commande_kubeadm_join_ici>"
```

Si vous avez manqué la commande join ou si le token a expiré (valide 24h par défaut), vous pouvez en générer un nouveau depuis le master :

```bash
vagrant ssh k8s-master -c "sudo kubeadm token create --print-join-command"
```

Puis exécutez la nouvelle commande sur le worker comme ci-dessus.

### 5. Vérification de l'État du Cluster

Une fois le worker joint, vérifiez que les deux nœuds sont Ready depuis le master :

```bash
vagrant ssh k8s-master -c "kubectl get nodes -o wide"
```

Vous devriez voir k8s-master (avec le rôle control-plane) et k8s-worker01, tous deux avec le statut Ready. Cela peut prendre une minute ou deux pour que le worker devienne Ready après la jonction, le temps que le CNI (Flannel) soit pleinement opérationnel sur ce nœud.

### 6. Déploiement des Applications

Les manifestes Kubernetes se trouvent dans le répertoire kubernetes-manifests/. Le chemin /vagrant/... dans les commandes ci-dessous fait référence au montage automatique du répertoire du projet à l'intérieur des VMs Vagrant.

Créer le Namespace clay-technology-prod :

```bash
vagrant ssh k8s-master -c "kubectl apply -f /vagrant/kubernetes-manifests/00-namespace.yaml"
```

Déployer Nginx :

```bash
vagrant ssh k8s-master -c "kubectl apply -f /vagrant/kubernetes-manifests/app-nginx/nginx-deployment-svc.yaml -n clay-technology-prod"
```

Déployer Odoo et PostgreSQL :

```bash
vagrant ssh k8s-master -c "kubectl apply -f /vagrant/kubernetes-manifests/app-odoo-postgres/odoo-postgres-full.yaml -n clay-technology-prod"
```

### 7. Vérification des Déploiements Applicatifs

Après quelques instants (le temps de tirer les images Docker depuis Docker Hub et de démarrer les conteneurs), vérifiez l'état des ressources déployées :

Voir tous les objets dans le namespace :

```bash
vagrant ssh k8s-master -c "kubectl get all -n clay-technology-prod -o wide"
```

Attendez que tous les pods (Nginx, Odoo, PostgreSQL) soient en statut Running.

Vérifier les Volumes Persistants :

```bash
vagrant ssh k8s-master -c "kubectl get pv,pvc -n clay-technology-prod"
```

Le PersistentVolumeClaim (PVC) postgres-pvc doit être en statut Bound avec le PersistentVolume (PV) postgres-pv.

Suivre la création des pods (optionnel pour le débogage) :

```bash
vagrant ssh k8s-master -c "kubectl get pods -n clay-technology-prod --watch"
```

(Pressez Ctrl+C pour arrêter le suivi). Pour des logs spécifiques : kubectl logs <nom-du-pod> -n clay-technology-prod.

### 8. Accès aux Applications

Les services Nginx et Odoo sont exposés via NodePort. Pour y accéder :

Récupérez les NodePort assignés :

```bash
vagrant ssh k8s-master -c "kubectl get svc -n clay-technology-prod"
```

Cherchez les ports dans la colonne PORT(S) pour nginx-service et odoo-service (ex: 80:3XXXX/TCP ou 8069:3YYYY/TCP). Le 3XXXX ou 3YYYY est le NodePort.

Accédez via votre navigateur :
L'adresse IP du nœud worker k8s-worker01 est 192.168.56.11 (telle que définie dans le Vagrantfile).

- Nginx : http://192.168.56.11:<NodePort_Nginx>
- Odoo : http://192.168.56.11:<NodePort_Odoo>

## Tests de l'Infrastructure (Optionnel mais Recommandé)

Avant de déployer les applications (après l'étape 5), il est conseillé de valider le bon fonctionnement du cluster lui-même :

Vérifier les pods système (CoreDNS, Flannel, etc.) :

```bash
vagrant ssh k8s-master -c "kubectl get pods -n kube-system"
vagrant ssh k8s-master -c "kubectl get pods -n kube-flannel"
```

Tous les pods devraient être Running.

Déployer un pod de test simple (ex: busybox) et tester le DNS interne au cluster :

```bash
vagrant ssh k8s-master -c "kubectl run dns-test --image=busybox:1.28 --rm -it --restart=Never -- nslookup kubernetes.default.svc.cluster.local"
```

Cette commande devrait réussir et afficher l'adresse IP du service API Kubernetes (généralement 10.96.0.1).

## Nettoyage de l'Environnement

Pour arrêter et supprimer les machines virtuelles créées par Vagrant, ainsi que toutes les ressources associées :

Assurez-vous d'être dans le répertoire infrastructure-setup/ :

```bash
cd infrastructure-setup
```

(Si vous êtes à la racine du projet, exécutez cd infrastructure-setup)

Détruisez les VMs :

```bash
vagrant destroy -f
```

Cette commande est irréversible et supprimera les disques virtuels.

## Rapport Technique

Une documentation détaillée du projet, incluant les choix techniques, les configurations, les défis rencontrés et les résultats, est disponible dans le fichier :

- rapport/Rapport_Integration_Cloud_Kubernetes.md

## Contribuer

Ce projet est réalisé dans le cadre d'un Travail Pratique (TP). Les contributions et suggestions d'amélioration sont les bienvenues, notamment pour affiner les configurations ou explorer des fonctionnalités avancées.

Pour contribuer :

- Forkez le dépôt (si hébergé sur une plateforme comme GitHub/GitLab).
- Créez une nouvelle branche pour vos modifications : `git checkout -b feature/ma-super-amelioration`.
- Effectuez vos modifications et commitez-les avec des messages clairs : `git commit -am 'Ajout: Explication détaillée pour X'`.
- Pushez votre branche vers votre fork : `git push origin feature/ma-super-amelioration`.
- Ouvrez une Pull Request (ou Merge Request) vers le dépôt original.

## Licence

Ce projet est principalement à des fins éducatives.
Sauf indication contraire, le contenu de ce dépôt peut être considéré sous la Licence MIT, ce qui permet une large réutilisation tout en attribuant la paternité. Si vous souhaitez inclure formellement une licence, créez un fichier LICENSE à la racine du projet avec le texte de la licence choisie (par exemple, MIT).
