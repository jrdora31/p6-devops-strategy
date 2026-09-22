# Synthèse des preuves de sécurité — 22 septembre 2026

## Périmètre et traçabilité

Les artefacts de ce dossier proviennent des jobs de sécurité exécutés pour le
commit `dd5e87fd51ac041ae66b4a79c5473559238950fe`. Les rapports de vulnérabilités
ont été générés le 21 septembre 2026 entre 15:07 et 15:11 UTC.

La capture de la pipeline `dev` `#2868146927` montre les jobs Gitleaks et Trivy
réussis. Une pipeline verte signifie ici qu'aucune vulnérabilité **CRITICAL**
corrigible et aucun secret n'ont déclenché le seuil bloquant. Elle ne signifie
pas qu'aucun constat HIGH n'existe : la configuration CI conserve les résultats
HIGH mais ne bloque que les CRITICAL pour les scans de vulnérabilités.

## Résultats

| Contrôle | Résultat | Interprétation |
|---|---:|---|
| Gitleaks | 0 secret | Aucun secret détecté dans l'historique Git accessible au job |
| Trivy — dépôt | 15 constats HIGH, 12 identifiants distincts, 0 CRITICAL | Dépendances applicatives ; un correctif est référencé pour chaque constat |
| Trivy — image frontend | 39 constats HIGH, 27 identifiants distincts, 0 CRITICAL | Paquets Alpine et dépendances embarquées ; `CVE-2026-56854` est filtrée séparément |
| Trivy — image backend | 11 constats HIGH, 8 identifiants distincts, 0 CRITICAL | Paquets Alpine et dépendances Java ; un correctif est référencé pour chaque constat |
| Total des 3 rapports de vulnérabilités | 65 constats HIGH, 46 identifiants distincts, 0 CRITICAL | Un même identifiant peut apparaître dans plusieurs composants |
| Trivy — secrets des images | 0 frontend, 0 backend | Aucun secret détecté dans les couches analysées |
| Trivy — Helm/Kubernetes | 0 constat sur minikube, K3s, staging et production | Les quatre profils passent le seuil HIGH/CRITICAL |
| Trivy — Terraform/IaC | 3 constats HIGH, 0 CRITICAL | Décisions d'architecture POC à documenter ou à durcir |

Les nombres ci-dessus sont issus des JSON présents dans ce dossier. Ils ne
doivent pas être présentés comme 65 CVE uniques : ce sont 65 occurrences pour
46 identifiants distincts. Les trois scans de vulnérabilités utilisent aussi
`--ignore-unfixed` : « 0 CRITICAL » signifie donc qu'aucun CRITICAL avec
correctif disponible n'apparaît dans les artefacts, et non que le scanner a
prouvé l'absence absolue de toute vulnérabilité sans correctif.

## Corrections vérifiées localement après ces artefacts

Les rapports précédents restent la preuve de la pipeline `dd5e87fd`. Ils ne sont
pas remplacés par les contrôles locaux suivants, exécutés le 22 septembre 2026
sur la branche de correction :

| Correction | Validation locale |
|---|---|
| PostgreSQL JDBC `42.7.11` vers `42.7.12` | 8 tests Gradle, `bootJar` et `dependencyInsight` réussis |
| Angular `17.3.8` vers `20.3.31` | 14 tests Karma et build de production réussis |
| Image backend avec mise à jour Alpine | reconstruction réussie ; Trivy `0.70.0` : 0 HIGH, 0 CRITICAL sur l'OS et le JAR |
| Image frontend Caddy actualisée | reconstruction réussie ; Alpine : 0 HIGH/CRITICAL ; binaire Caddy : 17 HIGH, 0 CRITICAL |

Le scan frontend a de nouveau détecté `CVE-2026-56854` dans le binaire Caddy.
La montée du digest et la mise à jour des paquets Alpine ne corrigent pas une
bibliothèque Go compilée dans ce binaire. La décision de risque nominative reste
donc active. Les autres HIGH du binaire devront être réévalués à partir des
artefacts de la prochaine pipeline.

## Constats nécessitant une action

### 1. Dépendances et images

Tous les constats HIGH présents dans les trois rapports indiquent une version
corrigée. Les principales actions sont :

1. le pilote PostgreSQL du backend est mis à jour de `42.7.11` vers `42.7.12`
   et les tests backend passent ;
2. les images ont été reconstruites et rescannées localement ; les paquets du
   backend sont corrigés et le binaire Caddy conserve des HIGH ;
3. Angular est migré de `17.3.8` vers `20.3.31`, avec tests et build réussis ;
4. traiter chaque identifiant restant, ou consigner une décision de risque
   datée et limitée si la correction immédiate est impossible.

`CVE-2026-56854` fait l'objet d'une décision séparée :
[décision de risque CVE-2026-56854](CVE-2026-56854-decision.md).

### 2. Infrastructure as Code

| ID | Constat | Décision POC | Cible de durcissement production |
|---|---|---|---|
| `AWS-0053` | NLB exposé à Internet | Attendu : le POC doit rendre MicroCRM accessible en HTTP | Restreindre les CIDR, terminer TLS et ajouter les protections d'entrée adaptées |
| `AWS-0132` | Chiffrement S3 sans clé gérée par le client | Le bucket temporaire est privé, chiffré AES-256 et purge ses objets sous 24 h | Utiliser SSE-KMS avec une CMK et une politique de clé minimale |
| `AWS-0164` | Attribution d'IP publique dans la subnet | Choix du POC sans NAT Gateway ni endpoints privés | Placer les nœuds en subnets privés et administrer via SSM/VPC endpoints |

Ces trois constats ne sont pas corrigés. Ils sont acceptés uniquement dans le
périmètre limité du POC et ne constituent pas une architecture de production
durcie.

## Plan de fermeture du critère « détectées et corrigées »

1. Pousser la branche de correction et ouvrir une merge request.
2. Relancer tous les jobs Gitleaks et Trivy sur cette merge request.
3. Télécharger les nouveaux artefacts et compléter cette synthèse avec les
   nouveaux totaux sans supprimer les rapports historiques.
4. Pour tout HIGH restant, corriger ou ajouter une décision nominative précisant le
   composant, l'exposition, les mesures compensatoires, le responsable et une
   date d'expiration.

Tant que ces étapes ne sont pas réalisées, la conclusion correcte est :
**détection démontrée, correction partielle**.

## Index des artefacts

- [Gitleaks JSON](gitleaks.json)
- [Trivy dépôt — texte](trivy-repository-vulnerabilities.txt) et
  [JSON](trivy-repository-vulnerabilities.json)
- [Trivy frontend — texte](trivy-image-frontend-vulnerabilities.txt),
  [JSON vulnérabilités](trivy-image-frontend-vulnerabilities.json) et
  [JSON secrets](trivy-image-frontend-secrets.json)
- [Trivy backend — texte](trivy-image-backend-vulnerabilities.txt),
  [JSON vulnérabilités](trivy-image-backend-vulnerabilities.json) et
  [JSON secrets](trivy-image-backend-secrets.json)
- [Trivy IaC — texte](trivy-iac.txt) et [JSON](trivy-iac.json)
- Kubernetes : [minikube](trivy-kubernetes-minikube.txt),
  [K3s](trivy-kubernetes-k3s.txt),
  [staging](trivy-kubernetes-staging.txt) et
  [production](trivy-kubernetes-production.txt)
- [Capture de la pipeline push dev](../pipeline_push_dev_21_09_26.png)
- [Validation locale des corrections](LOCAL_SECURITY_VALIDATION_2026-09-22.md)
