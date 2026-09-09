# Supervision

Comment surveiller MicroCRM une fois déployé et diagnostiquer son état.

## Dashboard CloudWatch

Lorsque CloudWatch est activé, Terraform crée :

- `microcrm-poc-infrastructure`, qui sépare l'EC2 staging et l'EC2 production ;
- `microcrm-application-production`, qui compare stable et Canary.

## Métriques

### EC2

Chaque EC2 dispose de CPU, RAM, disque, réseau et `StatusCheckFailed`. Les
InstanceId viennent directement des outputs du module Terraform ; aucun
identifiant n'est codé en dur.

Le backend publie en StatsD vers le CloudWatch Agent du nœud :

- `RequestCount` ;
- `ServerErrorCount` pour les réponses 5xx ;
- `Latency` avec une valeur par requête, permettant réellement `p95` ;
- `AuthenticationFailureCount` depuis le handler Spring Security réellement
  utilisé.

`AuthenticationFailureCount` ne représente pas une authentification métier
historique : MicroCRM n'en possédait pas. La métrique repose exclusivement sur
le mécanisme `/internal/auth-check` ajouté pour le contrôle du monitoring. Cet
endpoint est protégé par HTTP Basic ; les routes applicatives existantes,
notamment le CRUD `/persons`, restent publiques et sont couvertes par les tests
d'intégration.

Les dimensions applicatives sont bornées à `Environment`, `Track` et `Version`.
Une seconde série sans `Version` alimente les alarmes sur le Canary courant.
L'agent ajoute aussi l'`InstanceId` de l'EC2 production ; Terraform le référence
depuis l'output compute, jamais en dur. Aucun userId, requestId, token, en-tête
Authorization, IP ou URL complète n'est publié.

Le dashboard calcule `ErrorRate = ServerErrorCount / RequestCount * 100` avec
`IF` et `FILL` pour retourner zéro lorsque le nombre de requêtes est nul ou
qu'aucun 5xx n'existe.

### Exposition HTTP

Le NLB public TCP/80 distribue le trafic entre les deux EC2 saines. Traefik
conserve le routage HTTP par host vers chaque namespace.

Traefik est configuré avec deux réplicas, sans `nodeSelector` ni anti-affinité
obligatoire. L'anti-affinité seulement préférée cherche à placer un Pod sur
chaque EC2, mais autorise leur co-localisation sur staging. Dans ce cas, le
trafic production reçu par le NLB traverse l'EC2 staging avant de rejoindre les
Pods stable/Canary sur l'EC2 production.

La perte de l'EC2 staging supprime aussi l'unique control-plane. Les workloads
et un Pod Traefik déjà actifs sur l'agent production peuvent continuer à servir
le trafic avec l'état réseau existant, mais PROMOTE, ABORT, rollback et tout
nouveau scheduling sont impossibles jusqu'au rétablissement de l'API K3s. Si
les deux Pods Traefik étaient co-localisés sur staging, l'entrée HTTP production
tombe également. Cette limite est acceptée pour le POC à deux EC2 ; la corriger
proprement nécessiterait une architecture control-plane/worker hautement
disponible hors périmètre.

## Logs applicatifs

Les groupes `/microcrm/poc/{system,kubernetes,traefik}` collectent les journaux
des deux nœuds. Traefik écrit ses accès en JSON sans conserver les en-têtes ni
les paramètres de requête.

## CloudWatch Logs Insights

TODO : requêtes utiles pour :

* erreurs applicatives ;
* erreurs de déploiement ;
* échecs d'authentification.

## Alarmes

Les deux EC2 ont des alarmes de disponibilité et CPU. Le Canary possède quatre
alertes : au moins un 5xx sur cinq minutes, un taux de 5xx supérieur ou égal à
5 % pendant deux périodes de cinq minutes, au moins un échec d'authentification
sur cinq minutes et une latence p95 supérieure ou égale à 1000 ms pendant deux
périodes de cinq minutes. L'alarme de taux utilise les séries sans `Version` et
retourne zéro lorsque `RequestCount` vaut zéro. Elles notifient éventuellement
SNS ; elles ne déclenchent jamais PROMOTE, ABORT ou rollback.

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
`deploy:helm:staging:release-or-rollback`, les jobs Canary et le rollback de
production, ainsi que des contrôles Trivy
`quality:trivy:repository`, `quality:trivy:kubernetes`,
`release:trivy:image:frontend` et `release:trivy:image:backend` en cas d'échec.

TODO : ajouter une preuve observable (message Slack horodaté et pipeline liée)
avant de déclarer cette notification validée en conditions réelles.

## État K3s / Pods

Le contexte GitLab Agent unique `microcrm-poc` dessert les deux namespaces.
Le nœud server porte `microcrm.io/environment-role=staging` et le nœud agent
`microcrm.io/environment-role=production`. Les `nodeSelector` Helm empêchent
de traiter l'EC2 staging comme un Canary.

Le secret `KUBERNETES_MONITORING_PASSWORD` doit être une variable GitLab
masquée et protégée. Le test sûr consiste à envoyer des identifiants invalides
vers `/api/internal/auth-check`, attendre HTTP 401, puis chercher
`AuthenticationFailureCount` avec les dimensions attendues. Aucun credential
ne doit être copié dans les logs ou la commande conservée comme preuve.

## Diagnostic rapide

TODO : commandes utiles pour diagnostiquer :

* EC2 ;
* K3s / pods ;
* application ;
* contexte GitLab Agent et Traefik.

## Exploitation des données

Les observations issues du monitoring sont synthétisées et analysées dans [`../quality/performance.md`](../quality/performance.md).
