# Rapport de performance du POC

## 1. Objectif et périmètre

Ce rapport mesure les effets observables de la modernisation CI/CD de MicroCRM.
Il couvre la qualité du pipeline, la sécurité, CloudWatch, le NLB, les réplicas,
PostgreSQL, le Canary et les indicateurs DORA. CloudWatch répond ici au besoin
fonctionnel attribué à ELK : afficher des métriques, journaux et alertes.

**À compléter :** aucun clic requis. Présenter le document comme une évaluation
du POC, et non comme une qualification de production.

## 2. Méthode et limites de la baseline

La baseline du commit `526bd96cddd2903676988b56dfeb2778667aa435`
contient des tests, de la couverture, quatre jobs et les alertes npm, mais aucune
durée de pipeline ni mesure AWS historique. Ces valeurs ne sont donc pas
inventées. Les mesures du 16 au 22 septembre 2026 constituent la référence
reproductible actuelle du POC.

| Indicateur comparable | Avant | Après | Gain ou conclusion |
|---|---:|---:|---|
| Tests frontend réussis | 8 | 14 | +6 tests |
| Tests backend réussis | 2 | 8 | +6 tests |
| Couverture frontend — lignes | 30,76 % | 40,65 % | +9,89 points |
| Couverture frontend — branches | 9,52 % | 9,52 % | stable |
| Définitions de jobs CI | 4 | 42 | périmètre automatisé élargi ; tous ne s'exécutent pas sur chaque trigger |
| Contrôles sécurité automatisés | aucun | Gitleaks, Trivy et SonarQube | détection avant livraison |
| Durée de pipeline comparable | non mesurée | à relever | référence actuelle uniquement |

**À compléter dans GitLab :** ouvrir **Build > Pipelines**, choisir trois
pipelines `dev` réussies déclenchées par un push, relever leur durée, trier les
trois valeurs et reporter la valeur du milieu comme médiane. Ne pas annoncer un
gain de durée puisque la valeur historique n'existe pas.

## 3. Sécurité : résultats et corrections

Les artefacts du commit `dd5e87fd` constituent l'état CI avant correction :
65 occurrences HIGH, 46 identifiants distincts, 0 CRITICAL corrigible et
0 secret. La [synthèse sécurité](evidence/security/SECURITY_EVIDENCE_2026-09-22.md)
et la [décision CVE-2026-56854](evidence/security/CVE-2026-56854-decision.md)
conservent le détail et les limites.

Corrections vérifiées localement le 22 septembre 2026 :

- PostgreSQL JDBC `42.7.11` vers `42.7.12` : 8 tests backend, `bootJar` et
  résolution de dépendance réussis ;
- Angular `17.3.8` vers `20.3.31` : 14 tests et build de production réussis ;
- image backend reconstruite après mise à jour Alpine : Trivy retourne
  0 HIGH et 0 CRITICAL sur les paquets et le JAR ;
- image frontend Caddy actualisée : Alpine retourne 0 HIGH/CRITICAL, mais le
  binaire Caddy contient encore 17 HIGH, dont `CVE-2026-56854`, et 0 CRITICAL.

La correction est donc importante mais reste **partielle** tant que les HIGH du
binaire Caddy ne sont pas corrigés par une image amont ou couverts par des
décisions de risque explicites. `apk upgrade` ne peut pas remplacer les
bibliothèques Go compilées dans ce binaire.

**À compléter après le push :** ouvrir la nouvelle MR dans GitLab, puis
**Build > Pipelines**. Ouvrir successivement `quality:gitleaks`,
`quality:trivy:repository`, `quality:trivy:iac`,
`quality:trivy:kubernetes`, `release:trivy:image:frontend` et
`release:trivy:image:backend`. Dans chaque job, cliquer sur **Browse** ou
**Download artifacts**, archiver les nouveaux rapports dans
`docs/quality/evidence/security/`, puis remplacer ici les résultats locaux par
les totaux de cette pipeline.

## 4. CloudWatch : métriques, journaux et alertes

