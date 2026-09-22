# Synthèse des preuves de sécurité — 22 septembre 2026

## Périmètre et traçabilité

Les artefacts de ce dossier proviennent des jobs de sécurité exécutés pour le
commit `71f7d64e58ccfa194d652cd2b58e6feca8aaba3c`, dans la pipeline push `dev`
`#2870894000`. Les rapports ont été générés le 22 septembre 2026 entre 11:00 et
11:07 UTC.

La pipeline est réussie. Une pipeline verte signifie ici qu'aucune vulnérabilité **CRITICAL**
corrigible et aucun secret n'ont déclenché le seuil bloquant. Elle ne signifie
pas qu'aucun constat HIGH n'existe : la configuration CI conserve les résultats
HIGH mais ne bloque que les CRITICAL pour les scans de vulnérabilités.

## Résultats

| Contrôle | Résultat | Interprétation |
|---|---:|---|
| Gitleaks | 0 secret | Aucun secret détecté dans l'historique Git accessible au job |
| Trivy — dépôt | 0 HIGH, 0 CRITICAL | Les dépendances Angular et PostgreSQL corrigées ne sont plus signalées |
| Trivy — image frontend | 16 occurrences HIGH, 15 identifiants distincts, 0 CRITICAL | Constats du binaire Caddy ; `CVE-2026-56854` est filtrée séparément |
| Trivy — image backend | 0 HIGH, 0 CRITICAL | Aucun constat HIGH/CRITICAL sur Alpine ou le JAR |
| Total des 3 rapports de vulnérabilités | 16 occurrences HIGH, 15 identifiants distincts, 0 CRITICAL | Les constats restants sont concentrés dans Caddy |
| Trivy — secrets des images | 0 frontend, 0 backend | Aucun secret détecté dans les couches analysées |
| Trivy — Helm/Kubernetes | 0 constat sur minikube, K3s, staging et production | Les quatre profils passent le seuil HIGH/CRITICAL |
| Trivy — Terraform/IaC | 3 constats HIGH, 0 CRITICAL | Décisions d'architecture POC à documenter ou à durcir |

Les nombres ci-dessus sont issus des JSON présents dans ce dossier. Ils ne
doivent pas être présentés comme 16 CVE uniques : ce sont 16 occurrences pour
15 identifiants distincts. Les trois scans de vulnérabilités utilisent aussi
`--ignore-unfixed` : « 0 CRITICAL » signifie donc qu'aucun CRITICAL avec
correctif disponible n'apparaît dans les artefacts, et non que le scanner a
prouvé l'absence absolue de toute vulnérabilité sans correctif.

## Effet mesuré des corrections

La comparaison utilise les mêmes trois familles de rapports Trivy avant et
après correction :

| Rapport | Avant — `dd5e87fd` | Après — `71f7d64` | Écart |
|---|---:|---:|---:|
| Dépôt | 15 HIGH | 0 HIGH | -15 |
| Image backend | 11 HIGH | 0 HIGH | -11 |
| Image frontend | 39 HIGH | 16 HIGH | -23 |
| Total | 65 HIGH | 16 HIGH | -49 occurrences, soit -75,4 % |

Le scan CI applique `.trivyignore-frontend` et ne liste donc pas
`CVE-2026-56854`. Le scan local réalisé sans cet ignore retourne 17 HIGH : les
16 occurrences du rapport CI plus cette CVE. La décision de risque nominative
reste active ; les autres HIGH sont liés aux bibliothèques Go compilées dans
Caddy.

## Constats nécessitant une action

### 1. Dépendances et images

Les corrections applicatives et backend sont terminées :

1. le pilote PostgreSQL du backend est mis à jour de `42.7.11` vers `42.7.12`
   et les tests backend passent ;
2. les images ont été reconstruites et rescannées par la CI ; l'image backend
   est propre au seuil HIGH/CRITICAL et le binaire Caddy conserve 16 HIGH ;
3. Angular est migré de `17.3.8` vers `20.3.31`, avec tests et build réussis ;
4. mettre à jour Caddy lorsqu'une image corrigée existe, ou consigner une décision de risque
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

1. Conserver la pipeline `#2870894000` et ses artefacts comme preuve après correction.
2. Vérifier la pipeline finale de la merge request en cours.
3. Pour tout HIGH Caddy restant, corriger ou ajouter une décision nominative précisant le
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
