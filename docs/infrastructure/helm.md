# Helm et K3s

Helm installe MicroCRM dans le cluster K3s à partir du
[chart `microcrm`](../../infrastructure/helm/microcrm/Chart.yaml). Terraform
crée l'infrastructure AWS, Ansible configure K3s et la CI construit les
images Docker. Helm assemble ensuite les ressources Kubernetes avec les
valeurs propres à l'environnement et les images du bundle de release,
référencées par leur digest `repository@sha256`.

Repères dans le dépôt : [chart](../../infrastructure/helm/microcrm/Chart.yaml),
[valeurs communes](../../infrastructure/helm/microcrm/values.yaml) et
[templates Kubernetes](../../infrastructure/helm/microcrm/templates/).

Le [helper du chart](../../infrastructure/helm/microcrm/templates/_helpers.tpl)
privilégie le digest quand le job de déploiement le fournit ; le tag n'est
utilisé qu'en l'absence de digest :

```gotemplate
{{- define "microcrm.image" -}}
{{- if .digest -}}
{{ printf "%s@%s" .repository .digest }}
{{- else -}}
{{ printf "%s:%s" .repository (required "image.tag est obligatoire lorsque image.digest est vide" .tag) }}
{{- end -}}
{{- end }}
```

## Conteneurs et réseau

Une requête entre par le NLB, passe par Traefik, puis atteint le frontend
Caddy. Le frontend transmet les appels `/api` au backend Spring Boot, qui
accède à PostgreSQL. Le NLB fournit l'entrée réseau commune aux deux nœuds ;
Traefik choisit la route HTTP selon l'hôte et, en production Canary, la version
à servir. Chaque Service Kubernetes garde une adresse stable devant les Pods
du composant concerné.

```text
Utilisateur → NLB TCP/80 → Traefik → frontend (80) → backend (8080) → PostgreSQL (5432)
```

Les Deployments maintiennent les Pods frontend et backend. Le StatefulSet
PostgreSQL conserve l'identité de la base et son volume persistant. Les sondes
de démarrage, disponibilité et vie évitent d'envoyer du trafic à un conteneur
qui n'est pas prêt. Les `NetworkPolicies` limitent les connexions entrantes
entre composants — [source](../../infrastructure/helm/microcrm/templates/networkpolicy.yaml).

Les valeurs communes de [`values.yaml`](../../infrastructure/helm/microcrm/values.yaml)
fixent les capacités suivantes :

| Composant | Réplicas | Ressources demandées | Limites |
|---|---:|---|---|
| Frontend | 2 | 50m CPU, 32 Mi mémoire | 250m CPU, 128 Mi |
| Backend | 2 | 100m CPU, 256 Mi | 500m CPU, 512 Mi |
| PostgreSQL | 1 | 100m CPU, 256 Mi | 500m CPU, 512 Mi |

Les ressources demandées réservent une capacité minimale au placement des
Pods ; les limites plafonnent leur consommation. Une anti-affinité préférée
cherche à séparer les réplicas applicatifs sans bloquer le déploiement si ce
placement n'est pas possible. Les images du GitLab Registry utilisent
`IfNotPresent` ; les identifiants du registre, de la base et du monitoring
sont fournis par les variables CI protégées, puis injectés dans des Secrets.

PostgreSQL conserve ses données sur un volume de 2 Gio avec `local-path`,
c'est-à-dire sur le disque local du nœud K3s. Ce choix convient au POC mais
n'apporte ni réplication du stockage ni sauvegarde externe.

## Environnements

Staging et production partagent les deux EC2, le control-plane K3s et le NLB.
Leurs applications et leurs bases sont toutefois installées dans des
namespaces séparés : `microcrm-staging` et `microcrm-prod`. Cette séparation
évite qu'une mise à jour ou une configuration applicative de staging modifie
directement la production.

| Environnement | Fichier de valeurs | Placement | Routage |
|---|---|---|---|
| Staging | [`values-staging.yaml`](../../infrastructure/helm/microcrm/values-staging.yaml) | Nœud `staging` | Version RC, sans Canary |
| Production | [`values-production.yaml`](../../infrastructure/helm/microcrm/values-production.yaml) | Nœud `production` | Stable seule ou stable + Canary |

