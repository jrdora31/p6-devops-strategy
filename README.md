<p align="center">
  <img src="./front/src/favicon.png" width="192" alt="MicroCRM" />
</p>

# MicroCRM

MicroCRM est un monorepo de démonstration composé d’un frontend Angular, d’un
backend Spring Boot et d’une base PostgreSQL. Il gère des personnes rattachées à
des organisations.

## Composants

| Composant | Chemin | Technologie | Port local |
|---|---|---|---:|
| Frontend | `front/` | Angular, Caddy en conteneur | `4200` en développement, `80` en conteneur |
| Backend | `back/` | Spring Boot, Liquibase | `8080` |
| Base | chart Helm ou image officielle | PostgreSQL 17 | `5432` |

Le frontend appelle l’API avec `/api`. Caddy transmet cette route au backend.

## Démarrage local

### Backend et PostgreSQL

Prérequis : Docker et JDK compatible avec le Gradle Wrapper.

```shell
docker volume create microcrm-postgres
docker run --detach --name microcrm-postgres \
  --publish 5432:5432 \
  --env POSTGRES_DB=microcrm \
  --env POSTGRES_USER=microcrm \
  --env POSTGRES_PASSWORD=microcrm-local \
  --volume microcrm-postgres:/var/lib/postgresql/data \
  postgres:17.10-alpine3.23

cd back
./gradlew build
SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/microcrm \
SPRING_DATASOURCE_USERNAME=microcrm \
SPRING_DATASOURCE_PASSWORD=microcrm-local \
java -jar build/libs/microcrm-0.0.1-SNAPSHOT.jar
```

Sous Windows, utiliser `gradlew.bat build`, puis définir les trois variables
avec `$env:NOM='valeur'` dans PowerShell avant de lancer le JAR.

Vérification : `http://localhost:8080` doit répondre.

### Frontend

Prérequis : Node.js et npm compatibles avec Angular 17.

```shell
cd front
npm ci
npm start
```

Ouvrir `http://localhost:4200`.

## Tests et builds

Depuis la racine du dépôt :

```shell
bash scripts/ci/test.sh --component frontend
bash scripts/ci/test.sh --component backend
bash scripts/ci/tests/test_scripts.sh
python -m pytest scripts/ci/tests/
bash scripts/ci/build.sh --component all
```

La liste complète des jobs, artéfacts et contrôles bloquants se trouve dans la
[documentation des tests](documentation/ci_cd/tests.md) et la
[documentation de sécurité](documentation/ci_cd/securite.md).

## Images Docker

Construire d’abord les artéfacts applicatifs :

```shell
bash scripts/ci/build.sh --component all
docker build --file misc/docker/frontend.Dockerfile --tag microcrm-frontend:local .
docker build --file misc/docker/backend.Dockerfile --tag microcrm-backend:local .
```

Tester les trois conteneurs :

```shell
sh scripts/ci/smoke.sh \
  --frontend-image microcrm-frontend:local \
  --backend-image microcrm-backend:local \
  --database-image postgres:17.10-alpine3.23
```

Le smoke test vérifie les healthchecks, les utilisateurs non-root, l’API via le
frontend et la persistance sur un même volume Docker.

## Kubernetes et AWS

- Déploiement local : [`helm/microcrm/README.md`](helm/microcrm/README.md).
- Validation et cycle AWS :
  [`infrastructure/README.md`](infrastructure/README.md).
- Architecture :
  [`documentation/diagrammes/architecture_aws.md`](documentation/diagrammes/architecture_aws.md).
- Pipeline :
  [`documentation/diagrammes/workflow_ci_actuel.md`](documentation/diagrammes/workflow_ci_actuel.md).

## Documentation

Le point d’entrée est [`documentation/README.md`](documentation/README.md). Il
distingue les références opérationnelles actuelles des livrables historiques.
