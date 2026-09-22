# Scripts CI

Les scripts de ce dossier standardisent les commandes exécutées localement et
par [la pipeline GitLab](../../docs/ci-cd/pipeline.md). Ils doivent être lancés
depuis la racine du dépôt, sauf indication contraire.

## Conventions

- Les scripts Bash arrêtent l'exécution dès qu'une commande échoue, qu'une
  variable requise est absente ou qu'un pipeline de commandes échoue.
- `--help` ou `-h` affiche l'aide des scripts disposant d'une interface CLI.
- Les secrets sont fournis par les variables CI/CD GitLab et ne doivent jamais
  être passés en clair dans la ligne de commande.
- Sauf précision ci-dessous, le code `0` indique un succès et un code non nul
  indique une validation refusée ou l'échec d'une commande appelée.

## Vue d'ensemble

| Script | Rôle | Appel principal |
| --- | --- | --- |
| `dependencies.sh` | Vérifie ou installe les dépendances verrouillées | templates des jobs applicatifs |
| `test.sh` | Exécute les tests Angular ou Gradle | `test:frontend`, `test:backend` |
| `build.sh` | Construit les artefacts Angular ou Spring Boot | `build:frontend`, `build:backend` |
| `smoke.sh` | Vérifie les images et la persistance PostgreSQL sur Docker | `verify:images` |
| `smoke_deployment.sh` | Vérifie les workloads et endpoints Kubernetes | `verify:deployment:release:staging` |
| `smoke_production.sh` | Vérifie le NLB, ses targets et les routes HTTP | vérification, promotion, abandon et rollback production |
| `canary.sh` | Déploie, vérifie, promeut, abandonne ou restaure une release | jobs Canary production |
| `semantic_version.mjs` | Calcule les versions RC et finale proposées | `release:suggest:version` |
| `release_manifest.py` | Relie release, commit, pipeline et digests | `release:manifest` |
| `dora_metrics.py` | Produit les rapports DORA HTML, JSON et CSV | `pages:dora` |
| `notify.py` | Formate et envoie éventuellement une notification Slack | jobs de scans et de déploiement |
| `backup.sh` | Valide un contrat de sauvegarde en mode simulation | tests des scripts |
| `common.sh` | Fournit les fonctions partagées aux scripts Bash | chargé avec `source` |

## Installation des dépendances : `dependencies.sh`

```bash
bash scripts/ci/dependencies.sh [--component frontend|backend|all] [--action check|install]
```

| Élément | Détail |
| --- | --- |
| Fonction | Préparer un environnement reproductible à partir des versions de dépendances déjà verrouillées dans le dépôt. |
| Paramètres | `--component` sélectionne la cible, `all` par défaut. `--action check` vérifie les outils et lockfiles ; `install` lance aussi `npm ci` ou la résolution Gradle. |
| Variables | Aucune variable obligatoire. |
| Prérequis | Bash ; Node et npm pour le frontend ; `front/package-lock.json` ; Gradle Wrapper et `back/gradle/wrapper/gradle-wrapper.properties` pour le backend. Un accès au registre des dépendances peut être nécessaire avec `install`. |
| Effets et sorties | `check` n'installe rien. `install` prépare `front/node_modules` ou le cache Gradle sans modifier les versions déclarées. Les versions des outils sont écrites dans les logs. |
| Erreurs | Code `1` si le composant ou l'action est invalide, si un outil/fichier manque ou si npm/Gradle échoue. |

## Tests applicatifs : `test.sh`

```bash
bash scripts/ci/test.sh [--component frontend|backend|all]
```

| Élément | Détail |
| --- | --- |
| Fonction | Détecter les régressions du frontend et du backend avant leur construction, puis produire les rapports exploités par GitLab et SonarQube. |
| Paramètres | `--component` sélectionne `frontend`, `backend` ou `all` ; valeur par défaut : `all`. |
| Variables | `CHROME_BIN` peut indiquer à Karma le chemin du navigateur utilisé en CI. |
| Prérequis | Bash ; npm, `sed` et Chrome headless pour le frontend ; Gradle Wrapper pour le backend ; dépendances déjà installées. |
| Effets et sorties | Lance Karma/Jasmine avec couverture dans `front/coverage/`. Lance les tests Gradle et `prepareSonarAnalysis`, avec rapports sous `back/build/`. Le rapport LCOV est normalisé pour SonarQube. |
| Erreurs | Code `1` pour un composant invalide, un prérequis absent ou un test en échec. |

