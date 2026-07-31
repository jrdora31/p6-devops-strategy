#!/usr/bin/env bash

# Arrête le script à la première erreur, sur une variable inconnue ou sur
# l'échec d'une commande située dans un pipeline Bash.
set -Eeuo pipefail

# Calcule les chemins depuis l'emplacement réel du script. Les commandes
# fonctionnent ainsi quel que soit le dossier depuis lequel elles sont lancées.
CI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CI_SCRIPT_DIR

REPOSITORY_ROOT="$(cd "${CI_SCRIPT_DIR}/../.." && pwd)"
# Cette variable est utilisée par les scripts qui chargent ce fichier.
# shellcheck disable=SC2034
readonly REPOSITORY_ROOT

# Affiche des messages homogènes dans le terminal local et dans les logs GitLab.
log_info() {
  printf '[INFO] %s\n' "$*"
}

log_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

die() {
  log_error "$*"
  exit 1
}

# Vérifie qu'un outil indispensable, par exemple npm, est installé avant usage.
require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Commande requise introuvable : $1"
}

# Vérifie qu'un fichier indispensable au projet existe avant de lancer un outil.
require_file() {
  [[ -f "$1" ]] || die "Fichier requis introuvable : $1"
}

# Limite les valeurs acceptées afin d'éviter d'exécuter une commande imprévue.
validate_component() {
  case "$1" in
    frontend | backend | all) ;;
    *) die "Composant invalide : $1 (valeurs : frontend, backend, all)" ;;
  esac
}
