# Scripts CI

Les jobs de [la pipeline](../../docs/ci-cd/pipeline.md) appellent ces scripts
pour tester l'application, préparer les images, livrer les releases et
contrôler les déploiements. Les options détaillées et les codes de retour
restent dans chaque script.

| Script | Rôle | Appel principal |
|---|---|---|
| `build.sh --component frontend|backend|all` | Construit Angular ou JAR Gradle | `build:frontend`, `build:backend` |
| `test.sh --component frontend|backend|all` | Tests Angular ou Gradle | `test:frontend`, `test:backend` |
| `dependencies.sh` | Installe/vérifie les dépendances Node ou wrapper Gradle | templates des jobs applicatifs |
| `smoke.sh` | Démarre images frontend/backend et PostgreSQL sur réseau Docker isolé, vérifie santé et parcours API | `verify:images` |
| `smoke_deployment.sh` | Vérifie Deployments, Pods et endpoints staging via Kubernetes | `verify:deployment:release:staging` |
| `smoke_production.sh` | Vérifie NLB, targets saines et réponses HTTP avec Host production | `verify:production:canary` et décisions |
| `canary.sh` | Déploiement, vérification, promotion ou abandon ; contrôle versions, digests, tracks et poids Helm | jobs canary/rollback |
| `release_manifest.py` | Produit le manifeste de release avec tag, commit, images et digests | `release:manifest` |
| `semantic_version.mjs` | Suggestion de version RC en dry-run, sans création de tag | `release:suggest:version` |
| `dora_metrics.py` | API GitLab deployments/MR/incidents → HTML, JSON, CSV `public/` | `pages:dora` |
| `notify.py` | Formate des événements pour webhook Slack si configuré | jobs de déploiement/scans |
| `common.sh` | Journalisation et validations partagées par les scripts Bash | `source` dans scripts concernés |
| `backup.sh` | Contrôle `--source`, `--output`, `--dry-run` ; **aucune archive réelle** | manuel/test uniquement |

Les tests des scripts sont dans [`tests/`](tests/). Le comportement des jobs
et la réutilisation des images sont décrits dans la
[pipeline](../../docs/ci-cd/pipeline.md) ; le passage d'une version à une
autre figure dans la [stratégie](../../docs/ci-cd/deployment-strategy.md).
