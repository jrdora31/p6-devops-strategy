# Performance et DORA

Les métriques DORA suivent la cadence et la stabilité des livraisons du POC.
Le job non bloquant `pages:dora` interroge l'API GitLab avec
`DORA_GITLAB_TOKEN`, puis publie une page HTML et des exports JSON/CSV dans
`public/`. Il s'exécute sur `dev` et lors des pipelines planifiées sur `dev`.
La configuration vise `aws-poc-staging`, sur 90 jours, avec un suivi des
incidents commencé le `2026-08-11T00:00:00Z` (voir
[`dora.yml`](../../.gitlab/ci/dora.yml) et
[`dora_metrics.py`](../../scripts/ci/dora_metrics.py)).

| Indicateur | Calcul dans MicroCRM |
|---|---|
| Fréquence de déploiement | Deployments GitLab réussis dans la période, ramenés à une semaine |
| Délai des changements | Médiane entre la fusion d'une MR et son premier deployment réussi |
| Taux d'échec des changements | Part des deployments réussis reliés à un incident GitLab `dora` par `DORA_DEPLOYMENT_ID` |
| Temps de restauration | Médiane entre création et clôture des incidents suivis |

Sans échantillon, un indicateur reste non mesurable plutôt que de prendre la
valeur zéro. Les résultats dépendent des liens établis dans GitLab et de la
déclaration des incidents. Ils décrivent le POC, pas l'exploitation d'un
service de production réel.

Les métriques d'exploitation et les alarmes CloudWatch sont décrites dans la
[supervision](../Maintenance/supervision.md), distincte des indicateurs DORA.
