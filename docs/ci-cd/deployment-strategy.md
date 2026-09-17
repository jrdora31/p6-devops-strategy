# Stratégie de release et de promotion

MicroCRM valide une release candidate (RC) en staging avant de déployer sa
finale en production. Les images validées sont réutilisées sans reconstruction
lors du passage d'un environnement à l'autre ; le fonctionnement des
pipelines et de **Build Once, Promote Many** est décrit dans la
[pipeline CI/CD](pipeline.md).

## De la RC à la release finale

1. Une RC issue de `dev` est déployée en staging avec
   `deploy:helm:staging:release-or-rollback` pour validation.
2. Après validation et merge vers `main`, le maintainer crée la release
   finale en indiquant sa RC source avec `Promote-From` ; les digests des
   images restent ceux de la RC validée.
Une finale peut ensuite être introduite en production par le Canary décrit
ci-dessous.

## Canary de production

Le Canary permet de tester une nouvelle version sur une partie du trafic
production tout en conservant la version stable. Une RC se déploie uniquement
en staging ; après sa promotion en finale avec `Promote-From`, le job manuel
`deploy:helm:production:canary` introduit la nouvelle version à côté de la
stable existante.

Le trafic est réparti à 90 % vers la stable et à 10 % vers le Canary par
défaut. L'implémentation de ce routage dans Kubernetes est décrite dans
[Helm](../infrastructure/helm.md).

Une version stable doit déjà être déployée en production avec ses images par
digest : `deploy:helm:production:canary` ne peut pas installer la première
stable à lui seul. Celle-ci peut être installée depuis la pipeline d'une
release finale avec `rollback:helm:production:release`.

- `deploy:helm:production:canary` conserve la stable courante et ajoute la
  nouvelle version sur une partie du trafic.
- `verify:production:canary` vérifie automatiquement le déploiement après ce
  job ; ses contrôles sont détaillés dans les [tests](../quality/testing.md).
  Ce contrôle immédiat ne remplace pas l'observation du Canary décrite dans
  la [supervision](../Maintenance/supervision.md).
- `promote:helm:production:canary` route d'abord 100 % vers le Canary, le
  teste, reprend ses digests et sa version pour la stable, attend la mise à
  jour progressive (`RollingUpdate`), remet stable à 100 %, puis retire le
  Canary.
- `abort:helm:production:canary` remet la stable existante à 100 %, la teste,
  puis retire le Canary sans modifier la stable.

Après promotion, revenir à une ancienne release nécessite un
[rollback applicatif](../Maintenance/rollback.md), distinct de l'abandon d'un
Canary. Il ne restaure pas les données PostgreSQL ; leur périmètre est décrit
dans [Sauvegarde et restauration](../Maintenance/backup-recovery.md).
