# Documentation de l'infrastructure

> État au 5 août 2026 : architecture du POC déployée puis détruite avec la
> pipeline `main` `#2731910227`. Le cycle AWS reste éphémère et doit être
> reconstruit pour chaque nouvelle session de preuve.

## Architecture AWS retenue

Le POC utilise une seule instance EC2 dans la région `eu-west-3` (Paris). Cette instance héberge un cluster K3s mono-nœud et les workloads déployés par Helm.

| Composant | Choix | Justification |
|---|---|---|
| Réseau | Un VPC, une subnet publique, une Internet Gateway et une route Internet | Architecture minimale suffisante pour un POC public |
| Compute | EC2 `m7i-flex.large`, architecture `amd64`, Ubuntu LTS | 2 vCPU et 8 Gio observés pour K3s et MicroCRM |
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
- les jobs AWS obtiennent des credentials temporaires par OIDC et AWS STS ;
- l'Identity Provider GitLab et le rôle de plan en lecture seule sont configurés ;
- un rôle séparé a été utilisé pour les `apply` et `destroy` manuels, avec une
  confiance limitée au projet MicroCRM et aux branches `dev` et `main` ;
- la policy d'écriture versionnée limite IAM et S3 au préfixe `microcrm-poc` et
  les actions EC2 au cycle de vie nécessaire au POC ;
- l'EC2 utilise un instance profile pour Systems Manager ;
- les plans Terraform sont réservés aux membres autorisés et ne doivent contenir aucun secret ;
- les credentials PostgreSQL, registry et GitLab Agent restent dans des variables protégées ou des Secrets Kubernetes.

| Versionné | Fourni à l'exécution |
|---|---|
| Région, CIDR, type d'instance, taille du volume et tags | ARN du rôle AWS, token du GitLab Agent et secrets applicatifs |
| Noms logiques des ressources | Credentials AWS temporaires générés par STS |
| Valeurs non sensibles par environnement | Adresses du backend state fournies par les variables CI |

## Coût observé du premier cycle AWS

La facturation détaillée du cycle montre les montants suivants :

| Poste | Hypothèse de contrôle |
|---|---|
| EC2 Linux/UNIX `m7i-flex.large` | `11,894 h` à `0,11172 USD/h` : `1,33 USD` |
| EBS gp3 | `0,321 GB-Mo` à `0,0928 USD/GB-Mo` : `0,03 USD` |
| Total avant crédit | `1,36 USD` |
| Crédit AWS appliqué | `(1,36 USD)` dans le détail de facturation |
| Solde de crédits communiqué le 5 août | `22,18 USD` |

Le coût observé correspond à environ onze heures d'EC2, et non à une
consommation AWS inexpliquée pendant toute la nuit. Le cycle suivant doit
conserver la règle `apply → configuration → deployment → preuves → destroy`
et éviter de laisser l'instance active après la session.

## Preuves et limites actuelles

- La pipeline `#2731910227` a réussi `deploy:helm:aws`,
  `verify:kubernetes:aws` et `deploy:terraform:destroy`.
- Le script de vérification contrôle les rollouts frontend/backend/PostgreSQL,
  le PVC `Bound`, l'hôte Ingress et les parcours HTTP `/` et `/api/persons`.
- La pipeline prouve la destruction Terraform, mais une capture séparée de
  l'inventaire AWS post-destroy reste utile pour la preuve finale d'absence de
  ressources résiduelles.
- Aucun backup PostgreSQL, restore ou rollback applicatif réel n'est encore
  prouvé.

Pour une nouvelle session, vérifier les crédits, confirmer `eu-west-3`, relever
le tarif de `m7i-flex.large`, puis autoriser explicitement la création des
ressources.

## Références

- [GitLab-managed Terraform/OpenTofu state](https://docs.gitlab.com/user/infrastructure/iac/terraform_state/)
- [GitLab OIDC avec AWS](https://docs.gitlab.com/ci/cloud_services/aws/)
- [Backend HTTP Terraform](https://developer.hashicorp.com/terraform/language/backend/http)
- [Inventaire EC2 et connexion SSM Ansible](https://docs.ansible.com/projects/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html)
- [Connexion Ansible par AWS Systems Manager](https://docs.ansible.com/projects/ansible/latest/collections/amazon/aws/aws_ssm_connection.html)
- [Tarification des IPv4 publiques AWS](https://aws.amazon.com/vpc/pricing/)
