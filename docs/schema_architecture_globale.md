# Architecture globale du POC MicroCRM

Vue d’ensemble de l’infrastructure AWS, du cluster K3s, des déploiements
GitLab CI/CD et de la supervision du POC MicroCRM.

## Schéma

```mermaid
flowchart TB
    USER["Utilisateurs"] -->|HTTP| NLB

    subgraph AWS["AWS"]
        subgraph VPC["VPC"]
            subgraph SUBNET["Subnet public unique — une AZ"]
                NLB["NLB x1<br/>TCP/80"]

                subgraph K3S["Cluster K3s partagé — redondance partielle"]
                    EC1["EC2 STAGING<br/>server/control-plane x1<br/>+ workloads staging"]
                    EC2["EC2 PRODUCTION<br/>agent/worker x1<br/>+ stable et canary"]
                    TRAEFIK["Traefik<br/>routage HTTP"]
                    AGENT["Agent GitLab"]

                    subgraph STAGING["namespace staging"]
                        STGAPP["Frontend x2 → Backend x2"]
                        STGDB["PostgreSQL x1"]
                        STGAPP --> STGDB
                    end

                    subgraph PRODUCTION["namespace production"]
                        PRODAPP["Traefik 90/10<br/>stable + canary"]
                        PRODDB["PostgreSQL x1"]
                        PRODAPP --> PRODDB
                    end
                end
            end
        end

        CW["CloudWatch<br/>logs, métriques et alertes"]
    end

    NLB --> EC1
    NLB --> EC2
    EC1 --> TRAEFIK
    EC2 --> TRAEFIK
    TRAEFIK --> STGAPP
    TRAEFIK --> PRODAPP

    subgraph GITLAB["GitLab"]
        CI["Pipeline CI/CD"]
        REGISTRY["Container Registry"]
    end

    CI -->|déploiement Helm| AGENT
    AGENT --> STGAPP
    AGENT --> PRODAPP
    REGISTRY -.->|images| STGAPP
    REGISTRY -.->|images| PRODAPP

    IAC["Terraform + Ansible"] -.->|AWS et configuration via SSM| EC1
    IAC -.->|AWS et configuration via SSM| EC2
    EC1 -.->|logs et métriques| CW
    EC2 -.->|logs et métriques| CW
```

Le trafic utilisateur entre par le NLB, puis Traefik le dirige vers le
frontend de l'environnement demandé. En production, son routage pondéré natif
sépare stable et Canary sur l'EC2 production. GitLab déploie les releases Helm par son
agent, tandis que les Pods récupèrent leurs images dans le Container Registry.
Terraform provisionne AWS, Ansible configure les deux nœuds par SSM et
CloudWatch centralise leur supervision.

## Limites du POC

Le POC dispose de deux EC2, mais d’un seul control-plane K3s.

- **Si l'EC2 staging tombe :** les Pods présents sur l'EC2 production peuvent continuer à
  fonctionner, mais le cluster ne peut plus les déployer ou les remplacer.
- **Si l'EC2 production tombe :** le control-plane reste disponible, mais les
  `nodeSelector` empêchent de déplacer implicitement la production en staging.
- **PostgreSQL reste non redondé** et son stockage local demeure un point
  unique de défaillance.

Le NLB distribue le trafic TCP vers les deux EC2, tandis que Traefik gère le
routage HTTP dans K3s. Ce découpage est cohérent et simple pour le POC. Un ALB
ajouterait une seconde couche de routage HTTP, partiellement redondante avec
Traefik.

En production, il faudrait plusieurs nœuds `server` K3s répartis sur plusieurs
zones, des workers redondés et une base de données hautement disponible.
