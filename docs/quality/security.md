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

Les artefacts du commit corrigé `71f7d64` sont archivés dans
[`evidence/security`](evidence/security/SECURITY_EVIDENCE_2026-09-22.md). Ils
montrent 0 secret, 0 HIGH/CRITICAL pour le dépôt et le backend, 16 occurrences
HIGH représentant 15 identifiants dans le binaire Caddy, et 0 CRITICAL. Les
trois constats IaC HIGH restent des décisions d'architecture du POC. Par
rapport aux artefacts antérieurs, le total des trois rapports de
vulnérabilités passe de 65 à 16 occurrences HIGH, soit une baisse de 75,4 %.
La conclusion reste « détection démontrée, correction partielle » puisque les
HIGH Caddy ne sont pas encore tous corrigés ou acceptés nominativement.

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
