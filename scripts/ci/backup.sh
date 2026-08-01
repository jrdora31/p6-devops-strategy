#!/usr/bin/env bash
# Contrat de sauvegarde de la partie 1 : ce fichier valide les paramètres, mais
# n'écrit volontairement aucune archive tant que le stockage P2 n'est pas défini.

set -Eeuo pipefail
# Charge les fonctions partagées de journalisation et de validation.
# shellcheck source=scripts/ci/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

usage() {
  # Le here-document transmet littéralement le texte compris entre les deux `EOF`.
  # Les quotes de `'EOF'` empêchent toute expansion de variable dans l'aide.
  cat <<'EOF'
Usage: backup.sh --source PATH --output PATH --dry-run

Valide le contrat de backup sans écrire de sauvegarde.
L'exécution réelle sera ajoutée avec le stockage persistant en partie 2.
EOF
}

# Valeurs neutres avant l'analyse de la ligne de commande. Elles permettent de
# détecter proprement une option obligatoire absente.
source_path=""
output_path=""
dry_run="false"

# Lit les chemins à valider et l'option de simulation.
while (($#)); do
  # `$#` est le nombre d'arguments restants ; `$1` est l'argument courant.
  case "$1" in
    --source)
      # Il faut au moins deux éléments : l'option et sa valeur. `shift 2` les
      # retire ensuite pour passer à l'option suivante.
      (($# >= 2)) || die "Valeur manquante après --source"
      source_path="$2"
      shift 2
      ;;
    --output)
      (($# >= 2)) || die "Valeur manquante après --output"
      output_path="$2"
      shift 2
      ;;
    --dry-run)
      # Cette option est un drapeau : elle n'attend aucune valeur supplémentaire.
      dry_run="true"
      shift
      ;;
    --help | -h)
      usage
      exit 0
      ;;
    *)
      # Refuser l'inconnu évite d'ignorer silencieusement une faute de frappe.
      die "Argument inconnu : $1"
      ;;
  esac
done

# Refuse les chemins absents ou identiques avant toute future opération d'écriture.
# `[[ -n ... ]]` teste une chaîne non vide. Les quotes protègent les espaces.
[[ -n "$source_path" ]] || die "--source est obligatoire"
[[ -n "$output_path" ]] || die "--output est obligatoire"
[[ "$source_path" != "$output_path" ]] || die "La source et la sortie doivent être différentes"

# En partie 1, ce script valide seulement l'interface prévue. Il ne crée aucune
# archive et ne modifie aucune donnée tant que le stockage P2 n'est pas défini.
# La comparaison stricte rend le mode sûr explicite : oublier `--dry-run` échoue.
[[ "$dry_run" == "true" ]] ||
  die "Le backup réel n'est pas disponible en partie 1 ; utiliser --dry-run"

log_info "Dry-run backup : ${source_path} → ${output_path}"
