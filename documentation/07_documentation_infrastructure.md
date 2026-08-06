# Documentation de l'infrastructure

> État au 5 août 2026 : architecture du POC exécutée puis détruite par la
> pipeline `main` `#2731910227`. La prochaine session AWS restera éphémère.

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

## Observabilité CloudWatch proposée pour le POC

Le flux cible est volontairement limité afin de préserver les ressources de
l'instance unique et le crédit AWS. CloudWatch est traité comme un équivalent
provisoire d'ELK, sous réserve de l'avis du mentor :

```text
EC2 / K3s / Caddy / backend
          |
          | CloudWatch Agent (métriques hôte et logs sélectionnés)
          v
CloudWatch Metrics + CloudWatch Logs
          |
          +--> Dashboard et alarmes de session

GitLab pipelines / deployments / incidents
          |
          +--> artifacts et historique GitLab pour les métriques DORA
```

Sources prévues : logs applicatifs et Caddy, événements K3s utiles, métriques
CPU/mémoire/disque de l'EC2, résultats de vérification Kubernetes et événements
GitLab. Les logs Kubernetes détaillés ne seront collectés que si leur volume et
leur utilité sont démontrés.

Le transport repose sur les sorties HTTPS déjà nécessaires à SSM, GitLab et aux
registries. Aucun port entrant supplémentaire, notamment pour une interface
d'administration, ne doit être ouvert sur Internet. L'accès aux données doit
être limité par IAM ; les secrets, tokens, mots de passe, valeurs PostgreSQL et
en-têtes sensibles doivent être exclus ou masqués avant centralisation.

### Rétention et enveloppe de volume

Pour une session éphémère, les groupes de logs devront avoir une rétention
explicite de 1 à 3 jours, puis être supprimés avec l'environnement. Une
rétention indéfinie n'est pas acceptable pour ce POC compte tenu du suivi des
crédits.

Avant mesure réelle, l'enveloppe de travail est fixée à 10 Mo de logs par heure,
soit environ 240 Mo pour 24 heures. Il s'agit d'une estimation de conception,
pas d'une consommation observée. Si la mesure dépasse cette enveloppe, il faudra
réduire la verbosité ou la durée de rétention avant de poursuivre.

Cette proposition CloudWatch est liée à l'arbitrage `ARB-16`, qui reste soumis
à l'avis du mentor. Elle ne signifie pas que l'agent, les groupes de logs ou les
alarmes sont déjà déployés.

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

Le POC utilise un seul cluster K3s pour limiter le coût, avec deux environnements
applicatifs isolés par namespace : `microcrm-staging` pour `dev` et
`microcrm-prod` pour les tags SemVer promus manuellement. Cette séparation permet
de tester la livraison avant la production, mais ne doit pas être présentée
comme deux clusters, une haute disponibilité ou une isolation AWS complète.

- le state Terraform porte le nom `microcrm-poc` dans GitLab et n'est jamais versionné dans Git ;
- les jobs AWS obtiennent des credentials temporaires par OIDC et AWS STS ;
- l'Identity Provider GitLab et le rôle de plan en lecture seule sont configurés ;
- un rôle séparé réalisera les `apply` et `destroy` manuels, avec une confiance
  limitée au projet MicroCRM et aux branches `dev` et `main` ;
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

## Maîtrise du coût

Le budget de travail est calculé sur l'instance observée `m7i-flex.large`, active
au maximum `80 heures`, puis détruite hors essais. CloudWatch est limité aux
logs critiques, aux métriques nécessaires, à un dashboard et à quelques alarmes.

| Poste | Hypothèse de contrôle |
|---|---|
| EC2 `m7i-flex.large` | observation : `0,11172 USD/h`, soit environ `8,94 USD` pour 80 h |
| IPv4 publique | `0,005 USD/h`, soit `0,40 USD` pour 80 h |
| EBS gp3 20 Gio | environ `0,093 USD/GB-mois`, proratisé selon la durée |
| CloudWatch contrôlé | environ `0–0,12 USD/jour` selon volume et quotas |
| S3 temporaire | volume très faible, objets supprimés automatiquement |
| State GitLab | aucune ressource AWS supplémentaire |

Le coût prévisionnel de l'EC2 seule sur 80 heures est donc d'environ `8,94 USD`,
hors transfert, taxes, CloudWatch et ressources temporaires. Ce montant n'est
pas un devis : le prix de `eu-west-3`, les crédits restants et leur date
d'expiration doivent être vérifiés dans AWS avant tout `terraform apply`.

## Prochaine validation

Les sources Terraform passent `fmt` et `validate` localement. Les fichiers YAML
GitLab et Ansible sont syntaxiquement valides. La pipeline doit encore exécuter
`ansible-lint` et Trivy IaC avant tout provisionnement.

Avant le prochain `terraform plan` connecté à AWS : vérifier les crédits,
confirmer `eu-west-3`, relever le tarif de `m7i-flex.large` et les coûts
CloudWatch, puis autoriser explicitement la création des ressources.

## Références

- [GitLab-managed Terraform/OpenTofu state](https://docs.gitlab.com/user/infrastructure/iac/terraform_state/)
- [GitLab OIDC avec AWS](https://docs.gitlab.com/ci/cloud_services/aws/)
- [Backend HTTP Terraform](https://developer.hashicorp.com/terraform/language/backend/http)
- [Inventaire EC2 et connexion SSM Ansible](https://docs.ansible.com/projects/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html)
- [Connexion Ansible par AWS Systems Manager](https://docs.ansible.com/projects/ansible/latest/collections/amazon/aws/aws_ssm_connection.html)
- [Tarification des IPv4 publiques AWS](https://aws.amazon.com/vpc/pricing/)
- [Agent Amazon CloudWatch](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html)
- [Tarification Amazon CloudWatch](https://aws.amazon.com/cloudwatch/pricing/)
