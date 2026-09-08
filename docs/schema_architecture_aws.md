# Schéma d’architecture AWS

Vue d'ensemble de l'architecture déclarée de MicroCRM sur AWS. Son exécution
réelle doit encore être validée par un déploiement.

## Schéma

```text
VPC MicroCRM partagé
└── Subnet public + Security Group HTTP/HTTPS/SSM
    ├── EC2 Debian 12 staging
    │   └── K3s staging
    │       └── Helm : namespace microcrm-staging
    └── EC2 Debian 12 production
        └── K3s production
            └── Helm : namespace microcrm-prod

GitLab CI/CD
├── dev  ──> state microcrm-staging    ──> SSM/Ansible staging
├── main ──> state microcrm-production ──> SSM/Ansible production
├── tag RC    ──> GitLab Agent staging    ──> Helm staging
└── tag final ──> GitLab Agent production ──> Helm production
```
