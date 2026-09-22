# Preuves de tests MicroCRM — 16 septembre 2026

Ce document conserve les observations reçues dans la conversation. Les trois captures originales de vérification GitLab, du comptage HTTP et de santé NLB sont archivées dans `DOCS`.

## Canary production — vérification automatique

- GitLab : pipeline du tag `v1.4.0` `#2850551710`, job `verify:production:canary` `#16509653229`.
- Capture reçue : job `succeeded`. Le log indique les rollouts réussis des déploiements stable et Canary, puis `Verify réussi: stable=v1.3.1, canary=v1.4.0, ... poids=90/10` et `Smoke HTTP de la production via NLB réussi`.
- Capture archivée : [canary_succeed_1.4.0.png](canary_succeed_1.4.0.png).

## Distribution Canary — mesure HTTP

- Capture reçue précédemment : 100 requêtes PowerShell vers `/api/deployment-info?test=N` ont donné `10 × 200` et `90 × 404`.
- Dans les tags inspectés, cet endpoint est présent en `v1.4.0` et absent en `v1.3.1`. Ces résultats sont cohérents avec une distribution Canary 10 % / stable 90 % ; ils ne prouvent pas la distribution entre les cibles du NLB.
- Capture archivée : [résultat_comptage_canary_90_10.png](résultat_comptage_canary_90_10.png).

## NLB — santé des cibles

- Console AWS EC2, région `eu-west-3`, target group `microcrm-poc-http`, load balancer `microcrm-poc-nlb`, TCP/80.
- Capture reçue : deux cibles enregistrées, deux `Healthy`, zéro `Unhealthy`, au 16 septembre 2026. Les cibles sont les instances nommées production et staging.
- Cette capture prouve la santé TCP des deux cibles à cet instant ; elle ne prouve pas à elle seule la répartition des connexions ni la résilience à la perte d'une cible.
- Capture archivée : [NLB_target_group_healthy.png](NLB_target_group_healthy.png).

## NLB — accès HTTP public

- DNS testé : `microcrm-poc-nlb-226f13490f7c4431.elb.eu-west-3.amazonaws.com` avec l'en-tête `Host: microcrm.example.invalid`.
- Série observée : `20 × HTTP 200` sur `/`, via 20 appels `curl.exe` distincts depuis PowerShell.
- Le premier essai avec la valeur d'exemple `COLLE_LE_DNS_ICI` a échoué en résolution DNS ; il ne fait pas partie du résultat du test avec le vrai DNS.
- Cette série prouve l'accès HTTP via le DNS du NLB à cet instant. Elle ne prouve ni la distribution des connexions entre les deux EC2 ni la résilience à la perte d'une cible.
- Capture archivée : [HTTP_NLB_test_réponses_200.png](HTTP_NLB_test_réponses_200.png).

## Performance — référence HTTP légère

- Série de 50 requêtes successives sur `/` via le DNS du NLB et `Host: microcrm.example.invalid`.
- Capture archivée : [performance_nlb_50_requetes_http_200.png](performance_nlb_50_requetes_http_200.png).
- Résultat visible : `50 × HTTP 200`. La capture ne rend pas visibles les valeurs moyenne, minimum et maximum de `time_total` ; aucune latence chiffrée n'est donc retenue à ce stade.
- Ce test séquentiel est une vérification légère, pas un test de charge ni une preuve de capacité maximale.
- Une mesure directe supplémentaire depuis le shell de l'assistant a produit `50 × HTTP 200`, minimum `46,64 ms`, moyenne `60,98 ms`, P95 `111,27 ms`, maximum `120,28 ms` entre `12:53:49Z` et `12:53:53Z`. Commande, sortie et limites : [PREUVE_PERFORMANCE_NLB_2026-09-16.md](PREUVE_PERFORMANCE_NLB_2026-09-16.md).

## Suite

1. Examiner les métriques et décider ensuite de promouvoir ou d'abandonner le Canary.
