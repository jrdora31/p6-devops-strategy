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

1. valider le code puis construire, tester, scanner et publier les images SHA
   sur `dev` ;
2. créer une RC `vX.Y.Z-rc.N` et la valider en staging ;
3. après merge vers `main`, créer le tag final annoté avec
   `Promote-From: vX.Y.Z-rc.N` ;
4. vérifier les sources puis reprendre les digests de la RC, sans rebuild ;
5. archiver le manifeste, les digests et le chart dans le Generic Package
   Registry ;
6. promouvoir manuellement puis exécuter le contrôle HTTP post-déploiement.

Voir aussi [`deployment-strategy.md`](./deployment-strategy.md).

### Rollback

Le rollback consiste à relancer le job manuel de l'environnement depuis la
pipeline du tag stable précédent. Il ne prend plus un numéro de révision Helm :
la release choisie fournit elle-même son chart et ses digests immuables.

La procédure détaillée est décrite dans [`../Maintenance/rollback.md`](../Maintenance/rollback.md).

### Versioning

Les RC utilisent `vMAJOR.MINOR.PATCH-rc.N` et les finales
`vMAJOR.MINOR.PATCH`. Le manifeste final relie aussi la RC promue et son commit
source aux digests frontend/backend conservés.

## Traçabilité des versions et déploiements

Depuis la release GitLab et son manifeste, on retrouve :

* le commit SHA associé à une version ;
* le tag / numéro de release ;
* l'image Docker publiée et son digest ;
* l'environnement sur lequel la version a été déployée ;
* le déploiement GitLab correspondant.

La validation technique des scripts utilisés par la pipeline est documentée dans `scripts/ci/scripts.md`.
