#!/usr/bin/env bash
# Vérifie les mécanismes de verrouillage ou installe les dépendances sans changer
# leurs versions. Ce script ne remplace ni package-lock.json ni le Gradle Wrapper.

set -Eeuo pipefail
# Charge les fonctions partagées de journalisation et de validation.
# shellcheck source=scripts/ci/common.sh
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
      # `check` ne télécharge rien volontairement ; `install` prépare un job frontend
      # ou demande à Gradle de résoudre les dépendances backend.
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
# Le groupe entre `[[ ... ]]` n'accepte que les deux actions documentées.
[[ "$action" == "check" || "$action" == "install" ]] ||
  die "Action invalide : $action (valeurs : check, install)"

frontend_dependencies() {
  require_command node
  require_command npm
  # Le lockfile garantit que npm installe les versions déjà validées.
  require_file "${REPOSITORY_ROOT}/front/package-lock.json"

  log_info "Frontend : Node $(node --version), npm $(npm --version)"
  if [[ "$action" == "install" ]]; then
    # Les scripts de cycle de vie npm peuvent exécuter du code provenant d'une
    # dépendance pendant l'installation. MicroCRM n'en a pas besoin pour son build.
    # `npm ci` respecte strictement le lockfile et repart d'une installation propre ;
    # `--prefer-offline` réutilise le cache lorsque possible sans interdire le réseau.
    (cd "${REPOSITORY_ROOT}/front" && npm ci --ignore-scripts --prefer-offline)
  fi
}

backend_dependencies() {
  # Le Gradle Wrapper fixe la version de Gradle utilisée par le projet.
  require_file "${REPOSITORY_ROOT}/back/gradle/wrapper/gradle-wrapper.properties"
  require_file "${REPOSITORY_ROOT}/back/gradlew"

  log_info "Backend : Gradle Wrapper présent"
  if [[ "$action" == "install" ]]; then
    # La tâche `dependencies` force la résolution et affiche l'arbre sans modifier
    # les versions déclarées dans le projet.
    (cd "${REPOSITORY_ROOT}/back" && ./gradlew --no-daemon dependencies)
  fi
}

# Lance uniquement le composant demandé, ou les deux avec --component all.
[[ "$component" == "backend" ]] || frontend_dependencies
[[ "$component" == "frontend" ]] || backend_dependencies

log_info "Dépendances ${component} : action ${action} terminée"
