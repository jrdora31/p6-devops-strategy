# Schéma d’architecture AWS

Vue d'ensemble de l'architecture déclarée de MicroCRM sur AWS. Son exécution
réelle doit encore être validée par un déploiement.

## Schéma

```text
VPC MicroCRM partagé
└── Subnet public unique (limite mono-AZ du POC)
    ├── Network Load Balancer TCP/80
    └── Cluster K3s partagé
        ├── EC2 Debian 12 : server/control-plane + workloads
        ├── EC2 Debian 12 : agent/worker
        └── Traefik
            ├── namespace microcrm-staging
            └── namespace microcrm-prod

GitLab CI/CD
├── Web dev  ──> states microcrm-network + microcrm-poc ──> SSM/Ansible
├── tag RC    ──> GitLab Agent microcrm-poc ──> Helm staging
└── tag final ──> GitLab Agent microcrm-poc ──> Helm production
```
