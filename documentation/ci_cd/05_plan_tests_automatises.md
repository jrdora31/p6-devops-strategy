# Plan de tests automatisés

## Tests existants

| Composant | Type de test | Ce qui est vérifié | Fréquence | Critère de validation | Preuve |
|---|---|---|---|---|---|
| Frontend Angular | Tests unitaires de composants | Création des composants, titre de l’application et rendu principal | À chaque merge request et push sur `dev` ou `main` | Tous les tests réussissent | Couverture HTML et `front/coverage/microcrm/lcov.info` |
| Frontend Angular | Tests unitaires de services | Initialisation des services avec un client HTTP simulé | À chaque merge request et push sur `dev` ou `main` | Tous les tests réussissent | Résultat du job `test:frontend` |
| Backend Spring | Test de contexte | Démarrage du contexte Spring | À chaque merge request et push sur `dev` ou `main` | Le contexte démarre sans erreur | Rapport JUnit |
| Backend Spring | Test d’intégration repository | Écriture puis recherche d’une personne par adresse e-mail | À chaque merge request et push sur `dev` ou `main` | La donnée obtenue correspond à la donnée enregistrée | Rapport JUnit et couverture JaCoCo |
| Scripts Bash | Tests fonctionnels des commandes | Aide, dépendances verrouillées, dry-run et refus des paramètres dangereux | À chaque merge request et push sur `dev` ou `main` | 7 tests réussissent | Log du job `test:scripts:bash` |
| Scripts Python | Tests unitaires | Manifeste SemVer, notification locale, erreurs de webhook et absence de fuite | À chaque merge request et push sur `dev` ou `main` | 5 tests réussissent | Rapport JUnit pytest |
| Scripts Bash | Analyse statique | Erreurs et pratiques dangereuses détectées par ShellCheck | À chaque merge request et push sur `dev` ou `main` | Aucun diagnostic ShellCheck | Log du job `quality:shellcheck` |
| Application full-stack | Analyse statique SonarQube | Bugs, vulnérabilités, security hotspots, code smells, duplication et couverture | À chaque merge request et sur `main` | Quality gate réussi | Dashboard SonarQube et job `quality:sonarqube` |

## Tests à ajouter

| Test prévu | Besoin couvert | Étape du pipeline | Critère de validation |
|---|---|---|---|
| Requêtes HTTP des services Angular | Vérifier les URL, méthodes et données échangées | `test` | Requêtes attendues et réponses simulées conformes |
| Opérations CRUD de l’API Spring | Vérifier le comportement métier exposé par l’API | `test` | Création, lecture, modification et suppression conformes |
| Scan des dépendances | Détecter les dépendances vulnérables | `quality` | Aucune nouvelle vulnérabilité bloquante selon la politique retenue |
| Détection de secrets | Empêcher la publication d’un secret | `quality` | Aucun secret confirmé dans le repository |
| Scan Trivy des images | Détecter les vulnérabilités des images construites | `release` | Aucune nouvelle vulnérabilité bloquante selon la politique retenue |
| Smoke test des images | Vérifier que les conteneurs démarrent et répondent | `verify` | Frontend et API joignables, healthchecks réussis |
| Parcours full-stack critique | Vérifier la communication frontend–backend | `verify` | Un enregistrement peut être créé puis consulté |

Les seuils SonarQube et de vulnérabilités seront définis après mesure de la baseline. Une anomalie acceptée devra être justifiée et suivie ; elle ne sera pas masquée pour obtenir artificiellement un pipeline vert.

Le plan SonarQube Cloud Free analyse les merge requests et la branche principale `main`. Les pipelines directs sur `dev` conservent les tests applicatifs et les autres contrôles, mais n’exécutent pas SonarQube. Les changements doivent donc passer par une merge request avant leur intégration ; l’analyse complète de référence est produite sur `main`.
