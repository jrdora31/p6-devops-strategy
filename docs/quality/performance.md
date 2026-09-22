# Performance et DORA

Les métriques DORA suivent la cadence et la stabilité des livraisons du POC.
Le job non bloquant `pages:dora` interroge l'API GitLab avec
`DORA_GITLAB_TOKEN`, puis publie une comparaison de `aws-poc-staging` et
`aws-poc-production` en HTML, JSON et CSV dans `public/`. Les deux
environnements utilisent la même fenêtre de 90 jours. Le suivi des incidents
commence le `2026-08-11T00:00:00Z` (voir
[`dora.yml`](../../.gitlab/ci/dora.yml) et
[`dora_metrics.py`](../../scripts/ci/dora_metrics.py)).

| Indicateur | Calcul dans MicroCRM |
|---|---|
| Fréquence de déploiement | Deployments GitLab réussis dans la période, ramenés à une semaine |
| Délai des changements | Médiane entre la fusion d'une MR et son premier deployment réussi |
| Taux d'échec des changements | Part des deployments réussis reliés à un incident GitLab `dora` par `DORA_DEPLOYMENT_ID` |
| Temps de restauration | Médiane entre création et clôture des incidents suivis dont `DORA_DEPLOYMENT_ID` correspond à un deployment de l'environnement |

Sans échantillon, un indicateur affiche `N/A` plutôt que zéro. Les résultats
dépendent des liens établis dans GitLab et de la déclaration des incidents. Ils
décrivent les environnements logiques staging et production du POC, pas
l'exploitation d'un service de production utilisé par de vrais utilisateurs.

Les métriques d'exploitation et les alarmes CloudWatch sont décrites dans la
[supervision](../Maintenance/supervision.md), distincte des indicateurs DORA.
