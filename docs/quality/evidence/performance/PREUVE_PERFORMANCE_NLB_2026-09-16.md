# Mesure HTTP directe via le NLB — 16 septembre 2026

## Méthode

- Client : shell PowerShell de l'assistant sur le poste local.
- Cible : DNS public du NLB `microcrm-poc-nlb-226f13490f7c4431.elb.eu-west-3.amazonaws.com`, chemin `/`.
- Routage Traefik : en-tête `Host: microcrm.example.invalid`.
- 50 invocations `curl.exe` successives, une connexion par invocation ; délai maximal de 10 secondes par requête.
- Mesure : `curl.exe -w '%{http_code} %{time_total}'`. Les latences sont converties en millisecondes ; P95 = observation classée au rang `ceil(0,95 × 50)`.

Commande exécutée :

```powershell
$targetUrl = 'http://microcrm-poc-nlb-226f13490f7c4431.elb.eu-west-3.amazonaws.com/'
$started = (Get-Date).ToUniversalTime().ToString('o')
$measurements = 1..50 | ForEach-Object {
  $line = curl.exe -sS --max-time 10 -o NUL -w '%{http_code} %{time_total}' -H 'Host: microcrm.example.invalid' $targetUrl
  $fields = $line -split ' '
  [pscustomobject]@{
    Status = $fields[0]
    Seconds = [double]::Parse($fields[1], [System.Globalization.CultureInfo]::InvariantCulture)
  }
}
$latencies = @($measurements | Sort-Object Seconds | ForEach-Object Seconds)
$stats = $measurements | Measure-Object Seconds -Average -Minimum -Maximum
```

## Résultat observé

```text
UTC_START=2026-09-16T12:53:49.9287118Z
UTC_END=2026-09-16T12:53:53.7237928Z
REQUESTS=50
STATUS_COUNTS=200:50
MIN_MS=46.64
AVG_MS=60.98
P95_MS=111.27
MAX_MS=120.28
```

La série confirme la disponibilité de la route HTTP via le NLB pendant environ 4 secondes. Elle ne démontre ni une capacité sous charge concurrente, ni la distribution entre les deux instances, ni la résilience à la perte d'une cible. Le serveur est exposé en HTTP sur le port 80 pour ce POC.
