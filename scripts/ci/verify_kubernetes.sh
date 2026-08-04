#!/bin/sh

# Vérifie le déploiement MicroCRM réellement exécuté sur Kubernetes.
# Le tunnel `kubectl port-forward` passe par le GitLab Agent : aucun port du
# cluster AWS n'a besoin d'être exposé publiquement.

set -eu

usage() {
  cat <<'EOF'
Usage: verify_kubernetes.sh --context CONTEXT [OPTIONS]

Options:
  --context CONTEXT       Contexte Kubernetes injecté par le GitLab Agent
  --namespace NAMESPACE   Namespace de la release (défaut : microcrm)
  --release RELEASE       Nom de la release Helm (défaut : microcrm)
  --expected-host HOST    Hôte attendu dans l'Ingress
  --help                  Afficher cette aide
EOF
}

context=""
namespace="microcrm"
release="microcrm"
expected_host="microcrm.example.invalid"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --context)
      context="${2:-}"
      shift 2
      ;;
    --namespace)
      namespace="${2:-}"
      shift 2
      ;;
    --release)
      release="${2:-}"
      shift 2
      ;;
    --expected-host)
      expected_host="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Option inconnue : %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[ -n "$context" ] || {
  printf 'Erreur : --context est obligatoire.\n' >&2
  exit 2
}

command -v kubectl >/dev/null 2>&1 || {
  printf 'Erreur : kubectl est introuvable.\n' >&2
  exit 1
}
command -v curl >/dev/null 2>&1 || {
  printf 'Erreur : curl est introuvable.\n' >&2
  exit 1
}

kube() {
  kubectl --context "$context" --namespace "$namespace" "$@"
}

resource_prefix="${release}-microcrm"
frontend_deployment="${resource_prefix}-frontend"
backend_deployment="${resource_prefix}-backend"
database_statefulset="${resource_prefix}-database"
frontend_service="${resource_prefix}-frontend"
ingress_name="$resource_prefix"
pvc_name="data-${database_statefulset}-0"

# Ces attentes prouvent que les workloads déployés par Helm sont disponibles.
kube rollout status "deployment/${frontend_deployment}" --timeout=180s
kube rollout status "deployment/${backend_deployment}" --timeout=180s
kube rollout status "statefulset/${database_statefulset}" --timeout=180s

pvc_phase="$(kube get "pvc/${pvc_name}" --output=jsonpath='{.status.phase}')"
[ "$pvc_phase" = "Bound" ] || {
  printf "Erreur : le PVC %s est dans l'état %s.\n" "$pvc_name" "$pvc_phase" >&2
  exit 1
}

actual_host="$(kube get "ingress/${ingress_name}" --output=jsonpath='{.spec.rules[0].host}')"
[ "$actual_host" = "$expected_host" ] || {
  printf 'Erreur : hôte Ingress attendu %s, obtenu %s.\n' "$expected_host" "$actual_host" >&2
  exit 1
}

temporary_directory="${TMPDIR:-/tmp}/microcrm-kubernetes-verify-$$"
mkdir -p "$temporary_directory"
port_forward_pid=""

cleanup() {
  if [ -n "$port_forward_pid" ]; then
    kill "$port_forward_pid" 2>/dev/null || true
    wait "$port_forward_pid" 2>/dev/null || true
  fi
  rm -rf -- "$temporary_directory"
}
trap cleanup EXIT INT TERM

# Le port-forward traverse le GitLab Agent et cible le Service frontend réel.
kube port-forward "service/${frontend_service}" 18080:80 \
  --address=127.0.0.1 >"${temporary_directory}/port-forward.log" 2>&1 &
port_forward_pid=$!

frontend_ready=false
attempt=1
while [ "$attempt" -le 30 ]; do
  if curl --fail --silent --show-error --output /dev/null \
    http://127.0.0.1:18080/; then
    frontend_ready=true
    break
  fi

  if ! kill -0 "$port_forward_pid" 2>/dev/null; then
    cat "${temporary_directory}/port-forward.log" >&2
    printf "Erreur : le port-forward Kubernetes s'est arrêté.\n" >&2
    exit 1
  fi

  attempt=$((attempt + 1))
  sleep 2
done

[ "$frontend_ready" = true ] || {
  cat "${temporary_directory}/port-forward.log" >&2
  printf 'Erreur : le frontend ne répond pas après 60 secondes.\n' >&2
  exit 1
}

# Cette requête traverse Caddy, le Service backend et l'application Spring.
curl --fail --silent --show-error --output /dev/null \
  http://127.0.0.1:18080/api/persons

printf 'Déploiement Kubernetes vérifié : workloads prêts, PVC lié, Ingress conforme et parcours HTTP frontend/backend fonctionnel.\n'
