# Chart Helm MicroCRM

Ce chart déploie le frontend, le backend et PostgreSQL dans Kubernetes.

## Ressources créées

| Composant | Ressources | Accès |
|---|---|---|
| Frontend | Deployment et Service | Seul composant exposé par l'Ingress |
| Backend | Deployment, Service et ConfigMap | Accessible depuis le frontend |
| PostgreSQL | StatefulSet, Service et volume persistant | Accessible depuis le backend |
| Réseau | NetworkPolicies | Limite les flux entrants vers le backend et PostgreSQL |

Les Deployments utilisent des rolling updates. Chaque conteneur possède des
startup, readiness et liveness probes, des ressources minimales et un
`securityContext`. Les credentials PostgreSQL ne sont pas stockés dans le
repository ; la CI les transmet au chart depuis des variables GitLab protégées.
Le chart fournit à Caddy l'adresse du Service backend avec la variable
`BACKEND_ADDRESS` ; aucune adresse IP ni aucun nom de release n'est intégré à
l'image.

## Values disponibles

- `values.yaml` : valeurs communes ;
- `values-minikube.yaml` : images locales et Ingress Nginx ;
- `values-k3s.yaml` : valeurs historiques communes au POC K3s ;
- `values-staging.yaml` : environnement d'intégration déployé depuis `dev` ;
- `values-production.yaml` : environnement promu par tag SemVer.

Les valeurs `frontend.image.tag` et `backend.image.tag` doivent identifier les
images à déployer. En CI/CD ou sur AWS, un digest immuable peut être fourni avec
`frontend.image.digest` et `backend.image.digest`.

## Validation locale

Depuis la racine du repository :

```shell
helm lint helm/microcrm --values helm/microcrm/values-minikube.yaml
helm template microcrm helm/microcrm \
  --namespace microcrm \
  --values helm/microcrm/values-minikube.yaml
```

Ces commandes ne déploient rien. Les jobs `test:helm` et
`quality:trivy:kubernetes` exécutent les mêmes contrôles dans GitLab CI.

## Déploiement Minikube

Prérequis : Docker Desktop avec au moins 6 Go de mémoire, Minikube, `kubectl`
et Helm 3.

```shell
minikube start --profile microcrm --driver=docker --cpus=2 --memory=4096
minikube --profile microcrm addons enable ingress

docker build --file misc/docker/frontend.Dockerfile --tag microcrm-frontend:local .
docker build --file misc/docker/backend.Dockerfile --tag microcrm-backend:local .

minikube --profile microcrm image load microcrm-frontend:local
minikube --profile microcrm image load microcrm-backend:local
minikube --profile microcrm image load \
  postgres:17.10-alpine3.23@sha256:8189a1f6e40904781fc9e2612687877791d21679866db58b1de996b31fc312e4

kubectl create namespace microcrm --dry-run=client --output=yaml | kubectl apply -f -
kubectl --namespace microcrm create secret generic microcrm-database \
  --from-literal=username=microcrm \
  --from-literal=password='<valeur-secrete>' \
  --dry-run=client --output=yaml | kubectl apply -f -

helm upgrade --install microcrm helm/microcrm \
  --namespace microcrm \
  --values helm/microcrm/values-minikube.yaml \
  --wait \
  --timeout 5m
```

Vérification :

```shell
kubectl --namespace microcrm get pods,services,pvc,ingress
kubectl --namespace ingress-nginx wait \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s
```

Pour vérifier le routage Ingress sans modifier le fichier `hosts`, ouvrir un
port-forward vers son contrôleur :

```shell
kubectl --namespace ingress-nginx port-forward service/ingress-nginx-controller 18081:80
```

Puis, depuis un second terminal :

```shell
curl.exe --header "Host: microcrm.local" http://127.0.0.1:18081/
curl.exe --header "Host: microcrm.local" http://127.0.0.1:18081/api/persons
```

Le port-forward direct suivant reste utile pour diagnostiquer le frontend sans
passer par l’Ingress :

```shell
kubectl --namespace microcrm port-forward service/microcrm-microcrm-frontend 8080:80
```

Le frontend est alors accessible directement sur `http://127.0.0.1:8080`.
L'arrêt
`minikube stop --profile microcrm` conserve le cluster et ses données locales.

## Diagnostic et retrait de la release

```shell
helm status microcrm --namespace microcrm
helm history microcrm --namespace microcrm
kubectl --namespace microcrm describe pod <nom-du-pod>
kubectl --namespace microcrm logs <nom-du-pod>
```

Pour retirer uniquement les ressources gérées par Helm :

```shell
helm uninstall microcrm --namespace microcrm
```

Cette commande ne supprime pas automatiquement le namespace ni tous les volumes
persistants. Leur suppression doit rester une action explicite afin d'éviter une
perte de données involontaire.

## Gestion des Secrets

Pour un déploiement local, le namespace cible doit contenir un Secret nommé
`microcrm-database` avec les clés `username` et `password`. Il reste créé hors
du repository :

```shell
kubectl --namespace microcrm create secret generic microcrm-database \
  --from-literal=username=microcrm \
  --from-literal=password='<valeur-secrete>' \
  --dry-run=client --output=yaml | kubectl apply -f -
```

Pour K3s/AWS, `deploy:helm:staging` utilise le kubeconfig injecté par le GitLab
Agent et déploie le contenu de `dev` dans `microcrm-staging` pendant une
pipeline Web autorisée, après provisionnement de l'infrastructure éphémère.
`deploy:helm:aws` déploie la production dans `microcrm-prod` uniquement après
validation manuelle d'un tag SemVer. Les deux jobs génèrent le Secret Registry
depuis le deploy token GitLab et le Secret PostgreSQL depuis la variable
protégée `KUBERNETES_DATABASE_PASSWORD`. Les valeurs sensibles ne sont ni
versionnées ni conservées comme artifacts du pipeline.
