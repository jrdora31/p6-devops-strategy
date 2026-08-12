# Release, rollback et sauvegarde

## Créer une release

Prérequis : droits de création de tag et pipeline de la branche à publier
réussie.

```shell
git tag -a v1.2.0 -m "MicroCRM v1.2.0"
git push origin v1.2.0
```

Un tag conforme à SemVer déclenche les opérations suivantes :

1. construction et scan des images frontend et backend ;
2. publication dans la GitLab Container Registry avec le tag
   `CI_COMMIT_SHA` ;
3. écriture des digests dans `.ci/release/images.env` ;
4. génération de `.ci/release/release-manifest.json` ;
5. création de la release GitLab par `release:create` ;
6. mise à disposition du job manuel `deploy:helm:aws`.

Le déploiement production du POC utilise le chart de la pipeline et les digests
des images. Il cible l’environnement `aws-poc-production` et le namespace
`microcrm-prod` du cluster K3s.

Vérifier dans GitLab :

- la pipeline du tag est réussie ;
- la release existe dans `Deploy > Releases` ;
- `release-manifest.json` contient la version, le commit, la pipeline et les
  deux digests ;
- le job `deploy:helm:aws`, s’il est lancé, termine avec succès.

Le fonctionnement global et les conditions des autres événements sont décrits
dans le [workflow CI/CD actuel](../diagrammes/workflow_ci_actuel.md).

## Rollback applicatif

Aucun job de rollback dédié n’est implémenté. Le chart accepte des digests
d’image, mais la procédure de redéploiement d’une ancienne release n’est pas
automatisée ni validée de bout en bout.

Avant tout rollback, identifier une release antérieure dont le manifeste et les
deux images sont encore disponibles. Ne pas remplacer un seul composant sans
vérifier leur compatibilité.

La reprise est considérée comme stable seulement après :

- le succès de `helm upgrade --install --atomic --wait` avec les anciens
  digests ;
- la disponibilité des workloads ;
- un appel fonctionnel via le frontend.

Cette procédure reste une limite connue tant qu’un rollback réel n’a pas été
exécuté et documenté.

## Sauvegarde et restauration

| Élément | Mécanisme actuel | Limite |
|---|---|---|
| Code et configuration | Git | Permet de reconstruire, pas de restaurer les données |
| Infrastructure | Terraform et Ansible | Reproductibilité, pas sauvegarde |
| Images | GitLab Container Registry | Artefacts applicatifs, pas sauvegarde des données |
| Données PostgreSQL | PVC Kubernetes `local-path` | Persistance locale au nœud, sans sauvegarde externe |
| Script `backup.sh` | Validation des arguments avec `--dry-run` | Ne crée aucune archive |

Aucune sauvegarde PostgreSQL exploitable ni procédure de restauration n’est
implémentée. La persistance vérifiée par `verify:images` couvre la recréation de
conteneurs avec un même volume Docker ; elle ne couvre ni `pg_dump`, ni la perte
du volume ou du nœud EC2.
