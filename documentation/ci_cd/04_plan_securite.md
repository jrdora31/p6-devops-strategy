# Plan de sécurité

Ce plan vise à détecter les défauts et vulnérabilités avant la release, protéger
les secrets utilisés par la CI et conserver une preuve de chaque contrôle.

## Risques et traitements

| Faiblesse observée | Preuve / emplacement | Risque | Traitement | État |
|---|---|---|---|---|
| Les dépendances ne faisaient l’objet d’aucun contrôle dédié dans la CI. | 64 alertes npm consignées dans l’audit ; job `quality:trivy:repository` validé dans la pipeline `#2723610499`. | Une dépendance vulnérable peut être livrée. | Scanner les lockfiles à chaque pipeline et lors de la routine planifiée. | Actif ; 12 `HIGH`, 0 `CRITICAL` dans la baseline GitLab |
| L’analyse automatique du code et des images n’était pas complète. | SonarQube et les deux scans Trivy d’images réussissent dans la pipeline `#2723633630`. | Une faille peut être découverte après la publication. | Analyser le code, puis les images construites avant leur publication. | Actif |
| Aucun contrôle automatique des secrets n’était présent dans la CI cible. | Le scanner `secret` de `quality:trivy:repository` n’a trouvé aucun secret dans la pipeline `#2723610499`. | Un secret publié peut compromettre la registry ou un environnement. | Scanner chaque changement et révoquer immédiatement tout secret confirmé. | Actif ; aucun secret détecté |
| Les images utilisées par la CI ne sont pas épinglées par digest. | Tags complets dans `.gitlab/ci/common.yml`, mais aucune référence `@sha256`. | Une image amont peut changer sans modification du repository. | Enregistrer puis utiliser les digests des images CI validées. | Partiel |
| Les images historiques s’exécutaient sans utilisateur non-root explicite. | Les deux Dockerfiles spécialisés déclarent désormais `USER microcrm` ; le Dockerfile historique et sa configuration Supervisor ont été retirés. | Une compromission d’un conteneur privilégié disposerait de droits inutiles. | Conserver un utilisateur dédié dans chaque image et vérifier son identité effective dans la CI. | Configuration traitée ; validation runtime L.4 requise |
| L’API autorisait toutes les origines et ne possède pas de contrôle d’accès. | Les annotations `@CrossOrigin` et `allowedOrigins("*")` ont été retirées ; l’API reste sans Spring Security. | Une API exposée directement reste accessible sans authentification. | Utiliser le reverse proxy même origine et définir l’authentification si l’environnement contient des données sensibles. | CORS traité et testé ; authentification à décider avant exposition |
| Les données étaient stockées dans HSQLDB en mémoire. | PostgreSQL et Liquibase sont configurés dans `back/build.gradle` ; `verify:images` recrée la base et retrouve la donnée avec le même volume. | Un volume supprimé ou un backup inutilisable peut encore entraîner une perte de données. | Conserver le schéma versionné, définir le volume Kubernetes/AWS, puis tester `pg_dump` et le restore en `Q`. | Persistance Docker active ; backup/restore à prouver |
| Le routage et la santé des services n’étaient pas automatisés. | Route frontend `/api`, reverse proxy Caddy vers `backend:8080`, healthchecks dans les deux images et job `verify:images` réussi dans `#2723610499`. | Une release peut être déclarée réussie alors que l’application est indisponible. | Tester le démarrage, la santé et un appel API à travers le frontend. | Actif |
| Les ressources Kubernetes n’avaient aucun contrôle de sécurité automatisé. | Chart `helm/microcrm` déployé sur Minikube ; 9 templates analysés localement par Trivy. | Une configuration trop permissive peut être déployée sur le cluster. | Bloquer les mauvaises configurations `HIGH`/`CRITICAL`, exécuter en non-root, limiter les capabilities et isoler les flux réseau. | Aucun résultat local `HIGH`/`CRITICAL` ; preuve GitLab à obtenir |
| Un script d’automatisation peut recevoir une valeur invalide, exposer un secret ou déclencher une action externe non maîtrisée. | `scripts/ci/` contient les commandes de backup, release et notification ; pipeline `#2721317021`. | Le pipeline peut produire un résultat incorrect, divulguer une donnée ou modifier une cible inattendue. | Valider les paramètres, fixer l’emplacement du manifeste, écrire la notification sur stdout, imposer le dry-run du backup en partie 1, lire les webhooks depuis l’environnement, tester les erreurs et exécuter ShellCheck. | À revalider en CI : 7 tests Bash, 5 tests Python, ShellCheck et analyse SonarQube |

