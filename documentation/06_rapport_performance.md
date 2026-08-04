# Rapport de performance

## État initial

L’audit du repository a établi la baseline suivante avant la refonte de la CI :

| Indicateur | État initial |
|---|---|
| Pipeline | Tests et builds uniquement |
| Tests frontend | 8 tests réussis ; couverture limitée |
| Tests backend | 2 tests réussis |
| Qualité et sécurité | Aucun quality gate, scan de secrets, dépendances ou images |
| Livraison | Aucun artifact durable, image publiée ou manifeste de release |
| Production | Aucun deployment AWS observable |

## Comparaison avant/après la partie 1

| Indicateur | Avant | Après | Preuve |
|---|---|---|---|
| Pipeline CI | 2 stages et 4 jobs de test/build | Pipeline modulaire : tests, qualité, sécurité, builds, scans de release et vérification des images | MR `#2723633630` et pipeline `dev` `#2723639714` |
| Blocage sur erreur | Non démontré | Échec volontaire, pipeline bloquée, puis retour au vert | `#2721003734` et `#2721023911` |
| Tests frontend | 8 tests | 12 tests, dont les appels HTTP des services | Job `test:frontend` de `#2723639714` |
| Tests backend | 2 tests | 3 tests, dont un parcours CRUD HTTP complet | Rapport JUnit de `#2723639714` |
| Scripts | Aucun test dédié | 7 tests Bash, 5 tests Python et ShellCheck | Pipeline du correctif Quality Gate à renseigner |
| Qualité | Aucun contrôle continu | Quality gate réussi ; 0 bug, 0 vulnérabilité, 0 hotspot, 2 code smells et 33,3 % de couverture globale analysée | SonarQube et `#2723633630` |
| Sécurité du repository | Aucun scan CI | 12 `HIGH`, 0 `CRITICAL`, aucun secret détecté | Artifacts Trivy de `#2723610499` |
| Disponibilité des images | Aucun healthcheck ni test full-stack automatisé | Deux healthchecks et parcours create/read via Caddy réussis | Job `verify:images` de `#2723610499` |
| Sécurité des images | Frontend : 64 `HIGH` et 6 `CRITICAL` ; backend : 37 `HIGH` et 6 `CRITICAL` | Frontend : 10 `HIGH`, 0 `CRITICAL` ; backend : 3 `HIGH`, 0 `CRITICAL` ; aucun secret | Artifacts Trivy de `#2723610499` |
| Livraison | Aucun artifact durable, image publiée ou manifeste | Artifacts et images identifiées par commit ; manifeste prévu pour le tag SemVer final | Jobs de release et plan de release |

Toutes les valeurs de la colonne « après » proviennent d’une exécution locale
ou GitLab observable. La référence `main` et le manifeste SemVer seront ajoutés
après la release finale de la partie 1.

Avant durcissement, l’image frontend contenait 64 vulnérabilités `HIGH` et 6
`CRITICAL`, contre 37 `HIGH` et 6 `CRITICAL` pour l’image backend. La mise à
jour des runtimes et de Spring Boot supprime les vulnérabilités critiques
corrigibles de la baseline locale.

## Métriques DORA

Les métriques DORA mesurent la performance de la livraison en production. Elles
ne peuvent pas être calculées honnêtement tant que MicroCRM n’est pas déployé.

| Métrique | Calcul futur | Source prévue | État P1 |
|---|---|---|---|
| Deployment frequency | Nombre de deployments réussis par période | GitLab Environments et deployments | Non mesurable avant P2 |
| Lead time for changes | Temps entre le commit et son deployment | Commits, pipelines et deployment | Non mesurable avant P2 |
| Change failure rate | Deployments causant incident ou rollback / deployments totaux | Deployments, incidents et rollbacks | Non mesurable avant P2 |
| Mean time to restore | Temps entre détection et restauration du service | Alertes, incidents et retour au vert | Non mesurable avant P2 |

## Validation Kubernetes locale

Mesures réalisées le 3 août 2026 sur un profil Minikube local isolé. Elles
valident le fonctionnement de l'orchestration, pas la performance AWS finale.

| Vérification | Résultat |
|---|---|
| Déploiement Helm | Release `microcrm`, statut `deployed` |
| Disponibilité initiale | Frontend, backend et PostgreSQL prêts, sans restart |
| Stockage | PVC PostgreSQL `1Gi`, statut `Bound` |
| Parcours applicatif | Création puis lecture d'une personne via le frontend réussies |
| Routage Ingress | Contrôleur Nginx prêt ; frontend et API accessibles avec des réponses HTTP `200` via l'hôte `microcrm.local` |
| Recréation PostgreSQL | Nouveau pod prêt en `4,6 s` |
| Persistance | Donnée retrouvée après la recréation du pod PostgreSQL |
| Scalabilité backend | Passage de 1 à 2 endpoints réussi, puis retour à 1 par Helm |

## Mesures prévues après deployment

- disponibilité du frontend et de l’API ;
- temps de réponse et taux d’erreur ;
- consommation CPU, mémoire et stockage ;
- durée et résultat des deployments ;
- réussite du backup, du restore et du rollback ;
- métriques DORA calculées à partir des événements GitLab et du monitoring AWS.

La comparaison finale reprendra la baseline ci-dessus et les mêmes indicateurs
après deployment, afin de montrer les effets des recommandations sans mélanger
performance CI et performance de production.
