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

## Résultats de la partie 1

| Indicateur | Résultat vérifié | Preuve |
|---|---|---|
| Pipeline CI | Pipeline modulaire de bout en bout jusqu’au build et à la préparation de release | GitLab `#2721992698` |
| Blocage sur erreur | Échec volontaire puis retour au vert | GitLab `#2721003734` et `#2721023911` |
| Tests frontend | 12 tests réussis localement, dont des contrôles HTTP | Résultat local du 31 juillet 2026 ; validation GitLab attendue |
| Tests backend | 3 tests réussis localement, dont un CRUD HTTP complet | Rapport JUnit local du 31 juillet 2026 ; validation GitLab attendue |
| Scripts | 7 tests Bash, 5 tests Python et ShellCheck réussis | GitLab `#2721317021` |
| Qualité | Quality gate SonarQube réussi | GitLab `#2721899884` et dashboard SonarQube |
| Sécurité du repository | Baseline locale Trivy : 12 vulnérabilités `HIGH`, 0 `CRITICAL`, aucun secret détecté | Scan Trivy local du 31 juillet 2026 |
| Disponibilité des images | Deux healthchecks réussis et appel API via le reverse proxy | Smoke test Docker local du 31 juillet 2026 |
| Sécurité des images | Frontend : 10 `HIGH`, 0 `CRITICAL` ; backend : 4 `HIGH`, 0 `CRITICAL` ; aucun secret détecté après durcissement | Scans Trivy locaux du 31 juillet 2026 ; confirmation GitLab attendue |

Les résultats Trivy seront confirmés par le pipeline de validation. Aucune
valeur non observée n’est estimée.

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
