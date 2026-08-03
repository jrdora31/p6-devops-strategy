# Plan de tests automatisés

## Tests existants

| Composant | Type de test | Ce qui est vérifié | Fréquence | Critère de validation | Preuve |
|---|---|---|---|---|---|
| Frontend Angular | Tests unitaires de composants | Création des composants, titre de l’application et rendu principal | MR, `dev`, `main` et tags | Tous les tests réussissent | Couverture HTML et `front/coverage/microcrm/lcov.info` |
| Frontend Angular | Tests HTTP des services | Initialisation des services, méthodes, URL, payloads et réponses simulées | MR, `dev`, `main`, tags et routine planifiée | Tous les tests réussissent et aucune requête simulée ne reste ouverte | Résultat du job `test:frontend` |
| Backend Spring | Test de contexte | Démarrage du contexte Spring | MR, `dev`, `main` et tags | Le contexte démarre sans erreur | Rapport JUnit |
| Backend Spring | Test d’intégration repository | Écriture puis recherche d’une personne par adresse e-mail | MR, `dev`, `main` et tags | La donnée obtenue correspond à la donnée enregistrée | Rapport JUnit et couverture JaCoCo |
| Backend Spring | Test CRUD de l’API | Création, lecture, modification et suppression d’une personne via HTTP | MR, `dev`, `main`, tags et routine planifiée | Les statuts HTTP et les données retournées sont conformes | Rapport JUnit et couverture JaCoCo |
| Scripts Bash | Tests fonctionnels des commandes | Aide, dépendances verrouillées, dry-run et refus des paramètres dangereux | MR, `dev`, `main` et tags | 7 tests réussissent | Log du job `test:scripts:bash` |
| Scripts Python | Tests fonctionnels | Manifeste SemVer, notification locale, erreurs de webhook et absence de fuite | MR, `dev`, `main` et tags | 5 tests réussissent | Rapport JUnit pytest |
| Scripts Bash | Analyse statique | Erreurs et pratiques dangereuses détectées par ShellCheck | MR, `dev`, `main` et tags | Aucun diagnostic ShellCheck | Log du job `quality:shellcheck` |
| Application full-stack | Analyse statique SonarQube | Bugs, vulnérabilités, security hotspots, code smells, duplication et couverture | À chaque merge request et sur `main` | Quality gate réussi | Dashboard SonarQube et job `quality:sonarqube` |
| Images frontend et backend | Smoke test full-stack | Healthchecks, utilisateurs non-root, réseau Docker, appel API, création et recherche d’une personne via Caddy vers Spring | MR, `dev`, `main`, tags et routine planifiée | Deux conteneurs `healthy`, UID différents de `0` et parcours create/read réussi | Log du job `verify:images` |

## Règles bloquantes

Le quality gate SonarQube, les tests, ShellCheck, tout secret détecté et les
vulnérabilités Trivy `CRITICAL` corrigibles bloquent la pipeline. Les
vulnérabilités `HIGH` restent dans les rapports afin d’être corrigées
progressivement. Une anomalie acceptée doit être justifiée et suivie ; elle ne
doit pas être masquée pour obtenir artificiellement une pipeline verte.

Le seuil de couverture SonarQube reste fixé à 80 % sur le nouveau code
applicatif Angular et Java. Les scripts CI sont exclus uniquement de ce calcul :
ils restent analysés par SonarQube et contrôlés par pytest, Bash et ShellCheck.

Le plan SonarQube Cloud Free analyse les merge requests et la branche principale `main`. Les pipelines directs sur `dev` conservent les tests applicatifs et les autres contrôles, mais n’exécutent pas SonarQube. Les changements doivent donc passer par une merge request avant leur intégration ; l’analyse complète de référence est produite sur `main`.

## Exécution selon l’événement GitLab

| Événement | Tests applicatifs et scripts | SonarQube | Build | Release |
|---|---|---|---|---|
| Merge request | Oui | Oui | Oui | Non |
| Push sur `dev` | Oui | Non | Oui | Non |
| Push sur `main` | Oui | Oui | Oui | Publication des images |
| Tag SemVer | Oui | Non | Oui | Publication des images et manifeste |
| Pipeline planifiée | Oui | Non | Oui | Scans du repository et des images, sans publication |

Une pipeline échoue dès qu’un test ou un contrôle bloquant retourne un code non
nul. Les rapports sont conservés même lorsque les jobs de test échouent afin de
permettre le diagnostic.

## Frameworks retenus

| Composant | Framework | Justification |
|---|---|---|
| Frontend Angular | Karma et Jasmine | Outils déjà présents dans le projet Angular et adaptés aux composants et services |
| Backend Spring | JUnit 5, Spring Test et MockMvc | Vérifient les repositories, le contexte Spring et l’API HTTP sans service externe |
| Scripts Bash | Script de tests Bash et ShellCheck | Vérifient les commandes et l’analyse statique sans ajouter de framework lourd |
| Scripts Python | pytest | Adapté aux fonctions Python et capable de produire un rapport JUnit pour GitLab |

Chaque framework reste associé à son composant ; les tests applicatifs ne sont
pas réécrits artificiellement dans un langage unique.
