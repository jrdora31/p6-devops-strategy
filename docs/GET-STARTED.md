# Démarrer MicroCRM

## Local

Cloner le dépôt avec son URL GitLab, puis suivre les commandes frontend,
backend et Docker du [README](../README.md). Selon le parcours choisi, prévoir
Git, Java 21 et le wrapper Gradle, Node/npm ou Docker.

Le dossier [`scripts/bootstrap/`](../scripts/bootstrap/bootstrap.md) prépare
l'automatisation de l'initialisation d'un nouvel environnement. Son point
d'entrée prévu, `bootstrap.py`, regrouperait les prérequis AWS et GitLab.
Cette automatisation reste volontairement un squelette pour le P6 : le
déploiement actuel utilise les accès et variables configurés séparément.

## Premier déploiement du POC

Le premier déploiement prépare l'infrastructure AWS/K3s, puis installe une RC
en staging. Il nécessite un accès AWS en `eu-west-3`, un runner GitLab, des
droits IAM/OIDC, l'Agent GitLab et les variables protégées du projet. Les
secrets restent dans GitLab, jamais dans le dépôt.

Suivre les documents spécialisés selon l'étape : [Terraform](infrastructure/terraform.md)
pour les states et le plan/apply, [Ansible](infrastructure/ansible.md) pour
configurer K3s, [pipeline](ci-cd/pipeline.md) pour les jobs, puis
[stratégie de déploiement](ci-cd/deployment-strategy.md) pour la RC en staging
et la finale en production. Les vérifications Kubernetes sont dans
[Helm](infrastructure/helm.md) et les contrôles applicatifs dans les
[tests](quality/testing.md).

## Repères

[Architecture](schema_architecture_globale.md) · [stack](stack.md) ·
[pipeline](ci-cd/pipeline.md) · [Terraform](infrastructure/terraform.md) ·
[Ansible](infrastructure/ansible.md) · [Helm](infrastructure/helm.md)
