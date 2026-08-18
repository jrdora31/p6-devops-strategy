# Pipeline CI/CD

## Fonctionnement de la pipeline

Quand et dans quel ordre les jobs GitLab s'exécutent ?

TODO :

* présenter les stages ;
* expliquer les principales dépendances `needs` ;
* préciser les règles conditionnelles (`rules`, `rules:changes`) ;
* identifier les jobs manuels ou non bloquants.

## Plan d'automatisation des releases

Comment une version passe du code source à une release déployée ?

### Étapes de livraison

TODO : décrire brièvement :

1. validation du code ;
2. build et validation des images ;
3. création / identification de la version ;
4. promotion de l'image validée ;
5. déploiement ;
6. vérification post-déploiement.

Voir aussi [`deployment-strategy.md`](./deployment-strategy.md).

### Rollback

TODO :

* expliquer quand un rollback est déclenché ;
* préciser son intégration dans le processus de release.

La procédure détaillée est décrite dans [`../Maintenance/rollback.md`](../Maintenance/rollback.md).

### Versioning

TODO :

* convention de version utilisée ;
* création et protection des tags ;
* lien entre tag, commit SHA et image publiée.

## Traçabilité des versions et déploiements

TODO : expliquer comment la pipeline permet de retrouver :

* le commit SHA associé à une version ;
* le tag / numéro de release ;
* l'image Docker publiée et son digest ;
* l'environnement sur lequel la version a été déployée ;
* le déploiement GitLab correspondant.

La validation technique des scripts utilisés par la pipeline est documentée dans `scripts/ci/scripts.md`.
