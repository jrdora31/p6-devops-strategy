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

## Canary de production

- Une pipeline Web `dev` gère l'infrastructure partagée dans le state
  `microcrm-poc` : deux EC2, un cluster K3s et un NLB.
- Une pipeline Web `main` ne provisionne aucune seconde infrastructure.
- La pipeline d'infrastructure ne déploie aucune application.
- `deploy:helm:staging:release-or-rollback` accepte uniquement une RC et la déploie en staging.
- Une RC reste limitée à staging. Seule une finale `vX.Y.Z` valide avec
  `Promote-From` expose `deploy:helm:production:canary`.
- Le job conserve la stable courante et crée des Deployments et Services
  séparés portant `microcrm.io/track: canary` et
  `app.kubernetes.io/version: vX.Y.Z`.
- Le `TraefikService` natif répartit par défaut 90 % vers le Service stable et
  10 % vers le Service Canary. Les poids viennent des values Helm.
- `verify:production:canary` contrôle automatiquement les rollouts, Pods,
  versions, digests, Services internes stable/Canary et l'entrée NLB normale.
  Il ne réalise aucune période d'observation.
- CloudWatch est consulté directement par l'opérateur. Il n'existe aucun job
  `observation:cloudwatch`.
- `promote:helm:production:canary` route d'abord 100 % vers le Canary, le
  teste, copie exactement ses digests et sa version dans les Deployments
  stables, attend leur RollingUpdate, remet stable à 100 %, puis retire le
  Canary.
- `abort:helm:production:canary` remet la stable existante à 100 %, la teste,
  puis retire le Canary sans modifier les digests stables.
- `rollback:helm:production:release`, lancé depuis la pipeline d'une ancienne
  finale, restaure cette version comme stable à 100 %. Il refuse de démarrer
  tant qu'un Canary existe : ABORT CANARY et rollback production sont distincts.
- Tous ces jobs téléchargent le bundle du tag et passent à Helm des références
  `repository@sha256`. Aucun n'appelle une compilation, un build Docker, un
  push ou un retag d'image.
- Une ancienne RC se redéploie en staging depuis sa pipeline. Une ancienne
  finale se restaure en production avec le job de rollback dédié.

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

## Scénarios de validation

- **A — RC :** créer `vX.Y.Z-rc.N`, lancer le déploiement staging et vérifier
  qu'aucun job Canary production n'existe.
- **B — finale :** créer `vX.Y.Z` avec `Promote-From: vX.Y.Z-rc.N` et contrôler
  dans le manifeste que les deux digests sont ceux de la RC.
- **C — déploiement :** lancer `deploy:helm:production:canary`, puis observer
  `verify:production:canary` automatique et la pipeline `SUCCESS` avec 90/10.
- **D — observation :** ouvrir `microcrm-application-production` dans
  CloudWatch et comparer stable/Canary.
- **E — PROMOTE :** lancer le job correspondant ; stable doit finir à 100 %
  avec les digests du Canary, lequel doit être absent.
- **F — ABORT :** sur un nouveau Canary, lancer ABORT ; l'ancienne stable doit
  rester à 100 % et le Canary disparaître.
- **G — rollback :** après une promotion, ouvrir la pipeline d'une ancienne
  finale et lancer `rollback:helm:production:release`.
- **H — authentification :** depuis un Pod frontend, appeler
  `/api/internal/auth-check` avec des identifiants Basic volontairement
  invalides ; vérifier le HTTP 401 puis l'incrément
  `AuthenticationFailureCount` dans CloudWatch. Ne jamais afficher le mot de
  passe utilisé.
