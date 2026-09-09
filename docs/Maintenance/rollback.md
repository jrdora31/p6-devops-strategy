# Rollback d'une release

Le rollback applicatif est une promotion explicite de la dernière release
stable connue. Il n'utilise pas un numéro de révision Helm, car ce numéro est
local à un cluster et ne constitue pas une identité de release traçable.

1. Ouvrir **Deploy > Releases** dans GitLab et choisir le tag stable cible.
2. Suivre le lien vers la pipeline de cette release.
3. Relancer `deploy:helm:staging:release-or-rollback` depuis une ancienne RC
   pour staging, ou `rollback:helm:production:release` depuis une ancienne
   finale pour la production.
4. Attendre le job de vérification HTTP associé et contrôler l'environnement
   GitLab.

Le job recharge depuis le Generic Package Registry le manifeste, les digests
et le chart du tag. Un rollback de `v1.1.0` vers `v1.0.0` redéploie donc les
images exactes de `v1.0.0`, sans les reconstruire.

Chaque rollback utilise le contexte GitLab Agent commun, mais cible uniquement
le namespace et l'environment GitLab de staging ou de production.

Un ABORT remet le trafic sur la stable qui n'a pas encore été remplacée. Un
rollback redéploie une ancienne finale après qu'une nouvelle version a déjà été
promue stable. Le job de rollback échoue si un Canary existe encore afin de ne
pas mélanger ces deux opérations.

Le rollback Helm ne restaure pas PostgreSQL. Le projet DevOps ne prévoit aucune
évolution de schéma ; Liquibase, déjà présent dans le backend initial, n’est
donc ni ajouté ni étendu. Dans un futur environnement de production, toute
migration de schéma non rétrocompatible devra être versionnée, testée pour sa
compatibilité entre releases et accompagnée d’une procédure de restauration de
données distincte.
