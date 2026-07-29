# Normalisation du processus de développement et plan de mise en œuvre de la chaîne CI

**Projet :** MicroCRM

**État actuel du document :** introduction et baseline renseignées ; sections 2 à 4 à compléter aux étapes prévues.

> Le plan présenté dans ce document illustre la structure attendue dans le cadre d’un projet réel.
>
> Dans le contexte de cet exercice, chaque section doit rester proportionnée au besoin afin d’éviter un niveau de détail excessif.
>
> Ce document sert de guide plutôt que de liste d’attentes strictes à respecter à la lettre.

## Sommaire

1. [Introduction](#1-introduction)
2. [Normes et bonnes pratiques](#2-normes-et-bonnes-pratiques)
3. [Plan de mise en œuvre](#3-plan-de-mise-en-œuvre)
4. [Conclusion](#4-conclusion)

## 1. Introduction

### 1.1 Objectifs

Définir les règles communes et le plan de mise en œuvre de la future chaîne CI/CD de MicroCRM à partir d’un état initial vérifié.

### 1.2 Contexte

MicroCRM est un monorepo GitLab composé d’un frontend Angular et d’un backend Spring Boot. La CI actuelle comprend deux stages, `test` et `build`, et quatre jobs.

#### État initial de référence

| Aspect | État actuel | Preuve |
|---|---|---|
| Tests | 8 tests frontend et 2 tests backend réussis ; peu de scénarios métier | Rapports Karma et Gradle |
| Couverture | 30,76 % des lignes et 9,52 % des branches côté frontend | Rapport de couverture local |
| Builds | Builds Angular et Gradle réussis ; certaines opérations sont répétées | Sorties de build et `.gitlab-ci.yml` |
| Release | Aucun rapport, artifact ou image publié par la CI | `.gitlab-ci.yml` |
| Sécurité | Aucun scan automatisé ; 64 alertes npm observées | CI et sortie `npm ci` |
| Conteneurs | Trois cibles construites ; images non tracées, exécutées avec `root` et sans healthcheck | `Dockerfile` et smoke tests |
| Configuration | URL locale, port backend incohérent, données non persistantes et CORS permissif | Configurations Angular, Spring et Docker |

Les mesures ont été réalisées localement sur la branch `dev`, au commit `526bd96cddd2903676988b56dfeb2778667aa435`. Aucun runner GitLab distant, environnement AWS, test de charge ou indicateur de production n’a été observé.

Les résultats détaillés et leurs preuves sont conservés dans le [document d’audit](01_audit_veille_recommandations.md).

## 2. Normes et bonnes pratiques

> Cette partie sera complétée en `F`, après la veille technologique et la validation de la chaîne CI cible.

### 2.1 Principes de base

> Énoncer les principes fondamentaux qui guident la normalisation du processus de développement, par exemple l’automatisation, la répétabilité, la sécurité et la qualité.

À compléter en `F`.

### 2.2 Conventions d’écriture de code et règles de style

> Décrire les normes de codage suivies par les développeurs, par exemple les conventions de nommage, l’organisation du code et sa documentation.

À compléter en `F`.

### 2.3 Gestion des versions (`versioning`)

> Définir les règles de versioning et d’utilisation des branches, par exemple Gitflow, trunk-based development ou fork and pull.

À compléter en `F`.

### 2.4 Revue de code (`code review`)

> Établir les procédures de revue de code, les critères d’acceptation et les outils utilisés, par exemple les merge requests.

À compléter en `F`.

### 2.5 Intégration continue (`CI`)

> Spécifier les pratiques d’intégration continue, la fréquence des intégrations, les critères de réussite et les outils CI, par exemple GitLab CI.

À compléter en `F`.

### 2.6 Tests

> Définir les tests à automatiser dans la chaîne CI et leur fréquence d’exécution.

À compléter en `F`.

### 2.7 Sécurité

> Définir les pratiques de sécurité appliquées au processus de développement, par exemple les scans, la gestion des secrets et les audits de sécurité.

À compléter en `F`.

### 2.8 Documentation

> Définir les exigences documentaires à chaque étape du processus de développement, par exemple la documentation du code et la documentation utilisateur.

À compléter en `F`.

## 3. Plan de mise en œuvre

> Cette partie sera complétée lorsque les recommandations et l’architecture cible auront été validées.

### 3.1 Objectifs

> Rappeler les objectifs du plan de mise en œuvre et les résultats attendus.

À compléter en `F`.

### 3.2 Étapes

> Lister les étapes de mise en œuvre en indiquant l’objectif et les livrables associés à chacune.

À compléter en `F`.

#### 3.2.1 `<Étape X>`

- **Description :** décrire l’objectif de l’étape et les actions concrètes à mener.
- **Responsables :** identifier les responsables de la réalisation.
- **Livrables :** identifier les productions concrètes attendues, par exemple un rapport d’audit, une documentation ou un pipeline CI configuré et fonctionnel.

Cette rubrique sera dupliquée pour chaque étape réellement retenue.

### 3.3 Ressources nécessaires

> Lister les ressources nécessaires, par exemple le personnel, le budget et les environnements techniques.

À compléter en `F`.

### 3.4 Calendrier prévisionnel

> Proposer un calendrier prévisionnel dans un cadre normal de fonctionnement, avec les ressources disponibles et sans difficulté majeure.

À compléter en `F.4`.

### 3.5 Gestion des risques

> Identifier les risques liés à la mise en œuvre et les stratégies permettant de les atténuer.

À compléter en `F`.

## 4. Conclusion

### 4.1 Synthèse

> Synthétiser les principaux objectifs de la normalisation et les avantages apportés au projet.

À compléter après la mise en œuvre.

### 4.2 Prochaines étapes

> Identifier les étapes suivant la mise en œuvre afin d’assurer le succès à long terme de la stratégie de normalisation.

À compléter après la mise en œuvre.
