# Architecture AWS du POC

> Architecture cible au 3 août 2026. Elle deviendra une architecture réalisée après les preuves Terraform, Ansible et Helm.

```mermaid
flowchart LR
    DEV[Repository MicroCRM] --> CI[GitLab CI/CD]
    CI --> STATE[State Terraform GitLab]
    CI -->|OIDC| STS[AWS STS]
    STS --> TF[Terraform]
    STS --> ANS[Ansible]

    subgraph AWS[AWS eu-west-3]
        VPC[VPC]
        SUBNET[Subnet publique]
        EC2[EC2 t3.medium amd64]
        S3[S3 temporaire Ansible]
        SSM[Systems Manager]

        subgraph K3S[K3s mono-nœud]
            TRAEFIK[Traefik Ingress]
            AGENT[GitLab Agent]
            FRONT[Frontend]
            BACK[Backend]
            DB[(PostgreSQL sur gp3)]
        end

        VPC --> SUBNET --> EC2 --> K3S
        SSM --> EC2
        ANS -->|transfert temporaire| S3
        TRAEFIK --> FRONT --> BACK --> DB
    end

    TF --> VPC
    TF --> EC2
    TF --> S3
    ANS -->|inventaire par tags et connexion SSM| EC2
    AGENT -->|connexion sortante| CI
    CI -->|Helm via Agent| K3S
    USER[Utilisateur] -->|HTTP puis HTTPS| TRAEFIK
```

## Limite et évolution

L'architecture réalisée pour le POC restera mono-nœud : l'EC2, son Availability
Zone et son volume constituent des points uniques de panne. Les redémarrages
Kubernetes, les backups et la reconstruction par IaC améliorent la résilience,
mais ne constituent pas une haute disponibilité.

Une cible de production ajouterait plusieurs nodes répartis entre plusieurs
Availability Zones, une entrée réseau redondée et une base de données répliquée.
Cette cible est une recommandation et ne sera pas présentée comme déployée.
