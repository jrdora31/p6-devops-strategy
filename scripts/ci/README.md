# Scripts CI

Ces scripts regroupent les commandes répétitives du projet. Ils sont conçus pour
être lancés avec la même commande sur le poste du développeur et dans un job
GitLab.

| Besoin | Script | Langage | Effet |
|---|---|---|---|
| Dépendances | `dependencies.sh` | Bash | Vérifier ou résoudre les dépendances verrouillées |
| Tests | `test.sh` | Bash | Tester le frontend, le backend ou les deux |
| Builds | `build.sh` | Bash | Construire Angular et/ou le JAR |
| Smoke test | `smoke.sh` | Shell POSIX | Vérifier les images, PostgreSQL, leur communication et la persistance sur un réseau temporaire |
| Backup | `backup.sh` | Bash | Valider le contrat en dry-run en partie 1 |
| Release | `release_manifest.py` | Python | Générer un manifeste reliant version, pipeline, commit et digests |
| Notification | `notify.py` | Python | Normaliser le résultat et, sur demande, appeler un webhook |

Chaque commande accepte `--help`. Elle retourne `0` en cas de succès et un code
différent de zéro en cas d’erreur, ce qui permet à GitLab d'arrêter le job.

## Utilisation dans GitLab

| Script | Utilisation actuelle |
|---|---|
| `dependencies.sh` | Installation frontend et vérification du Gradle Wrapper avant les jobs applicatifs |
| `test.sh` | Jobs `test:frontend` et `test:backend` |
| `build.sh` | Jobs `build:frontend` et `build:backend` |
| `release_manifest.py` | Génération du manifeste après publication d’un tag SemVer |
| `smoke.sh` | Job `verify:images` après la construction et le scan des images |
| `backup.sh` | Dry-run testé ; backup réel réservé au stockage persistant de la partie 2 |
| `notify.py` | Comportement testé sans envoi ; canal réel encore à choisir |

## Commandes Bash

```shell
bash scripts/ci/dependencies.sh --component all --action check
bash scripts/ci/test.sh --component backend
bash scripts/ci/build.sh --component frontend
sh scripts/ci/smoke.sh --frontend-image IMAGE --backend-image IMAGE --database-image POSTGRES_IMAGE
bash scripts/ci/backup.sh --source /data --output /backup/microcrm.tar --dry-run
```

- `dependencies.sh` vérifie ici les fichiers qui verrouillent les dépendances.
- `test.sh` exécute ici les tests du backend.
- `build.sh` construit ici le frontend.
- `smoke.sh` lance PostgreSQL et les deux images applicatives, attend leurs healthchecks, vérifie les UID applicatifs, appelle l’API via le frontend, puis recrée la base et le backend pour confirmer la persistance.
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
  --backend-image "$BACKEND_IMAGE_DIGEST"
```

Cette commande crée un fichier qui relie la version au commit, au pipeline et
aux images publiées dans `.ci/release/release-manifest.json`. Ce chemin fixe
empêche un argument CLI de choisir un autre emplacement du système. Les valeurs
entre `$...` seront fournies par GitLab.

## Notification

```shell
python scripts/ci/notify.py \
  --status success \
  --pipeline-id "$CI_PIPELINE_ID" \
  --pipeline-url "$CI_PIPELINE_URL" \
  --ref "$CI_COMMIT_REF_NAME" \
  --commit "$CI_COMMIT_SHA"
```

Cette commande prépare et affiche le résumé du pipeline sur la sortie standard :
elle n'écrit aucun fichier et n'envoie aucun message par défaut. Le canal et l'envoi réel seront décidés plus tard
dans l'arbitrage `ARB-07`. L'adresse d'un éventuel webhook restera dans une
variable protégée GitLab et ne sera jamais écrite dans le repository.

## Vérification des scripts

```shell
bash scripts/ci/tests/test_scripts.sh
python -m pytest scripts/ci/tests/test_python_scripts.py
shellcheck scripts/ci/*.sh scripts/ci/tests/*.sh
```

- le premier test vérifie les commandes Bash et leurs erreurs attendues ;
- le second vérifie le manifeste, la notification et l’indisponibilité d’un webhook ;
- ShellCheck détecte les erreurs et pratiques fragiles dans les scripts Bash.

Dans GitLab, les tests Python produisent un rapport JUnit consultable depuis la
merge request et le pipeline.
