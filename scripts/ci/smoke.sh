#!/bin/sh

# Vérifie les images runtime sans publier de port sur la machine hôte.
# Le test lance les deux conteneurs sur un réseau Docker temporaire, attend leurs
# healthchecks, puis appelle l'API à travers le reverse proxy du frontend.

set -eu

log_info() {
  printf '[INFO] %s\n' "$*"
}

die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Commande requise introuvable : $1"
}

usage() {
  cat <<'EOF'
Usage: smoke.sh --frontend-image IMAGE --backend-image IMAGE

Lance les images sur un réseau temporaire et vérifie le frontend ainsi que
l'accès à l'API via /api.
EOF
}

frontend_image=""
backend_image=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --frontend-image)
      [ "$#" -ge 2 ] || die "Valeur manquante après --frontend-image"
      frontend_image="$2"
      shift 2
      ;;
    --backend-image)
      [ "$#" -ge 2 ] || die "Valeur manquante après --backend-image"
      backend_image="$2"
      shift 2
      ;;
    --help | -h)
      usage
      exit 0
      ;;
    *)
      die "Argument inconnu : $1"
      ;;
  esac
done

[ -n "$frontend_image" ] || die "L'image frontend est obligatoire"
[ -n "$backend_image" ] || die "L'image backend est obligatoire"
require_command docker

# Les noms contiennent le PID afin que deux pipelines concurrents ne partagent
# jamais les mêmes conteneurs ou le même réseau.
suffix="${CI_PIPELINE_ID:-local}-$$"
network="microcrm-smoke-${suffix}"
frontend_container="microcrm-frontend-${suffix}"
backend_container="microcrm-backend-${suffix}"

cleanup() {
  docker rm --force "$frontend_container" "$backend_container" >/dev/null 2>&1 || true
  docker network rm "$network" >/dev/null 2>&1 || true
}
trap cleanup EXIT

wait_for_healthy() {
  wait_container="$1"
  wait_attempts=30

  wait_attempt=1
  while [ "$wait_attempt" -le "$wait_attempts" ]; do
    wait_status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' "$wait_container")"
    if [ "$wait_status" = "healthy" ]; then
      log_info "$wait_container est healthy"
      return 0
    fi
    if [ "$wait_status" = "unhealthy" ]; then
      docker logs "$wait_container" >&2
      die "$wait_container est unhealthy"
    fi
    sleep 2
    wait_attempt=$((wait_attempt + 1))
  done

  docker logs "$wait_container" >&2
  die "Timeout en attendant le healthcheck de $wait_container"
}

docker network create "$network" >/dev/null
docker run --detach --name "$backend_container" --network "$network" --network-alias backend "$backend_image" >/dev/null
wait_for_healthy "$backend_container"

docker run --detach --name "$frontend_container" --network "$network" "$frontend_image" >/dev/null
wait_for_healthy "$frontend_container"

# Cette requête traverse Caddy puis atteint Spring. Elle valide donc à la fois
# le démarrage des images, leur réseau et le routage frontend vers backend.
docker exec "$frontend_container" wget --quiet --output-document=- http://127.0.0.1/api/persons >/dev/null

# Le parcours fonctionnel reste volontairement court : création d'une personne
# dans la base éphémère du test, puis recherche de cette même personne par email.
email="smoke-${suffix}@example.net"
payload="{\"firstName\":\"Smoke\",\"lastName\":\"Test\",\"email\":\"${email}\"}"
docker exec "$frontend_container" wget \
  --quiet \
  --output-document=/dev/null \
  --header='Content-Type: application/json' \
  --post-data="$payload" \
  http://127.0.0.1/api/persons
docker exec "$frontend_container" wget \
  --quiet \
  --output-document=- \
  "http://127.0.0.1/api/persons/search/findByEmail?email=${email}" \
  | grep -q "$email"

log_info "Smoke test full-stack et parcours create/read réussis"
