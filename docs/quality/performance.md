# Performance

Ce rapport synthétise les résultats du monitoring et des tests de performance, puis les améliorations qui en découlent.

La configuration du monitoring est décrite dans [`../Maintenance/supervision.md`](../Maintenance/supervision.md).

## Indicateurs retenus

### Métriques DORA

* **Fréquence de déploiement** : TODO
* **Change Lead Time** : TODO
* **Change Failure Rate** : TODO
* **Temps de restauration** : TODO

Pour chaque indicateur :

* signification ;
* valeur obtenue ;
* intérêt pour MicroCRM.

### Métriques techniques

* disponibilité EC2 ;
* CPU ;
* mémoire ;
* disque ;
* erreurs applicatives ;
* échecs d'authentification ;
* métriques / health checks du Load Balancer.

Préciser leur signification et justifier leur présence.

## Résultats du monitoring et des tests

TODO :

* captures pertinentes des dashboards ;
* résultats des tests ;
* métriques concrètes observées ;
* synthèse compréhensible des constats.

## Analyse des résultats

TODO :

* interpréter les métriques ;
* identifier saturation, indisponibilité ou anomalie ;
* expliquer les impacts observés sur la disponibilité, la stabilité et les performances.

## Gains obtenus

### Performance de livraison

Comparer le processus OPS initial avec le processus automatisé actuel.

**Avant :**

* réception du numéro de version de l'image ;
* scan Trivy manuel ;
* déploiement Docker manuel sur l'environnement de démonstration ;
* vérification du fonctionnement.

**Après :**

* contrôles, release, déploiement et vérifications automatisés par la CI/CD.

TODO :

* chronométrer une exécution du processus manuel initial ;
* mesurer le temps d'intervention humaine actuel ;
* calculer le gain par déploiement.

Ne pas inclure dans le calcul les fonctionnalités ajoutées sans équivalent dans le processus initial.

### Disponibilité et performance

TODO : présenter les impacts mesurés des améliorations apportées.

## Recommandations d'amélioration continue

Pour chaque recommandation :

* problème constaté ;
* métrique ou observation associée ;
* amélioration proposée ;
* bénéfice attendu ;
* justification technique et organisationnelle.

Exemples déjà prévus :

* ajustement des seuils d'alerte ;
* scaling / deuxième EC2 ;
* Load Balancer ;
* amélioration du monitoring ;
* amélioration du rollback.

## Sécurité

### Gains obtenus

TODO : présenter les gains obtenus grâce aux contrôles de sécurité.

### Vulnérabilités et corrections

TODO : vulnérabilités détectées et corrections apportées.

### Recommandations

TODO : améliorations proposées pour le suivi et la correction des vulnérabilités.

## Conclusion

TODO : expliquer comment les mesures et améliorations mises en place contribuent :

* à l'amélioration continue de la pipeline CI/CD ;
* à la disponibilité du système ;
* à sa stabilité ;
* à sa fiabilité ;
* à ses performances globales.
