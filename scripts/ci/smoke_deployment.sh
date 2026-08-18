#!/usr/bin/env bash

# Vérifie l'API à travers Caddy dans le pod frontend déjà déployé par Helm.
# Le test ne crée aucun conteneur local et ne dépend d'aucun nom DNS public.

set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: smoke_deployment.sh --namespace NAMESPACE --context KUBE_CONTEXT
EOF
}

namespace=""
kube_context=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --namespace)
      namespace="${2:-}"
      shift 2
      ;;
    --context)
      kube_context="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

[[ -n "$namespace" ]] || { echo "Le namespace est obligatoire" >&2; exit 2; }
[[ -n "$kube_context" ]] || { echo "Le contexte Kubernetes est obligatoire" >&2; exit 2; }

kubectl --context "$kube_context" --namespace "$namespace" \
  rollout status deployment -l 'app.kubernetes.io/instance=microcrm,app.kubernetes.io/component=frontend' \
  --timeout=5m

frontend_deployment="$(kubectl --context "$kube_context" --namespace "$namespace" \
  get deployment -l 'app.kubernetes.io/instance=microcrm,app.kubernetes.io/component=frontend' \
  --output=jsonpath='{.items[0].metadata.name}')"
[[ -n "$frontend_deployment" ]] || { echo "Deployment frontend introuvable" >&2; exit 1; }

# La première requête confirme que le frontend Caddy sert bien sa page.
kubectl --context "$kube_context" --namespace "$namespace" \
  exec "deployment/$frontend_deployment" --container frontend -- \
  wget --quiet --output-document=/dev/null http://127.0.0.1/

# La seconde traverse Caddy vers le backend déployé et vérifie l'API.
kubectl --context "$kube_context" --namespace "$namespace" \
  exec "deployment/$frontend_deployment" --container frontend -- \
  wget --quiet --output-document=/dev/null http://127.0.0.1/api/persons

echo "Smoke HTTP du déploiement Kubernetes réussi dans $namespace"
