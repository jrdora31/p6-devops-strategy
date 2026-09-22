# Mettre MicroCRM en ligne

Ce guide décrit le chemin réellement implémenté dans ce dépôt : préparer
GitLab et AWS, créer le cluster K3s partagé, déployer une RC en staging, puis
promouvoir les mêmes images en production.

> Le bootstrap IAM/OIDC et GitLab n'est pas automatisé. Les scripts de
> [`scripts/bootstrap/`](../scripts/bootstrap/bootstrap.md) sont des squelettes
> qui s'arrêtent sans créer de ressource. La première configuration doit donc
> être réalisée manuellement.

## 1. Prérequis

- accès Maintainer au projet GitLab `project_6_group/microcrm` ;
- compte AWS autorisant la gestion des ressources décrites dans
  [`infrastructure/aws/gitlab-apply-policy.json`](../infrastructure/aws/gitlab-apply-policy.json) ;
- région AWS `eu-west-3` ;
- un GitLab Runner Docker en ligne avec le tag `local-docker` et compatible
  Docker-in-Docker ;
- Git en local ; AWS CLI est utile uniquement pour contrôler le compte et
  retrouver le DNS du NLB. Terraform, Ansible, Helm et `kubectl` sont exécutés
  par la CI et ne sont pas requis localement.

```bash
git --version && aws --version && aws sts get-caller-identity
```

Le déploiement crée notamment deux EC2, leurs volumes, un NLB et des ressources
annexes. Vérifier les coûts applicables au compte AWS avant l'apply.

## 2. Cloner le projet

```bash
git clone https://gitlab.com/project_6_group/microcrm.git
cd microcrm
git switch dev
```

Le chemin du projet et le contexte Agent sont actuellement codés pour
`project_6_group/microcrm`. Un fork sous un autre namespace nécessite d'adapter
la configuration de l'Agent et les valeurs `KUBE_CONTEXT` de la CI.

## 3. Préparer AWS et GitLab

Effectuer ces actions une seule fois, dans cet ordre.

### 3.1 Créer les accès AWS OIDC

Dans AWS :

1. créer la confiance OIDC GitLab avec l'audience `https://gitlab.com` ;
2. créer un rôle de lecture pour les plans Terraform ;
3. créer un rôle d'écriture pour les apply Terraform, Ansible et les contrôles
   du NLB ;
4. limiter leur trust policy au projet et aux références GitLab nécessaires ;
5. noter leurs ARN.

Le dépôt fournit un modèle des permissions d'apply dans
[`gitlab-apply-policy.json`](../infrastructure/aws/gitlab-apply-policy.json),
mais aucune trust policy ni policy complète du rôle de plan. Ces éléments sont
des prérequis externes : il n'existe pas de commande fiable dans le dépôt pour
les créer automatiquement.

### 3.2 Préparer le projet GitLab

1. vérifier que le Container Registry et le Package Registry sont disponibles ;
2. vérifier que le runner `local-docker` prend les jobs du projet ;
3. protéger `dev`, `main` et les tags `v*` lorsque les variables ci-dessous
   sont protégées ;
4. créer dans GitLab un Agent Kubernetes nommé exactement `microcrm-poc`, puis
   conserver son token pour `GITLAB_AGENT_TOKEN` ;
5. créer un Deploy Token ayant au minimum la lecture du Container Registry.

La configuration versionnée de l'Agent autorise les environnements
`aws-poc-staging` et `aws-poc-production` dans
[`config.yaml`](../.gitlab/agents/microcrm-poc/config.yaml). Ansible installera
l'Agent dans K3s lors du premier déploiement d'infrastructure.

### 3.3 Ajouter les variables CI/CD

Créer ces variables dans GitLab sans jamais les écrire dans le dépôt :

| Variable | Valeur attendue | Utilisation |
|---|---|---|
| `AWS_PLAN_ROLE_ARN` | ARN du rôle OIDC de lecture | plans Terraform |
| `AWS_APPLY_ROLE_ARN` | ARN du rôle OIDC d'écriture | apply, Ansible et vérifications AWS |
| `GITLAB_AGENT_TOKEN` | token de l'Agent `microcrm-poc` | installation de l'Agent par Ansible |
| `CI_DEPLOY_USER` | utilisateur du Deploy Token | pull des images par Kubernetes |
| `CI_DEPLOY_PASSWORD` | secret du Deploy Token | pull des images par Kubernetes |
| `KUBERNETES_DATABASE_PASSWORD` | mot de passe PostgreSQL à créer | Secret de chaque namespace |
| `KUBERNETES_MONITORING_PASSWORD` | mot de passe Basic Auth à créer | endpoint de métriques |

Les secrets doivent être masqués et protégés. Leur scope doit couvrir les jobs
qui les consomment ; en particulier `KUBERNETES_MONITORING_PASSWORD` doit être
disponible pour `aws-poc-staging` et `aws-poc-production`, ou avoir le scope
`*`.

Variables complémentaires réellement utilisées :

- `SONAR_TOKEN` pour l'analyse Sonar des merge requests et de `main` ; la
  destination Sonar est une configuration externe au dépôt ;
- `SLACK_WEBHOOK_URL`, facultative, pour les notifications ;
- `DORA_GITLAB_TOKEN`, pour le job `pages:dora` sur `dev` (push ou pipeline
  planifiée), pas pour le déploiement.

`CI_REGISTRY`, `CI_REGISTRY_USER`, `CI_REGISTRY_PASSWORD`, `CI_JOB_TOKEN` et
les autres variables `CI_*` sont fournies par GitLab. Ne pas les recréer.

## 4. Créer l'infrastructure AWS et K3s

