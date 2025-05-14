# ☁️ Clay Technology – TP Intégration Cloud Kubernetes

Un projet pédagogique complet pour simuler la migration d'une infrastructure d'entreprise vers Kubernetes, avec déploiement automatisé (Vagrant), manifestes applicatifs (Nginx, Odoo/PostgreSQL), et documentation professionnelle.

![Cluster Preview](https://raw.githubusercontent.com/your-org/your-repo/main/.github/images/cluster-preview.png)

---

## ✨ Fonctionnalités principales

### Infrastructure & Déploiement
- 🚀 Cluster Kubernetes local (Vagrant + VirtualBox)
- 🗂️ Scripts de provisionnement master/worker
- 📦 Déploiement automatisé de Nginx, Odoo, PostgreSQL
- 🗄️ Stockage persistant pour PostgreSQL
- 🛡️ Namespace dédié & bonnes pratiques YAML

### Documentation & UX
- 📖 Rapport technique détaillé (LaTeX/Markdown)
- 📝 Guide pas-à-pas pour installation et tests
- 🧑‍💻 Commandes prêtes à l'emploi
- 🧩 Structure de dépôt claire et modulaire

---

## ⚠️ Prérequis

- **OS** : Linux, Windows ou MacOS (avec Vagrant & VirtualBox)
- **Outils** :
  - [Vagrant](https://www.vagrantup.com/downloads.html)
  - [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
  - [kubectl](https://kubernetes.io/docs/tasks/tools/) (optionnel)
  - Git
- **Accès Internet** : pour télécharger images et dépendances

---

## 🏗️ Structure du projet

```
cloudprojet/
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

---

## 🚀 Installation & Utilisation

1. **Cloner le dépôt**
   ```bash
   git clone <URL_DU_DEPOT_GIT>
   cd <NOM_DU_REPERTOIRE_PROJET>
   ```

2. **Préparer le stockage persistant PostgreSQL**
   ```bash
   (cd infrastructure-setup && vagrant ssh k8s-worker01 -c "sudo mkdir -p /mnt/data-postgres-pv && sudo chmod -R 777 /mnt/data-postgres-pv")
   ```

3. **Démarrer l'infrastructure**
   ```bash
   cd infrastructure-setup
   vagrant up
   ```

4. **Joindre le worker au cluster**
   - Récupérez la commande `kubeadm join ...` affichée à la fin du provisionnement du master.
   - Exécutez-la sur le worker :
     ```bash
     vagrant ssh k8s-worker01 -c "sudo <coller_la_commande_kubeadm_join_ici>"
     ```

5. **Déployer les applications**
   ```bash
   vagrant ssh k8s-master -c "kubectl apply -f /vagrant/kubernetes-manifests/00-namespace.yaml"
   vagrant ssh k8s-master -c "kubectl apply -f /vagrant/kubernetes-manifests/app-nginx/nginx-deployment-svc.yaml -n clay-technology-prod"
   vagrant ssh k8s-master -c "kubectl apply -f /vagrant/kubernetes-manifests/app-odoo-postgres/odoo-postgres-full.yaml -n clay-technology-prod"
   ```

6. **Vérifier le cluster et l'accès aux apps**
   ```bash
   vagrant ssh k8s-master -c "kubectl get nodes -o wide"
   vagrant ssh k8s-master -c "kubectl get pods -n clay-technology-prod -o wide"
   vagrant ssh k8s-master -c "kubectl get svc -n clay-technology-prod"
   ```
   - Accédez à Nginx/Odoo via l'IP du worker et les NodePorts affichés.

---

## 🧪 Tests & Débogage

- Vérifier les pods système :
  ```bash
  vagrant ssh k8s-master -c "kubectl get pods -n kube-system"
  vagrant ssh k8s-master -c "kubectl get pods -n kube-flannel"
  ```
- Tester le DNS interne :
  ```bash
  vagrant ssh k8s-master -c "kubectl run dns-test --image=busybox:1.28 --rm -it --restart=Never -- nslookup kubernetes.default.svc.cluster.local"
  ```

---

## 🧹 Nettoyage de l'environnement

Pour tout supprimer :
```bash
cd infrastructure-setup
vagrant destroy -f
```

---

## 📖 Rapport technique

- Rapport détaillé : `rapport/Rapport_Integration_Cloud_Kubernetes.md`
- Inclut : choix techniques, schémas, logs, bonnes pratiques, annexes

---

## 🤝 Contribuer

1. Forkez le dépôt
2. Créez une branche : `git checkout -b feature/ma-super-amelioration`
3. Commitez vos changements
4. Pushez et ouvrez une Pull Request

---

## 📝 Licence

Projet sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

---

## ⚠️ Avertissements & Bonnes pratiques

- **Usage pédagogique uniquement**
- **Ne pas utiliser en production sans adaptation**
- **Sécurisez vos mots de passe et accès**
- **Nettoyez les ressources après usage**

---

## 🙏 Remerciements

Merci à tous les contributeurs et à la communauté open source !
