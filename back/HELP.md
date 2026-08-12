# Backend MicroCRM

API REST Spring Boot avec Spring Data JPA, PostgreSQL et migrations Liquibase.
Les tests utilisent HSQLDB.

## Build et tests

Sous Linux :

```shell
./gradlew test
./gradlew build
```

Sous Windows :

```powershell
.\gradlew.bat test
.\gradlew.bat build
```

Les rapports sont générés dans `build/reports/tests/test/` et
`build/reports/jacoco/test/`.

## Exécution avec PostgreSQL

Définir les variables suivantes avant de lancer le JAR :

```text
SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/microcrm
SPRING_DATASOURCE_USERNAME=microcrm
SPRING_DATASOURCE_PASSWORD=<valeur-locale>
```

```shell
java -jar build/libs/microcrm-0.0.1-SNAPSHOT.jar
```

Liquibase applique le changelog
`src/main/resources/db/changelog/db.changelog-master.yaml`. Hibernate valide
ensuite le schéma avec `spring.jpa.hibernate.ddl-auto=validate`.

Le démarrage complet de PostgreSQL, du backend et du frontend est documenté
dans [`../README.md`](../README.md).
