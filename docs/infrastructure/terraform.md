# Terraform

## States et ressources AWS

Terraform conserve le réseau AWS commun dans le root `network/` et le state
`microcrm-network`. Le root parent utilise l'unique state `microcrm-poc` pour
les deux EC2 du cluster K3s partagé et le Network Load Balancer.

Repères dans le dépôt : [root réseau](../../infrastructure/terraform/network/),
[root cluster](../../infrastructure/terraform/) et
[modules Terraform](../../infrastructure/terraform/modules/).

- `microcrm-network` contient le VPC, le subnet public, la route Internet et le
  Security Group commun ;
- `microcrm-poc` contient les deux EC2, le NLB, son IAM, le bucket temporaire
  Ansible/SSM et les ressources de monitoring.

Le [root réseau](../../infrastructure/terraform/network/main.tf) appelle le
module réseau ; le [root cluster](../../infrastructure/terraform/main.tf) lit
ses outputs depuis un autre state HTTP. L'adresse du state réseau est fournie
à l'exécution par `network_state_address` :

```hcl
module "network" {
  source = "../modules/network"

  name_prefix        = "${var.project_name}-poc"
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  availability_zone  = local.selected_availability_zone
  http_ingress_cidrs = var.http_ingress_cidrs
}
```

```hcl
data "terraform_remote_state" "network" {
  backend = "http"

  config = {
    address = var.network_state_address
  }
}
```

Le module `compute` consomme ainsi le subnet et le Security Group produits
par le state réseau, sans recréer ces ressources dans `microcrm-poc`.

Le root réseau reste séparé du root cluster. Le plan et l'apply du cluster
refusent toute combinaison autre que
`dev/poc/microcrm-poc/aws-poc-infrastructure` —
[source](../../.gitlab/ci/iac.yml).

Le cluster contient un serveur/control-plane dédié aux workloads staging et un
agent dédié aux workloads production. Les tags `EnvironmentRole` et les labels
Kubernetes rendent ce placement reproductible. Le control-plane reste partagé :
il ne s'agit pas de deux clusters indépendants.

Le [root cluster](../../infrastructure/terraform/main.tf) associe des clés
stables aux deux rôles, puis rattache les identifiants EC2 produits par le
module `compute` au target group du NLB. Les clés du `for_each` sont connues
dès le plan, même si les identifiants EC2 ne le sont qu'à l'apply :

```hcl
instance_roles = {
  staging    = 0
  production = 1
}
```

```hcl
resource "aws_lb_target_group_attachment" "k3s" {
  for_each = local.instance_roles

  target_group_arn = aws_lb_target_group.http.arn
  target_id        = module.compute.instance_id[each.value]
  port             = 80
}
```

Le target group et le listener utilisent `TCP/80` : Terraform vérifie la
connectivité au port, tandis que Traefik effectue le routage HTTP décrit dans
[Helm](helm.md).

Terraform crée aussi les ressources CloudWatch, détaillées dans la
[supervision](../Maintenance/supervision.md) —
[source](../../infrastructure/terraform/main.tf).

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
le state réseau. Aucun job Helm staging ou production ne peut le déclencher —
[source](../../.gitlab/ci/iac.yml).

## Limites du POC

La perte de l'EC2 staging supprime l'unique control-plane K3s. Les workloads
déjà actifs sur l'agent production peuvent continuer avec l'état réseau
existant, mais la gestion du cluster et tout nouveau placement de Pod sont
impossibles jusqu'au rétablissement de l'API K3s. Cette dépendance est
acceptée pour le POC à deux EC2 ; une architecture hautement disponible est
hors périmètre.
