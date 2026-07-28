# Plan de sécurité

| Faiblesse observée | Preuve / emplacement | Risque | Mesure envisagée |
|---|---|---|---|
| Les dépendances ne sont pas analysées. | Aucun scan dans `.gitlab-ci.yml` ; alertes npm consignées dans `documentation/01_audit_veille_recommandations.pdf`. | Une dépendance vulnérable peut être livrée. | Ajouter des scans de dépendances frontend et backend. |
| Le code et les images ne sont pas analysés automatiquement. | `.gitlab-ci.yml` contient uniquement les stages `test` et `build`. | Une faille peut être découverte trop tard. | Ajouter SonarQube et un scan des images dans la CI. |
| Aucun contrôle automatique des secrets n’est configuré. | Aucun job de détection de secrets dans `.gitlab-ci.yml`. | Un futur jeton GitLab ou AWS peut être publié par erreur. | Scanner le dépôt et stocker les secrets dans des variables protégées. |
| Les images de construction utilisent des versions flottantes. | Tags `latest`, `node` et `gradle:jdk17` dans `.gitlab-ci.yml` et `Dockerfile`. | Un build peut changer sans modification du code. | Épingler les versions et tracer les images par SHA et digest. |
| Les conteneurs s’exécutent avec `root`. | Aucune instruction `USER` dans `Dockerfile`. | Une compromission peut disposer de privilèges excessifs. | Utiliser un compte non privilégié. |
| L’API autorise toutes les origines et ne possède pas de contrôle d’accès. | `allowedOrigins("*")` dans `SpringDataRestCustomization.java` ; aucune dépendance Spring Security dans `back/build.gradle`. | Des données peuvent être consultées ou modifiées sans autorisation. | Restreindre CORS et définir l’authentification avant l’exposition publique. |
| Les données ne sont pas persistantes. | HSQLDB déclaré dans `back/build.gradle` ; aucune datasource persistante dans `application.properties`. | Les données disparaissent avec le conteneur. | Définir la persistance, la sauvegarde et la restauration. |
| Le routage et l’état des services ne sont pas vérifiés. | URL `localhost:8080` dans `front/src/app/config.ts`, port `4200` exposé pour le backend et aucun `HEALTHCHECK` dans `Dockerfile`. | Une livraison peut être déclarée réussie alors que l’application est indisponible. | Corriger le routage et ajouter des healthchecks et smoke tests. |
