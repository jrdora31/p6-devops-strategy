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

1. lancer manuellement `release:version:semantic` sur une pipeline de push
   `dev` pour obtenir le prochain numéro RC calculé depuis les Conventional
   Commits ; le job est un dry-run et ne crée aucun tag ;
2. valider le code puis construire, tester, scanner et publier les images SHA
   sur `dev` ;
3. créer manuellement la RC proposée `vX.Y.Z-rc.N` et la valider en staging ;
4. après merge vers `main`, créer manuellement le tag final proposé, annoté avec
   `Promote-From: vX.Y.Z-rc.N` ;
5. vérifier les sources puis reprendre les digests de la RC, sans rebuild ;
6. archiver le manifeste, les digests et le chart dans le Generic Package
   Registry ;
7. lancer manuellement `deploy:helm:production:canary` ; ce job est bloquant
   afin que `verify:production:canary` parte automatiquement après son succès ;
8. après le verify, la pipeline est `SUCCESS` et les jobs manuels optionnels
   `promote:helm:production:canary` et `abort:helm:production:canary` restent
   disponibles dans cette même pipeline.

Les deux décisions finales utilisent `when: manual` avec
`rules:allow_failure: true`. Ne pas les lancer ne bloque donc pas la pipeline.
Si une décision est lancée et échoue, son job devient rouge avec son diagnostic,
mais le succès déjà obtenu par la pipeline reste inchangé. Chaque script
termine néanmoins avec un code non nul sur digest, rollout ou smoke test
incorrect.

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

Semantic Release ne publie rien dans ce workflow. Son plugin officiel
`commit-analyzer` calcule uniquement le prochain numéro : `fix` incrémente le
patch, `feat` la minor et un changement incompatible la major. La création des
tags RC/final, la mention `Promote-From`, les déploiements et les rollbacks
restent des décisions manuelles.

## Traçabilité des versions et déploiements

Depuis la release GitLab et son manifeste, on retrouve :

* le commit SHA associé à une version ;
* le tag / numéro de release ;
* l'image Docker publiée et son digest ;
* l'environnement sur lequel la version a été déployée ;
* le déploiement GitLab correspondant.

La validation technique des scripts utilisés par la pipeline est documentée dans `scripts/ci/scripts.md`.
