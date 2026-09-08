<p align="center">
   <img src="./front/src/favicon.png" width="192px" />
</p>

# MicroCRM (P5 - Expert DevOps - Gérez le cycle de vie de développement logiciel)

MicroCRM est une application de démonstration basique ayant pour être objectif de servir de socle pour le module "P5 - Expert DevOps".

L'application MicroCRM est une implémentation simplifiée d'un ["CRM" (Customer Relationship Management)](https://fr.wikipedia.org/wiki/Gestion_de_la_relation_client). Les fonctionnalités sont limitées à la création, édition et la visualisations des individus liés à des organisations.

![Page d'accueil](./misc/screenshots/screenshot_1.png)
![Édition de la fiche d'un individu](./misc/screenshots/screenshot_2.png)

## Code source

### Organisation

Ce [monorepo](https://en.wikipedia.org/wiki/Monorepo) contient les 2 composantes du projet "MicroCRM":

- La partie serveur (ou "backend"), en Java SpringBoot 3;
- La partie cliente (ou "frontend"), en Angular 17.

Une intégration basique avec Gitlab CI est définie via le fichier [`.gitlab-ci.yml`](./.gitlab-ci.yml).

### Démarrer avec les sources

#### Serveur

##### Dépendances

- [OpenJDK >= 17](https://openjdk.org/)

##### Procédure

1. Se positionner dans le répertoire `back` avec une invite de commande:

   ```shell
   cd back
   ```

2. Construire le JAR:

   ```shell
   # Sur Linux
   ./gradlew build

   # Sur Windows
   gradlew.bat build
   ```

3. Démarrer le service:

   ```shell
   java -jar build/libs/microcrm-0.0.1-SNAPSHOT.jar
   ```

Puis ouvrir l'URL http://localhost:8080 dans votre navigateur.

#### Client

##### Dépendances

- [NPM >= 10.2.4](https://www.npmjs.com/)

##### Procédure

1. Se positionner dans le répertoire `front` avec une invite de commande:

   ```shell
   cd front
   ```

2. (La première fois seulement) Installer les dépendances NodeJS:

   ```shell
   npm install
   ```

3. Démarrer le service de développement:

   ```shell
   npx @angular/cli serve
   ```

Puis ouvrir l'URL http://localhost:4200 dans votre navigateur.

### Exécution des tests

#### Client

**Dépendances**

- Google Chrome ou Chromium

Dans votre terminal:

```shell
cd front
CHROME_BIN=</path/to/google/chrome> npm test
```

#### Serveur

Dans votre terminal:

```shell
cd back
./gradlew test
```

### Images Docker

La CI construit deux images distinctes. Les builds applicatifs doivent être
produits avant les images :

```shell
bash scripts/ci/build.sh --component all
docker build --file misc/docker/frontend.Dockerfile --tag microcrm-frontend:local .
docker build --file misc/docker/backend.Dockerfile --tag microcrm-backend:local .
```

Le frontend appelle l’API avec la route relative `/api`. Caddy transmet cette
route au conteneur backend par son nom de service ; aucune adresse IP n’est
intégrée au code.

Le smoke test local démarre les images avec PostgreSQL, vérifie les
healthchecks et exécute un parcours de création et de lecture :

```shell
sh scripts/ci/smoke.sh \
  --frontend-image microcrm-frontend:local \
  --backend-image microcrm-backend:local \
  --database-image postgres:17.10-alpine3.23
```

## Documentation

Pour reprendre le projet depuis un clone et effectuer un premier déploiement
sur AWS, consulter [`DOCS/GET-STARTED.md`](./DOCS/GET-STARTED.md).

La documentation peut être adaptée aux besoins de l'équipe : information
jamais transmise par la couleur seule et diagrammes légendés, titres Markdown
cohérents et textes alternatifs pour les lecteurs d'écran, procédures
utilisables au clavier avec des commandes copiables.

### Architecture et infrastructure

- [`DOCS/stack.md`](./DOCS/stack.md) — Stack technique du projet.
- [`DOCS/schema_architecture_aws.md`](./DOCS/schema_architecture_aws.md) — Architecture AWS et interactions entre les composants.
- [`DOCS/infrastructure/terraform.md`](./DOCS/infrastructure/terraform.md) — Provisionnement AWS avec Terraform.
- [`DOCS/infrastructure/ansible.md`](./DOCS/infrastructure/ansible.md) — Configuration de l’instance et du cluster K3s.
- [`DOCS/infrastructure/helm.md`](./DOCS/infrastructure/helm.md) — Déploiement de MicroCRM dans K3s.

### CI/CD et maintenance

- [`DOCS/ci-cd/pipeline.md`](./DOCS/ci-cd/pipeline.md) — Organisation de la pipeline GitLab CI/CD.
- [`DOCS/ci-cd/deployment-strategy.md`](./DOCS/ci-cd/deployment-strategy.md) — Release, promotion et rollback.
- [`DOCS/Maintenance/backup-recovery.md`](./DOCS/Maintenance/backup-recovery.md) — Sauvegarde et restauration.
- [`DOCS/Maintenance/rollback.md`](./DOCS/Maintenance/rollback.md) — Retour à une version précédente.
- [`DOCS/Maintenance/supervision.md`](./DOCS/Maintenance/supervision.md) — Supervision CloudWatch.

### Qualité et scripts

- [`DOCS/quality/testing.md`](./DOCS/quality/testing.md) — Stratégie de tests.
- [`DOCS/quality/security.md`](./DOCS/quality/security.md) — Sécurité, secrets et scans.
- [`DOCS/quality/performance.md`](./DOCS/quality/performance.md) — Performance et métriques DORA.
- [`scripts/bootstrap/bootstrap.md`](./scripts/bootstrap/bootstrap.md) — Initialisation AWS et GitLab.
- [`scripts/ci/scripts.md`](./scripts/ci/scripts.md) — Scripts utilisés par la pipeline.