## Construction : `build.sh`

```bash
bash scripts/ci/build.sh [--component frontend|backend|all]
```

| Élément | Détail |
| --- | --- |
| Fonction | Transformer les sources validées en artefacts applicatifs prêts à être intégrés dans les images Docker. |
| Paramètres | `--component` sélectionne `frontend`, `backend` ou `all` ; valeur par défaut : `all`. |
| Variables | Aucune variable obligatoire. |
| Prérequis | Bash et npm pour Angular ; Gradle Wrapper pour Spring Boot ; dépendances applicatives disponibles. |
| Effets et sorties | Produit le frontend optimisé dans `front/dist/microcrm/` et le JAR exécutable dans `back/build/libs/`. Les images Docker sont construites par des jobs distincts. |
| Erreurs | Code `1` pour un composant invalide, un prérequis absent ou un build Angular/Gradle en échec. |

## Smoke test des images : `smoke.sh`

```bash
sh scripts/ci/smoke.sh \
  --frontend-image IMAGE \
  --backend-image IMAGE \
  --database-image IMAGE
```

| Élément | Détail |
| --- | --- |
| Fonction | Vérifier que les trois images fonctionnent ensemble et que les données PostgreSQL survivent au redémarrage des conteneurs concernés. |
| Paramètres | Les trois références d'images sont obligatoires. |
| Variables | `CI_PIPELINE_ID` est facultative et participe aux noms uniques ; la valeur `local` est utilisée hors CI. |
| Prérequis | Shell POSIX, Docker accessible, images avec healthchecks, `wget` dans le frontend et `id` dans les images applicatives. |
| Effets et sorties | Crée un réseau, un volume et trois conteneurs temporaires. Vérifie les healthchecks, l'exécution non-root, les routes API, l'écriture/lecture d'une personne et la persistance après recréation de PostgreSQL et du backend. Le nettoyage est automatique. |
| Erreurs | Code `1` si un argument ou Docker manque, si un conteneur devient `unhealthy`, si le délai de 60 secondes expire ou si une vérification HTTP/persistance échoue. |

## Smoke test Kubernetes : `smoke_deployment.sh`

```bash
bash scripts/ci/smoke_deployment.sh --namespace NAMESPACE --context KUBE_CONTEXT
```

| Élément | Détail |
| --- | --- |
| Fonction | Confirmer qu'un déploiement Helm est disponible dans Kubernetes avant de poursuivre la livraison. |
| Paramètres | `--namespace` et `--context` sont obligatoires. |
| Variables | Aucune ; les paramètres désignent explicitement la cible. |
| Prérequis | Bash, `kubectl`, accès au contexte Kubernetes et `wget` dans le conteneur frontend. Les ressources doivent porter les labels Helm MicroCRM. |
| Effets et sorties | Attend les rollouts frontend/backend, exige deux replicas et deux endpoints prêts par composant, affiche le nombre de nœuds utilisés, puis teste `/` et `/api/persons` via Caddy. Ne modifie pas le cluster. |
| Erreurs | Code `2` pour une CLI invalide ; code `1` si le déploiement, les replicas, les endpoints ou les probes échouent. Une répartition sur un seul nœud produit un avertissement sans faire échouer le script. |

## Smoke test production : `smoke_production.sh`

```bash
AWS_REGION=eu-west-3 \
NLB_NAME=microcrm-prod \
NLB_TARGET_GROUP_NAME=microcrm-prod \
INGRESS_HOST=microcrm.example.invalid \
bash scripts/ci/smoke_production.sh
```

| Élément | Détail |
| --- | --- |
| Fonction | Confirmer que l'entrée publique de production atteint le frontend et l'API à travers un NLB disposant de deux targets saines. |
| Paramètres | Aucun argument, hors `--help`. |
| Variables | `AWS_REGION`, `NLB_NAME`, `NLB_TARGET_GROUP_NAME` et `INGRESS_HOST` sont obligatoires. Les credentials AWS sont fournis par l'environnement d'exécution. |
| Prérequis | Bash, AWS CLI, `curl`, authentification AWS et droits de lecture ELBv2. |
| Effets et sorties | Résout le DNS du NLB, exige deux targets saines, puis vérifie `/` et `/api/persons` en HTTP avec l'en-tête `Host`. Ne modifie aucune ressource. |
| Erreurs | Code `2` pour un argument ou une variable invalide ; code `1` si AWS ne retourne pas le NLB/deux targets saines ou si une probe HTTP échoue après les tentatives prévues. |

