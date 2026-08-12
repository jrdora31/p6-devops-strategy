# Conception initiale et état de mise en œuvre

Ce document conserve les règles retenues après l’audit initial. La capture
[CI/CD cible initiale](workflow_ci_cible_initiale.svg) représente la
conception de cette période, pas l’état actuel.

## Conventions retenues

- `dev` sert de branche d’intégration ; `main` est la branche par défaut.
- Les changements passent par une merge request avant intégration.
- Les releases utilisent des tags SemVer `vX.Y.Z`.
- Les images applicatives portent le SHA du commit et sont déployées par digest.
- Les secrets restent dans les variables GitLab ou les Secrets Kubernetes.
- Les commandes partagées sont placées dans `scripts/ci/` et testées.
- Le pipeline bloque les contrôles définis comme obligatoires.

Les protections de branche, approbations et droits GitLab sont des réglages de
plateforme. Leur présence doit être vérifiée dans GitLab ; le dépôt seul ne les
prouve pas.

## Architecture CI/CD retenue

| Stage | Responsabilité |
|---|---|
| `test` | Tests applicatifs, scripts, Helm, Terraform et Ansible |
| `quality` | SonarQube, ShellCheck et scans Trivy |
| `build` | Build Angular, JAR et archives d’images |
| `release` | Scans d’images, publication, chart, manifeste et release GitLab |
| `deploy` | Terraform, Ansible et Helm |
| `verify` | Smoke test des images et publication DORA |

La configuration est répartie dans `.gitlab/ci/` par responsabilité. Les
templates cachés de `common.yml` mutualisent les images, caches et préparations
réutilisées. Les dépendances entre jobs sont déclarées avec `needs`.

Voir le [workflow actuel](../diagrammes/workflow_ci_actuel.md) pour les règles de
déclenchement.

## Compatibilité technique

| Composant | Configuration du dépôt |
|---|---|
| Frontend | Angular 17, Node 20 dans la CI, Karma/Jasmine |
| Backend | Spring Boot, Gradle Wrapper, JDK 21 dans la CI, cible Java 17 |
| Qualité | SonarQube Scanner avec rapports LCOV et JaCoCo |
| Images | Docker-in-Docker, runtimes frontend/backend séparés |
| Kubernetes | Helm 3, tests Minikube et déploiement K3s |
| Infrastructure | Terraform, Ansible et AWS OIDC |

Les versions exactes appartiennent aux fichiers de dépendances et aux images CI.
Elles ne sont pas recopiées ici afin d’éviter une seconde source de vérité.

## État de réalisation

| Lot conçu | État | Référence |
|---|---|---|
| Tests et builds | Réalisé | `.gitlab/ci/test.yml`, `build.yml` |
| Scripts partagés | Réalisé | `scripts/ci/` |
| Qualité et sécurité | Réalisé | `.gitlab/ci/quality.yml`, `iac.yml`, `release.yml` |
| Images et releases | Réalisé | `.gitlab/ci/release.yml` |
| Infrastructure AWS | Versionnée et déjà exécutée | `infrastructure/terraform/`, `ansible/` |
| Déploiement Kubernetes | Versionné et déjà exécuté | `helm/microcrm/`, `.gitlab/ci/deploy.yml` |
| Monitoring | Versionné ; reconstruction complète encore à observer | Terraform et rôle Ansible CloudWatch |
| DORA | Réalisé et publié avec GitLab Pages | `.gitlab/ci/dora.yml` |
| Rollback | Non automatisé | Limite documentée |
| Backup et restore | Non réalisés | `backup.sh` reste un dry-run |

## Risques encore ouverts

- le POC AWS est mono-nœud et éphémère ;
- PostgreSQL utilise un volume local au nœud K3s ;
- l’application ne configure pas TLS ni authentification applicative ;
- le rollback et la restauration des données ne sont pas prouvés ;
- certaines images de jobs CI utilisent des tags sans digest ;
- les coûts et quotas AWS doivent être contrôlés avant chaque session.
