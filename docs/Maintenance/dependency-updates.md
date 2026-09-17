# Mise à jour des dépendances

Les dépendances du frontend, du backend et de l'infrastructure évoluent
séparément. La CI exécute les tests, builds et scans selon ses
[`rules`](../ci-cd/pipeline.md), mais ne met pas les versions à jour
automatiquement. Une revue périodique complète n'est pas programmée.

Pour rechercher les versions et alertes côté frontend, utiliser
`npm outdated` et `npm audit` depuis `front/` ; ces commandes ne sont pas des
jobs CI. Aucun plugin Gradle de suivi des versions obsolètes n'est configuré.

Isoler la mise à jour sur une branche dédiée et modifier les manifestes et
lockfiles concernés. Exécuter ensuite les contrôles adaptés au composant :

- frontend : `cd front && npm ci && npm test && npm run build` (Chrome requis
  pour les tests) ;
- backend : `cd back && ./gradlew test build` (ou `gradlew.bat` sous Windows) ;
- scripts : suites sous [`scripts/ci/tests`](../../scripts/ci/tests/) ;
- Terraform : `terraform fmt -check -recursive`, `terraform validate`, puis
  examiner le plan du state exact avant un apply ;
- Ansible : syntax-check/lint des playbooks du dépôt et inventaire dynamique
  avant exécution ;
- Helm : `helm lint infrastructure/helm/microcrm` puis rendu des fichiers de
  valeurs staging et production ;
- images et IaC : lire les rapports Trivy, Gitleaks et Sonar dans la pipeline.

Une mise à jour de K3s, du provider AWS ou de PostgreSQL peut modifier l'état
du cluster ou les données. Examiner le plan d'infrastructure avant apply et
tester le déploiement concerné. Pour chaque revue, conserver les versions,
CVE, décisions et résultats de pipeline afin de suivre les changements dans
le temps.
