# Sécurité de la CI/CD

## Contrôles actifs

| Périmètre | Job | Contrôle | Bloquant |
|---|---|---|---:|
| Code et couverture | `quality:sonarqube` | Quality gate SonarQube | Oui |
| Scripts shell | `quality:shellcheck` | Diagnostics ShellCheck | Oui |
| Dépôt | `quality:trivy:repository` | Vulnérabilités `CRITICAL` corrigibles | Oui |
| Dépôt | `quality:trivy:repository` | Secrets détectés | Oui |
| Images | `release:scan:image:frontend`, `release:scan:image:backend` | Vulnérabilités `CRITICAL` corrigibles et secrets | Oui |
| Manifests Helm | `quality:trivy:kubernetes` | Mauvaises configurations `HIGH` ou `CRITICAL` | Oui |
| Terraform | `quality:trivy:iac` | Mauvaises configurations `CRITICAL` | Oui |
| Déploiement Helm | `deploy:helm:staging`, `deploy:helm:aws` | Déploiement atomique avec attente | Oui |

Les vulnérabilités `HIGH` du dépôt, des images et de Terraform restent dans les
rapports. Elles ne bloquent pas automatiquement la pipeline. Les rapports Trivy
sont conservés 30 jours.

SonarQube s’exécute sur les merge requests et sur la branche par défaut. Le job
attend le résultat du quality gate. Les tests et leur portée sont décrits dans
les [tests automatisés](tests.md).

## Protection du déploiement

- AWS utilise des jetons OIDC GitLab temporaires.
- `AWS_PLAN_ROLE_ARN` sert au plan Terraform ; `AWS_APPLY_ROLE_ARN` sert aux
  opérations d’écriture.
- Terraform applique le fichier `.terraform-plan` produit par le job de plan.
- Le plan binaire et les sorties Terraform expirent après un jour.
- `deploy:terraform:destroy` est manuel et refuse l’exécution si
  `TF_DESTROY_CONFIRM` ne vaut pas `true`.
- Les déploiements Helm consomment des images identifiées par digest.
- Les Dockerfiles frontend et backend exécutent l’application avec un
  utilisateur non-root.
- Les `NetworkPolicy` limitent les flux entre frontend, backend et PostgreSQL.

## Variables sensibles

| Variable ou identité | Usage | Exigence |
|---|---|---|
| `SONAR_TOKEN` | Analyse SonarQube | Variable GitLab masquée |
| `AWS_PLAN_ROLE_ARN` | Plan Terraform | Rôle AWS en lecture |
| `AWS_APPLY_ROLE_ARN` | Apply, destroy et Ansible | Rôle AWS limité au POC |
| `GITLAB_AGENT_TOKEN` | Connexion sortante du GitLab Agent | Variable protégée et masquée |
| `CI_DEPLOY_USER`, `CI_DEPLOY_PASSWORD` | Lecture de la registry depuis K3s | Identifiants de déploiement GitLab |
| `KUBERNETES_DATABASE_PASSWORD` | Secret PostgreSQL | Variable GitLab masquée |
| `DORA_GITLAB_TOKEN` | API deployments, MR et issues | Jeton limité à `read_api` |

Les jobs Helm encodent les valeurs puis créent les Secrets Kubernetes
`microcrm-registry` et `microcrm-database`. Aucun secret ne doit être ajouté aux
values Helm, aux artefacts ou aux logs.

## Limites connues

- Les images de certains jobs CI utilisent des tags sans digest. Les images
  Trivy et Helm sont épinglées par digest.
- L’API MicroCRM ne contient pas de mécanisme d’authentification applicative.
- L’Ingress du POC ne configure pas TLS.
- Le stockage PostgreSQL `local-path` reste lié au nœud K3s.
