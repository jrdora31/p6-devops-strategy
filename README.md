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
- PostgreSQL 17, lancé localement ou dans un conteneur

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

3. Démarrer PostgreSQL, puis fournir la connexion au backend. Exemple local avec Docker :

   ```shell
   docker volume create microcrm-postgres
   docker run --detach --name microcrm-postgres \
     --publish 5432:5432 \
     --env POSTGRES_DB=microcrm \
     --env POSTGRES_USER=microcrm \
     --env POSTGRES_PASSWORD=microcrm-local \
     --volume microcrm-postgres:/var/lib/postgresql/data \
     postgres:17.10-alpine3.23
   ```

4. Démarrer le service sous Linux :

   ```shell
   SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/microcrm \
   SPRING_DATASOURCE_USERNAME=microcrm \
   SPRING_DATASOURCE_PASSWORD=microcrm-local \
   java -jar build/libs/microcrm-0.0.1-SNAPSHOT.jar
   ```

   Sous PowerShell :

   ```powershell
   $env:SPRING_DATASOURCE_URL='jdbc:postgresql://localhost:5432/microcrm'
   $env:SPRING_DATASOURCE_USERNAME='microcrm'
   $env:SPRING_DATASOURCE_PASSWORD='microcrm-local'
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

#### Tests automatisés dans GitLab CI

La pipeline exécute les tests du frontend, du backend et des scripts à chaque
merge request ainsi que sur `dev`, `main`, les tags et les pipelines planifiés.

L’exécution locale nécessite Bash, Python avec les dépendances de test,
ShellCheck et Chrome ou Chromium. Si le navigateur n’est pas détecté,
`CHROME_BIN` doit contenir le chemin de son exécutable.

Depuis la racine du repository, les mêmes tests peuvent être lancés avec :

```shell
bash scripts/ci/test.sh --component frontend
bash scripts/ci/test.sh --component backend
bash scripts/ci/tests/test_scripts.sh
python -m pip install -r scripts/ci/requirements-test.txt
python -m pytest scripts/ci/tests/test_python_scripts.py
shellcheck scripts/ci/*.sh scripts/ci/tests/*.sh
```

| Job GitLab | Vérification | Résultat conservé |
|---|---|---|
| `test:frontend` | Tests Angular, dont les échanges HTTP simulés, et couverture | Rapport de couverture HTML et LCOV |
| `test:backend` | Tests JUnit du contexte, du repository et du CRUD HTTP | Rapport JUnit, rapport HTML et JaCoCo XML |
| `test:scripts:bash` | Commandes Bash, erreurs et dry-run | Log du job |
| `test:scripts:python` | Manifeste et notification | Rapport JUnit pytest |
| `test:helm` | Structure, values et rendu du chart Helm | Log du job |
| `quality:shellcheck` | Analyse statique des scripts Bash | Log du job |
| `quality:sonarqube` | Qualité, sécurité et couverture du code | Dashboard SonarQube et quality gate |
| `quality:trivy:repository` | Vulnérabilités des dépendances et secrets | Rapports Trivy JSON et texte |
| `quality:trivy:kubernetes` | Mauvaises configurations Kubernetes/Helm | Rapports Trivy JSON et texte |
| `release:scan:image:frontend` | Vulnérabilités de l’image frontend avant publication | Rapports Trivy JSON et texte |
| `release:scan:image:backend` | Vulnérabilités de l’image backend avant publication | Rapports Trivy JSON et texte |
| `release:manifest` | Traçabilité de la version, du commit, de la pipeline et des images | Manifeste JSON de release |
| `release:create` | Publication d’un tag SemVer dans GitLab Releases | Release GitLab liée à sa pipeline |
| `release:helm:package` | Création de l’archive du chart | Package Helm conservé comme artifact |
| `deploy:helm:staging` | Deployment automatique de `dev` vers staging | Release Helm dans `microcrm-staging` |
| `deploy:helm:aws` | Deployment manuel et atomique sur K3s/AWS | Release Helm et environnement GitLab |

Avec SonarQube Cloud Free, `quality:sonarqube` s’exécute sur les merge requests
et sur `main`, mais pas sur les push directs vers `dev`.

Les jobs Trivy conservent les vulnérabilités élevées et critiques dans leurs
rapports. Une erreur du scanner, un secret détecté ou une vulnérabilité critique
corrigible fait échouer le job ; les vulnérabilités élevées existantes restent
visibles pour un traitement progressif.

Le détail des scripts se trouve dans [`scripts/ci/README.md`](scripts/ci/README.md)
et la matrice complète dans
[`documentation/ci_cd/05_plan_tests_automatises.md`](documentation/ci_cd/05_plan_tests_automatises.md).

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

Le test suivant crée un réseau Docker temporaire, attend les deux healthchecks,
vérifie le routage Caddy puis exécute un parcours de création et de lecture :

```shell
sh scripts/ci/smoke.sh \
  --frontend-image microcrm-frontend:local \
  --backend-image microcrm-backend:local \
  --database-image postgres:17.10-alpine3.23
```

Le smoke test démarre PostgreSQL avec un volume temporaire, crée une donnée,
recrée la base et le backend, puis confirme que cette donnée reste accessible.
La CI utilise la même image PostgreSQL épinglée par digest.

### Orchestration Kubernetes

Le chart [`helm/microcrm`](helm/microcrm/README.md) décrit le frontend, le
backend et PostgreSQL. Les fichiers de values séparent les paramètres Minikube
et K3s, tandis que les credentials restent dans un Secret Kubernetes externe au
repository. Il a été validé sur un profil Minikube isolé ; le deployment AWS
reste manuel et protégé tant que l'infrastructure K3s n'est pas disponible.
