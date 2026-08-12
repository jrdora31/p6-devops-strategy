# Architecture AWS du POC

```mermaid
flowchart LR
    REPO[Dépôt MicroCRM] --> CI[GitLab CI/CD]
    CI --> STATE[State Terraform GitLab]
    CI -->|OIDC| STS[AWS STS]
    STS --> TF[Terraform]
    STS --> ANS[Ansible via SSM]

    subgraph AWS[AWS eu-west-3]
        VPC[VPC]
        SUBNET[Subnet publique]
        EC2[EC2 x86_64]
        S3[S3 temporaire pour Ansible]
        SSM[AWS Systems Manager]
        CW[CloudWatch Logs, métriques et dashboard]

        subgraph K3S[K3s mono-nœud]
            TRAEFIK[Traefik Ingress]
            AGENT[GitLab Agent]
            FRONT[Frontend]
            BACK[Backend]
            DB[(PostgreSQL sur PVC local-path)]
        end

        VPC --> SUBNET --> EC2 --> K3S
        SSM --> EC2
        EC2 -.-> CW
        ANS -->|transfert temporaire| S3
        TRAEFIK --> FRONT --> BACK --> DB
    end

    TF --> VPC
    TF --> EC2
    TF --> S3
    ANS --> EC2
    AGENT -->|connexion sortante| CI
    CI -->|Helm via GitLab Agent| K3S
    USER[Utilisateur HTTP] --> TRAEFIK
```

## Composants versionnés

| Couche | Configuration | Rôle |
|---|---|---|
| Réseau et EC2 | `infrastructure/terraform/` | VPC, subnet, routes, security group, IAM et instance K3s |
| Transfert Ansible | `infrastructure/terraform/modules/ansible_transfer/` | Bucket S3 temporaire et privé pour la connexion SSM |
| Configuration | `ansible/` | K3s, GitLab Agent et CloudWatch Agent conditionnel |
| Application | `helm/microcrm/` | Frontend, backend, PostgreSQL, Ingress et NetworkPolicies |
| Monitoring | Terraform et rôle Ansible `cloudwatch_agent` | Groupes de logs, métriques hôte et dashboard |

CloudWatch est créé uniquement lorsque `CLOUDWATCH_AGENT_ENABLED=true`. Le
dépôt ne crée aucune alarme CloudWatch.

## Limites

- Le POC utilise une seule instance EC2, une seule Availability Zone et un
  stockage PostgreSQL local au nœud.
- Le chart expose l’application par Traefik sans configuration TLS.
- L’infrastructure peut être reconstruite par IaC, mais cette reproductibilité
  ne remplace pas une sauvegarde des données.
- L’architecture versionnée a déjà été déployée lors des cycles de preuve. La
  reconstruction complète du monitoring après destruction reste à observer.
