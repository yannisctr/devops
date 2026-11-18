# TP DevOps · Liste de tâches

Nginx sert l’interface web. Apache/PHP reçoit les appels API et stocke les tâches dans MySQL. DEV tourne avec Docker Compose. VAL et PROD tournent dans deux namespaces Minikube avec des volumes MySQL distincts.

Lancer les commandes depuis la racine du dépôt.

## DEV

Sur le poste du TP, Docker nécessite `sudo`. Sur un poste qui a déjà accès à Docker, retirer `sudo`.

```bash
sudo docker compose up -d --build --wait
```

Ouvrir http://127.0.0.1:8080 avec le port par défaut. Pour arrêter DEV et conserver les tâches :

```bash
sudo docker compose stop
```

## VAL et PROD

Ces commandes ouvrent les applications déjà déployées sur le Minikube du poste du TP. Utiliser un terminal par environnement.

### VAL

```bash
source scripts/minikube-env.sh &&
  kubectl --context tp-devops -n val port-forward svc/frontend 8081:80
```

Ouvrir http://127.0.0.1:8081.

### PROD

```bash
source scripts/minikube-env.sh &&
  kubectl --context tp-devops -n prod port-forward svc/frontend 8082:80
```

Ouvrir http://127.0.0.1:8082. Appuyer sur **Ctrl+C** dans le terminal pour fermer l’accès web. Le cluster et les données restent disponibles.

## Démonstration et suivi

Créer une tâche avec une priorité et une échéance, puis actualiser la page. Modifier la tâche, la terminer, vérifier la recherche, le filtre et le compteur, puis la supprimer. VAL et PROD réutilisent les mêmes images locales.

La CI construit les images et vérifie l’application. Les preuves de la validation initiale figurent dans la PR de promotion. La publication Docker Hub reste à vérifier. Les neuf fonctionnalités du socle ont été préparées avec Codex. Les contributions des étudiants sont à tracer dans leurs propres PR. [GitHub Actions](https://github.com/yannisctr/tp_devops/actions) · [Validation et promotion](https://github.com/yannisctr/tp_devops/pull/1)
