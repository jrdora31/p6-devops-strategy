# Terraform

## States et ressources AWS

Terraform conserve le réseau AWS commun dans le root `network/` et le state
`microcrm-network`. Le root parent utilise l'unique state `microcrm-poc` pour
les deux EC2 du cluster K3s partagé et le Network Load Balancer.

- `microcrm-network` contient le VPC, le subnet public, la route Internet et le
  Security Group commun ;
- `microcrm-poc` contient les deux EC2, le NLB, son IAM, le bucket temporaire
  Ansible/SSM et les ressources de monitoring.

Le root réseau reste séparé du root cluster. Le plan et l'apply du cluster
refusent toute combinaison autre que
`dev/poc/microcrm-poc/aws-poc-infrastructure`.

Le cluster contient un serveur/control-plane dédié aux workloads staging et un
agent dédié aux workloads production. Les tags `EnvironmentRole` et les labels
Kubernetes rendent ce placement reproductible. Le control-plane reste partagé :
il ne s'agit pas de deux clusters indépendants.

Terraform crée aussi les ressources CloudWatch, détaillées dans la
[supervision](../Maintenance/supervision.md).

## Cycle de l'infrastructure

Une pipeline Web `dev` gère cette infrastructure partagée ; une pipeline Web
`main` ne provisionne aucune seconde infrastructure. La pipeline
d'infrastructure ne déploie aucune application. Son plan et son apply sont
décrits dans la [pipeline CI/CD](../ci-cd/pipeline.md).

Avant le premier déploiement, contrôler l'identité AWS avec
`aws sts get-caller-identity` et vérifier les droits GitLab dans le projet.
Examiner les plans des deux states avant les jobs apply : une pipeline Web
`dev` prépare le réseau et le cluster, sans déployer l'application.

Avant le premier apply, inventorier les éventuels states
`microcrm-staging`/`microcrm-production` et remettre leur ownership dans
`microcrm-poc` sans dupliquer les ressources. Cette migration n'est pas
exécutée automatiquement par la CI.

Le destroy de `microcrm-poc` est manuel, dédié à l'infrastructure et conserve
le state réseau. Aucun job Helm staging ou production ne peut le déclencher.

## Limites du POC

La perte de l'EC2 staging supprime l'unique control-plane K3s. Les workloads
déjà actifs sur l'agent production peuvent continuer avec l'état réseau
existant, mais la gestion du cluster et tout nouveau placement de Pod sont
impossibles jusqu'au rétablissement de l'API K3s. Cette dépendance est
acceptée pour le POC à deux EC2 ; une architecture hautement disponible est
hors périmètre.
