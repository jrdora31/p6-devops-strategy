# Infrastructure MicroCRM

Ce dossier contient les sources de l'infrastructure AWS du POC. Leur présence
ne signifie pas que les ressources sont déjà créées.

## Responsabilités

| Dossier | Rôle |
|---|---|
| `terraform/` | Crée le réseau, l'EC2, son rôle SSM et le bucket temporaire Ansible ; la collecte CloudWatch sera ajoutée après validation de `ARB-16` |
| `../ansible/` | Configure Ubuntu et installe K3s via l'inventaire EC2 dynamique |
| `../helm/microcrm/` | Déploie l'application et PostgreSQL dans K3s |

## Validation sans création AWS

```shell
terraform -chdir=infrastructure/terraform fmt -check -recursive
terraform -chdir=infrastructure/terraform init -backend=false
terraform -chdir=infrastructure/terraform validate

ANSIBLE_CONFIG=ansible/ansible.cfg \
  ansible-playbook --syntax-check --inventory localhost, ansible/playbooks/site.yml
ansible-lint ansible/
```

Ces commandes vérifient les fichiers mais ne créent aucune ressource.

L'observabilité CloudWatch reste désactivée par défaut. Pour une exécution
manuelle explicitement autorisée, la variable CI `CLOUDWATCH_AGENT_ENABLED`
doit être positionnée à `true` ; elle pilote à la fois la création Terraform
des groupes de logs et l'installation Ansible de l'agent. Elle ne doit pas être
activée dans un simple contrôle de qualité.

## Exécution future

Le job `quality:terraform:plan` obtient des credentials AWS temporaires avec le
token OIDC émis par GitLab. La variable GitLab `AWS_PLAN_ROLE_ARN` contient
l'ARN du rôle AWS de lecture utilisé pour le plan. `AWS_APPLY_ROLE_ARN` désigne
un second rôle, limité aux branches autorisées et aux ressources du POC, pour
les opérations Terraform autorisées (`apply` dans une pipeline Web et
`destroy` manuel). Ces ARN ne sont pas des secrets.
La politique d'autorisations proposée est versionnée dans
`aws/gitlab-apply-policy.json`. Elle limite IAM et S3 au préfixe
`microcrm-poc` et n'accorde à EC2 que les actions nécessaires au cycle du POC.
Cette policy du rôle `MicroCRM-GitLab-Terraform-Apply` n'est pas gérée par
Terraform : après toute modification du fichier, sa version active dans AWS
doit être synchronisée avant un nouvel `apply`. Lorsque CloudWatch est activé,
elle doit notamment autoriser la gestion des groupes de logs `/microcrm/poc*`
et `iam:GetRolePolicy`, `iam:PutRolePolicy` et `iam:DeleteRolePolicy` sur les
rôles d'instance `microcrm-poc-*`.

La relation de confiance du rôle d'écriture doit accepter uniquement les
subjects GitLab suivants :

```text
project_path:project_6_group/microcrm:ref_type:branch:ref:dev
project_path:project_6_group/microcrm:ref_type:branch:ref:main
```

Le state distant utilise le backend HTTP GitLab `microcrm-poc`. Ses adresses et
son authentification sont construites dans le job à partir de
`CI_API_V4_URL`, `CI_PROJECT_ID` et `CI_JOB_TOKEN` ; aucun credential durable
n'est enregistré dans le repository.

`deploy:terraform:apply` consomme le plan binaire produit par
`quality:terraform:plan` et s'exécute automatiquement dans une pipeline Web
autorisée. Après l'application, les outputs `aws_region` et
`ansible_transfer_bucket` alimentent automatiquement `deploy:ansible:check`,
puis `deploy:ansible:apply`.
Ces jobs installent la version `1.2.835.0` du Session Manager Plugin depuis le
paquet officiel AWS ; ce binaire est requis par la connexion Ansible SSM.

`deploy:terraform:apply` reste déclenché uniquement par une pipeline Web
autorisée. `deploy:terraform:destroy` reste manuel et les deux jobs partagent
le même `resource_group`, ce qui interdit leur exécution simultanée.

Dans le formulaire `Build > Pipelines > Run pipeline`, la variable
`TF_DESTROY_CONFIRM` est préremplie à `false` et propose `false` ou `true`.
Conserver `false` par défaut ; sélectionner `true` uniquement pour une session
AWS autorisée et après vérification du coût. Cette sélection ne lance pas le
destroy automatiquement : il faut ensuite déclencher le job manuel
`deploy:terraform:destroy`.

Un pipeline lancé depuis l'interface GitLab sur `dev` ou `main` permet de
reconstruire le POC sans commit artificiel. Le cycle attendu est : plan, apply
Terraform autorisé, check et configuration Ansible, déploiement Helm, preuves,
puis destroy manuel.

Le monitoring provisoire cible CloudWatch plutôt qu'une stack ELK/OpenSearch
locale afin de conserver les ressources de l'EC2 pour K3s et MicroCRM. La
configuration de l'agent, les permissions IAM, les groupes de logs, les
dashboards et les alarmes devront être versionnés avant le déploiement. Aucun
composant CloudWatch n'est encore créé par la présence de cette documentation.

## Limite de disponibilité

Le POC utilise une seule EC2. Les probes, les redémarrages Kubernetes, les
backups et la reconstruction par IaC améliorent sa résilience, mais ne rendent
pas l'infrastructure hautement disponible. Une cible de production ajouterait
plusieurs nodes répartis sur plusieurs Availability Zones, une entrée réseau et
une base de données redondées.
