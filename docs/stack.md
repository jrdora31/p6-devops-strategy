# Stack technique

Vue exhaustive et concise des technologies utilisées dans MicroCRM.

## Vue d'ensemble

| Domaine | Technologies |
|---|---|
| Frontend | Angular 17.3, TypeScript 5.4 |
| Backend | Spring Boot 3.x, Java 17 |
| Conteneurisation | Docker |
| CI/CD | GitLab CI/CD |
| IaC | Terraform, Ansible |
| Système EC2 | 2 × Debian 12 (Bookworm) amd64 |
| Orchestration | 1 cluster K3s partagé (1 server + 1 agent), Helm |
| Cloud | AWS |
| Observabilité | CloudWatch |

## Frontend

- Angular 17.3
- TypeScript 5.4
- Emplacement : `front/`

## Backend

- Spring Boot 3.x
- Java 17
- Emplacement : `back/`

## Infrastructure

- Terraform : provisionnement AWS
- Ansible : nœud serveur dédié aux workloads staging et nœud agent dédié à production
- Helm : staging normal et stable/Canary production dans deux namespaces du cluster partagé
- Emplacement : `infrastructure/`

## CI/CD

- GitLab CI/CD
- Pipeline : `.gitlab-ci.yml`

## Cloud

- AWS

## observabilité

- CloudWatch
