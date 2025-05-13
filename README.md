# TP Intégration Cloud Computing avec Kubernetes pour Clay Technology

## Objectif du Projet

Ce projet simule la migration de l'infrastructure de l'entreprise "Clay Technology" vers une solution Cloud basée sur Kubernetes. L'objectif est de mettre en place un cluster Kubernetes localement avec Vagrant, de déployer des applications clés (Nginx, Odoo avec PostgreSQL) et de documenter l'ensemble du processus.

## Structure du Projet

Le projet est organisé comme suit :

-   `README.md` : Ce fichier. Description du projet et instructions.
-   `infrastructure-setup/` : Contient les fichiers pour la mise en place de l'infrastructure Kubernetes avec Vagrant.
    -   `Vagrantfile` : Fichier de configuration Vagrant pour créer les VMs (1 master, 1 worker).
    -   `setup-scripts/` : Scripts de provisionnement pour les VMs.
        -   `master-setup.sh` : Script d'installation et de configuration du nœud master Kubernetes.
        -   `worker-setup.sh` : Script d'installation et de configuration du nœud worker Kubernetes.
-   `kubernetes-manifests/` : Contient les manifestes YAML pour déployer les applications sur Kubernetes.
    -   `00-namespace.yaml` : Définit le namespace `clay-technology-prod`.
    -   `app-nginx/nginx-deployment-svc.yaml` : Manifestes pour le déploiement de Nginx (Deployment et Service).
    -   `app-odoo-postgres/odoo-postgres-full.yaml` : Manifestes pour le déploiement d'Odoo et PostgreSQL (ConfigMap, PersistentVolume, PersistentVolumeClaim, Deployments, Services).
-   `rapport/` : Contient le rapport technique du projet.
    -   `Rapport_Integration_Cloud_Kubernetes.md` : Document détaillant le processus, les configurations, les choix techniques et les résultats.

## Prérequis

-   Vagrant installé
-   VirtualBox (ou un autre fournisseur compatible avec Vagrant) installé
-   `kubectl` installé localement (optionnel, pour interagir avec le cluster depuis l'hôte)

## Instructions de Mise en Place et Déploiement

1.  **Cloner le dépôt (si applicable) ou créer la structure de fichiers.**

2.  **Préparer l'environnement pour le PersistentVolume PostgreSQL :**
    Avant de lancer `vagrant up` ou après que la VM `k8s-worker01` soit démarrée mais *avant* d'appliquer les manifestes Kubernetes, vous devez créer manuellement le répertoire pour le `PersistentVolume` sur le nœud worker `k8s-worker01`. Exécutez la commande suivante :
    ```bash
    vagrant ssh k8s-worker01 -c "sudo mkdir -p /mnt/data-postgres-pv && sudo chmod -R 777 /mnt/data-postgres-pv"
    ```
    *Note : L'utilisation de `chmod 777` est pour simplifier dans ce TP. En production, des permissions plus restrictives et une gestion des propriétaires/groupes appropriés seraient nécessaires, potentiellement via un `initContainer` ou des `securityContext` dans le pod PostgreSQL.*

3.  **Monter l'infrastructure Kubernetes avec Vagrant :**
    Naviguez vers le répertoire `infrastructure-setup/` et lancez Vagrant :
    ```bash
    cd infrastructure-setup
    vagrant up
    ```
    Cela va créer et provisionner le nœud master (`k8s-master`) et le nœud worker (`k8s-worker01`). Le script `master-setup.sh` affichera la commande `kubeadm join` nécessaire. Copiez cette commande.

4.  **Joindre le nœud worker au cluster :**
    Le script `worker-setup.sh` attend la commande `kubeadm join`. Vous devrez l'exécuter manuellement ou l'intégrer dans le script si vous souhaitez une automatisation complète (non couvert par ce TP de base).
    Si le script `worker-setup.sh` n'inclut pas l'exécution automatique du join, connectez-vous au master pour récupérer la commande `join` si vous l'avez manquée :
    ```bash
    vagrant ssh k8s-master -c "kubeadm token create --print-join-command"
    ```
    Puis, exécutez cette commande sur le worker :
    ```bash
    vagrant ssh k8s-worker01 -c "sudo <coller_la_commande_kubeadm_join_ici>"
    ```

5.  **Vérifier l'état du cluster :**
    Une fois les nœuds prêts, vérifiez leur état depuis le master :
    ```bash
    vagrant ssh k8s-master -c "kubectl get nodes -o wide"
    ```

6.  **Déployer les applications :**
    Appliquez les manifestes Kubernetes depuis le nœud master.

    *   **Créer le namespace :**
        ```bash
        vagrant ssh k8s-master -c "kubectl apply -f /vagrant/kubernetes-manifests/00-namespace.yaml"
        ```
        *Note : Le répertoire du projet local est généralement monté dans `/vagrant` sur les VMs Vagrant.*

    *   **Déployer Nginx :**
        ```bash
        vagrant ssh k8s-master -c "kubectl apply -f /vagrant/kubernetes-manifests/app-nginx/nginx-deployment-svc.yaml -n clay-technology-prod"
        ```

    *   **Déployer Odoo et PostgreSQL :**
        ```bash
        vagrant ssh k8s-master -c "kubectl apply -f /vagrant/kubernetes-manifests/app-odoo-postgres/odoo-postgres-full.yaml -n clay-technology-prod"
        ```

7.  **Vérifier les déploiements :**
    ```bash
    vagrant ssh k8s-master -c "kubectl get all -n clay-technology-prod -o wide"
    vagrant ssh k8s-master -c "kubectl get pv,pvc -n clay-technology-prod"
    ```

8.  **Accéder aux applications :**
    Récupérez les NodePorts des services Nginx et Odoo :
    ```bash
    vagrant ssh k8s-master -c "kubectl get svc -n clay-technology-prod"
    ```
    Les applications seront accessibles via `http://<IP_WORKER>:<NodePort>`. L'IP du worker est définie dans le `Vagrantfile` (par exemple, `192.168.56.11`).

    *   Nginx : `http://192.168.56.11:<NodePort_Nginx>`
    *   Odoo : `http://192.168.56.11:<NodePort_Odoo>`

## Contenu du Rapport

Le rapport technique se trouve dans `rapport/Rapport_Integration_Cloud_Kubernetes.md`. Il détaille l'ensemble du processus, les configurations, les choix techniques et les résultats obtenus.
