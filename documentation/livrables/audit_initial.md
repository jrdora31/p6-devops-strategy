# Audit initial et recommandations

Baseline : branche `dev`, commit
`526bd96cddd2903676988b56dfeb2778667aa435`, audit du 26 juillet 2026.

Ce document conserve l’état initial utilisé pour concevoir la chaîne actuelle.
Il ne décrit pas le dépôt actuel. Voir le
[workflow CI/CD actuel](../diagrammes/workflow_ci_actuel.md).

## État initial

| Sujet | Observation |
|---|---|
| Pipeline | Deux stages, quatre jobs de test et build |
| Frontend | 8 tests ; couverture lignes 30,76 %, branches 9,52 % |
| Backend | 2 tests |
| Artéfacts | Aucun rapport ou build conservé par GitLab |
| Images | Builds et transmission manuels, sans digest |
| Sécurité | Aucun scan CI ; 64 alertes npm observées |
| Données | HSQLDB en mémoire |
| Runtime | URL d’API locale, CORS permissif, aucun healthcheck |

La capture [workflow CI initial](workflow_ci_initial.svg) représente
cette baseline historique.

## Sources de l’audit

- dépôt et pipeline au commit audité ;
- tests, builds et images reproduits localement ;
- sondages Dev et Ops ;
- sorties npm et configurations runtime.

Les sondages décrivent les pratiques déclarées. Le dépôt et les résultats
exécutés constituent les preuves techniques.

## Besoins identifiés

| Besoin | Origine |
|---|---|
| Détecter plus tôt les défauts de code | Sondage Dev et absence d’analyse continue |
| Scanner dépendances, secrets et images | Audit CI et contrôle manuel déclaré par les Ops |
| Publier des images traçables | Absence de registry dans le flux CI initial |
| Conserver rapports et builds | Aucun artéfact GitLab initial |
| Externaliser la configuration | URL locale et ports incohérents |
| Persister les données | HSQLDB en mémoire |
| Automatiser release et déploiement | Opérations manuelles déclarées |

## Veille et décisions

| Sujet | Options évaluées | Choix MicroCRM | Raison |
|---|---|---|---|
| CI/CD | GitLab CI/CD | GitLab CI/CD modulaire | Plateforme déjà utilisée par le projet |
| Qualité | SonarQube Cloud ou serveur | SonarQube Cloud | Aucun serveur supplémentaire à maintenir |
| Sécurité | Templates GitLab ou Trivy direct | Trivy direct | Utilisable avec le tier GitLab du projet et localement |
| Registry | GitLab Registry ou Amazon ECR | GitLab Container Registry | Images rattachées au dépôt et aux variables CI natives |
| Données | HSQLDB fichier ou PostgreSQL | PostgreSQL | Persistance, migrations et exploitation mieux adaptées |
| Schéma | Initialisation implicite ou migrations | Liquibase | Changelog versionné avec l’application |

Références consultées pendant la veille : documentation officielle de
[GitLab CI/CD](https://docs.gitlab.com/ci/),
[SonarQube Cloud](https://docs.sonarsource.com/sonarqube-cloud/),
[Trivy](https://trivy.dev/docs/),
[PostgreSQL](https://www.postgresql.org/docs/) et
[Liquibase](https://docs.liquibase.com/).

## Recommandations et état actuel

| Recommandation issue de l’audit | État dans le dépôt |
|---|---|
| Modulariser la CI | Réalisé dans `.gitlab/ci/` |
| Conserver rapports et builds | Réalisé avec les artéfacts GitLab |
| Renforcer les tests | Réalisé pour Angular, Java, scripts, images, Helm et IaC |
| Ajouter un quality gate | Réalisé avec SonarQube |
| Scanner dépôt, images et IaC | Réalisé avec Trivy et ShellCheck |
| Publier des images par SHA et digest | Réalisé dans la GitLab Container Registry |
| Externaliser la configuration | Réalisé par variables, Services et ConfigMap |
| Utiliser PostgreSQL et versionner le schéma | Réalisé avec PostgreSQL et Liquibase |
| Automatiser les déploiements | Réalisé pour le POC avec Terraform, Ansible et Helm |
| Automatiser le rollback | Non réalisé |
| Sauvegarder et restaurer PostgreSQL | Non réalisé |
| Envoyer les notifications | Script testé, aucun canal configuré |

Les procédures et limites actuelles sont décrites dans
[`../ci_cd/`](../ci_cd/).
