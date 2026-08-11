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

Les métriques DORA mesurent la vitesse et la stabilité de la livraison. Le POC
automatise les quatre indicateurs demandés avec `scripts/ci/dora_metrics.py` et
publie un rapport HTML/JSON/CSV par GitLab Pages, sans dépendre de la présence
de l'infrastructure AWS.

| Métrique | Convention retenue | Source GitLab |
|---|---|---|
| Deployment frequency | Nombre moyen de déploiements réussis par semaine sur 90 jours | Deployments de `aws-poc-staging`, date de fin |
| Lead time for changes | Médiane entre la fusion d'une MR et son premier déploiement réussi | MRs associées aux deployments |
| Change failure rate | Déploiements réussis reliés à un incident / déploiements réussis depuis le début du suivi | Deployments et incidents labellisés `dora` |
| Time to restore service | Médiane entre création et clôture des incidents suivis | Incidents GitLab |

`aws-poc-staging` est utilisé comme proxy opérationnel parce qu'il possède un
historique réel de déploiements du POC. Cette mesure ne doit pas être présentée
comme une performance de production. Quand `aws-poc-production` possédera un
historique suffisant, la variable `DORA_ENVIRONMENT` permettra de basculer le
périmètre sans modifier le script.

Le suivi des incidents débute le 11 août 2026. Une valeur indisponible reste
affichée « non calculable » plutôt que d'être estimée depuis un simple échec de
pipeline ou un historique antérieur non suivi.

## Indicateurs opérationnels retenus pour la partie 2

La matrice suivante distingue les indicateurs à mesurer pendant une session AWS
des métriques DORA, qui sont calculées à partir de l'historique GitLab. Les seuils
marqués « proposition » devront être calibrés après une première mesure réelle.

| Indicateur | Question suivie | Source prévue | Fréquence | Seuil ou résultat attendu |
|---|---|---|---|---|
| Disponibilité HTTP | L'application répond-elle ? | Probe frontend `/` et API `/api/persons`, vérification GitLab | 1 à 5 min si monitoring actif ; par déploiement sinon | 100 % des smoke tests ; alerte continue sous 99 % (proposition) |
| Latence p95 | Les réponses restent-elles acceptables ? | Probe HTTP et logs d'accès | 1 à 5 min | Baseline à établir ; alerte sur dépassement durable de la baseline (proposition) |
| Taux d'erreur | L'application produit-elle des erreurs ? | Codes HTTP, logs Caddy/backend | 5 min | Alerte au-delà de 1 % sur une fenêtre de 5 min (proposition) |
| CPU, mémoire, disque | L'instance ou un pod sature-t-il ? | CloudWatch Agent et état Kubernetes | 1 à 5 min | Alerte indicative à 80 % ; vérifier le disque avant toute nouvelle session |
| Restarts et readiness | Un workload redémarre-t-il ou devient-il indisponible ? | Kubernetes : pods, rollouts, StatefulSet | À chaque vérification et après incident | Aucun restart inattendu ; tous les workloads doivent être prêts |
| Événements de sécurité | Une activité anormale est-elle détectée ? | GitLab security jobs, CloudTrail si activé, logs système | Par événement et par pipeline | Aucun secret détecté ; toute anomalie doit être analysée |
| Coût AWS | La session reste-t-elle compatible avec le crédit disponible ? | Cost Explorer/Billing | Relevé avant et après session | Détruire l'environnement le jour même ; seuil budgétaire de session à définir |

Les quatre métriques DORA utilisent les événements GitLab : pipelines,
deployments, merge requests, incidents et retour au service. Elles ne seront
calculées qu'après constitution d'un historique suffisant ; une seule session
AWS ne permet pas d'en déduire une tendance.

## Arbitrage O.2 — CloudWatch comme équivalent provisoire

| Solution | Couverture | Intégration | Ressources et coût POC | Limite principale |
|---|---|---|---|---|
| ELK/OpenSearch auto-hébergé | Logs, recherche avancée et dashboards locaux | Plusieurs composants, indexation, stockage et sécurisation à maintenir | Ressources élevées pour une EC2 unique ; instance plus grande potentiellement nécessaire | Risque de concurrence avec K3s, PostgreSQL et MicroCRM |
| Grafana + Prometheus/Loki | Très bonne visualisation et métriques/logs ouverts | Plusieurs composants à installer et maintenir | Moyens à élevés | Rétention, stockage et exposition à gérer soi-même |
| CloudWatch Agent + Logs/Metrics | Métriques EC2, logs centralisés, dashboards et alarmes | Native AWS, IAM et HTTPS sortant | Faible empreinte locale ; coût à contrôler par rétention et volume | Dépendance AWS et absence de Kibana |

Proposition provisoire pour `ARB-16` : retenir CloudWatch Agent comme équivalent
ELK pour le POC éphémère, sans installer ELK/OpenSearch ni Grafana en parallèle.
CloudWatch couvre la collecte, la centralisation, la visualisation et les
alarmes ; GitLab reste la source des métriques DORA. L'équivalence doit être
confirmée par le mentor et démontrée par des captures et des mesures réelles.

### Estimation de ressources et de coût

| Environnement | Dimensionnement | Empreinte locale | Coût estimé pour 12 h |
|---|---|---|---:|
| CloudWatch | EC2 `m7i-flex.large`, 2 vCPU, 8 Gio, gp3 20 Gio | Agent léger ; pas d'index local | `1,37–1,49 USD` |
| ELK/OpenSearch | EC2 théorique `m7i-flex.xlarge`, 4 vCPU, 16 Gio, gp3 30 Gio | JVM, indexation, dashboards et collecteur ; marge réduite pour K3s | `≈2,73 USD` |

Ces montants incluent l'EC2 et le stockage estimés, pas seulement le monitoring.
Ils ne constituent pas un devis et devront être recalculés dans AWS avant un
`apply`. Le scénario CloudWatch est retenu provisoirement pour limiter à la
fois l'empreinte mémoire et le coût du cycle éphémère.

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