Le dashboard applicatif sépare stable et Canary pour les requêtes, versions,
latence p95, 5xx, taux d'erreur et échecs d'authentification. Les captures et
leur interprétation sont regroupées dans la
[documentation de supervision](../Maintenance/supervision.md#validation-du-dashboard-applicatif).
Les 5xx et le taux d'erreur visibles proviennent d'un test synthétique ; ils ne
doivent pas être présentés comme un incident réel.

**À compléter dans AWS :** ouvrir **CloudWatch > Dashboards >
microcrm-application-production**, choisir la période du test Canary, afficher
chaque widget stable/Canary puis faire une capture avec la période visible.
Ouvrir ensuite **CloudWatch > Log groups**, sélectionner
`/microcrm/poc/kubernetes` puis `/microcrm/poc/traefik`, et utiliser **Logs
Insights** pour rechercher `ERROR`, `AuthenticationFailure` et les statuts 5xx.

## 5. NLB, réplicas, PostgreSQL et Canary

Le test NLB du 16 septembre 2026 a exécuté 50 requêtes séquentielles :

| Requêtes | HTTP 200 | Minimum | Moyenne | P95 | Maximum |
|---:|---:|---:|---:|---:|---:|
| 50 | 50 | 46,64 ms | 60,98 ms | 111,27 ms | 120,28 ms |

Preuves : [protocole et sortie](evidence/performance/PREUVE_PERFORMANCE_NLB_2026-09-16.md)
et [capture](evidence/performance/performance_nlb_50_requetes_http_200.png).
Ce test démontre la disponibilité de la route pendant environ quatre secondes ;
il ne démontre ni une capacité maximale, ni un failover, ni la distribution
entre les deux EC2.

| Mécanisme | Après observé | Impact démontré | Limite |
|---|---|---|---|
| NLB | deux cibles TCP saines ; 50/50 réponses HTTP 200 | point d'entrée unique disponible pendant le test | aucune panne de cible provoquée |
| Réplicas | deux réplicas frontend/backend configurés | rollouts et nombre de Pods contrôlés | gain de débit et tolérance à la panne non mesurés |
| PostgreSQL | StatefulSet persistant à un replica | persistance au redémarrage du Pod | pas de haute disponibilité ni de restauration automatisée |
| Canary | stable/Canary séparés, routage 90/10 observé | exposition initiale limitée à 10 % | ne prouve pas un gain de vitesse |

Preuves complémentaires : [tests du POC](evidence/performance/TESTS_MICROCRM_2026-09-16.md),
[Canary réussi](evidence/performance/canary_succeed_1.4.0.png),
[comptage 90/10](evidence/performance/résultat_comptage_canary_90_10.png) et
[cibles NLB saines](evidence/performance/NLB_target_group_healthy.png).

**À compléter dans AWS :** ouvrir **EC2 > Target Groups >
microcrm-poc-http > Targets** et refaire une capture montrant les deux cibles
`Healthy` avec la date. Aucun nouveau test de charge ou de panne n'est requis
pour le périmètre actuel ; toute conclusion de failover doit rester absente.

## 6. Indicateurs DORA

Le job non bloquant `pages:dora` interroge l'API GitLab avec
`DORA_GITLAB_TOKEN` et publie `index.html`, `dora-metrics.json` et
`dora-metrics.csv` dans `public/`, sur une fenêtre de 90 jours.

| Indicateur | Calcul dans MicroCRM |
|---|---|
| Fréquence de déploiement | déploiements GitLab réussis, ramenés à une semaine |
| Délai des changements | médiane entre fusion d'une MR et premier déploiement réussi |
| Taux d'échec des changements | part des déploiements reliés à un incident GitLab `dora` |
| Temps de restauration | médiane entre création et clôture des incidents reliés |

Sans échantillon, la valeur correcte est `N/A`, jamais zéro.

**À compléter dans GitLab :** ouvrir **Build > Pipelines > #2868146927 >
pages:dora**, vérifier que le job est réussi, cliquer sur **Download artifacts**
et copier les trois fichiers de `public/` dans
`docs/quality/evidence/performance/dora/`. Reporter ensuite les quatre valeurs
ci-dessus en précisant la taille de l'échantillon.

## 7. Gains et recommandations d'amélioration continue

| Problème initial | Réponse mise en œuvre | Résultat vérifiable | Suite prioritaire |
|---|---|---|---|
| transmission manuelle des images | Registry, digests et bundle immuable | RC et finale réutilisent les mêmes digests | conserver les preuves de release |
| contrôles sécurité tardifs | Gitleaks, Trivy et SonarQube | rapports liés au commit | suivre les HIGH Caddy |
| déploiements peu traçables | Terraform, Ansible, Helm et environnements GitLab | jobs et environnements visibles | terminer le bootstrap dans une phase future |
| risque de diffusion d'une version | Canary 90/10, vérification et promotion | routage et smoke tests prouvés | automatiser une fenêtre d'observation |
| absence de métriques | CloudWatch et DORA | dashboards et exports | augmenter l'historique DORA |
| sauvegarde non opérationnelle | cible documentée hors POC | limite explicite | implémenter/tester avant production |

**À compléter :** après téléchargement des artifacts DORA et sécurité, remplacer
les formulations générales par les valeurs de la dernière pipeline. Prioriser
d'abord sécurité et sauvegarde/restauration, puis l'amélioration du reporting.

## 8. Conclusion

Le POC démontre une CI/CD plus étendue, davantage de tests, une meilleure
couverture, des images traçables, un déploiement Canary observé et une route NLB
disponible durant le test. Il ne démontre pas une capacité sous charge, un
failover, une haute disponibilité PostgreSQL ou un gain historique de durée.
Les dernières preuves à joindre sont la médiane de trois pipelines comparables,
les exports DORA et les artefacts de sécurité générés après le prochain push.

**À compléter pour la remise :** vérifier tous les liens de cette page, ajouter
les fichiers téléchargés aux sous-dossiers `evidence`, puis exporter ou afficher
ce Markdown dans le support choisi pour la soutenance.
