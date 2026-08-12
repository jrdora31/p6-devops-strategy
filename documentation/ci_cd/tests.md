# Tests automatisés

## Jobs de test

| Job | Outil | Vérification | Artefact utile |
|---|---|---|---|
| `test:frontend` | Karma, Jasmine, Chrome | Composants et services Angular | Couverture dans `front/coverage/` |
| `test:backend` | Gradle, JUnit 5, Spring Test, MockMvc | Contexte, repository et API REST | JUnit, JaCoCo, classes pour SonarQube |
| `test:scripts:bash` | Bash | Interfaces et garde-fous des scripts CI | Log du job |
| `test:scripts:python` | pytest | Manifeste, notification et métriques DORA | Rapport JUnit |
| `test:helm` | Helm | Lint et rendu des quatre jeux de values | Log du job |
| `test:terraform` | Terraform | Format, initialisation sans backend et validation | Log du job |
| `test:ansible` | Ansible | Syntaxe du playbook et `ansible-lint` | Log du job |
| `verify:images` | Docker et `smoke.sh` | Santé, utilisateurs non-root, API et persistance sur volume Docker | Log du job |

Tous ces jobs sont bloquants. Un code de sortie non nul arrête leur chaîne de
dépendances. Les rapports de tests et de couverture configurés avec
`artifacts: when: always` restent disponibles pendant sept jours, même en cas
d’échec.

`verify:images` teste les images construites dans la pipeline avec PostgreSQL.
Il ne valide pas le déploiement Kubernetes ni la restauration après perte du
volume.

## Quality gates associés

- `quality:sonarqube` analyse le code et la couverture sur les merge requests et
  sur la branche par défaut.
- `quality:shellcheck` analyse les scripts shell.
- Les jobs Trivy contrôlent le dépôt, les images, Helm et Terraform.

Les seuils et les exceptions sont décrits dans la
[sécurité de la CI/CD](securite.md).

## Exécution locale

Depuis la racine du dépôt :

```shell
bash scripts/ci/test.sh --component frontend
bash scripts/ci/test.sh --component backend
bash scripts/ci/tests/test_scripts.sh
python -m pytest scripts/ci/tests/
shellcheck scripts/ci/*.sh scripts/ci/tests/*.sh
helm lint helm/microcrm --values helm/microcrm/values-k3s.yaml
terraform -chdir=infrastructure/terraform fmt -check -recursive
terraform -chdir=infrastructure/terraform init -backend=false
terraform -chdir=infrastructure/terraform validate
```

Les dépendances requises sont précisées dans `front/package-lock.json`, le
Gradle Wrapper, `scripts/ci/requirements-test.txt`,
`ansible/requirements-ci.txt` et `ansible/requirements.yml`.

## Déclenchement

La pipeline exécute les tests sur les merge requests, `dev`, `main`, les tags,
les pipelines Web et les pipelines planifiées. SonarQube et certains jobs de
déploiement appliquent des règles plus restrictives. Voir le
[workflow CI/CD actuel](../diagrammes/workflow_ci_actuel.md).
