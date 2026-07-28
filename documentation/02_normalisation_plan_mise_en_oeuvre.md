# Normalisation du processus et plan de mise en œuvre

**Projet :** MicroCRM  
**Périmètre actuel :** baseline de la chaîne CI/CD  
**Date de référence :** 26 juillet 2026

## Sommaire

1. [Introduction et baseline](#1-introduction-et-baseline)
2. [Normes et bonnes pratiques](#2-normes-et-bonnes-pratiques)
3. [Plan de mise en œuvre](#3-plan-de-mise-en-œuvre)
4. [Conclusion](#4-conclusion)

## 1. Introduction et baseline

### 1.1 Objectif

Définir les règles communes et le plan de mise en œuvre de la future chaîne CI/CD de MicroCRM à partir d’un état initial vérifié.

### 1.2 Contexte

MicroCRM est un monorepo GitLab composé d’un frontend Angular et d’un backend Spring Boot. La CI actuelle comprend deux stages, `test` et `build`, et quatre jobs.

### 1.3 Baseline

| Aspect | État actuel | Preuve |
|---|---|---|
| Tests | 8 tests frontend et 2 tests backend réussis ; peu de scénarios métier | Rapports Karma et Gradle |
| Couverture | 30,76 % des lignes et 9,52 % des branches côté frontend | Rapport de couverture local |
| Builds | Builds Angular et Gradle réussis ; certaines opérations sont répétées | Sorties de build et `.gitlab-ci.yml` |
| Livraison | Aucun rapport, artefact ou image publié par la CI | `.gitlab-ci.yml` |
| Sécurité | Aucun scan automatisé ; 64 alertes npm observées | CI et sortie `npm ci` |
| Conteneurs | Trois cibles construites ; images non tracées, exécutées avec `root` et sans healthcheck | `Dockerfile` et smoke tests |
| Configuration | URL locale, port backend incohérent, données non persistantes et CORS permissif | Configurations Angular, Spring et Docker |

**Périmètre de la baseline**

Les mesures ont été réalisées localement sur la branche `dev`, au commit `526bd96cddd2903676988b56dfeb2778667aa435`. Aucun runner GitLab distant, environnement AWS, test de charge ou indicateur de production n’a été observé.

Les résultats détaillés et leurs preuves sont conservés dans le [document d’audit](01_audit_veille_recommandations.md).

## 2. Normes et bonnes pratiques

Les règles définitives seront arrêtées après validation de l’architecture cible et des outils.

| Domaine | Décision à formaliser |
|---|---|
| Principes | Automatisation, reproductibilité, sécurité, qualité, DRY, KISS et YAGNI |
| Code | Formatage, nommage, contrôles statiques et critères d’acceptation |
| Git et versions | Branches, merge requests, tags et convention de versioning |
| Revue | Responsables, vérifications requises et conditions de fusion |
| CI/CD | Déclencheurs, stages, artefacts, cache et critères de réussite |
| Tests | Types, fréquence, rapports, couverture et seuils progressifs |
| Sécurité | Scans, secrets, images, exceptions et règles bloquantes |
| Documentation | Contenu à maintenir avec le code et preuves à conserver |

## 3. Plan de mise en œuvre

> Cette section sera complétée lorsque les recommandations et l’architecture cible auront été validées.

### 3.1 Résultat attendu

Une chaîne CI/CD full-stack reproductible, documentée et testée, capable de produire des rapports, des artefacts et des images traçables.

### 3.2 Étapes

Les étapes, responsabilités et résultats seront définis après la sélection des recommandations.

### 3.3 Ressources nécessaires

À préciser : compétences, accès GitLab, runners, outils, budget et environnement AWS.

### 3.4 Calendrier prévisionnel

À construire à partir des dépendances, responsables et disponibilités réelles.

### 3.5 Risques de mise en œuvre

À relier aux choix techniques, aux ressources disponibles et aux mesures d’atténuation.

## 4. Conclusion

La baseline fournit le point de comparaison nécessaire. Les normes et le plan de mise en œuvre seront finalisés après la comparaison des solutions et la validation de la cible.
