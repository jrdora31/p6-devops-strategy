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

### Vérifier la répartition Canary 90/10

Pour un contrôle visuel rapide de la campagne stable `v1.3.1` / Canary
`v1.4.0`, ouvrir cette URL puis la rafraîchir plusieurs fois :

```text
http://microcrm.example.invalid/api/deployment-info?test=123
```

Une page HTTP 404 correspond à la stable `v1.3.1`, où l'endpoint est absent ;
une réponse JSON contenant `"track":"canary"` et `"version":"v1.4.0"`
correspond au Canary. Utiliser `Ctrl+F5` ou modifier `test=` pour éviter le
cache. Plusieurs réponses stables successives restent normales : 10 % ne
signifie pas qu'exactement un rafraîchissement sur dix sera Canary. Cette
distinction par code HTTP est propre à ces deux versions.

Pour un contrôle quantifié et réutilisable, pendant la fenêtre Canary et avant
`promote` ou `abort`, compter le track retourné par 100 requêtes indépendantes.
Les deux versions testées doivent alors exposer `/api/deployment-info`.

```powershell
$nlbDns = aws elbv2 describe-load-balancers --region eu-west-3 `
  --names microcrm-poc-nlb --query 'LoadBalancers[0].DNSName' --output text

1..100 | ForEach-Object {
  $body = curl.exe --fail --silent --show-error `
    -H 'Host: microcrm.example.invalid' `
    "http://$nlbDns/api/deployment-info?test=$_"
  ($body | ConvertFrom-Json).track
} | Group-Object | Select-Object Count, Name
```

Le résultat attendu est proche de `90 stable / 10 canary`, sans garantie d'un
compte exact sur chaque série. Ce test observe le routage Traefik via le NLB ;
il ne prouve ni la répartition entre les EC2 ni une affinité de session. La
[première campagne v1.4.0](evidence/performance/TESTS_MICROCRM_2026-09-16.md)
utilisait les codes HTTP, car l'endpoint était absent de la stable `v1.3.1`.

Depuis un contexte Kubernetes autorisé, vérifier que les Pods applicatifs
sont prêts avec `kubectl -n microcrm-prod get pods,deploy,svc,ingress` ou,
pour staging, `kubectl -n microcrm-staging get pods,deploy,svc,ingress`.

Pour vérifier l'instrumentation des échecs d'authentification, appeler
`/api/internal/auth-check` depuis un Pod frontend avec des identifiants Basic
volontairement invalides. Le résultat attendu est HTTP 401, suivi de
l'incrément `AuthenticationFailureCount` dans CloudWatch avec les dimensions
attendues. Ne jamais afficher ni archiver le mot de passe utilisé.
