# Documentation MicroCRM

## Démarrage rapide

| Besoin | Source principale |
|---|---|
| Installer et lancer l’application | [`../README.md`](../README.md) |
| Comprendre la pipeline | [`diagrammes/workflow_ci_actuel.md`](diagrammes/workflow_ci_actuel.md) |
| Exécuter les tests | [`ci_cd/tests.md`](ci_cd/tests.md) |
| Comprendre les contrôles de sécurité | [`ci_cd/securite.md`](ci_cd/securite.md) |
| Créer une release | [`ci_cd/release_rollback_sauvegarde.md`](ci_cd/release_rollback_sauvegarde.md) |
| Valider ou déployer l’infrastructure | [`../infrastructure/README.md`](../infrastructure/README.md) |
| Déployer le chart localement | [`../helm/microcrm/README.md`](../helm/microcrm/README.md) |
| Comprendre l’architecture AWS | [`diagrammes/architecture_aws.md`](diagrammes/architecture_aws.md) |
| Identifier les évolutions non implémentées | [`diagrammes/evolutions_ci_cd.md`](diagrammes/evolutions_ci_cd.md) |
| Consulter les mesures | [`livrables/mesures.md`](livrables/mesures.md) |
| Retrouver l’audit initial | [`livrables/audit_initial.md`](livrables/audit_initial.md) |
| Retrouver la conception initiale | [`livrables/conception_initiale.md`](livrables/conception_initiale.md) |

## Organisation

```text
documentation/
├── README.md
├── ci_cd/       Procédures et références CI/CD actuelles
├── diagrammes/  Architectures actuelles et évolutions non implémentées
└── livrables/   Audit, plan, rapports et captures historiques datés
```

Les fichiers de `livrables/` expliquent les constats et décisions à une date
donnée. Ils ne remplacent pas les références opérationnelles. Les fichiers de
`ci_cd/`, les README de composant et le code du dépôt décrivent le
fonctionnement actuel.

## Sources de vérité

- Pipeline : `.gitlab-ci.yml` et `.gitlab/ci/*.yml`.
- Images : `misc/docker/*.Dockerfile` et `misc/docker/Caddyfile`.
- Infrastructure AWS : `infrastructure/terraform/`.
- Configuration du serveur : `ansible/`.
- Ressources Kubernetes : `helm/microcrm/`.
- Scripts d’automatisation : `scripts/ci/`.
- Monitoring : Terraform et `ansible/roles/cloudwatch_agent/`.

En cas d’écart, le code versionné prévaut. Une preuve GitLab ou AWS datée reste
nécessaire pour affirmer qu’une configuration a réellement été exécutée.