Les `nodeSelector` assurent ce placement. Les bases PostgreSQL restent
distinctes, chacune sur son volume `local-path`. Les hôtes
`*.example.invalid` du chart sont des exemples : le POC utilise un accès HTTP
via le NLB, sans domaine public ni TLS configurés ici.

Par exemple, les [valeurs de production](../../infrastructure/helm/microcrm/values-production.yaml)
fixent le rôle du nœud et le stockage local. Le
[Deployment backend](../../infrastructure/helm/microcrm/templates/backend-deployment.yaml)
insère ce sélecteur dans la spécification de chaque Pod :

```yaml
nodeSelector:
  microcrm.io/environment-role: production

database:
  persistence:
    size: 2Gi
    storageClass: local-path
```

```gotemplate
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 8 }}
{{- end }}
```

## Ressources Kubernetes du Canary

Quand `canary.enabled=true`, le chart conserve les Deployments et Services
frontend/backend stables et crée des Deployments et Services frontend/backend
Canary distincts. Ils portent notamment les labels `microcrm.io/track: canary`
et `app.kubernetes.io/version` ; les deux versions utilisent la même base
PostgreSQL de production. Le frontend Canary appelle le backend Canary, et le
frontend stable appelle le backend stable.

Traefik répartit les requêtes entre les Services avec un `TraefikService`
pondéré. L'`IngressRoute` expose cette route derrière le NLB. La
[configuration de production](../../infrastructure/helm/microcrm/values-production.yaml)
fixe `canary.stableWeight=90` et `canary.canaryWeight=10` :

| Version | Trafic configuré |
|---|---:|
| Stable | 90 % |
| Canary | 10 % |

Le chart exige que les deux poids totalisent 100. Quand `canary.enabled=false`,
l'Ingress Kubernetes dirige tout le trafic vers la version stable. Les jobs
de [promotion ou d'abandon](../ci-cd/deployment-strategy.md) ramènent ensuite
la production à une seule version stable.

Dans le [template de routage](../../infrastructure/helm/microcrm/templates/ingress.yaml),
les poids sont vérifiés avant de produire le `TraefikService`. Les Services
stable et Canary reçoivent ensuite les valeurs `90` et `10` définies dans
`values-production.yaml` :

```gotemplate
{{- if ne (add (int .Values.canary.stableWeight) (int .Values.canary.canaryWeight)) 100 }}
{{- fail "la somme de canary.stableWeight et canary.canaryWeight doit être égale à 100" }}
{{- end }}
```

```yaml
canary:
  stableWeight: 90
  canaryWeight: 10
```

Traefik est configuré avec deux réplicas et une anti-affinité préférée, sans
garantie de placement sur les deux EC2. Si les deux Pods Traefik se trouvent
sur staging, la perte de cette EC2 supprime aussi l'entrée HTTP production —
[source](../../infrastructure/ansible/roles/k3s_server/templates/traefik-config.yaml.j2).
Le détail de la limite d'infrastructure figure dans
[Terraform](terraform.md).

## Commandes d'inspection

Depuis un contexte Kubernetes autorisé, remplacer `<namespace>` par
`microcrm-staging` ou `microcrm-prod`. La release Helm s'appelle `microcrm`.

```bash
helm -n <namespace> history microcrm
kubectl -n <namespace> get pods,deploy,svc,ingress
kubectl -n <namespace> get events --sort-by=.lastTimestamp
```

L'historique Helm montre les révisions ; les commandes Kubernetes affichent
l'état des Pods, Services, Ingress et événements. Les jobs Helm utilisent
`helm upgrade --install` avec attente et retour automatique en cas d'échec
(`--atomic`). Les critères de validation applicative figurent dans les
[tests](../quality/testing.md).

Voir aussi le [rollback](../Maintenance/rollback.md) et les
[limites de sauvegarde](../Maintenance/backup-recovery.md).
