# Tests et validations

Les contrôles CI détectent les régressions avant la publication d'une image
ou le déploiement d'une release. Les jobs sont regroupés par composant dans
[`test.yml`](../../.gitlab/ci/test.yml) :

| Périmètre | Jobs | Ce qu'ils vérifient |
|---|---|---|
| Application | `test:frontend`, `test:backend` | Tests Angular avec Chrome et tests Gradle/JUnit |
| Scripts | `test:scripts:bash`, `test:scripts:python` | Comportement des scripts CI |
| Déploiement | `test:helm`, `test:terraform`, `test:ansible` | Validité du chart et des configurations d'infrastructure |

[`test.sh`](../../scripts/ci/test.sh) lance les tests applicatifs ; les suites
des scripts sont dans [`scripts/ci/tests`](../../scripts/ci/tests/). En
complément, `quality:shellcheck` vérifie le shell et `quality:sonarqube`
analyse la qualité du code. Les rapports et la couverture se consultent dans
les jobs concernés.

Les smoke tests contrôlent ensuite le fonctionnement de la version livrée :
`smoke.sh` démarre les images avec PostgreSQL, `smoke_deployment.sh` vérifie
staging, et `smoke_production.sh` ainsi que `canary.sh` contrôlent la
production. Les jobs `verify:deployment:release:staging` et
`verify:production:canary` relient ces vérifications aux déploiements de
release.

Voir la [pipeline](../ci-cd/pipeline.md) pour les déclencheurs et la
[sécurité](security.md) pour les scans.

## Vérifications après déploiement

`verify:production:canary` contrôle automatiquement les rollouts, Pods,
versions, digests, Services internes stable/Canary et l'entrée NLB normale.
Il vérifie les réponses des deux tracks via leurs Services, puis le parcours
HTTP de production. Le contrôle immédiat ne constitue pas une période
d'observation ; les métriques à consulter sont décrites dans la
[supervision](../Maintenance/supervision.md).

Depuis un contexte Kubernetes autorisé, vérifier que les Pods applicatifs
sont prêts avec `kubectl -n microcrm-prod get pods,deploy,svc,ingress` ou,
pour staging, `kubectl -n microcrm-staging get pods,deploy,svc,ingress`.

Pour vérifier l'instrumentation des échecs d'authentification, appeler
`/api/internal/auth-check` depuis un Pod frontend avec des identifiants Basic
volontairement invalides. Le résultat attendu est HTTP 401, suivi de
l'incrément `AuthenticationFailureCount` dans CloudWatch avec les dimensions
attendues. Ne jamais afficher ni archiver le mot de passe utilisé.
