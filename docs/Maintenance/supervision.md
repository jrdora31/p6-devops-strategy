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
