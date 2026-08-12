# Infrastructure du POC

## Architecture

Le POC utilise une instance EC2 x86_64 dans `eu-west-3`. Elle héberge K3s,
Traefik, le GitLab Agent, MicroCRM et PostgreSQL. Voir le
[diagramme AWS](../diagrammes/architecture_aws.md).

| Couche | Outil | Responsabilité |
|---|---|---|
| Réseau et compute | Terraform | VPC, subnet, routes, security group, EC2 et IAM |
| Transfert Ansible | Terraform | Bucket S3 privé et temporaire pour la connexion SSM |
| Configuration | Ansible | Ubuntu, K3s, GitLab Agent et CloudWatch Agent |
| Application | Helm | Frontend, backend, PostgreSQL, Ingress et NetworkPolicies |
| Orchestration | GitLab CI/CD | Plan, apply, configuration, déploiement et destroy contrôlé |

Terraform fournit les tags et sorties consommés par l’inventaire Ansible. Le
GitLab Agent ouvre une connexion sortante vers GitLab ; le port Kubernetes
`6443` n’est pas exposé sur Internet.

## Réseau

| Flux | Configuration |
|---|---|
| Entrée application | TCP `80` et `443` vers Traefik |
| Administration | AWS Systems Manager ; SSH `22` fermé |
| API Kubernetes | `6443` fermé sur Internet |
| Sorties | HTTP `80`, HTTPS `443` et NTP `123` vers Amazon Time Sync |

Le port `443` est autorisé par le security group, mais le chart ne configure pas
TLS. L’application est donc documentée comme accessible en HTTP seulement.

## État et identités

- Le state Terraform `microcrm-poc` utilise le backend HTTP GitLab.
- Les jobs AWS obtiennent des credentials temporaires avec GitLab OIDC et AWS
  STS.
- `AWS_PLAN_ROLE_ARN` porte les droits de plan ; `AWS_APPLY_ROLE_ARN` porte les
  opérations d’écriture du POC.
- L’EC2 utilise un instance profile pour Systems Manager et, lorsque activé,
  CloudWatch.
- Les secrets PostgreSQL, registry et GitLab Agent sont fournis à l’exécution.

La policy d’écriture attendue est versionnée dans
`infrastructure/aws/gitlab-apply-policy.json`. Terraform ne gère pas la version
active de cette policy dans AWS.

## Déploiement

Une pipeline Web sur `dev` peut enchaîner :

1. `quality:terraform:plan` ;
2. `deploy:terraform:apply` ;
3. `deploy:ansible:check` ;
4. `deploy:ansible:apply` ;
5. `deploy:helm:staging`.

Le destroy est séparé et manuel. Il exige `TF_DESTROY_CONFIRM=true`. Les jobs
Terraform partagent le `resource_group` `aws-poc` afin d’éviter deux opérations
concurrentes.

Les commandes de validation et les variables sont documentées dans
[`../../infrastructure/README.md`](../../infrastructure/README.md).

## Monitoring

`CLOUDWATCH_AGENT_ENABLED=true` active ensemble :

- la policy IAM de l’agent ;
- les groupes `/microcrm/poc/system` et `/microcrm/poc/kubernetes` ;
- le dashboard `microcrm-poc-monitoring` ;
- l’installation et la configuration de l’agent par Ansible.

La rétention des groupes est de trois jours. Le dashboard affiche disponibilité
EC2, CPU, mémoire, disque et résultats Logs Insights. Aucune alarme CloudWatch
n’est créée.

## Disponibilité et données

L’instance, son Availability Zone et son volume sont des points uniques de
panne. PostgreSQL utilise un PVC `local-path` sur ce nœud. Les redémarrages
Kubernetes et la reconstruction par IaC apportent de la résilience, pas une
haute disponibilité.

Aucune sauvegarde PostgreSQL externe ni restauration après perte du volume
n’est implémentée. Voir
[`../ci_cd/release_rollback_sauvegarde.md`](../ci_cd/release_rollback_sauvegarde.md).

## Coûts

Le POC est éphémère. Avant chaque session :

1. vérifier la région `eu-west-3`, les crédits et les tarifs AWS actuels ;
2. lancer uniquement la pipeline autorisée ;
3. collecter les preuves nécessaires ;
4. lancer le destroy le même jour ;
5. contrôler les ressources résiduelles.

Le dépôt ne constitue pas une source de prix AWS à jour.
