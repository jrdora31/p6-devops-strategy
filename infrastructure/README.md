# Infrastructure MicroCRM

Ce dossier contient les sources Terraform du POC AWS. Ansible configure
l’instance dans `../ansible/` et Helm déploie l’application depuis
`../helm/microcrm/`.

L’architecture et ses limites sont décrites dans
[`../documentation/livrables/infrastructure.md`](../documentation/livrables/infrastructure.md).

## Validation locale sans création AWS

Depuis la racine du dépôt :

```shell
terraform -chdir=infrastructure/terraform fmt -check -recursive
terraform -chdir=infrastructure/terraform init -backend=false
terraform -chdir=infrastructure/terraform validate

ANSIBLE_CONFIG=ansible/ansible.cfg \
  ansible-playbook --syntax-check --inventory localhost, ansible/playbooks/site.yml
ansible-lint ansible/
```

Ces commandes ne créent aucune ressource. La validation connectée à AWS et
l’apply s’exécutent dans GitLab CI.

## Variables GitLab

| Variable | Usage |
|---|---|
| `AWS_PLAN_ROLE_ARN` | Rôle OIDC en lecture pour le plan Terraform |
| `AWS_APPLY_ROLE_ARN` | Rôle OIDC d’écriture limité au POC |
| `GITLAB_AGENT_TOKEN` | Connexion du GitLab Agent installé par Ansible |
| `KUBERNETES_DATABASE_PASSWORD` | Secret PostgreSQL créé pendant le déploiement Helm |
| `CLOUDWATCH_AGENT_ENABLED` | Active Terraform et Ansible CloudWatch ; défaut `false` |
| `TF_DESTROY_CONFIRM` | Autorise le job manuel de destroy ; défaut `false` |

La policy attendue pour le rôle d’écriture est
`aws/gitlab-apply-policy.json`. Terraform ne synchronise pas cette policy avec
AWS.

## Cycle AWS

Une pipeline Web autorisée sur `dev` exécute le plan, l’apply Terraform, le
check Ansible, la configuration Ansible et le déploiement Helm staging.

Le destroy n’est jamais automatique :

1. lancer la pipeline avec `TF_DESTROY_CONFIRM=true` ;
2. vérifier que les preuves utiles ont été collectées ;
3. déclencher manuellement `deploy:terraform:destroy` ;
4. contrôler les ressources résiduelles dans `eu-west-3` et les buckets S3.

`CLOUDWATCH_AGENT_ENABLED=true` crée les groupes de logs et le dashboard, puis
installe l’agent. Utiliser cette option uniquement pour une session AWS
autorisée.