## Contrôles, outils et preuves

| Contrôle | Outil ou job | Fréquence | Critère | Preuve | État |
|---|---|---|---|---|---|
| Analyse du code | SonarQube Cloud — `quality:sonarqube` | Merge requests et `main` | Quality gate réussi | Dashboard SonarQube et pipeline `#2721899884` | Actif |
| Analyse des scripts Bash | ShellCheck — `quality:shellcheck` | MR, `dev`, `main` et tags | Aucun diagnostic | Log GitLab | Actif |
| Tests des scripts | Bash et pytest | MR, `dev`, `main` et tags | Tous les tests réussissent | Logs et rapport JUnit pytest | Actif |
| Dépendances | Trivy — `quality:trivy:repository` | Chaque pipeline et routine planifiée | Baseline recensée puis aucune nouvelle vulnérabilité critique acceptée sans décision | Artifacts JSON et texte de `#2723610499` | Actif |
| Secrets | Trivy — `quality:trivy:repository` | Chaque pipeline et routine planifiée | Aucun secret confirmé | Artifacts JSON et texte de `#2723610499` | Actif |
| Images | Trivy — `release:scan:image:frontend` et `release:scan:image:backend` | MR, `main`, tags et routine planifiée | Aucun secret et aucune vulnérabilité `CRITICAL` corrigible ; les `HIGH` restent visibles | Artifacts JSON et texte de `#2723610499` | Actif |
| Kubernetes/Helm | Helm et Trivy — `test:helm`, `quality:trivy:kubernetes` | Chaque pipeline | Chart valide et aucune mauvaise configuration `HIGH`/`CRITICAL` | Lint/rendu locaux réussis, 9 templates Trivy propres ; artifacts GitLab à obtenir | Local actif ; CI à prouver |
| Infrastructure AWS | Terraform et Trivy — `test:terraform`, `quality:trivy:iac` | Chaque pipeline | Aucune mauvaise configuration `CRITICAL` sans décision documentée | Rapport IaC `#2726980116` : sorties Internet trop larges détectées puis limitées à `80/443` ; exception `AWS-0104` expirant le 1er septembre 2026 | Correction à valider en CI |

SonarJava reçoit les classes compilées, les classes de test, les dépendances
Gradle et les rapports JaCoCo. La pipeline `#2723633630` a validé le quality
gate sans les avertissements de classpath observés lors de la première analyse.

## Inventaire des secrets

Aucune valeur de secret ne doit apparaître dans le repository ou dans les logs.

| Secret ou identité | Usage | Stockage attendu | Droits minimaux | En cas de fuite |
|---|---|---|---|---|
| Identifiants temporaires de registry GitLab | Publier les images | Variables fournies au job GitLab | Push sur la registry du projet | Invalider le job/token et contrôler les images publiées |
| Token SonarQube | Envoyer les analyses | Variable GitLab masquée, non protégée pour être disponible dans les merge requests du repository | Analyse du seul projet MicroCRM | Révoquer puis générer un nouveau token |
| Webhook de notification | Envoyer le statut du pipeline | Variable GitLab masquée | Publication sur le seul canal retenu | Révoquer le webhook et contrôler les messages envoyés |
| Identité AWS | Planifier, provisionner et déployer | Identité temporaire fédérée depuis GitLab | Rôle de plan en lecture seule séparé du rôle d'apply ; confiance limitée au projet et aux branches autorisées | Révoquer la session, auditer CloudTrail et réduire la policy |

## État des variables GitLab

État observé le 31 juillet 2026 :

