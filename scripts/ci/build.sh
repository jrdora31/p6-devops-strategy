#!/usr/bin/env bash

set -Eeuo pipefail
# Charge les fonctions partagées de journalisation et de validation.
# shellcheck source=scripts/ci/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

usage() {
  cat <<'EOF'
Usage: build.sh [--component frontend|backend|all]

Construit les artifacts applicatifs sans reconstruire les images.
EOF
}

component="all"

# Sélectionne le frontend, le backend ou les deux.
while (($#)); do
  case "$1" in
    --component)
      (($# >= 2)) || die "Valeur manquante après --component"
      component="$2"
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

validate_component "$component"

frontend_build() {
  require_command npm
  log_info "Construction du frontend"
  # Produit les fichiers statiques Angular optimisés pour un environnement runtime.
  (cd "${REPOSITORY_ROOT}/front" && npm run build -- --configuration production)
}

backend_build() {
  require_file "${REPOSITORY_ROOT}/back/gradlew"
  log_info "Construction du JAR backend"
  # Les tests sont exclus ici car ils sont exécutés séparément par test.sh.
  (cd "${REPOSITORY_ROOT}/back" && ./gradlew --no-daemon bootJar -x test)
}

# Lance uniquement le composant demandé, ou les deux avec --component all.
[[ "$component" == "backend" ]] || frontend_build
[[ "$component" == "frontend" ]] || backend_build

log_info "Build ${component} terminé"
