#!/usr/bin/env bash

set -Eeuo pipefail
# Charge les fonctions partagées de journalisation et de validation.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

usage() {
  cat <<'EOF'
Usage: dependencies.sh [--component frontend|backend|all] [--action check|install]

Vérifie ou résout les dépendances à partir des fichiers versionnés.
La commande ne met jamais les versions à jour.
EOF
}

component="all"
action="check"

# Lit les options fournies après le nom du script.
while (($#)); do
  case "$1" in
    --component)
      (($# >= 2)) || die "Valeur manquante après --component"
      component="$2"
      shift 2
      ;;
    --action)
      (($# >= 2)) || die "Valeur manquante après --action"
      action="$2"
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
[[ "$action" == "check" || "$action" == "install" ]] ||
  die "Action invalide : $action (valeurs : check, install)"

frontend_dependencies() {
  require_command npm
  # Le lockfile garantit que npm installe les versions déjà validées.
  [[ -f "${REPOSITORY_ROOT}/front/package-lock.json" ]] ||
    die "Lockfile frontend introuvable"

  log_info "Frontend : Node $(node --version), npm $(npm --version)"
  if [[ "$action" == "install" ]]; then
    (cd "${REPOSITORY_ROOT}/front" && npm ci --prefer-offline)
  fi
}

backend_dependencies() {
  # Le Gradle Wrapper fixe la version de Gradle utilisée par le projet.
  [[ -f "${REPOSITORY_ROOT}/back/gradle/wrapper/gradle-wrapper.properties" ]] ||
    die "Gradle Wrapper backend introuvable"

  log_info "Backend : Gradle Wrapper présent"
  if [[ "$action" == "install" ]]; then
    (cd "${REPOSITORY_ROOT}/back" && ./gradlew --no-daemon dependencies)
  fi
}

# Lance uniquement le composant demandé, ou les deux avec --component all.
[[ "$component" == "backend" ]] || frontend_dependencies
[[ "$component" == "frontend" ]] || backend_dependencies

log_info "Dépendances ${component} : action ${action} terminée"
