# Synthèse des preuves de déclenchement CI/CD — 22 septembre 2026

Cette page décrit uniquement ce que les captures permettent de prouver. Le nom
d'un fichier image n'est pas utilisé comme preuve du type de déclencheur.

| Capture | Éléments visibles | Conclusion |
|---|---|---|
| [Merge request](pipeline_MR_21_09_26.png) | Pipeline `#2868095016`, commit `dd5e87fd`, MR `!109`, statut Passed, 23 jobs et 34 tests | Le déclenchement par merge request et ses jobs obligatoires sont prouvés |
| [Push sur dev](pipeline_push_dev_21_09_26.png) | Pipeline `#2868146927`, branche `dev`, statut Passed, 25 jobs, 34 tests, `pages:dora` et `pages:deploy` | Le déclenchement par push sur `dev` et ses jobs obligatoires sont prouvés |
| [Pipeline Web dev](pipeline_web_dev_21_09_26.png) | Pipeline `#2867174305`, commit `a031cbca`, branche `dev`, 10 jobs et 3 variables manuelles ; uniquement les jobs Terraform/IaC et Ansible attendus | Le déclenchement Web d'infrastructure est prouvé par le graphe conforme aux règles `CI_PIPELINE_SOURCE == "web"` ; les jobs d'application sont correctement absents |
| [Release candidate](pipeline_staging_release_candidate_15_09_26.png) | Pipeline `#2849937587`, tag `v1.4.0-rc.1`, statut Passed, déploiement et vérification staging réussis | Le déclenchement par tag RC et le déploiement staging sont prouvés |
| [Tag final et Canary](pipeline_tag_final_canary_production_v1.4.0_15_09_26.png) | Pipeline `#2850551710`, tag `v1.4.0`, statut Warning, jobs de déploiement et de vérification Canary réussis | Le tag final et le Canary `v1.4.0` sont prouvés ; cette capture seule ne prouve pas sa promotion |
| [Promotion manuelle](job_manual_promote_production_v1.3.1_14_09_26.png) | Job de la pipeline `#2848029220` sur `v1.3.1` : `PROMOTE réussi`, stable `v1.3.1`, Canary absent, smoke test HTTP réussi et job succeeded | Une exécution réelle et réussie du job manuel de promotion production est prouvée pour `v1.3.1` |
| [CI Lint dev](ci_lint_dev_22_09_26.png) | Branche `dev`, « Pipeline syntax is correct » et « Simulation completed successfully » pour un événement push sur la branche par défaut | La syntaxe CI et l'évaluation statique des `rules`, `only`, `except` et `needs` sont prouvées pour ce scénario |
| [Notifications Slack](slack_notifications_deploiement_rollback_15_16_09_26.png) | Notifications d'échec puis de succès de `rollback:helm:production:release` sur la pipeline `#2848029220`, tag `v1.3.1`, ainsi que des succès Canary et staging | Une exécution réussie du job de rollback production et le fonctionnement des notifications sont prouvés |

## Distinction entre push et Web

La configuration exclut les jobs généraux de test, qualité, build et release
pour `CI_PIPELINE_SOURCE == "web"`. Elle désactive également `pages:dora` sur
un déclenchement Web. La pipeline `#2868146927`, qui contient ces jobs, est donc
un push sur `dev`. À l'inverse, la pipeline `#2867174305` contient uniquement la
chaîne Terraform/IaC et Ansible réservée au déclenchement Web `dev`.

La pipeline Web est affichée `Blocked` après la réussite des jobs
d'infrastructure parce qu'un job manuel reste présent. Ce statut n'efface pas
la preuve du déclenchement ni la réussite des jobs déjà exécutés ; il doit être
présenté tel quel et non comme une pipeline intégralement `Passed`.

Références : [règles globales](../../../.gitlab-ci.yml),
[règles des jobs communs](../../../.gitlab/ci/common.yml) et
[règles DORA](../../../.gitlab/ci/dora.yml).

## Couverture obtenue

La matrice des déclencheurs est maintenant couverte par les captures MR, push
`dev`, Web `dev`, RC et tag final. La promotion manuelle est également prouvée
sur `v1.3.1`. Le CI Lint complète ces exécutions par une validation statique et
une simulation réussie du scénario push `dev`. La capture Slack conserve aussi
une notification de rollback production réussie sur `v1.3.1`.
