# Rollback d'une release

Le rollback applicatif est une promotion explicite de la dernière release
stable connue. Il n'utilise pas un numéro de révision Helm, car ce numéro est
local à un cluster et ne constitue pas une identité de release traçable.

1. Ouvrir **Deploy > Releases** dans GitLab et choisir le tag stable cible.
2. Suivre le lien vers la pipeline de cette release.
3. Relancer `deploy:helm:release:staging` depuis une ancienne RC pour staging,
   ou `deploy:helm:aws` depuis une ancienne finale pour la production.
4. Attendre le job de vérification HTTP associé et contrôler l'environnement
   GitLab.

Le job recharge depuis le Generic Package Registry le manifeste, les digests
et le chart du tag. Un rollback de `v1.1.0` vers `v1.0.0` redéploie donc les
images exactes de `v1.0.0`, sans les reconstruire.

Le rollback Helm ne restaure pas PostgreSQL. Une migration de schéma non
rétrocompatible exige une procédure de restauration de données distincte.