## Cycle Canary : `canary.sh`

```bash
bash scripts/ci/canary.sh deploy|verify|promote|abort|rollback
```

| Action | Effet |
| --- | --- |
| `deploy` | Ajoute la release finale comme Canary et applique les poids `90/10` par défaut. |
| `verify` | Contrôle versions, digests, disponibilité, poids Traefik et routes HTTP des tracks stable et Canary. |
| `promote` | Bascule le trafic sur le Canary, remplace la stable par ses digests puis supprime les workloads Canary. |
| `abort` | Rétablit la stable à 100 % puis supprime les workloads Canary. |
| `rollback` | Redéploie une release finale antérieure comme stable à 100 %, uniquement en l'absence de Canary actif. |

| Élément | Détail |
| --- | --- |
| Fonction | Piloter la mise en production progressive d'une release et permettre sa promotion, son abandon ou son remplacement par une version antérieure. |
| Variables obligatoires | `KUBE_CONTEXT`, `KUBE_NAMESPACE`, `HELM_CHART`, `HELM_VALUES`, `RELEASE_VERSION`, `FRONTEND_IMAGE_DIGEST`, `BACKEND_IMAGE_DIGEST`, `CI_REGISTRY`, `CI_DEPLOY_USER`, `CI_DEPLOY_PASSWORD`, `KUBERNETES_DATABASE_PASSWORD`, `KUBERNETES_MONITORING_PASSWORD`. |
| Variables facultatives | `CANARY_STABLE_WEIGHT` (`90`) et `CANARY_WEIGHT` (`10`) ; leur somme doit valoir `100`. |
| Prérequis | Bash, `kubectl`, Helm, `jq`, `base64`, accès au cluster, chart/values lisibles, release stable existante pour `deploy` et images au format `repository@sha256:...`. |
| Effets et sorties | `deploy`, `promote`, `abort` et `rollback` modifient la release Helm `microcrm` dans le namespace ciblé. `verify` lit le cluster et exécute des probes. Chaque action écrit un résumé avec versions, digests et poids utiles. |
| Erreurs | Code `2` pour une action, variable, version finale ou pondération invalide ; code `1` pour un état Kubernetes/Helm incohérent, un digest mutable, un rollout ou une probe en échec. |

## Version sémantique : `semantic_version.mjs`

Ce fichier est un module Semantic Release, pas une commande autonome.

```json
["./scripts/ci/semantic_version.mjs", {"outputFile": ".ci/release/semantic-version.env"}]
```

| Élément | Détail |
| --- | --- |
| Fonction | Convertir la version proposée par Semantic Release en un tag RC disponible et en son tag final correspondant. |
| Entrées | `context.nextRelease.version` doit être une RC `X.Y.Z-rc.N`. `pluginConfig.outputFile` et `pluginConfig.existingTags` peuvent surcharger les valeurs par défaut. |
| Variables | `SEMANTIC_VERSION_OUTPUT` change le fichier de sortie ; `SEMANTIC_RELEASE_EXISTING_TAGS` fournit les tags RC existants, un par ligne. |
| Prérequis | Node.js et Semantic Release ; historique des tags récupéré par le job appelant. |
| Effets et sorties | Écrit un rapport dotenv contenant `NEXT_RELEASE_VERSION`, `NEXT_RC_VERSION`, `NEXT_RC_TAG` et `NEXT_FINAL_TAG`. Le suffixe RC est relevé pour éviter une collision. |
| Erreurs | Une version hors canal RC lève une exception et fait échouer Semantic Release. Une erreur d'écriture est propagée au processus appelant. |

## Manifeste de release : `release_manifest.py`

```bash
python scripts/ci/release_manifest.py \
  --version v1.2.0-rc.1 \
  --commit COMMIT_SHA \
  --pipeline-id PIPELINE_ID \
  --pipeline-url PIPELINE_URL \
  --frontend-image IMAGE@sha256:DIGEST \
  --backend-image IMAGE@sha256:DIGEST \
  [--source-version v1.2.0-rc.1 --source-commit COMMIT_SHA]
```

