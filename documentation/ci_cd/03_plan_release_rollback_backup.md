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

Le pipeline actuel publie sur `main` et sur les tags. Les images sont identifiées par le commit SHA et le job `release:images` produit `.ci/release/images.env`.

L’automatisation SemVer et la génération du manifeste complet restent à intégrer aux scripts de release.

## Déclenchement

| Événement | Contrôles | Publication |
|---|---|---|
| Merge request | Tests et builds | Non |
| `dev` | Tests et builds | Non |
| `main` | Tests et builds | Images identifiées par SHA |
| Tag SemVer | Tests et builds | Release versionnée à finaliser |

## Rollback

Le rollback applicatif consiste à redéployer les digests de la dernière release validée, puis à exécuter les smoke tests.

En partie 1, le pipeline conserve les identifiants nécessaires. Le rollback réel sera exécuté après le deployment Kubernetes en partie 2.

## Backup et restore

Le backup concerne les données persistantes, pas les images déjà conservées dans la registry.

La base actuelle étant éphémère, aucune preuve de backup réelle ne peut encore être produite. La procédure sera définie et testée avec le stockage persistant retenu en partie 2.

## Preuves actuelles

| Preuve | Référence |
|---|---|
| Pipeline de merge request réussi | [Pipeline #2718894672](https://gitlab.com/project_6_group/microcrm/-/pipelines/2718894672) |
| Publication sur `main` réussie | [Pipeline #2719417750](https://gitlab.com/project_6_group/microcrm/-/pipelines/2719417750) |
| Images publiées | Frontend et backend identifiés par le commit `c50f38c28a8e56762703496fca2b1aa858b903c2` |
| Digests conservés | Artifact `.ci/release/images.env` du job `release:images` |
