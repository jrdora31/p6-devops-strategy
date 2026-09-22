# Validation locale des corrections de sécurité — 22 septembre 2026

## Périmètre

Ces contrôles portent sur la branche de travail avant push. Ils complètent les
artefacts GitLab du commit `dd5e87fd`, mais ne les remplacent pas. La validation
définitive devra provenir de la prochaine pipeline.

## Dépendances applicatives

| Composant | Modification | Validation | Résultat |
|---|---|---|---|
| Backend | PostgreSQL JDBC `42.7.11` vers `42.7.12` | `clean`, tests, `bootJar`, `dependencyInsight` | succès ; 8 tests ; version résolue `42.7.12` |
| Frontend | Angular `17.3.8` vers `20.3.31` par migrations majeures successives | tests après chaque majeure, puis test et build finaux | succès ; 14 tests ; build sans avertissement |
| CI frontend | image Cypress avec Node 24 compatible Angular 20 | suite Karma dans l'image CI choisie | succès ; 14 tests |

Couverture frontend finale : 41,30 % statements, 9,52 % branches, 35 %
fonctions et 40,65 % lignes.

## Images finales

Commandes de construction :

```powershell
docker build --pull --no-cache --file misc/docker/frontend.Dockerfile `
  --tag microcrm-frontend:security-check .
docker build --pull --no-cache --file misc/docker/backend.Dockerfile `
  --tag microcrm-backend:security-check .
```

Scans exécutés avec Trivy `0.70.0`, scanners de vulnérabilités, sévérités
HIGH/CRITICAL et `--ignore-unfixed` :

| Cible | HIGH | CRITICAL | Interprétation |
|---|---:|---:|---|
| Backend — paquets Alpine | 0 | 0 | les paquets corrigibles de l'image de base ont été mis à niveau |
| Backend — JAR | 0 | 0 | le pilote PostgreSQL vulnérable n'est plus signalé |
| Frontend — paquets Alpine | 0 | 0 | la couche Alpine du digest Caddy courant est propre à ce seuil |
| Frontend — binaire Caddy | 17 | 0 | bibliothèques Go compilées dans Caddy ; non corrigeables par `apk upgrade` |

Le binaire Caddy contient toujours `CVE-2026-56854`. L'acceptation temporaire
décrite dans [la décision dédiée](CVE-2026-56854-decision.md) reste donc active.
Les autres HIGH Caddy devront être rapprochés du prochain rapport CI et corrigés
ou faire chacun l'objet d'une décision explicite.

## Limite et prochaine preuve

Les tags `microcrm-frontend:security-check` et
`microcrm-backend:security-check` sont des images locales. Après le push, il
faut archiver les rapports des jobs `quality:trivy:repository` et
`release:trivy:image:frontend/backend`, puis vérifier qu'ils correspondent au
nouveau commit et aux images publiées par la CI.
