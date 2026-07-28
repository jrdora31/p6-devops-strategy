# Veille technologique, audit et recommandations

**Projet :** MicroCRM  
**Périmètre actuel :** audit initial de la chaîne CI/CD  
**Date de référence :** 26 juillet 2026

## Sommaire

1. [Introduction](#1-introduction)
2. [Rapport de veille technologique](#2-rapport-de-veille-technologique)
3. [Audit des processus de développement](#3-audit-des-processus-de-développement)
4. [Recommandations initiales](#4-recommandations-initiales)
5. [Conclusion](#5-conclusion)

## 1. Introduction

### 1.1 Objectif

Établir l’état de la chaîne CI/CD de MicroCRM, rapprocher les besoins des équipes Dev et Ops, puis identifier les améliorations à comparer pendant la veille technologique.

### 1.2 Contexte

MicroCRM est un monorepo GitLab composé d’un frontend Angular et d’un backend Spring Boot. La CI actuelle teste et construit les deux composants. Les images Docker sont ensuite construites, contrôlées et transmises manuellement selon les équipes.

| Indicateur initial | Résultat |
|---|---:|
| Jobs GitLab CI | 4 |
| Tests frontend réussis | 8 |
| Tests backend réussis | 2 |
| Couverture frontend — lignes | 30,76 % |
| Couverture frontend — branches | 9,52 % |
| Alertes de vulnérabilité npm | 64 |

## 2. Rapport de veille technologique

> Cette section sera complétée après l’audit. Une technologie ne sera retenue que si elle répond à un besoin vérifié de MicroCRM.

### 2.1 Axes de recherche

| Axe | Besoin à couvrir |
|---|---|
| GitLab CI | Réduire les répétitions, conserver les rapports et automatiser la livraison |
| Qualité et tests | Mesurer la couverture et détecter les régressions utiles |
| Sécurité | Contrôler le code, les dépendances, les secrets et les images plus tôt |
| Conteneurs et registre | Produire des images immuables et traçables |
| Exploitation et coût | Préparer une cible AWS simple, maintenable et économique |

### 2.2 Technologies évaluées

À compléter avec les technologies réellement comparées, leurs sources, leur compatibilité et leur coût.

### 2.3 Matrices comparatives

À compléter avant toute décision technique définitive.

## 3. Audit des processus de développement

### 3.1 Objectifs

L’audit vise à :

- reconstituer le workflow réel, du changement de code à la transmission aux Ops ;
- distinguer les pratiques déclarées des configurations observées ;
- identifier les opérations manuelles, répétitions et points de friction ;
- mesurer les tests, builds, images et contrôles existants ;
- faire ressortir les besoins communs aux équipes Dev et Ops.

Cette baseline servira de point de comparaison avec la future chaîne CI/CD.

### 3.2 Méthodologie

L’audit a été réalisé sur la branche `dev`, au commit `526bd96cddd2903676988b56dfeb2778667aa435`.

| Source | Utilisation | Niveau de preuve |
|---|---|---|
| Sondages Dev/Ops | Comprendre les pratiques, besoins et difficultés | Déclaratif, vérifié dans le dépôt lorsque possible |
| README et configurations | Reconstituer le workflow et les outils existants | Observation versionnée |
| Tests et builds locaux | Vérifier le fonctionnement et établir la baseline | Résultat reproduit |
| Docker et smoke tests | Vérifier les images, ports, processus et données | Résultat reproduit localement |

L’audit ne couvre pas de runner GitLab distant, d’environnement AWS, de test de charge ou d’indicateur de production.

#### 3.2.1 État initial de référence

| Élément | Référence « avant » |
|---|---|
| Code et configurations | Branche `dev`, commit `526bd96cddd2903676988b56dfeb2778667aa435` |
| Pipeline | `.gitlab-ci.yml` du commit audité : stages `test` et `build`, quatre jobs |
| Exécution | `Dockerfile`, `misc/docker/Caddyfile`, `misc/docker/supervisor.ini`, configurations Angular et Spring |
| Mesures | Indicateurs de la section 1.2 et résultats détaillés de la section 3.3 |
| Workflow | [Source Mermaid modifiable](diagrammes/workflow_ci_actuel.md) et [export SVG](diagrammes/workflow_ci_actuel.svg) |

Le workflow distingue les faits observés dans le dépôt du flux Docker manuel déclaré par les Ops.

![Workflow CI actuel de MicroCRM](diagrammes/workflow_ci_actuel.svg)

### 3.3 Processus audités

#### 3.3.1 Gestion du code et intégration continue

| Point | Synthèse |
|---|---|
| Fonctionnement | Monorepo GitLab avec un frontend Angular et un backend Spring Boot. La CI comprend deux stages et quatre jobs. |
| Forces | Dépôt centralisé, composants séparés, lockfile npm et Gradle Wrapper. |
| Faiblesses | Aucune règle documentée pour les branches, merge requests ou tags. Aucun cache ni artefact. |
| Risque principal | Intégrations peu prévisibles et résultats impossibles à réutiliser. |
| Preuves | `README.md`, `.gitlab-ci.yml`, état Git et sondage Dev. |

#### 3.3.2 Dépendances, tests et builds

| Point | Synthèse |
|---|---|
| Fonctionnement | La CI installe les dépendances, teste les deux composants, puis les reconstruit. |
| Forces | 8 tests frontend et 2 tests backend réussis. Builds Angular et Gradle fonctionnels. |
| Faiblesses | Peu de tests métier, couverture faible, opérations répétées, aucun rapport ni artefact conservé. |
| Risque principal | Régressions non détectées et pipeline inutilement ralenti. |
| Preuves | Tests, rapports Karma/Gradle, couverture et `.gitlab-ci.yml`. |

#### 3.3.3 Conteneurisation et transmission aux Ops

| Point | Synthèse |
|---|---|
| Fonctionnement | Trois cibles Docker sont construites manuellement. Les Ops déclarent contrôler les images avec Trivy avant un déploiement manuel. |
| Forces | Docker sert d’interface commune aux équipes. Les trois images ont pu être construites. |
| Faiblesses | Aucune image publiée par la CI, aucun digest, exécution avec `root`, port backend incohérent et absence de healthcheck. |
| Risque principal | Erreur de version, contrôle tardif ou service indisponible. |
| Preuves | `Dockerfile`, Caddyfile, Supervisor, `.gitlab-ci.yml`, sondages et smoke tests. |

#### 3.3.4 Qualité, sécurité et traçabilité

| Point | Synthèse |
|---|---|
| Fonctionnement | La CI exécute uniquement les tests et les builds. Le scan d’images est déclaré manuel. |
| Forces | Une pratique de scan existe déjà côté Ops. npm signale les alertes pendant l’installation. |
| Faiblesses | Aucun contrôle SonarQube, dépendances, secrets ou images dans la CI. La baseline npm signale 64 vulnérabilités. |
| Risque principal | Détection tardive et absence de preuve liée au commit. |
| Preuves | `.gitlab-ci.yml`, sortie `npm ci` et sondages Dev/Ops. |

#### 3.3.5 Configuration d’exécution et données

| Point | Synthèse |
|---|---|
| Fonctionnement | Le frontend utilise une URL d’API intégrée au code. Le backend utilise HSQLDB et un CORS permissif. |
| Forces | L’API fonctionne sur le port 8080 et l’environnement local est simple à démarrer. |
| Faiblesses | URL `localhost` non portable, données perdues avec le conteneur et CORS trop large. |
| Risque principal | Mauvaise cible réseau, perte de données ou exposition inutile de l’API. |
| Preuves | `config.ts`, bundle Angular, configuration Spring et tests contrôlés. |

### 3.4 Synthèse

MicroCRM possède une base exploitable : code centralisé, dépendances reproductibles, tests et builds fonctionnels, et trois cibles Docker constructibles.

La chaîne reste limitée à l’intégration. Elle ne conserve aucun rapport ou artefact, ne publie aucune image et n’automatise ni les contrôles de sécurité ni la livraison.

#### 3.4.1 Retours des équipes

| Équipe | Constats et besoins déclarés |
|---|---|
| Dev | L’équipe se déclare à l’aise avec Angular, npm, Karma et Docker, mais débutante avec Java, Spring Boot, Gradle et JUnit. Elle souhaite une analyse statique et une aide à la conception afin de détecter plus tôt les mauvaises pratiques. Elle signale également qu’une CVE a retardé le premier déploiement. |
| Ops | L’équipe contrôle manuellement les images avec un outil comme Trivy, puis les déploie manuellement avec Docker. Elle souhaite un registre d’images interne, des contrôles de sécurité réalisés avant la transmission et davantage d’automatisation. |

Le croisement des deux sondages fait ressortir :

- une convergence explicite : la majorité des opérations est encore manuelle ;
- un enjeu partagé : les Dev ont subi un retard lié à une CVE et les Ops demandent que le contrôle des images intervienne avant leur transmission.

Docker constitue l’interface entre les équipes : les Dev produisent et transmettent des références d’images, puis les Ops les contrôlent et les déploient. L’audit montre toutefois que cette transmission n’est ni automatisée ni traçable dans la CI.

Les besoins suivants restent spécifiques ou doivent être clarifiés :

- l’analyse statique du code répond principalement au besoin exprimé par les Dev ;
- le registre interne, le scan des images en amont et l’automatisation du déploiement répondent principalement aux Ops ;
- le lien entre l’environnement de `staging` cité par les Dev et l’environnement de démonstration cité par les Ops n’est pas établi ;
- le dépôt utilise HSQLDB alors que PostgreSQL figure dans les technologies Ops ; aucune migration de base de données n’est donc décidée à ce stade.

Les sondages orientent la veille, mais n’imposent aucun outil. Trivy décrit une pratique Ops actuelle ; les solutions seront comparées pendant la veille technologique.

Les besoins techniques suivants sont issus de l’audit du dépôt, et non d’un consensus déclaré dans les sondages :

- livrer une image identifiable et vérifiée ;
- rendre la configuration portable ;
- conserver des preuves liées au commit.

#### 3.4.2 Analyse SWOT

| Forces | Faiblesses |
|---|---|
| GitLab et une CI minimale existent déjà. | La CI est limitée aux tests et aux builds. |
| Les dépendances sont reproductibles. | Les tests métier et la couverture sont faibles. |
| Les tests et builds réussissent. | Aucun contrôle qualité ou sécurité n’est automatisé. |
| Docker est commun aux équipes Dev et Ops. | La configuration, les données et les images sont peu portables ou traçables. |

| Opportunités | Menaces |
|---|---|
| Les retours justifient l’automatisation et la sécurité plus en amont. | Les vulnérabilités évoluent dans le temps. |
| GitLab et Docker peuvent être étendus sans remplacer l’existant. | Les tags flottants peuvent modifier un build. |
| Une CI full-stack peut relier code, contrôles et images. | Un contrôle tardif peut retarder la livraison. |
| L’automatisation peut réduire les manipulations manuelles. | Des besoins d’environnement mal clarifiés peuvent conduire à une solution inadaptée. |

## 4. Recommandations initiales

### 4.1 Objectif

Les recommandations transforment les constats de l’audit en améliorations à étudier. Les outils, leur coût et leur compatibilité seront comparés pendant la veille avant toute décision définitive.

### 4.2 Recommandations

| Priorité | Constat | Recommandation | Gain attendu |
|---|---|---|---|
| Critique | Contrôles de sécurité tardifs ou absents | Automatiser les scans des dépendances, secrets et images | Détection plus précoce et décisions traçables |
| Élevée | Aucun rapport ni artefact conservé | Publier les rapports et réutiliser les builds validés | Preuves durables et moins de répétitions |
| Élevée | Tests métier et couverture faibles | Ajouter progressivement des tests HTTP, CRUD, scripts et images | Davantage de régressions détectées |
| Élevée | Aucune analyse continue du code | Intégrer SonarQube et contrôler les nouvelles anomalies | Qualité et dette technique mesurables |
| Élevée | Images construites et transmises manuellement | Construire, publier et identifier les images par commit et digest | Livraison reproductible et traçable |
| Élevée | URL, ports et routage non portables | Externaliser la configuration et ajouter healthchecks et smoke tests | Même version utilisable sur plusieurs environnements |
| Élevée | Données perdues avec le conteneur | Définir la persistance, la sauvegarde et la restauration | Continuité des données vérifiable |
| Élevée | Branches, versions et releases non normalisées | Définir les règles Git, le versioning et les validations | Intégrations et releases prévisibles |
| Élevée | Opérations répétées ou manuelles | Créer des scripts simples appelés en local et dans la CI | Moins de duplication et d’écarts |
| Moyenne | Retour d’information manuel | Générer une notification standard indépendante du canal | Échecs et releases plus rapidement visibles |

## 5. Conclusion

L’existant peut être amélioré progressivement sans remplacer GitLab ni Docker. Les priorités sont l’automatisation des contrôles, la conservation des preuves, la traçabilité des images et la portabilité de l’application.

La veille comparera les solutions capables de couvrir ces besoins avant la définition de l’architecture cible.
