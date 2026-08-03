# Infrastructure MicroCRM

Ce dossier contient les sources de l'infrastructure AWS du POC. Leur présence
ne signifie pas que les ressources sont déjà créées.

## Responsabilités

| Dossier | Rôle |
|---|---|
| `terraform/` | Crée le réseau, l'EC2, son rôle SSM et le bucket temporaire Ansible |
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

## Exécution future

Le job `quality:terraform:plan` obtient des credentials AWS temporaires avec le
token OIDC émis par GitLab. La variable GitLab `AWS_PLAN_ROLE_ARN` contient
l'ARN du rôle AWS de lecture utilisé pour le plan. `AWS_APPLY_ROLE_ARN` désigne
un second rôle, limité aux branches autorisées et aux ressources du POC, pour
les opérations manuelles `apply` et `destroy`. Ces ARN ne sont pas des secrets.
La politique d'autorisations proposée est versionnée dans
`aws/gitlab-apply-policy.json`. Elle limite IAM et S3 au préfixe
`microcrm-poc` et n'accorde à EC2 que les actions nécessaires au cycle du POC.

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
`quality:terraform:plan`. Après l'application, les outputs `aws_region` et
`ansible_transfer_bucket` alimentent automatiquement `deploy:ansible:check`,
puis le job manuel `deploy:ansible:apply`.
Ces jobs installent la version `1.2.835.0` du Session Manager Plugin depuis le
paquet officiel AWS ; ce binaire est requis par la connexion Ansible SSM.

Les commandes `apply` et `destroy` restent manuelles et partagent le même
`resource_group`, ce qui interdit leur exécution simultanée. Le destroy exige la
variable `TF_DESTROY_CONFIRM=destroy-microcrm-poc`. Aucun `apply` ne doit être
lancé avant vérification du coût et autorisation explicite.

Un pipeline lancé depuis l'interface GitLab sur `dev` ou `main` permet de
reconstruire le POC sans commit artificiel. Le cycle attendu est : plan, apply
Terraform manuel, check mode Ansible, configuration Ansible manuelle,
déploiement Helm, preuves, puis destroy manuel.

## Limite de disponibilité

Le POC utilise une seule EC2. Les probes, les redémarrages Kubernetes, les
backups et la reconstruction par IaC améliorent sa résilience, mais ne rendent
pas l'infrastructure hautement disponible. Une cible de production ajouterait
plusieurs nodes répartis sur plusieurs Availability Zones, une entrée réseau et
une base de données redondées.
