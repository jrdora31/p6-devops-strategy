# Plan de sécurité

## Risques et traitements

| Faiblesse observée | Preuve / emplacement | Risque | Traitement | État |
|---|---|---|---|---|
| Les dépendances ne font l’objet d’aucun contrôle dédié dans la CI. | Aucun job de scan dans `.gitlab/ci/` ; 64 alertes npm consignées dans l’audit. | Une dépendance vulnérable peut être livrée. | Ajouter les scans des dépendances frontend et backend. | À faire |
| L’analyse automatique du code et des images n’est pas encore entièrement validée. | Le job `quality:sonarqube` est configuré dans `.gitlab/ci/quality.yml` ; aucun job Trivy n’est encore présent. | Une faille peut être découverte après la publication. | Valider SonarQube dans GitLab puis ajouter Trivy avant la publication des images. | SonarQube configuré, validation CI à faire ; Trivy à faire |
| Aucun contrôle automatique des secrets n’est présent dans la CI cible. | Aucun job de détection de secrets dans `.gitlab/ci/`. | Un secret publié peut compromettre la registry ou un environnement. | Scanner le repository et révoquer immédiatement tout secret exposé. | À faire |
| Les images utilisées par la CI ne sont pas épinglées par digest. | Tags complets dans `.gitlab/ci/common.yml`, mais aucune référence `@sha256`. | Une image amont peut changer sans modification du repository. | Enregistrer puis utiliser les digests des images CI validées. | Partiel |
| Tous les conteneurs ne sont pas encore non privilégiés. | `USER microcrm` dans `misc/docker/backend.Dockerfile` ; aucun `USER` explicite dans l’image frontend. | Une compromission peut disposer de privilèges excessifs. | Vérifier l’utilisateur runtime de Caddy et imposer un compte non privilégié lorsque nécessaire. | Partiel |
| L’API autorise toutes les origines et ne possède pas de contrôle d’accès. | `allowedOrigins("*")` dans `SpringDataRestCustomization.java` ; aucune dépendance Spring Security. | Des données peuvent être consultées ou modifiées sans autorisation. | Restreindre CORS et définir l’authentification avant l’exposition publique. | À faire |
| Les données ne sont pas persistantes. | HSQLDB dans `back/build.gradle` ; aucune datasource persistante configurée. | Les données disparaissent avec le conteneur. | Définir la persistance, le backup et le restore. | Partie 2 |
| Le routage et la santé des services ne sont pas automatisés. | URL `localhost:8080` dans le frontend et aucun healthcheck dans les images runtime. | Une release peut être déclarée réussie alors que l’application est indisponible. | Externaliser la route API, ajouter des healthchecks et automatiser les smoke tests. | À faire |
| Un script d’automatisation peut recevoir une valeur invalide, exposer un secret ou déclencher une action externe non maîtrisée. | `scripts/ci/` contient les commandes de backup, release et notification ; pipeline `#2721317021`. | Le pipeline peut produire un résultat incorrect, divulguer une donnée ou modifier une cible inattendue. | Valider les paramètres, imposer le dry-run du backup en partie 1, lire les webhooks depuis l’environnement, tester les erreurs et exécuter ShellCheck. | Validé en CI : 7 tests Bash, 5 tests Python et ShellCheck |

## Inventaire des secrets

Aucune valeur de secret ne doit apparaître dans le repository ou dans les logs.

| Secret ou identité | Usage | Stockage attendu | Droits minimaux | En cas de fuite |
|---|---|---|---|---|
| Identifiants temporaires de registry GitLab | Publier les images | Variables fournies au job GitLab | Push sur la registry du projet | Invalider le job/token et contrôler les images publiées |
| Token SonarQube | Envoyer les analyses | Variable GitLab masquée et protégée | Analyse du seul projet MicroCRM | Révoquer puis générer un nouveau token |
| Webhook de notification | Envoyer le statut du pipeline | Variable GitLab masquée | Publication sur le seul canal retenu | Révoquer le webhook et contrôler les messages envoyés |
| Identité AWS | Provisionner et déployer | Identité temporaire fédérée depuis GitLab | Rôle limité aux ressources MicroCRM | Révoquer la session, auditer CloudTrail et réduire la policy |

## État des variables GitLab

État observé le 31 juillet 2026 :

| Réglage | État |
|---|---|
| Variables CI/CD du projet | Aucune |
| Variables héritées du groupe | Aucune |
| Variables saisies au lancement manuel | Interdites |
| Affichage des variables manuelles | Désactivé |
| Ressources protégées dans les pipelines de MR | Autorisées uniquement lorsque les branches source et cible sont protégées |

La publication actuelle utilise les identifiants temporaires fournis par GitLab. Les tokens SonarQube, notification et AWS devront être ajoutés ultérieurement comme variables masquées et protégées.

La maintenance de ces contrôles relève du maintainer du repository MicroCRM. Les exceptions doivent être documentées avec leur risque, leur responsable et leur date de correction.