| Élément | Détail |
| --- | --- |
| Fonction | Créer une preuve de traçabilité reliant une release à son code source, sa pipeline et ses deux images immuables. |
| Paramètres | Les six premiers paramètres sont obligatoires. `--source-version` et `--source-commit` sont obligatoires ensemble pour une finale et interdits pour une RC. |
| Variables | Aucune variable obligatoire. |
| Prérequis | Python 3 ; exécution depuis la racine pour conserver la sortie dans le dépôt. |
| Effets et sorties | Valide SemVer, SHA et digests puis écrit `.ci/release/release-manifest.json`. Une finale conserve aussi la RC et le commit promus. |
| Erreurs | Code `2` pour une CLI incomplète ; code `1` pour une version, un commit, un digest, une promotion ou un chemin de sortie invalide ; code `0` après écriture. |

## Métriques DORA : `dora_metrics.py`

```bash
python scripts/ci/dora_metrics.py \
  [--environments staging=aws-poc-staging,production=aws-poc-production] \
  [--days 90] [--incident-tracking-start ISO_8601] \
  [--fixture FILE] [--now ISO_8601]
```

| Élément | Détail |
| --- | --- |
| Fonction | Transformer l'historique GitLab du projet en un rapport lisible sur les quatre indicateurs DORA. |
| Paramètres | `--environments` associe les noms logiques aux environnements GitLab ; `--days` fixe la période ; `--incident-tracking-start` borne le calcul d'incidents. `--fixture` remplace l'API par un JSON local et `--now` fige la date des tests. |
| Variables | `DORA_ENVIRONMENTS`, `DORA_PERIOD_DAYS` et `DORA_INCIDENT_TRACKING_START` fournissent les valeurs par défaut. Sans fixture : `DORA_GITLAB_TOKEN`, `CI_API_V4_URL` et `CI_PROJECT_ID` sont obligatoires. |
| Prérequis | Python 3 ; accès à l'API GitLab et token en lecture, sauf avec une fixture. |
| Effets et sorties | Lit deployments, merge requests et incidents, calcule les quatre métriques DORA et écrit `public/index.html`, `public/dora-metrics.json` et `public/dora-metrics.csv`. |
| Erreurs | Code `2` pour une période non positive, une CLI invalide ou des variables API absentes ; code `1` pour un horodatage, une fixture, un mapping, un accès API ou une écriture invalide ; code `0` après génération. |

## Notification : `notify.py`

```bash
python scripts/ci/notify.py \
  --status success|failed|canceled|running \
  [--event pipeline|deployment|vulnerability|rollback] \
  [--job JOB] \
  --pipeline-id ID --pipeline-url URL --ref REF --commit SHA \
  [--send-webhook-env NOM_VARIABLE]
```

| Élément | Détail |
| --- | --- |
| Fonction | Uniformiser les messages de statut de la CI et les transmettre à Slack lorsqu'un webhook est configuré. |
| Paramètres | Statut, identifiant/URL de pipeline, ref et commit sont obligatoires. L'événement vaut `pipeline` par défaut. `--send-webhook-env` reçoit le nom de la variable du webhook, jamais son URL. |
| Variables | Seule la variable désignée par `--send-webhook-env` est lue, par exemple `SLACK_WEBHOOK_URL`. |
| Prérequis | Python 3. Un accès réseau au webhook est nécessaire uniquement pour l'envoi. |
| Effets et sorties | Écrit toujours le payload JSON sur stdout. Sans `--send-webhook-env`, aucun appel réseau n'est effectué ; avec l'option, le payload est envoyé à Slack. |
| Erreurs | Code `2` pour des arguments absents ou hors liste ; code `1` si la variable du webhook manque, si le service est indisponible ou refuse la requête ; code `0` après génération/envoi. |

## Contrat de sauvegarde : `backup.sh`

```bash
bash scripts/ci/backup.sh --source PATH --output PATH --dry-run
```

| Élément | Détail |
| --- | --- |
| Fonction | Vérifier qu'une demande de sauvegarde contient une source et une destination cohérentes, sans créer d'archive. |
| Paramètres | `--source`, `--output` et `--dry-run` sont obligatoires ; source et sortie doivent être différentes. |
| Variables | Aucune. |
| Prérequis | Bash. Les chemins sont validés comme chaînes ; aucune archive n'est lue ou écrite. |
| Effets et sorties | Valide l'interface de sauvegarde et écrit un résumé de simulation dans les logs. |
| Erreurs | Code `1` si une option manque, si les chemins sont identiques, si un argument est inconnu ou si `--dry-run` est absent. |

