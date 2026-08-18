# Supervision

Comment surveiller MicroCRM une fois déployé et diagnostiquer son état.

## Dashboard CloudWatch

TODO :

* emplacement du dashboard ;
* métriques affichées ;
* disponibilité, performance et sécurité ;
* widget **Échecs d'authentification système**.

## Métriques

### EC2

TODO : CPU, mémoire, disque, disponibilité.

### Load Balancer

TODO : métriques et health checks.

## Logs applicatifs

TODO :

* où consulter les logs ;
* quels logs sont collectés.

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

TODO : ajouter une preuve observable (message Slack horodaté et pipeline liée)
avant de déclarer cette notification validée en conditions réelles.

## État K3s / Pods

TODO : commandes de vérification du cluster et des pods.

## Diagnostic rapide

TODO : commandes utiles pour diagnostiquer :

* EC2 ;
* K3s / pods ;
* application ;
* Load Balancer.

## Exploitation des données

Les observations issues du monitoring sont synthétisées et analysées dans [`../quality/performance.md`](../quality/performance.md).
