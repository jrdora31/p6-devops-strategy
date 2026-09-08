# Sauvegarde et restauration

## Périmètre du POC

Le POC MicroCRM ne met volontairement en place aucune sauvegarde PostgreSQL
automatisée ni procédure de restauration complète. Le volume persistant du
cluster ne constitue pas une sauvegarde externe.

## Production

En production, une stratégie de sauvegarde et de restauration serait
obligatoire : sauvegardes PostgreSQL régulières, stockage chiffré hors du
cluster et de l'EC2, politique de rétention et tests périodiques de
restauration. Les RPO et RTO seraient définis selon le besoin métier.