## Fonctions partagées : `common.sh`

```bash
source scripts/ci/common.sh
```

| Élément | Détail |
| --- | --- |
| Fonction | Éviter la duplication des contrôles, des chemins et du format des logs dans les autres scripts Bash. |
| Interface | Expose `CI_SCRIPT_DIR`, `REPOSITORY_ROOT`, `log_info`, `log_error`, `die`, `require_command`, `require_file` et `validate_component`. |
| Variables | Calcule les chemins à partir de l'emplacement du fichier ; aucune variable externe requise. |
| Prérequis | Bash. Ce fichier doit être chargé, pas exécuté comme une commande métier. |
| Effets et sorties | Active `set -Eeuo pipefail`, normalise les logs et centralise les contrôles de prérequis. |
| Erreurs | `die` termine avec le code `1` ; les contrôles appellent `die` lorsqu'un outil, un fichier ou un composant est invalide. |

## Scripts de test

### `tests/test_scripts.sh`

```bash
bash scripts/ci/tests/test_scripts.sh
```

| Élément | Détail |
| --- | --- |
| Fonction | Détecter rapidement une régression dans les interfaces CLI et les garde-fous des scripts Bash. |
| Prérequis | Bash, `mktemp`, Node/npm et fichiers Gradle nécessaires au contrôle `dependencies.sh --action check`. |
| Effets et sorties | Teste les aides CLI, les dépendances, le dry-run de sauvegarde et plusieurs refus attendus. Utilise puis supprime un dossier temporaire. Affiche un compteur réussite/échec. |
| Erreurs | Code `0` si tous les scénarios passent ; code non nul dès qu'au moins une assertion échoue. |

### Tests Python

```bash
python -m pip install -r scripts/ci/requirements-test.txt
python -m pytest scripts/ci/tests/ --junitxml=.ci/reports/scripts-python.xml
```

| Fichier | Fonction | Entrées et effets | Erreurs |
| --- | --- | --- | --- |
| `test_python_scripts.py` | Vérifier les interfaces, sorties et erreurs de `release_manifest.py` et `notify.py`. | Utilise des SHA, digests et webhooks factices ; isole les écritures dans les dossiers temporaires pytest. | pytest retourne un code non nul si une sortie, un code retour ou une règle de sécurité diffère. |
| `test_dora_metrics.py` | Vérifier la collecte, les calculs, les exports et la protection des chemins DORA. | Utilise des fixtures locales ; génère HTML/JSON/CSV dans un dossier temporaire, sans appel GitLab. | pytest échoue si une métrique, un export ou le confinement des chemins régresse. |
| `test_infrastructure_configuration.py` | Détecter une régression dans les choix critiques Terraform, Ansible, Helm et CI. | Lit uniquement les fichiers versionnés ; ne lance ni plan Terraform, ni rendu Helm, ni déploiement AWS. | pytest échoue si une configuration critique attendue disparaît. |
| `test_canary_configuration.py` | Détecter une régression dans le cycle Canary, les digests, les poids et les métriques. | Lit les fichiers CI, Helm, Terraform et monitoring ; ne contacte aucun cluster. | pytest échoue si un invariant Canary ou monitoring régresse. |

La dépendance de test est fixée dans `requirements-test.txt`. Les fichiers de
test Python n'acceptent ni argument métier ni variable obligatoire.

### `tests/test_semantic_version.mjs`

```bash
node --test scripts/ci/tests/test_semantic_version.mjs
```

| Élément | Détail |
| --- | --- |
| Fonction | Vérifier que le calcul des tags RC et la génération du rapport dotenv restent compatibles avec la pipeline. |
| Prérequis | Node.js avec le runner `node:test`. |
| Effets et sorties | Vérifie les tags RC/final, les collisions de suffixes, le refus d'une version finale en entrée et le contenu du rapport dotenv. Le fichier de test est créé dans un dossier temporaire système. |
| Erreurs | Code `0` si tous les tests passent ; code non nul si une assertion ou une écriture échoue. |

## Documentation associée

- [Stratégie de déploiement](../../docs/ci-cd/deployment-strategy.md)
- [Démarrer MicroCRM](../../docs/GET-STARTED.md)
- [Bootstrap initial](../bootstrap/bootstrap.md)
