#!/usr/bin/env bash
# Point d'entrée des tests applicatifs. Il normalise les commandes utilisées en
# local et par les jobs GitLab, et laisse chaque framework produire ses rapports.

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
  # Le sous-shell limite le changement de dossier au bloc entre parenthèses. Les
  # options imposent un seul passage, des logs allégés, Chrome sans sandbox dans
  # le conteneur et la génération du rapport de couverture.
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
    # Première substitution : uniformise `\` en `/`. Deuxième substitution :
    # transforme `SF:src/...` en `SF:front/src/...` pour SonarQube.
    sed -i -e 's#\\#/#g' -e 's#^SF:src/#SF:front/src/#' "${lcov_report}"
  fi
}

backend_tests() {
  require_file "${REPOSITORY_ROOT}/back/gradlew"
  log_info "Exécution des tests backend"
  # Le Gradle Wrapper fournit la même version de Gradle en local et dans GitLab.
  # prepareSonarAnalysis rassemble ensuite les classes et dependances dont
  # SonarQube a besoin pour analyser correctement le code Java et ses tests.
  # Avec `&&`, la préparation SonarQube ne démarre que si le `cd` réussit.
  (cd "${REPOSITORY_ROOT}/back" && ./gradlew --no-daemon test prepareSonarAnalysis)
}

# Lance uniquement le composant demandé, ou les deux avec --component all.
[[ "$component" == "backend" ]] || frontend_tests
[[ "$component" == "frontend" ]] || backend_tests

log_info "Tests ${component} terminés"
