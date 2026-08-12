# Évolutions CI/CD non implémentées

L’architecture CI/CD versionnée est décrite dans le
[workflow actuel](workflow_ci_actuel.md). Ce fichier recense uniquement les
écarts encore ouverts.

```mermaid
flowchart LR
    CURRENT[Pipeline actuelle] --> ROLLBACK[Rollback automatisé]
    CURRENT --> BACKUP[Sauvegarde PostgreSQL et restauration testée]
    CURRENT --> TLS[Entrée HTTPS configurée]
    CURRENT --> PROD[Architecture de production résiliente]

    classDef current fill:#eff6ff,stroke:#2563eb,color:#172554
    classDef target fill:#f8fafc,stroke:#64748b,color:#334155,stroke-dasharray:5 5
    class CURRENT current
    class ROLLBACK,BACKUP,TLS,PROD target
```

| Évolution | État actuel | Condition de réalisation |
|---|---|---|
| Rollback automatisé | Aucun job dédié | Redéployer des digests connus et vérifier l’application |
| Sauvegarde des données | `backup.sh` valide seulement un `--dry-run` | Produire une sauvegarde PostgreSQL et réussir une restauration contrôlée |
| HTTPS | Ports réseau disponibles, aucun TLS configuré dans le chart | Configurer le certificat et l’Ingress |
| Production résiliente | POC K3s mono-nœud | Définir une architecture multi-nœuds et un stockage adapté |

Ces éléments sont des évolutions possibles. Ils ne décrivent pas des fonctions
disponibles dans le dépôt.
