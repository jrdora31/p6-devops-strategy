# Sauvegarde et restauration

## Périmètre du POC

PostgreSQL conserve les données de chaque environnement sur un volume
persistant K3s. Ce volume permet de les retrouver après un redémarrage du
Pod, mais reste sur le nœud : il ne remplace pas une sauvegarde externe. Le
POC ne comporte ni sauvegarde PostgreSQL automatisée ni procédure de
restauration complète.

Le script `scripts/ci/backup.sh --source PATH --output PATH --dry-run` sert à
vérifier l'interface prévue pour une future sauvegarde. Il contrôle les
arguments et refuse toute exécution sans `--dry-run` ; il ne crée pas
d'archive. La restauration PostgreSQL n'est pas implémentée.

## Production

En production, une stratégie de sauvegarde et de restauration serait
obligatoire : sauvegardes PostgreSQL régulières, stockage chiffré hors du
cluster et de l'EC2, politique de rétention et tests périodiques de
restauration. Les RPO et RTO seraient définis selon le besoin métier.
