# Plan de release, rollback et backup

## Release

Une release doit permettre de relier sans ambiguïté le code, le pipeline et les images déployables.

| Élément | Règle |
|---|---|
| Version fonctionnelle | Tag Git au format SemVer, par exemple `v1.2.0` |
| Identité technique | Commit SHA ayant produit les images |
| Identité déployable | Digest immuable de chaque image |
| Registry | GitLab Container Registry du repository |
| Manifest | Version, commit, pipeline et digests frontend/backend |

Le pipeline publie sur `main` et sur les tags SemVer. Les images sont identifiées par le commit SHA et le job `release:images` produit `.ci/release/images.env`.

Sur un tag SemVer, `release:manifest` doit ensuite appeler `release_manifest.py` et conserver `.ci/release/release-manifest.json`. L’exécution distante de ce chemin devra être prouvée avec le premier tag de release.

## Déclenchement

| Événement | Contrôles | Publication |
|---|---|---|
| Merge request | Tests et builds | Non |
| `dev` | Tests et builds | Non |
| `main` | Tests et builds | Images identifiées par SHA |
| Tag SemVer | Tests, builds et manifeste | Images et manifeste de release |

## Responsabilités et contrôles

| Opération | Prérequis | Contrôle final | Responsable |
|---|---|---|---|
| Release | Pipeline vert et tag SemVer | Images, digests et manifeste présents | Maintainer GitLab |
| Rollback | Manifeste d’une release précédente validée | Smoke tests après redéploiement | Maintainer du déploiement |
| Backup | Stockage persistant disponible | Restore exécuté sur une cible contrôlée | Maintainer de l’infrastructure |

## Rollback

Le rollback applicatif consiste à sélectionner le manifeste de la dernière release validée, redéployer ses digests, puis exécuter les smoke tests. En cas d’échec des smoke tests, le déploiement reste déclaré en échec et nécessite une intervention.

En partie 1, le pipeline conserve les identifiants nécessaires. Le rollback réel sera exécuté après le deployment Kubernetes en partie 2.

## Backup et restore

Le backup concerne les données persistantes, pas les images déjà conservées dans la registry.

La base actuelle étant éphémère, aucune preuve de backup réelle ne peut encore être produite. `backup.sh --dry-run` vérifie uniquement les paramètres et les garde-fous. La création du backup et le restore seront définis et testés avec le stockage persistant retenu en partie 2.

## Preuves actuelles

| Preuve | Référence |
|---|---|
| Pipeline de merge request réussi | [Pipeline #2718894672](https://gitlab.com/project_6_group/microcrm/-/pipelines/2718894672) |
| Publication sur `main` réussie | [Pipeline #2719417750](https://gitlab.com/project_6_group/microcrm/-/pipelines/2719417750) |
| Images publiées | Frontend et backend identifiés par le commit `c50f38c28a8e56762703496fca2b1aa858b903c2` |
| Digests conservés | Artifact `.ci/release/images.env` du job `release:images` |
| Pipeline complète avant clôture | [Pipeline de MR #2723633630](https://gitlab.com/project_6_group/microcrm/-/pipelines/2723633630) |
| Validation post-merge sur `dev` | [Pipeline #2723639714](https://gitlab.com/project_6_group/microcrm/-/pipelines/2723639714) |

La référence finale sera remplacée par la pipeline `main`, ses digests et le
manifeste du premier tag SemVer après validation de la partie 1.
