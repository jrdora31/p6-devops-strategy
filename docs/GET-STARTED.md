# Get Started

Procédure à suivre après avoir cloné MicroCRM pour lancer le projet et effectuer un premier déploiement.

## 1. Prérequis

TODO : lister uniquement les outils et accès réellement nécessaires.

* Git
* Docker
* AWS CLI
* Terraform
* Ansible
* Helm
* kubectl
* Compte AWS
* Accès au projet GitLab

## 2. Cloner le repository

```bash
TODO
```

## 3. Lancer en local

Le lancement local, les tests et l'utilisation des images Docker sont documentés dans le [README principal](../README.md).

## 4. Authentification

### AWS

TODO : procédure / commande de connexion AWS.

### GitLab

TODO : procédure nécessaire pour permettre au bootstrap de configurer le projet GitLab.

## 5. Bootstrap initial

→ QUOI FAIRE
→ dans quel ordre
→ commandes à lancer

> À exécuter une seule fois lors de l'initialisation du projet.

```text
Bootstrap
├── Provisionnement des rôles et permissions IAM AWS
├── Récupération des ARN nécessaires
└── Création des variables CI/CD GitLab
```

TODO : ajouter la commande du script bootstrap.

```bash
TODO
```

## 6. Variables et secrets

TODO : lister les variables nécessaires et préciser lesquelles sont :

* créées automatiquement par le bootstrap ;
* renseignées manuellement ;
* générées par AWS ;
* stockées dans GitLab CI/CD.

## 7. Premier déploiement

TODO : expliquer uniquement comment déclencher le premier déploiement.

```text
GitLab CI/CD
    ↓
Terraform
    ↓
Ansible
    ↓
Helm
    ↓
MicroCRM
```

TODO : commande ou action GitLab nécessaire.

## 8. Vérifier le déploiement

TODO : ajouter uniquement les vérifications utiles.

```bash
TODO
```

## 9. Où modifier quoi

| Besoin                            | Emplacement                 |
| --------------------------------- | --------------------------- |
| Infrastructure AWS                | `infrastructure/terraform/` |
| Configuration des instances / K3s | `infrastructure/ansible/`   |
| Déploiement applicatif K3s        | `infrastructure/helm/`      |
| Pipeline CI/CD                    | `.gitlab-ci.yml`            |
| Scripts d'initialisation          | `scripts/`                  |

## 10. Documentation associée

* [Stack](stack.md)
* [Architecture AWS](schema_architecture_aws.md)
* [Pipeline CI/CD](ci-cd/pipeline.md)
* [Stratégie de release](ci-cd/release-strategy.md)
* [Terraform](infrastructure/terraform.md)
* [Ansible](infrastructure/ansible.md)
* [Helm](infrastructure/helm.md)
