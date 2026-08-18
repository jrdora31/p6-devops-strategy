Quelle stratégie de release utilise-t-on : canary, promotion, rollback, sauvegarde ?

# Stratégie de release et de promotion

MicroCRM applique **Build Once, Promote Many** : une image applicative est
construite, testée, scannée et publiée une seule fois sous le tag technique du
commit (`CI_COMMIT_SHA`). Les environnements ne reconstruisent jamais l'image.

## Création d'une release

1. La pipeline de branche `dev` construit et publie
   `frontend:$CI_COMMIT_SHA` et `backend:$CI_COMMIT_SHA`.
2. Le tag RC `vMAJOR.MINOR.PATCH-rc.N` pointe sur ce commit. Sa pipeline
   récupère les images SHA existantes et leurs digests, sans rebuild.
3. Après validation staging et merge vers `main`, le tag final est annoté avec
   `Promote-From: vMAJOR.MINOR.PATCH-rc.N`.
4. La pipeline finale recharge le manifeste RC et refuse la promotion si les
   sources frontend/backend, les Dockerfiles ou la chaîne de build ont changé
   entre le commit RC et le commit final.
5. `release:manifest` relie le tag, le commit, la pipeline et les deux
   références `repository@sha256`.
   Pour une finale, il indique aussi la RC et son commit source.
6. `release:bundle` conserve durablement dans le Generic Package Registry le
   manifeste, `images.env` et le chart Helm versionné.
7. La release GitLab expose le lien vers sa pipeline et son manifeste.

La pipeline RC échoue si les images SHA du commit n'existent pas. La pipeline
finale échoue si le tag n'est pas annoté, si le manifeste RC est absent ou si
les sources influençant les images ont changé. Aucune ne reconstruit d'image.

## Promotion et rollback

- Le Web pipeline `dev` conserve le déploiement staging courant après build.
- `deploy:helm:release:staging` accepte uniquement une RC et la déploie en staging.
- `deploy:helm:aws` accepte uniquement une version finale et la déploie en production.
- Les deux jobs téléchargent le bundle du tag et passent à Helm les digests
  frontend/backend. Le chart produit donc des images `repository@sha256`.
- Une ancienne RC se redéploie en staging depuis sa pipeline. Une ancienne
  finale se redéploie en production depuis sa pipeline.

Cette procédure restaure la release applicative. Elle ne restaure pas les
données PostgreSQL et ne remplace pas une procédure de restauration de base.