| Réglage | État |
|---|---|
| `SONAR_TOKEN` | Ajoutée, masquée et non protégée |
| `SONAR_HOST_URL` | Ajoutée, visible et non protégée ; cette URL n’est pas un secret |
| Variables héritées du groupe | Aucune |
| Variables saisies au lancement manuel | Interdites |
| Affichage des variables manuelles | Désactivé |
| Ressources protégées dans les pipelines de MR | Autorisées uniquement lorsque les branches source et cible sont protégées |

La publication actuelle utilise les identifiants temporaires fournis par GitLab. Le token SonarQube est limité à l’analyse de MicroCRM. Les futurs secrets de notification et identités AWS seront protégés et limités à leur usage ; leur disponibilité dans les merge requests ne sera ouverte que si elle est nécessaire et sûre.

La maintenance de ces contrôles relève du maintainer du repository MicroCRM. Les exceptions doivent être documentées avec leur risque, leur responsable et leur date de correction.

## Routine de contrôle

| Déclencheur | Contrôles | Responsable | Preuve |
|---|---|---|---|
| Merge request | Tests, ShellCheck, SonarQube, dépendances, secrets et images | Auteur de la MR ; validation par le maintainer | Pipeline et artifacts |
| Push sur `dev` | Tests, ShellCheck, dépendances et secrets | Maintainer | Pipeline et artifacts |
| Push sur `main` | Tous les contrôles, scans d’images puis publication | Maintainer | Pipeline, artifacts et digests |
| Tag SemVer | Tests, contrôles hors SonarQube, scans d’images et manifeste | Maintainer | Pipeline, artifacts, manifeste et digests |
| Pipeline planifiée | Tests, dépendances, secrets et images sans publication | Maintainer | Pipeline planifiée et artifacts |

La configuration accepte les pipelines planifiées. Leur fréquence doit encore
être créée dans l’interface GitLab après validation du pipeline de ce lot.

## Priorité et politique de blocage

1. un secret confirmé est critique et doit être révoqué avant la merge ;
2. une vulnérabilité critique exploitable dans le code ou une image doit être corrigée ou faire l’objet d’une décision documentée ;
3. les vulnérabilités élevées sont classées après la baseline selon leur exposition et la présence d’un correctif ;
4. une panne du scanner bloque le pipeline, car l’absence de rapport ne vaut pas validation.

Les rapports conservent les vulnérabilités `HIGH` et `CRITICAL`. Après mesure de
la baseline, les jobs ont été configurés pour bloquer tout secret détecté et
toute vulnérabilité `CRITICAL` corrigible. Les vulnérabilités `HIGH` existantes
restent visibles et doivent être suivies sans provoquer une montée majeure non
maîtrisée.

### Baseline Trivy locale du 31 juillet 2026

| Cible | High | Critical | Secret | Décision |
|---|---:|---:|---:|---|
| `front/package-lock.json` | 12 | 0 | 0 détecté | Mise à niveau Angular à planifier ; ne pas masquer les résultats |
| Image frontend avant durcissement | 64 | 6 | Non mesuré séparément | Mettre à jour l’image Caddy avant validation |
| Image frontend durcie | 10 | 0 | 0 détecté | Accepter la baseline `HIGH` et bloquer les secrets et `CRITICAL` |
| Image backend avant durcissement | 37 | 6 | Non mesuré séparément | Mettre à jour le runtime et Spring Boot avant validation |
| Image backend durcie | 3 | 0 | 0 détecté | Accepter la baseline `HIGH` et bloquer les secrets et `CRITICAL` |

Les 12 vulnérabilités concernent Angular 17.3.8 et disposent de correctifs dans
des versions majeures plus récentes. Une montée majeure précipitée n’est pas
intégrée à ce lot : elle nécessite une migration et des tests de régression.

Le durcissement utilise Caddy `2.11.4`, Eclipse Temurin
`21.0.11_10-jre-alpine-3.23` et Spring Boot `3.5.16`. Les images de runtime sont
épinglées par digest. La pipeline GitLab `#2723610499` confirme 12 vulnérabilités
`HIGH` dans le repository, 10 dans l’image frontend et 3 dans l’image backend,
sans vulnérabilité `CRITICAL` ni secret détecté.
