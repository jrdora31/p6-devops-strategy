# Documentation de l'infrastructure

> État au 3 août 2026 : architecture cible retenue pour le POC. Les sources IaC
> sont préparées, mais les ressources AWS ne sont pas encore créées.

## Architecture AWS retenue

Le POC utilise une seule instance EC2 dans la région `eu-west-3` (Paris). Cette instance héberge un cluster K3s mono-nœud et les workloads déployés par Helm.

| Composant | Choix | Justification |
|---|---|---|
| Réseau | Un VPC, une subnet publique, une Internet Gateway et une route Internet | Architecture minimale suffisante pour un POC public |
| Compute | EC2 `t3.medium`, architecture `amd64`, Ubuntu LTS | 2 vCPU et 4 Gio pour K3s et MicroCRM ; compatible avec les images actuelles |
| Stockage | Volume racine gp3 de 20 Gio | Héberge K3s, les images et le volume PostgreSQL `local-path` |
| Kubernetes | K3s mono-nœud avec Traefik | Pas de coût de control plane EKS ; mêmes charts Helm que les tests Minikube |
| Accès système | AWS Systems Manager | Ansible peut configurer l'instance sans exposer SSH |
| Transfert Ansible | Bucket S3 privé, chiffré, sans versioning et avec expiration courte | Requis par la connexion Ansible SSM ; limite la conservation des fichiers temporaires |
| État Terraform | Backend HTTP géré par GitLab | State distant, verrouillé et versionné sans créer un second bucket dédié |
| Accès Kubernetes | GitLab Agent for Kubernetes | Le cluster initie la connexion ; le port `6443` reste fermé sur Internet |

Ne sont pas retenus pour ce POC : EKS, NAT Gateway, ALB, RDS, Elastic IP et
cluster multi-nœuds. Ils augmenteraient le coût ou la maintenance sans être
nécessaires pour démontrer le déploiement demandé.

## Disponibilité et limites

K3s redémarre les containers défaillants et l'IaC permet de reconstruire
l'environnement. Les backups et les procédures de restore limitent également
la perte de données. Ces mécanismes apportent de la **résilience**, mais pas une
haute disponibilité complète : l'unique EC2, son Availability Zone et son
volume gp3 restent des points uniques de panne.

Une cible de production hautement disponible utiliserait plusieurs nodes dans
plusieurs Availability Zones, une entrée réseau redondée et une base de données
répliquée. Cette évolution est documentée, mais n'est ni nécessaire ni déployée
pour le POC afin de conserver un coût maîtrisé.

## Répartition des responsabilités

| Outil | Responsabilité |
|---|---|
| Terraform | Créer le réseau, l'EC2, le volume, les rôles IAM, le bucket temporaire et les règles de sécurité |
| Ansible | Découvrir l'EC2 par ses tags, préparer Ubuntu et installer/configurer K3s |
| Helm | Déployer frontend, backend et PostgreSQL dans K3s |
| GitLab CI/CD | Valider, planifier, déclencher les actions autorisées et conserver les preuves |

Une même ressource n'est gérée que par un seul outil. Terraform fournit les tags et identifiants ; l'inventaire dynamique `amazon.aws.aws_ec2` les transmet à Ansible sans adresse IP codée en dur.

## Réseau et accès

- `80/443` : entrée HTTP(S) de l'application via Traefik ;
- `22` : fermé ; l'administration passe par Systems Manager ;
- `6443` : fermé sur Internet ; GitLab communique avec Kubernetes au moyen de son agent ;
- sorties Internet : limitées à HTTP `80` pour les dépôts Ubuntu, HTTPS `443`
  pour SSM, registries et GitLab, et NTP `123` vers Amazon Time Sync ;
- exception Trivy `AWS-0104` ciblée sur les sorties HTTP/HTTPS, valable jusqu'au
  1er septembre 2026 ; une cible privée utiliserait des VPC endpoints et un
  contrôle d'egress plus strict.

L'instance reçoit une IPv4 publique dynamique. Elle peut changer après un arrêt, sans modifier le code ni l'inventaire Ansible.

## State, identités et variables

- le state Terraform porte le nom `microcrm-poc` dans GitLab et n'est jamais versionné dans Git ;
- les futurs jobs AWS obtiendront des credentials temporaires par OIDC et AWS STS ;
- l'Identity Provider et le rôle AWS doivent encore être créés lors du bootstrap
  de `N.7`, avec une confiance limitée au projet MicroCRM et aux refs autorisées ;
- l'EC2 utilise un instance profile pour Systems Manager ;
- les plans Terraform sont réservés aux membres autorisés et ne doivent contenir aucun secret ;
- les credentials PostgreSQL, registry et GitLab Agent restent dans des variables protégées ou des Secrets Kubernetes.

| Versionné | Fourni à l'exécution |
|---|---|
| Région, CIDR, type d'instance, taille du volume et tags | ARN du rôle AWS, token du GitLab Agent et secrets applicatifs |
| Noms logiques des ressources | Credentials AWS temporaires générés par STS |
| Valeurs non sensibles par environnement | Adresses du backend state fournies par les variables CI |

## Maîtrise du coût

Le budget de travail est calculé sur une instance active au maximum `80 heures`, puis arrêtée hors essais.

| Poste | Hypothèse de contrôle |
|---|---|
| EC2 `t3.medium` | plafond de travail `0,06 USD/h`, soit `4,80 USD` pour 80 h |
| IPv4 publique | `0,005 USD/h`, soit `0,40 USD` pour 80 h |
| EBS gp3 20 Gio | plafond de travail `2,50 USD/mois` |
| S3 temporaire | volume très faible, objets supprimés automatiquement |
| State GitLab | aucune ressource AWS supplémentaire |

Le plafond prévisionnel est donc d'environ `7,70 USD`, hors transfert sortant et taxes. Ce montant n'est pas un devis : le prix de `eu-west-3`, les crédits restants et leur date d'expiration doivent être vérifiés dans AWS avant tout `terraform apply`.

## Prochaine validation

Les sources Terraform passent `fmt` et `validate` localement. Les fichiers YAML
GitLab et Ansible sont syntaxiquement valides. La pipeline doit encore exécuter
`ansible-lint` et Trivy IaC avant tout provisionnement.

Avant le premier `terraform plan` connecté à AWS : vérifier les crédits,
confirmer `eu-west-3`, relever le tarif de `t3.medium`, puis autoriser
explicitement la création des ressources.

## Références

- [GitLab-managed Terraform/OpenTofu state](https://docs.gitlab.com/user/infrastructure/iac/terraform_state/)
- [GitLab OIDC avec AWS](https://docs.gitlab.com/ci/cloud_services/aws/)
- [Backend HTTP Terraform](https://developer.hashicorp.com/terraform/language/backend/http)
- [Inventaire EC2 et connexion SSM Ansible](https://docs.ansible.com/projects/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html)
- [Connexion Ansible par AWS Systems Manager](https://docs.ansible.com/projects/ansible/latest/collections/amazon/aws/aws_ssm_connection.html)
- [Tarification des IPv4 publiques AWS](https://aws.amazon.com/vpc/pricing/)
