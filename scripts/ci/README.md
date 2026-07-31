# Scripts CI

Ces scripts regroupent les commandes répétitives du projet. Ils sont conçus pour
être lancés avec la même commande sur le poste du développeur et dans un job
GitLab. GitLab ne les appelle pas encore : leur intégration au pipeline est
prévue après leur validation.

| Besoin | Script | Langage | Effet |
|---|---|---|---|
| Dépendances | `dependencies.sh` | Bash | Vérifier ou résoudre les dépendances verrouillées |
| Tests | `test.sh` | Bash | Tester le frontend, le backend ou les deux |
| Builds | `build.sh` | Bash | Construire Angular et/ou le JAR |
| Backup | `backup.sh` | Bash | Valider le contrat en dry-run en partie 1 |
| Release | `release_manifest.py` | Python | Générer un manifeste reliant version, pipeline, commit et digests |
| Notification | `notify.py` | Python | Normaliser le résultat et, sur demande, appeler un webhook |

Chaque commande accepte `--help`. Elle retourne `0` en cas de succès et un code
différent de zéro en cas d’erreur, ce qui permet à GitLab d'arrêter le job.

## Commandes Bash

```shell
bash scripts/ci/dependencies.sh --component all --action check
bash scripts/ci/test.sh --component backend
bash scripts/ci/build.sh --component frontend
bash scripts/ci/backup.sh --source /data --output /backup/microcrm.tar --dry-run
```

- `dependencies.sh` vérifie ici les fichiers qui verrouillent les dépendances.
- `test.sh` exécute ici les tests du backend.
- `build.sh` construit ici le frontend.
- `backup.sh` simule la future commande de backup sans créer de fichier.

`--component` indique la partie concernée : `frontend`, `backend` ou `all`.

## Manifeste de release

```shell
python scripts/ci/release_manifest.py \
  --version v1.0.0 \
  --commit "$CI_COMMIT_SHA" \
  --pipeline-id "$CI_PIPELINE_ID" \
  --pipeline-url "$CI_PIPELINE_URL" \
  --frontend-image "$FRONTEND_IMAGE_DIGEST" \
  --backend-image "$BACKEND_IMAGE_DIGEST" \
  --output release-manifest.json
```

Cette commande crée un fichier qui relie la version au commit, au pipeline et
aux images publiées. Les valeurs entre `$...` seront fournies par GitLab.

## Notification

```shell
python scripts/ci/notify.py \
  --status success \
  --pipeline-id "$CI_PIPELINE_ID" \
  --pipeline-url "$CI_PIPELINE_URL" \
  --ref "$CI_COMMIT_REF_NAME" \
  --commit "$CI_COMMIT_SHA"
```

Par défaut, cette commande prépare et affiche seulement un résumé du pipeline :
elle n'envoie aucun message. Le canal et l'envoi réel seront décidés plus tard
dans l'arbitrage `ARB-07`. L'adresse d'un éventuel webhook restera dans une
variable protégée GitLab et ne sera jamais écrite dans le repository.
