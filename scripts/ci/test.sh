#!/usr/bin/env bash

set -Eeuo pipefail
# Charge les fonctions partagées de journalisation et de validation.
# shellcheck source=scripts/ci/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

usage() {
  cat <<'EOF'
Usage: test.sh [--component frontend|backend|all]

Exécute les tests sans mode interactif et retourne un code non nul en cas d'échec.
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

frontend_tests() {
  require_command npm
  require_command sed
  log_info "Exécution des tests frontend"
  # Le mode headless permet d'exécuter Angular sans fenêtre graphique dans la CI.
  (
    cd "${REPOSITORY_ROOT}/front"
    npm test -- \
      --no-watch \
      --no-progress \
      --browsers=ChromeHeadlessNoSandbox \
      --code-coverage
  )

  # Karma écrit des chemins relatifs au dossier front. Le scanner SonarQube
  # s'exécute depuis la racine du repository et attend donc le préfixe front/.
  local lcov_report="${REPOSITORY_ROOT}/front/coverage/microcrm/lcov.info"
  if [[ -f "${lcov_report}" ]]; then
    sed -i -e 's#\\#/#g' -e 's#^SF:src/#SF:front/src/#' "${lcov_report}"
  fi
}

backend_tests() {
  require_file "${REPOSITORY_ROOT}/back/gradlew"
  log_info "Exécution des tests backend"
  # Le Gradle Wrapper fournit la même version de Gradle en local et dans GitLab.
  (cd "${REPOSITORY_ROOT}/back" && ./gradlew --no-daemon test)
}

# Lance uniquement le composant demandé, ou les deux avec --component all.
[[ "$component" == "backend" ]] || frontend_tests
[[ "$component" == "frontend" ]] || backend_tests

log_info "Tests ${component} terminés"
