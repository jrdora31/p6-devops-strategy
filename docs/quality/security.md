# Sécurité

La CI contrôle les secrets, les dépendances, les images et la configuration
avant livraison. Chaque outil couvre un risque différent :

| Contrôle | Jobs | Rôle |
|---|---|---|
| Gitleaks | `quality:gitleaks` | Rechercher les secrets dans l'historique Git accessible depuis la référence |
| Trivy | `quality:trivy:repository`, `quality:trivy:kubernetes`, `quality:trivy:iac`, `release:trivy:image:frontend/backend` | Scanner dépôt, manifests, infrastructure et images |

Gitleaks `v8.30.1` bloque la pipeline s'il trouve un secret. Il conserve un
rapport JSON expurgé pendant 30 jours et s'exécute sur les merge requests,
`dev`, la branche principale et les tags. Les pipelines Web et planifiées ne
chargent pas les jobs `quality` généraux. Aucune exception Gitleaks n'est
configurée ; un éventuel faux positif doit être justifié sans exposer de
secret réel.

Trivy couvre les vulnérabilités des dépendances, des images et de l'IaC,
ainsi que les secrets incorporés aux images. Il ne remplace pas la recherche
de secrets dans l'historique Git, et ces jobs ne sont pas le scanner de
dépendances natif de GitLab. Les rapports HIGH/CRITICAL n'impliquent pas tous
un blocage : celui-ci dépend du seuil `--exit-code 1` propre au contrôle.
Les artefacts des jobs concernés sont conservés 30 jours.

## Résultats et limites connus

Les contrôles du commit corrigé `71f7d64` donnent les résultats suivants :

| Contrôle | Résultat | Limite restante |
|---|---|---|
| Gitleaks | 0 secret détecté | aucune exception configurée |
| Trivy — dépôt | 0 HIGH, 0 CRITICAL | aucune au seuil contrôlé |
| Trivy — image backend | 0 HIGH, 0 CRITICAL | aucune au seuil contrôlé |
| Trivy — image frontend | 16 occurrences HIGH, 15 identifiants distincts, 0 CRITICAL | vulnérabilités présentes dans le binaire Caddy |
| Trivy — Helm/Kubernetes | 0 constat HIGH/CRITICAL sur les quatre profils | aucune au seuil contrôlé |
| Trivy — Terraform/IaC | 3 constats HIGH, 0 CRITICAL | choix d'architecture acceptés uniquement pour le POC |

Par rapport aux artefacts antérieurs, les trois rapports de vulnérabilités
passent de 65 à 16 occurrences HIGH, soit une baisse de 75,4 %. La conclusion
reste « détection démontrée, correction partielle » puisque les HIGH Caddy ne
sont pas encore tous corrigés ou acceptés nominativement.

Une CVE identifie une vulnérabilité connue dans un logiciel ou une
bibliothèque. Un constat IaC (*Infrastructure as Code*) signale une
configuration d'infrastructure à durcir ; il ne correspond pas nécessairement
à une CVE. Les trois constats IaC de MicroCRM sont distincts de
`CVE-2026-56854` :

| ID | Constat | Décision pour le POC | Durcissement attendu en production |
|---|---|---|---|
| `AWS-0053` | Le NLB est exposé à Internet (`internal = false`) | exposition attendue pour rendre le POC accessible en HTTP | restreindre les CIDR, terminer TLS et ajouter les protections d'entrée adaptées |
| `AWS-0132` | Le bucket S3 utilise le chiffrement `AES256` fourni par AWS, sans clé KMS propre au projet | bucket temporaire privé, chiffré et vidé sous 24 heures | utiliser une clé KMS gérée par le projet avec une politique minimale |
| `AWS-0164` | Le sous-réseau attribue automatiquement des IP publiques (`map_public_ip_on_launch = true`) | choix du POC sans NAT Gateway ni endpoints privés | placer les nœuds dans des sous-réseaux privés et les administrer avec SSM/VPC endpoints |

Ces trois constats ne sont pas corrigés et ne représentent pas une architecture
de production durcie. Pour une mise en production réelle, l'image frontend ne
serait pas livrée avec les HIGH Caddy résiduels et les choix IaC ci-dessus
seraient durcis avant le déploiement.

Plus de détails dans la
[synthèse des preuves de sécurité du 22 septembre 2026](evidence/security/SECURITY_EVIDENCE_2026-09-22.md).

## Exception Trivy

Le frontend utilise `.trivyignore-frontend` pour `CVE-2026-56854`, liée à
l'image Caddy. L'exception expire le 31 décembre 2026. Le POC n'expose pas la
fonction SSH concernée ; l'exception doit être retirée lorsqu'une image
corrigée est disponible. L'option `--ignore-unfixed` filtre séparément les
vulnérabilités sans correctif : ce n'est pas une exception nominative.

La justification, le risque résiduel, les conditions de réexamen et la procédure
de clôture sont consignés dans la
[décision de risque CVE-2026-56854](evidence/security/CVE-2026-56854-decision.md).

Pour traiter un signalement, ouvrir le job et son rapport, identifier le
composant, la version et la sévérité, corriger ou justifier le cas précis,
puis relancer la pipeline. Une nouvelle exception doit préciser le risque
résiduel et sa date de revue.

## Secrets de déploiement

Les secrets GitLab, dont `KUBERNETES_MONITORING_PASSWORD` et
`SLACK_WEBHOOK_URL`, doivent rester masqués et protégés ; ils ne doivent être
copiés ni dans le dépôt ni dans les logs. Une variable protégée n'est fournie
qu'aux branches ou tags également protégés : les releases doivent donc utiliser
une règle de tags protégés, par exemple `v*` avec création limitée aux
Maintainers. Le scope de `KUBERNETES_MONITORING_PASSWORD` doit couvrir
`aws-poc-staging` et `aws-poc-production`, ou rester à `*`. Si le secret est
absent d'un job de release, corriger la protection ou le scope plutôt que
rendre la variable non protégée. Pour notifier le staging via Slack, `dev`
doit également être protégé.
