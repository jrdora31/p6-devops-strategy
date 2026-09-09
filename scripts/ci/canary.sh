#!/usr/bin/env bash

# Orchestre le cycle Canary sans construire ni retaguer d'image. Toutes les
# transitions relisent les références repository@sha256 depuis Kubernetes ou
# depuis le bundle immuable de la release finale.

set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: canary.sh deploy|verify|promote|abort|rollback

Variables requises : KUBE_CONTEXT, KUBE_NAMESPACE, HELM_CHART, HELM_VALUES,
RELEASE_VERSION, FRONTEND_IMAGE_DIGEST, BACKEND_IMAGE_DIGEST et les valeurs
Kubernetes de registre/base/monitoring utilisées par le chart.
EOF
}

[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { usage; exit 0; }
action="${1:-}"
case "$action" in
  deploy|verify|promote|abort|rollback) ;;
  *) usage >&2; exit 2 ;;
esac

required_variables=(
  KUBE_CONTEXT KUBE_NAMESPACE HELM_CHART HELM_VALUES RELEASE_VERSION
  FRONTEND_IMAGE_DIGEST BACKEND_IMAGE_DIGEST CI_REGISTRY CI_DEPLOY_USER
  CI_DEPLOY_PASSWORD KUBERNETES_DATABASE_PASSWORD
  KUBERNETES_MONITORING_PASSWORD
)
for variable_name in "${required_variables[@]}"; do
  [[ -n "${!variable_name:-}" ]] || {
    echo "Variable requise absente : ${variable_name}" >&2
    exit 2
  }
done

