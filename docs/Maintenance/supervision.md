# Supervision

Comment surveiller MicroCRM une fois déployé et diagnostiquer son état.

## Dashboard CloudWatch

Lorsque CloudWatch est activé, Terraform crée un dashboard distinct par state :
`microcrm-staging-monitoring` et `microcrm-production-monitoring`. Chacun cible
uniquement l'instance, les métriques et les logs de son environnement.

## Métriques

### EC2

Chaque dashboard affiche la disponibilité, le CPU, la mémoire et le disque de
sa propre EC2.

### Exposition HTTP

Chaque EC2 expose son Traefik sur sa propre IPv4 publique. Aucun ALB n'est
déclaré dans cette architecture.

## Logs applicatifs

Les groupes `/microcrm/staging/{system,kubernetes}` et
`/microcrm/production/{system,kubernetes}` empêchent le mélange des journaux.

## CloudWatch Logs Insights

TODO : requêtes utiles pour :

* erreurs applicatives ;
* erreurs de déploiement ;
* échecs d'authentification.

## Alarmes

TODO : documenter les alertes liées à :

* disponibilité ;
* performance ;
* sécurité.

Pour chacune :

* métrique ;
* seuil ;
* action déclenchée.

## Notifications Slack

Le canal opérationnel prévu est `#microcrm-devops`. Les jobs Helm notifient les
déploiements et les rollbacks, réussis ou échoués. Les jobs Trivy notifient un
échec de contrôle de sécurité ; le rapport du job précise ensuite s'il s'agit
d'une vulnérabilité, d'un secret détecté ou d'une erreur du scanner.

L'envoi utilise `scripts/ci/notify.py` et un **Incoming Webhook** Slack conservé
dans la variable GitLab `SLACK_WEBHOOK_URL`. Cette variable doit être masquée,
protégée et non développée. Elle ne doit jamais être copiée dans le dépôt ou
les logs. Une variable protégée n'est disponible que sur une branche ou un tag
également protégé ; `dev` doit donc être protégé pour notifier le staging.

Créer l'Incoming Webhook dans Slack, récupérer son URL puis l'ajouter dans
**Settings > CI/CD > Variables** sous le nom `SLACK_WEBHOOK_URL`. Le message
contient uniquement le type d'événement, le statut, le job lorsqu'il est fourni,
le lien et l'identifiant du pipeline, la branche ou le tag et les huit premiers
caractères du commit.

Les appels actuels proviennent des jobs Helm
`deploy:helm:staging:release-or-rollback` et
`deploy:helm:production:release-or-rollback`, ainsi que des contrôles Trivy
`quality:trivy:repository`, `quality:trivy:kubernetes`,
`release:trivy:image:frontend` et `release:trivy:image:backend` en cas d'échec.

TODO : ajouter une preuve observable (message Slack horodaté et pipeline liée)
avant de déclarer cette notification validée en conditions réelles.

## État K3s / Pods

Les deux contextes GitLab Agent sont distincts. Les jobs de vérification
contrôlent le label `microcrm-environment=staging|production` avant le smoke
HTTP dans le pod frontend.

## Diagnostic rapide

TODO : commandes utiles pour diagnostiquer :

* EC2 ;
* K3s / pods ;
* application ;
* contexte GitLab Agent et Traefik.

## Exploitation des données

Les observations issues du monitoring sont synthétisées et analysées dans [`../quality/performance.md`](../quality/performance.md).
