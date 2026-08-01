#!/usr/bin/env bash
# Le shebang demande à `env` de trouver Bash dans le PATH. Le même fichier peut
# ainsi être lancé sur différents systèmes sans coder `/bin/bash` en dur.

# Arrête le script à la première erreur, sur une variable inconnue ou sur
# l'échec d'une commande située dans un pipeline Bash :
# - `-E` propage les futurs traps ERR dans les fonctions et sous-shells ;
# - `-e` arrête l'exécution après une commande en échec ;
# - `-u` refuse une variable non définie ;
# - `pipefail` fait remonter l'échec de n'importe quelle commande d'un pipeline.
set -Eeuo pipefail

# Calcule les chemins depuis l'emplacement réel du script. Les commandes
# fonctionnent ainsi quel que soit le dossier depuis lequel elles sont lancées.
# `${BASH_SOURCE[0]}` désigne ce fichier même lorsqu'il est chargé avec `source` ;
# `dirname` en extrait le dossier et `pwd` le transforme en chemin absolu.
CI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# `readonly` empêche une réaffectation accidentelle plus loin dans un script.
readonly CI_SCRIPT_DIR

# Deux remontées (`../..`) conduisent de `scripts/ci` à la racine de MicroCRM.
REPOSITORY_ROOT="$(cd "${CI_SCRIPT_DIR}/../.." && pwd)"
# Cette variable est utilisée par les scripts qui chargent ce fichier.
# shellcheck disable=SC2034
readonly REPOSITORY_ROOT

# Affiche des messages homogènes dans le terminal local et dans les logs GitLab.
log_info() {
  # `$*` rassemble tous les arguments dans un message ; `%s` évite que leur
  # contenu soit interprété comme une directive de formatage par `printf`.
  printf '[INFO] %s\n' "$*"
}

log_error() {
  # `>&2` réserve la sortie standard à un éventuel résultat exploitable et envoie
  # les diagnostics sur stderr, comme le font les outils Unix classiques.
  printf '[ERROR] %s\n' "$*" >&2
}

die() {
  # Centralise le contrat d'erreur : message explicite puis code retour non nul.
  log_error "$*"
  exit 1
}

# Vérifie qu'un outil indispensable, par exemple npm, est installé avant usage.
require_command() {
  # `command -v` cherche sans exécuter. Ses sorties sont masquées car seul son
  # code retour nous intéresse ; `||` appelle `die` si la recherche échoue.
  command -v "$1" >/dev/null 2>&1 || die "Commande requise introuvable : $1"
}

# Vérifie qu'un fichier indispensable au projet existe avant de lancer un outil.
require_file() {
  [[ -f "$1" ]] || die "Fichier requis introuvable : $1"
}

# Limite les valeurs acceptées afin d'éviter d'exécuter une commande imprévue.
validate_component() {
  # Le premier argument de la fonction devient `$1`. Les trois valeurs valides
  # ne font rien (`;;`) ; toute autre valeur passe dans le cas générique `*`.
  case "$1" in
    frontend | backend | all) ;;
    *) die "Composant invalide : $1 (valeurs : frontend, backend, all)" ;;
  esac
}
