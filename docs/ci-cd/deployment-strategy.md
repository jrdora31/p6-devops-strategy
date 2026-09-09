Quelle stratégie de release utilise-t-on : canary, promotion, rollback, sauvegarde ?

# Stratégie de release et de promotion

MicroCRM applique **Build Once, Promote Many** : une image applicative est
construite, testée, scannée et publiée une seule fois sous le tag technique du
commit (`CI_COMMIT_SHA`). Les environnements ne reconstruisent jamais l'image.

## Création d'une release

1. Depuis une pipeline de push `dev`, le maintainer peut lancer manuellement
   `release:version:semantic`. Semantic Release analyse les commits depuis la
   dernière version et propose le prochain tag RC et le tag final associé. Ce
   job fonctionne uniquement en `dry-run` : il ne crée ni tag ni release.
2. La pipeline de branche `dev` construit et publie
   `frontend:$CI_COMMIT_SHA` et `backend:$CI_COMMIT_SHA`.
3. Le maintainer crée le tag RC proposé `vMAJOR.MINOR.PATCH-rc.N` sur ce
   commit. Sa pipeline réutilise les images SHA existantes et ne construit que
   l'image éventuellement absente avant d'enregistrer les digests.
4. Après validation staging et merge vers `main`, le maintainer crée le tag
   final proposé et l'annote avec
   `Promote-From: vMAJOR.MINOR.PATCH-rc.N`.
5. La pipeline finale recharge le manifeste RC et refuse la promotion si les
   sources frontend/backend, les Dockerfiles ou la chaîne de build ont changé
   entre le commit RC et le commit final.
6. `release:manifest` relie le tag, le commit, la pipeline et les deux
   références `repository@sha256`.
   Pour une finale, il indique aussi la RC et son commit source.
7. `release:bundle` conserve durablement dans le Generic Package Registry le
   manifeste, `images.env` et le chart Helm versionné.
8. `release:create` crée la release GitLab et expose le lien vers sa pipeline
   et son manifeste.

La pipeline RC réutilise chaque image SHA déjà présente et ne construit que
l'image absente. La pipeline finale échoue si le tag n'est pas annoté, si le
manifeste RC est absent ou si les sources influençant les images ont changé.
Elle ne déclenche aucun job de build et ne reconstruit aucune image.

## Convention de commits

Le calcul utilise la convention Conventional Commits reconnue par
`@semantic-release/commit-analyzer` :

- `fix(scope): ...` produit une version corrective (`PATCH`) ;
- `feat(scope): ...` produit une version mineure (`MINOR`) ;
- `type(scope)!: ...` ou un pied de message `BREAKING CHANGE: ...` produit une
  version majeure (`MAJOR`) ;
- les commits `docs`, `chore`, `ci`, `test`, `style` et `refactor` ne changent
  pas le numéro par défaut.

Une nouvelle RC nécessite donc au moins un commit produisant une release depuis
la dernière version calculée. Pour rejouer exactement la même RC, il faut
relancer sa pipeline existante plutôt que créer un nouveau tag.

## Promotion et rollback

- Une pipeline Web `dev` gère l'infrastructure partagée dans le state
  `microcrm-poc` : deux EC2, un cluster K3s et un NLB.
- Une pipeline Web `main` ne provisionne aucune seconde infrastructure.
- La pipeline d'infrastructure ne déploie aucune application.
- `deploy:helm:staging:release-or-rollback` accepte uniquement une RC et la déploie en staging.
- `deploy:helm:production:release-or-rollback` accepte uniquement une version finale et la déploie en production.
- Les deux jobs téléchargent le bundle du tag et passent à Helm les digests
  frontend/backend. Le chart produit donc des images `repository@sha256`.
- Une ancienne RC se redéploie en staging depuis sa pipeline. Une ancienne
  finale se redéploie en production depuis sa pipeline.

Cette procédure restaure la release applicative. Elle ne restaure pas les
données PostgreSQL et ne remplace pas une procédure de restauration de base.

## Séparation de l'infrastructure

L'infrastructure est déclarée dans deux states GitLab distincts :

- `microcrm-network` contient le VPC, le subnet public, la route Internet et le
  Security Group commun ;
- `microcrm-poc` contient exactement deux EC2, le cluster K3s partagé, le NLB,
  son IAM, le bucket temporaire Ansible/SSM et le monitoring.

Le root réseau reste séparé du root cluster. Le plan et l'apply du cluster
refusent toute combinaison autre que
`dev/poc/microcrm-poc/aws-poc-infrastructure`. Son destroy est manuel, dédié
à l'infrastructure et conserve le state réseau. Aucun job Helm staging ou
production ne peut le déclencher.

Avant le premier apply, inventorier les éventuels states
`microcrm-staging`/`microcrm-production` et remettre leur ownership dans
`microcrm-poc` sans dupliquer les ressources. Cette migration n'est pas
exécutée automatiquement par la CI.
