#!/bin/sh
# Ce script vise le Shell POSIX (`/bin/sh`) plutôt que Bash, car l'image légère
# du client Docker ne garantit pas la présence de Bash.

# Vérifie les images runtime sans publier de port sur la machine hôte.
# Le test lance les deux conteneurs sur un réseau Docker temporaire, attend leurs
# healthchecks, puis appelle l'API à travers le reverse proxy du frontend.

# `-e` arrête au premier échec ; `-u` interdit l'usage d'une variable non définie.
# `pipefail` n'est pas portable en POSIX et n'est donc pas activé ici.
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
  # Le délimiteur quoté conserve le texte d'aide sans expansion de variables.
  cat <<'EOF'
Usage: smoke.sh --frontend-image IMAGE --backend-image IMAGE

Lance les images sur un réseau temporaire et vérifie le frontend ainsi que
l'accès à l'API via /api.
EOF
}

frontend_image=""
backend_image=""

# Analyse manuelle des options compatible avec `/bin/sh`.
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
# `${CI_PIPELINE_ID:-local}` utilise l'identifiant GitLab s'il existe, sinon
# `local`. `$$` ajoute le PID du script pour garantir l'unicité sur la machine.
suffix="${CI_PIPELINE_ID:-local}-$$"
network="microcrm-smoke-${suffix}"
frontend_container="microcrm-frontend-${suffix}"
backend_container="microcrm-backend-${suffix}"

cleanup() {
  # `--force` arrête puis supprime les conteneurs s'ils existent encore. Les
  # erreurs sont ignorées parce que le nettoyage doit aussi fonctionner après
  # un échec survenu avant leur création.
  docker rm --force "$frontend_container" "$backend_container" >/dev/null 2>&1 || true
  docker network rm "$network" >/dev/null 2>&1 || true
}
# Le trap appelle toujours `cleanup` à la sortie : succès, erreur ou `exit`.
trap cleanup EXIT

wait_for_healthy() {
  # Les variables ne sont pas `local` car ce mot-clé n'appartient pas au standard
  # POSIX. Chaque appel remplace simplement les valeurs utilisées par la boucle.
  wait_container="$1"
  wait_attempts=30

  wait_attempt=1
  while [ "$wait_attempt" -le "$wait_attempts" ]; do
    # Le template Go renvoie `missing` si l'image ne déclare aucun HEALTHCHECK.
    wait_status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' "$wait_container")"
    if [ "$wait_status" = "healthy" ]; then
      log_info "$wait_container est healthy"
      return 0
    fi
    if [ "$wait_status" = "unhealthy" ]; then
      # Les logs applicatifs sont affichés seulement en cas d'échec pour aider au diagnostic.
      docker logs "$wait_container" >&2
      die "$wait_container est unhealthy"
    fi
    sleep 2
    # Arithmétique POSIX : incrémente le compteur jusqu'à 30 tentatives.
    wait_attempt=$((wait_attempt + 1))
  done

  docker logs "$wait_container" >&2
  die "Timeout en attendant le healthcheck de $wait_container"
}

assert_non_root() {
  # `id -u` renvoie 0 pour root. Le contrôle est exécuté dans le conteneur réel
  # afin de valider l'utilisateur effectif, pas seulement la directive Dockerfile.
  identity_container="$1"
  identity_uid="$(docker exec "$identity_container" id -u)"
  [ "$identity_uid" -ne 0 ] || die "$identity_container s'exécute avec l'utilisateur root"
  log_info "$identity_container s'exécute avec l'UID $identity_uid"
}

# Le réseau privé fournit une résolution DNS par nom/alias sans publier de port hôte.
docker network create "$network" >/dev/null
# Le backend est lancé en premier. L'alias `backend` correspond à la destination
# déclarée dans le Caddyfile du frontend.
docker run --detach --name "$backend_container" --network "$network" --network-alias backend "$backend_image" >/dev/null
wait_for_healthy "$backend_container"
assert_non_root "$backend_container"

docker run --detach --name "$frontend_container" --network "$network" "$frontend_image" >/dev/null
wait_for_healthy "$frontend_container"
assert_non_root "$frontend_container"

# Cette requête traverse Caddy puis atteint Spring. Elle valide donc à la fois
# le démarrage des images, leur réseau et le routage frontend vers backend.
docker exec "$frontend_container" wget --quiet --output-document=- http://127.0.0.1/api/persons >/dev/null

# Le parcours fonctionnel reste volontairement court : création d'une personne
# dans la base éphémère du test, puis recherche de cette même personne par email.
# L'identifiant unique évite qu'un précédent parcours crée la même adresse.
email="smoke-${suffix}@example.net"
# Les guillemets JSON sont échappés ; seule l'adresse calculée est interpolée.
payload="{\"firstName\":\"Smoke\",\"lastName\":\"Test\",\"email\":\"${email}\"}"
# Le premier appel POST vérifie que l'écriture répond sans erreur HTTP.
docker exec "$frontend_container" wget \
  --quiet \
  --output-document=/dev/null \
  --header='Content-Type: application/json' \
  --post-data="$payload" \
  http://127.0.0.1/api/persons
# Le second appel lit la ressource à travers Caddy. `grep -q` ne réaffiche pas
# la réponse : son code retour prouve seulement que l'email attendu est présent.
docker exec "$frontend_container" wget \
  --quiet \
  --output-document=- \
  "http://127.0.0.1/api/persons/search/findByEmail?email=${email}" \
  | grep -q "$email"

log_info "Smoke test full-stack et parcours create/read réussis"