Dans GitLab, lancer une pipeline manuelle **Run pipeline** sur la branche
`dev`.

Valeurs disponibles dans le formulaire :

- `CLOUDWATCH_AGENT_ENABLED=false` par défaut ; passer à `true` pour créer les
  logs, métriques, dashboards et alarmes CloudWatch ;
- `ALERT_EMAIL` peut rester vide ; si elle est renseignée avec CloudWatch
  activé, confirmer ensuite l'abonnement SNS reçu par e-mail ;
- conserver `TF_DESTROY_CONFIRM=false` pendant la création.

La pipeline Web ne construit ni ne déploie l'application. Elle exécute ce
parcours :

1. `quality:terraform:network:plan` produit le plan du state
   `microcrm-network` ;
2. contrôler ce plan, puis lancer manuellement
   `deploy:terraform:network:apply` ;
3. `quality:terraform:plan` prépare alors le state `microcrm-poc` ;
4. `deploy:terraform:apply` crée automatiquement les deux EC2 et le NLB ;
5. `deploy:ansible:check`, puis `deploy:ansible:apply`, configurent le serveur
   et l'agent K3s, Traefik et l'Agent GitLab.

Attendre le succès de `deploy:ansible:apply`. Les deux states sont stockés dans
GitLab ; aucun fichier `terraform.tfstate` local n'est nécessaire.

> Si d'anciens states `microcrm-staging` ou `microcrm-production` possèdent déjà
> des ressources du POC, ne pas relancer l'apply : leur migration vers
> `microcrm-poc` n'est pas automatisée.

## 5. Construire une RC et déployer staging

1. intégrer le code validé sur `dev` avec des Conventional Commits ;
2. attendre le succès de la pipeline de push `dev` : elle teste, scanne,
   construit et publie les images sous le SHA du commit ;
3. lancer le job manuel `release:suggest:version` et lire `NEXT_RC_TAG` dans
   son rapport dotenv ; ce job ne crée aucun tag ;
4. créer exactement le tag proposé sur le commit `dev` validé :

   ```bash
   git switch dev
   git pull --ff-only origin dev
   git tag vX.Y.Z-rc.N
   git push origin vX.Y.Z-rc.N
   ```

5. dans la pipeline du tag RC, attendre `release:bundle`, puis lancer
   `deploy:helm:staging:release-or-rollback` ;
6. attendre le succès automatique de
   `verify:deployment:release:staging`.

Staging utilise le namespace `microcrm-staging` et l'hôte
`microcrm-staging.example.invalid`.

## 6. Promouvoir la RC en production

Après validation de staging :

1. fusionner `dev` dans `main` et attendre les contrôles de `main` ;
2. créer sur `main` un tag final annoté de même version, avec la ligne
   `Promote-From` exacte :

   ```bash
   git switch main
   git pull --ff-only origin main
   git tag -a vX.Y.Z -m "Promote-From: vX.Y.Z-rc.N"
   git push origin vX.Y.Z
   ```

3. attendre le succès de `release:bundle`. La pipeline vérifie la RC source et
   réutilise ses digests `repository@sha256` sans reconstruire les images.

Pour la **toute première mise en production**, lancer
`rollback:helm:production:release` dans la pipeline du tag final. Malgré son
nom, ce job sait installer cette release comme première stable à 100 %. Le job
Canary exige qu'une stable existe déjà.

Pour les versions suivantes :

1. lancer `deploy:helm:production:canary` ;
2. attendre le succès automatique de `verify:production:canary` ;
3. [contrôler la répartition 90 % stable / 10 %
   Canary](quality/testing.md#verifier-la-repartition-canary-9010) ;
4. lancer `promote:helm:production:canary` pour passer la nouvelle version à
   100 %, ou `abort:helm:production:canary` pour conserver l'ancienne stable.

Production utilise le namespace `microcrm-prod` et l'hôte
`microcrm.example.invalid`.

## 7. Vérifier l'accès public

Récupérer le DNS du NLB :

```bash
aws elbv2 describe-load-balancers --region eu-west-3 \
  --names microcrm-poc-nlb \
  --query 'LoadBalancers[0].DNSName' --output text
```

Puis tester la production avec le routage réellement configuré :

```bash
curl --fail --header 'Host: microcrm.example.invalid' http://<DNS_DU_NLB>/
curl --fail --header 'Host: microcrm.example.invalid' http://<DNS_DU_NLB>/api/persons
```

Le dépôt expose actuellement HTTP sur le NLB, sans domaine public réel ni TLS.
Les noms `*.example.invalid` sont réservés à la documentation : ouvrir
directement le DNS du NLB dans un navigateur ne correspond pas à l'hôte attendu
par Traefik. Un accès utilisateur par URL publique exige donc encore un domaine,
un enregistrement DNS et une configuration TLS ; cette étape n'est pas
implémentée dans le dépôt.

## 8. Repères et arrêt du POC

- fonctionnement détaillé : [pipeline CI/CD](ci-cd/pipeline.md) ;
- stratégie RC/production : [déploiement](ci-cd/deployment-strategy.md) ;
- infrastructure : [Terraform](infrastructure/terraform.md),
  [Ansible](infrastructure/ansible.md) et [Helm](infrastructure/helm.md) ;
- retour arrière : [rollback](Maintenance/rollback.md).

Pour détruire le cluster et le NLB, lancer une nouvelle pipeline Web sur `dev`
avec `TF_DESTROY_CONFIRM=true`, puis confirmer manuellement
`deploy:terraform:destroy`. Ce job détruit le state `microcrm-poc` mais conserve
le réseau partagé `microcrm-network`.
