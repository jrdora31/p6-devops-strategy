# Workflow CI actuel

**État audité :** branche `dev`, commit `526bd96cddd2903676988b56dfeb2778667aa435`.

**Export :** [SVG](workflow_ci_actuel.svg)

```mermaid
flowchart TB
    subgraph CI["Flux observé dans .gitlab-ci.yml"]
        DEV[Développeur] -->|push| REPO[Dépôt GitLab]
        REPO --> PIPE[Pipeline GitLab CI]

        subgraph TESTS["Stage test"]
            TF["test-front<br/>npm ci<br/>8 tests Angular"]
            TB["test-back<br/>./gradlew test<br/>2 tests JUnit"]
        end

        subgraph BUILDS["Stage build"]
            BF["build-front<br/>npm ci relancé<br/>build Angular"]
            BB["build-back<br/>./gradlew build<br/>tests JUnit relancés<br/>JAR Spring Boot"]
        end

        PIPE --> TF
        PIPE --> TB
        TF --> TEST_GATE{"Condition de passage<br/>les deux jobs réussissent"}
        TB --> TEST_GATE
        TEST_GATE --> BF
        TEST_GATE --> BB
        BF --> BUILD_GATE{"Condition de fin<br/>les deux builds réussissent"}
        BB --> BUILD_GATE

        BUILD_GATE --> FIN["Fin du pipeline<br/>sorties de jobs non publiées"]
        FIN -.-> ABS1["Aucun rapport ni artefact applicatif<br/>configuré dans la CI"]
        ABS1 -.-> ABS2["Aucune image publiée par la CI"]
        ABS2 -.-> ABS3["Aucun déploiement automatisé<br/>dans la CI"]
    end

    subgraph MANUAL["Flux Docker hors CI"]
        DOCKER["Build Docker manuel<br/>commandes du README"]
        IMAGES["Images locales<br/>frontend · backend · standalone"]
        OPS["Transmission à l’équipe Ops"]
        TRIVY["Scan Trivy manuel"]
        TARGET["Déploiement manuel<br/>cible non décrite dans le dépôt"]
    end

    DEV -. "documenté et reproduit" .-> DOCKER
    DOCKER --> IMAGES
    IMAGES -. "déclaré par les Ops" .-> OPS
    OPS -. "déclaré par les Ops" .-> TRIVY
    TRIVY -. "déclaré par les Ops" .-> TARGET

    classDef observed fill:#e8f1fb,stroke:#2563eb,color:#172554,stroke-width:1.5px
    classDef reproduced fill:#ecfdf5,stroke:#059669,color:#064e3b,stroke-width:1.5px
    classDef declared fill:#fff7ed,stroke:#ea580c,color:#7c2d12,stroke-width:1.5px,stroke-dasharray:5 5
    classDef gap fill:#fef2f2,stroke:#dc2626,color:#7f1d1d,stroke-width:1.5px

    class DEV,REPO,PIPE,TF,TB,TEST_GATE,BF,BB,BUILD_GATE,FIN observed
    class DOCKER,IMAGES reproduced
    class OPS,TRIVY,TARGET declared
    class ABS1,ABS2,ABS3 gap
```

## Lecture du schéma

| Couleur | Nature de l’information |
|---|---|
| Bleu | Configuration observée dans le dépôt et comportement reproduit pendant l’audit |
| Vert | Commandes Docker documentées dans le README et reproduites localement |
| Orange pointillé | Pratique déclarée dans le sondage Ops, non observable dans la CI actuelle |
| Rouge | Fonction absente de la configuration GitLab CI actuelle |

Les deux jobs d’un même stage peuvent s’exécuter en parallèle. Le stage suivant ne commence que si les deux jobs précédents réussissent.

## Sources

- `.gitlab-ci.yml` au commit audité ;
- `README.md` pour les commandes Docker ;
- mesures locales de l’audit pour les tests, builds et images ;
- sondage Ops pour la transmission, le scan Trivy et le déploiement manuels.
