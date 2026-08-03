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
l'ARN du rôle AWS de lecture utilisé pour le plan ; cet ARN n'est pas un secret
et doit être disponible dans les pipelines de merge request.

Le state distant utilise le backend HTTP GitLab `microcrm-poc`. Ses adresses et
son authentification sont construites dans le job à partir de
`CI_API_V4_URL`, `CI_PROJECT_ID` et `CI_JOB_TOKEN` ; aucun credential durable
n'est enregistré dans le repository.

Après `apply`, l'output `ansible_transfer_bucket` alimentera
`ANSIBLE_AWS_SSM_BUCKET_NAME`.

Les commandes `apply` et `destroy` resteront manuelles et protégées. Aucun
`apply` ne doit être lancé avant vérification du coût et autorisation explicite.

## Limite de disponibilité

Le POC utilise une seule EC2. Les probes, les redémarrages Kubernetes, les
backups et la reconstruction par IaC améliorent sa résilience, mais ne rendent
pas l'infrastructure hautement disponible. Une cible de production ajouterait
plusieurs nodes répartis sur plusieurs Availability Zones, une entrée réseau et
une base de données redondées.
