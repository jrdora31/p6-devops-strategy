# Mesures et indicateurs

Les résultats ci-dessous sont datés. Ils ne constituent pas un état temps réel
de GitLab, AWS ou SonarQube.

## Baseline et amélioration de la CI

| Indicateur | Baseline initiale | Dernière preuve consignée |
|---|---|---|
| Pipeline | 2 stages, 4 jobs | 6 stages et configuration modulaire |
| Tests frontend | 8 tests | 12 tests dans la pipeline `#2723639714` |
| Tests backend | 2 tests | 3 tests dans la pipeline `#2723639714` |
| Qualité | Aucun contrôle continu | Quality gate réussi dans `#2723633630` |
| Scan du dépôt | Aucun | 12 `HIGH`, 0 `CRITICAL`, aucun secret dans `#2723610499` |
| Image frontend | 64 `HIGH`, 6 `CRITICAL` | 10 `HIGH`, 0 `CRITICAL` dans `#2723610499` |
| Image backend | 37 `HIGH`, 6 `CRITICAL` | 3 `HIGH`, 0 `CRITICAL` dans `#2723610499` |
| Test full-stack | Aucun | Santé, API et persistance validées par `verify:images` |

Les nombres de vulnérabilités décrivent les scans cités. Ils peuvent évoluer
avec les bases de vulnérabilités et doivent être relus dans les derniers
artefacts Trivy.

## Mesures DORA

Le job `pages:dora` calcule les indicateurs depuis GitLab et publie HTML, JSON
et CSV. Le périmètre actuel est l’environnement `aws-poc-staging` sur 90 jours.
Il représente le POC de staging, pas une production réelle.

| Indicateur | Définition dans MicroCRM | Première mesure du 11 août 2026 |
|---|---|---:|
| Fréquence de déploiement | Déploiements réussis par semaine | `0,78` |
| Lead time | Médiane entre fusion d’une MR et premier déploiement réussi | `3,03 jours` |
| Taux d’échec des changements | Déploiements réussis reliés à un incident `dora` | Non calculable |
| Temps de restauration | Durée médiane des incidents `dora` clôturés | Non calculable |

Le suivi des incidents commence le 11 août 2026. Un échec de pipeline ou de
déploiement n’est pas automatiquement un incident DORA. La convention complète
est documentée dans [`../../scripts/ci/README.md`](../../scripts/ci/README.md).

## Validation Kubernetes locale

Observation du 3 août 2026 sur un profil Minikube isolé :

| Vérification | Résultat |
|---|---|
| Déploiement Helm | Release `microcrm` déployée |
| Workloads | Frontend, backend et PostgreSQL prêts |
| Stockage | PVC PostgreSQL `1Gi` lié |
| API | Création et lecture via le frontend réussies |
| Ingress | Frontend et API accessibles avec HTTP `200` |
| Recréation PostgreSQL | Nouveau pod prêt en `4,6 s` |
| Persistance | Donnée retrouvée après recréation du pod |
| Backend | Passage temporaire de 1 à 2 endpoints réussi |

Cette observation valide le chart localement. Elle ne mesure pas la
performance AWS et ne prouve pas une restauration après perte du volume.

## Observabilité AWS

Le dashboard `microcrm-poc-monitoring` a affiché des séries de disponibilité
EC2, CPU, mémoire et disque ainsi que les deux tables Logs Insights. Les groupes
`/microcrm/poc/system` et `/microcrm/poc/kubernetes` utilisent une rétention de
trois jours.

Le dépôt ne collecte pas la latence p95 ni un taux d’erreur HTTP agrégé. Il ne
crée aucune alarme CloudWatch. Aucun seuil d’alerte ne doit donc être présenté
comme actif.

## Limites de mesure

- aucune mesure de charge applicative AWS n’est conservée ;
- la disponibilité continue n’est pas calculée ;
- le rollback et la restauration ne sont pas mesurés ;
- les coûts doivent être vérifiés dans AWS avant chaque session ; les anciennes
  estimations ne sont pas des tarifs actuels.
