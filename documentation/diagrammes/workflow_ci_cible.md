# Architecture CI/CD cible

**État :** architecture conçue en F.5 ; son implémentation sera prouvée progressivement dans les parties 1 et 2.

**Vue avant :** [workflow CI actuel](workflow_ci_actuel.md)

**Export :** [SVG](workflow_ci_cible.svg)

```mermaid
flowchart TB
    DEV["Développeur"] -->|"push · merge request · tag"| REPO["Repository GitLab"]

    subgraph P1["Partie 1 — GitLab CI/CD"]
        direction TB
        REPO --> PIPE["Pipeline GitLab CI"]

        subgraph FLOW["Stages"]
            direction LR
            TEST["test<br/>linters · Angular · JUnit · scripts"]
            QUALITY["quality<br/>SonarQube · dépendances · secrets"]
            BUILD["build<br/>Angular · JAR · images"]
            RELEASE["release<br/>scan Trivy · publication · manifeste"]
            TEST --> QUALITY --> BUILD --> RELEASE
        end

        PIPE --> TEST
        TEST -. "JUnit · couverture" .-> REPORTS["Rapports et artifacts GitLab"]
        QUALITY -. "qualité · vulnérabilités" .-> REPORTS
        BUILD --> ARTIFACTS["Build Angular · JAR · images"]
        ARTIFACTS --> RELEASE
        QUALITY <-->|"analyse"| SONAR["SonarQube Cloud"]
        RELEASE --> REGISTRY["GitLab Container Registry<br/>images par SHA et digest"]
        RELEASE --> MANIFEST["Manifeste de release<br/>version · commit · pipeline · digests"]
        PIPE -. "statut" .-> NOTIFY["Notification<br/>canal à arbitrer"]
    end

    subgraph P2["Partie 2 — Deployment AWS"]
        direction TB
        DEPLOY["deploy<br/>Terraform · Ansible · Helm"]
        VERIFY["verify<br/>healthchecks · smoke tests · API · métriques"]

        subgraph AWS["AWS — EC2 avec cluster K3s"]
            direction LR
            ENTRY["Entrée HTTP(S)"]
            FRONT["Pods frontend"]
            BACK["Pods backend"]
            DB[("PostgreSQL<br/>stockage persistant")]
            ENTRY --> FRONT -->|"nom de service"| BACK --> DB
        end

        DEPLOY --> AWS
        AWS --> VERIFY
        VERIFY --> EVIDENCE["Preuves de deployment<br/>performance · backup/restore · rollback"]
    end

    REGISTRY -->|"images immuables"| DEPLOY
    MANIFEST -->|"version à déployer"| DEPLOY

    classDef actor fill:#f8fafc,stroke:#475569,color:#0f172a,stroke-width:1.5px
    classDef gitlab fill:#eff6ff,stroke:#2563eb,color:#172554,stroke-width:1.5px
    classDef output fill:#ecfdf5,stroke:#059669,color:#064e3b,stroke-width:1.5px
    classDef external fill:#faf5ff,stroke:#9333ea,color:#581c87,stroke-width:1.5px
    classDef aws fill:#fff7ed,stroke:#ea580c,color:#7c2d12,stroke-width:1.5px
    classDef pending fill:#f8fafc,stroke:#64748b,color:#334155,stroke-width:1.5px,stroke-dasharray:5 5

    style P1 fill:#eff6ff,stroke:#2563eb,color:#172554,stroke-width:2px
    style FLOW fill:#f8fafc,stroke:#93c5fd,color:#172554,stroke-width:1.5px
    style P2 fill:#fff7ed,stroke:#ea580c,color:#7c2d12,stroke-width:2px
    style AWS fill:#fffbeb,stroke:#fdba74,color:#7c2d12,stroke-width:1.5px

    class DEV,REPO actor
    class PIPE,TEST,QUALITY,BUILD,RELEASE gitlab
    class REPORTS,ARTIFACTS,REGISTRY,MANIFEST,EVIDENCE output
    class SONAR external
    class DEPLOY,VERIFY,ENTRY,FRONT,BACK,DB aws
    class NOTIFY pending
```

## Lecture du schéma

| Zone | Signification |
|---|---|
| Partie 1 — bleu | Pipeline GitLab à mettre en œuvre et prouver pendant la partie 1 |
| Sorties — vert | Rapports, artifacts, images et manifeste conservés comme preuves |
| Services — violet | Service externe utilisé par la CI |
| Partie 2 — orange | Infrastructure et deployment AWS à réaliser pendant la partie 2 |
| Pointillé gris | Élément prévu dont le choix final reste à arbitrer |

## Règles de circulation

- une merge request exécute `test → quality → build → scan des images`, sans publication ;
- avec SonarQube Cloud Free, le job `quality:sonarqube` analyse les merge requests et `main`, mais pas les push directs sur `dev` ;
- `release` publie uniquement depuis la branche principale ou un tag autorisé ;
- une pipeline planifiée répète les tests et scans sans publier d’image ;
- `deploy` consomme les images et le manifeste produits par la release ;
- le frontend rejoint le backend par un nom de service, sans adresse IP codée en dur ;
- `verify` intervient après le deployment et conserve ses résultats comme preuves.

## Traçabilité avant/après

| État | Référence |
|---|---|
| Avant | branche `dev`, commit `526bd96cddd2903676988b56dfeb2778667aa435` |
| Cible conçue | présent schéma F.5 |
| Après | release finale et commit à renseigner après l’implémentation |