[[ "$RELEASE_VERSION" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || {
  echo "Le cycle Canary accepte uniquement une release finale vX.Y.Z" >&2
  exit 2
}

readonly release_name="microcrm"
readonly fullname="microcrm-prod"
readonly stable_weight="${CANARY_STABLE_WEIGHT:-90}"
readonly canary_weight="${CANARY_WEIGHT:-10}"

for weight in "$stable_weight" "$canary_weight"; do
  [[ "$weight" =~ ^[0-9]+$ && "$weight" -le 100 ]] || {
    echo "Les poids Canary doivent être des entiers compris entre 0 et 100" >&2
    exit 2
  }
done
[[ $((stable_weight + canary_weight)) -eq 100 ]] || {
  echo "La somme des poids stable et Canary doit être égale à 100" >&2
  exit 2
}

kube() {
  kubectl --context "$KUBE_CONTEXT" --namespace "$KUBE_NAMESPACE" "$@"
}

deployment_name() {
  local track="$1"
  local component="$2"
  if [[ "$track" == "stable" ]]; then
    printf '%s-%s' "$fullname" "$component"
  else
    printf '%s-canary-%s' "$fullname" "$component"
  fi
}

deployment_image() {
  kube get deployment "$(deployment_name "$1" "$2")" \
    --output=jsonpath='{.spec.template.spec.containers[0].image}'
}

deployment_version() {
  kube get deployment "$(deployment_name "$1" "$2")" \
    --output=jsonpath='{.metadata.labels.app\.kubernetes\.io/version}'
}

require_digest() {
  local image="$1"
  [[ "$image" =~ ^.+@sha256:[0-9a-f]{64}$ ]] || {
    echo "Référence d'image non immuable : ${image}" >&2
    exit 1
  }
}

require_track() {
  local track="$1"
  local expected_frontend="$2"
  local expected_backend="$3"
  local expected_version="$4"
  local component expected image version replicas ready

  for component in frontend backend; do
    kube rollout status "deployment/$(deployment_name "$track" "$component")" --timeout=5m
    if [[ "$component" == "frontend" ]]; then
      expected="$expected_frontend"
    else
      expected="$expected_backend"
    fi
    image="$(deployment_image "$track" "$component")"
    [[ "$image" == "$expected" ]] || {
      echo "Digest ${track}/${component} inattendu : ${image}" >&2
      exit 1
    }
    version="$(deployment_version "$track" "$component")"
    [[ "$version" == "$expected_version" ]] || {
      echo "Version ${track}/${component} inattendue : ${version}" >&2
      exit 1
    }
    replicas="$(kube get deployment "$(deployment_name "$track" "$component")" --output=jsonpath='{.spec.replicas}')"
    ready="$(kube get deployment "$(deployment_name "$track" "$component")" --output=jsonpath='{.status.readyReplicas}')"
    [[ "$ready" == "$replicas" ]] || {
      echo "Deployment ${track}/${component} non prêt (${ready:-0}/${replicas})" >&2
      exit 1
    }
  done
}

smoke_track() {
  local track="$1"
  local frontend
  frontend="$(deployment_name "$track" frontend)"
  kube exec "deployment/${frontend}" --container frontend -- \
    wget --quiet --output-document=/dev/null http://127.0.0.1/
  kube exec "deployment/${frontend}" --container frontend -- \
    wget --quiet --output-document=/dev/null http://127.0.0.1/api/persons
}

helm_apply() {
  local stable_frontend="$1"
  local stable_backend="$2"
  local stable_version="$3"
  local canary_enabled="$4"
  local canary_frontend="$5"
  local canary_backend="$6"
  local canary_version="$7"
  local route_stable_weight="$8"
  local route_canary_weight="$9"

  require_digest "$stable_frontend"
  require_digest "$stable_backend"
  require_digest "$canary_frontend"
  require_digest "$canary_backend"
  local stable_frontend_repository="${stable_frontend%@*}"
  local stable_frontend_digest="${stable_frontend#*@}"
  local stable_backend_repository="${stable_backend%@*}"
  local stable_backend_digest="${stable_backend#*@}"
  local canary_frontend_repository="${canary_frontend%@*}"
  local canary_frontend_digest="${canary_frontend#*@}"
  local canary_backend_repository="${canary_backend%@*}"
  local canary_backend_digest="${canary_backend#*@}"

  local registry_username_b64 registry_password_b64 database_password_b64 monitoring_password_b64
  registry_username_b64="$(printf '%s' "$CI_DEPLOY_USER" | base64 | tr -d '\n')"
  registry_password_b64="$(printf '%s' "$CI_DEPLOY_PASSWORD" | base64 | tr -d '\n')"
  database_password_b64="$(printf '%s' "$KUBERNETES_DATABASE_PASSWORD" | base64 | tr -d '\n')"
  monitoring_password_b64="$(printf '%s' "$KUBERNETES_MONITORING_PASSWORD" | base64 | tr -d '\n')"

  helm upgrade --install "$release_name" "$HELM_CHART" \
    --kube-context "$KUBE_CONTEXT" \
    --namespace "$KUBE_NAMESPACE" \
    --create-namespace \
    --values "$HELM_VALUES" \
    --set-string "release.version=$stable_version" \
    --set-string "frontend.image.repository=$stable_frontend_repository" \
    --set-string "frontend.image.digest=$stable_frontend_digest" \
    --set-string "backend.image.repository=$stable_backend_repository" \
    --set-string "backend.image.digest=$stable_backend_digest" \
    --set "canary.enabled=$canary_enabled" \
    --set "canary.stableWeight=$route_stable_weight" \
    --set "canary.canaryWeight=$route_canary_weight" \
    --set-string "canary.version=$canary_version" \
    --set-string "canary.frontend.image.repository=$canary_frontend_repository" \
    --set-string "canary.frontend.image.digest=$canary_frontend_digest" \
    --set-string "canary.backend.image.repository=$canary_backend_repository" \
    --set-string "canary.backend.image.digest=$canary_backend_digest" \
    --set-string "imagePullSecrets[0].name=microcrm-registry" \
    --set "registrySecret.enabled=true" \
    --set-string "registrySecret.name=microcrm-registry" \
    --set-string "registrySecret.server=$CI_REGISTRY" \
    --set-string "registrySecret.usernameBase64=$registry_username_b64" \
    --set-string "registrySecret.passwordBase64=$registry_password_b64" \
    --set-string "database.existingSecret=microcrm-database" \
    --set "database.managedSecret.enabled=true" \
    --set-string "database.managedSecret.username=microcrm" \
    --set-string "database.managedSecret.passwordBase64=$database_password_b64" \
    --set-string "monitoringAuth.existingSecret=microcrm-monitoring" \
    --set "monitoringAuth.managedSecret.enabled=true" \
    --set-string "monitoringAuth.managedSecret.username=monitoring" \
    --set-string "monitoringAuth.managedSecret.passwordBase64=$monitoring_password_b64" \
    --atomic \
    --wait \
    --timeout 5m
}

require_digest "$FRONTEND_IMAGE_DIGEST"
require_digest "$BACKEND_IMAGE_DIGEST"

case "$action" in
  deploy)
    kube get deployment "${fullname}-frontend" >/dev/null
    kube get deployment "${fullname}-backend" >/dev/null
    if kube get deployment "${fullname}-canary-frontend" >/dev/null 2>&1; then
      echo "Un Canary existe déjà; utilisez PROMOTE ou ABORT avant un nouveau déploiement" >&2
      exit 1
    fi
    current_frontend="$(deployment_image stable frontend)"
    current_backend="$(deployment_image stable backend)"
    require_digest "$current_frontend"
    require_digest "$current_backend"
    current_version="$(deployment_version stable frontend)"
    if [[ -z "$current_version" ]]; then
      current_chart="$(helm list --kube-context "$KUBE_CONTEXT" --namespace "$KUBE_NAMESPACE" --filter '^microcrm$' --output json | jq -r '.[0].chart // empty')"
      current_version="v${current_chart#microcrm-}"
    fi
    [[ "$current_version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
      echo "Impossible d'identifier la version stable courante" >&2
      exit 1
    }
    helm_apply "$current_frontend" "$current_backend" "$current_version" true \
      "$FRONTEND_IMAGE_DIGEST" "$BACKEND_IMAGE_DIGEST" "$RELEASE_VERSION" \
      "$stable_weight" "$canary_weight"
    printf 'Canary déployé: stable=%s (%s/%s), canary=%s (%s/%s), poids=%s/%s\n' \
      "$current_version" "$current_frontend" "$current_backend" \
      "$RELEASE_VERSION" "$FRONTEND_IMAGE_DIGEST" "$BACKEND_IMAGE_DIGEST" \
      "$stable_weight" "$canary_weight"
    ;;
  verify)
    stable_frontend="$(deployment_image stable frontend)"
    stable_backend="$(deployment_image stable backend)"
    stable_version="$(deployment_version stable frontend)"
    require_track stable "$stable_frontend" "$stable_backend" "$stable_version"
    require_track canary "$FRONTEND_IMAGE_DIGEST" "$BACKEND_IMAGE_DIGEST" "$RELEASE_VERSION"
    actual_stable_weight="$(kube get traefikservice "${fullname}-frontend-weighted" --output=jsonpath='{.spec.weighted.services[?(@.name=="microcrm-prod-frontend")].weight}')"
    actual_canary_weight="$(kube get traefikservice "${fullname}-frontend-weighted" --output=jsonpath='{.spec.weighted.services[?(@.name=="microcrm-prod-canary-frontend")].weight}')"
    [[ "$actual_stable_weight:$actual_canary_weight" == "$stable_weight:$canary_weight" ]] || {
      echo "Poids Traefik inattendus : ${actual_stable_weight:-absent}/${actual_canary_weight:-absent}" >&2
      exit 1
    }
    smoke_track canary
    smoke_track stable
    printf 'Verify réussi: stable=%s, canary=%s, digests=%s/%s, poids=%s/%s\n' \
      "$stable_version" "$RELEASE_VERSION" "$FRONTEND_IMAGE_DIGEST" \
      "$BACKEND_IMAGE_DIGEST" "$actual_stable_weight" "$actual_canary_weight"
    ;;
  promote)
    stable_frontend="$(deployment_image stable frontend)"
    stable_backend="$(deployment_image stable backend)"
    stable_version="$(deployment_version stable frontend)"
    canary_frontend="$(deployment_image canary frontend)"
    canary_backend="$(deployment_image canary backend)"
    canary_version="$(deployment_version canary frontend)"
    [[ "$canary_frontend" == "$FRONTEND_IMAGE_DIGEST" && "$canary_backend" == "$BACKEND_IMAGE_DIGEST" && "$canary_version" == "$RELEASE_VERSION" ]] || {
      echo "Le Canary actif ne correspond pas au bundle de cette pipeline" >&2
      exit 1
    }
    helm_apply "$stable_frontend" "$stable_backend" "$stable_version" true \
      "$canary_frontend" "$canary_backend" "$canary_version" 0 100
    smoke_track canary
    helm_apply "$canary_frontend" "$canary_backend" "$canary_version" true \
      "$canary_frontend" "$canary_backend" "$canary_version" 0 100
    require_track stable "$canary_frontend" "$canary_backend" "$canary_version"
    smoke_track stable
    helm_apply "$canary_frontend" "$canary_backend" "$canary_version" false \
      "$canary_frontend" "$canary_backend" "$canary_version" 100 0
    ! kube get deployment "${fullname}-canary-frontend" >/dev/null 2>&1
    ! kube get deployment "${fullname}-canary-backend" >/dev/null 2>&1
    smoke_track stable
    printf 'PROMOTE réussi: stable=%s frontend=%s backend=%s; Canary absent\n' \
      "$canary_version" "$canary_frontend" "$canary_backend"
    ;;
  abort)
    stable_frontend="$(deployment_image stable frontend)"
    stable_backend="$(deployment_image stable backend)"
    stable_version="$(deployment_version stable frontend)"
    canary_frontend="$(deployment_image canary frontend)"
    canary_backend="$(deployment_image canary backend)"
    canary_version="$(deployment_version canary frontend)"
    [[ "$canary_frontend" == "$FRONTEND_IMAGE_DIGEST" && "$canary_backend" == "$BACKEND_IMAGE_DIGEST" && "$canary_version" == "$RELEASE_VERSION" ]] || {
      echo "Le Canary actif ne correspond pas au bundle de cette pipeline" >&2
      exit 1
    }
    helm_apply "$stable_frontend" "$stable_backend" "$stable_version" true \
      "$canary_frontend" "$canary_backend" "$canary_version" 100 0
    require_track stable "$stable_frontend" "$stable_backend" "$stable_version"
    smoke_track stable
    helm_apply "$stable_frontend" "$stable_backend" "$stable_version" false \
      "$canary_frontend" "$canary_backend" "$canary_version" 100 0
    ! kube get deployment "${fullname}-canary-frontend" >/dev/null 2>&1
    ! kube get deployment "${fullname}-canary-backend" >/dev/null 2>&1
    smoke_track stable
    printf 'ABORT réussi: stable conservée=%s frontend=%s backend=%s; Canary abandonné=%s\n' \
      "$stable_version" "$stable_frontend" "$stable_backend" "$canary_version"
    ;;
  rollback)
    if kube get deployment "${fullname}-canary-frontend" >/dev/null 2>&1; then
      echo "ABORT CANARY requis avant un rollback de production" >&2
      exit 1
    fi
    helm_apply "$FRONTEND_IMAGE_DIGEST" "$BACKEND_IMAGE_DIGEST" "$RELEASE_VERSION" false \
      "$FRONTEND_IMAGE_DIGEST" "$BACKEND_IMAGE_DIGEST" "$RELEASE_VERSION" 100 0
    require_track stable "$FRONTEND_IMAGE_DIGEST" "$BACKEND_IMAGE_DIGEST" "$RELEASE_VERSION"
    smoke_track stable
    printf 'ROLLBACK production réussi: stable=%s frontend=%s backend=%s\n' \
      "$RELEASE_VERSION" "$FRONTEND_IMAGE_DIGEST" "$BACKEND_IMAGE_DIGEST"
    ;;
esac
