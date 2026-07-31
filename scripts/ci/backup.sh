#!/usr/bin/env bash

set -Eeuo pipefail
# Charge les fonctions partagées de journalisation et de validation.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

usage() {
  cat <<'EOF'
Usage: backup.sh --source PATH --output PATH --dry-run

Valide le contrat de backup sans écrire de sauvegarde.
L'exécution réelle sera ajoutée avec le stockage persistant en partie 2.
EOF
}

source_path=""
output_path=""
dry_run="false"

# Lit les chemins à valider et l'option de simulation.
while (($#)); do
  case "$1" in
    --source)
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
      dry_run="true"
      shift
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

# Refuse les chemins absents ou identiques avant toute future opération d'écriture.
[[ -n "$source_path" ]] || die "--source est obligatoire"
[[ -n "$output_path" ]] || die "--output est obligatoire"
[[ "$source_path" != "$output_path" ]] || die "La source et la sortie doivent être différentes"

# En partie 1, ce script valide seulement l'interface prévue. Il ne crée aucune
# archive et ne modifie aucune donnée tant que le stockage P2 n'est pas défini.
[[ "$dry_run" == "true" ]] ||
  die "Le backup réel n'est pas disponible en partie 1 ; utiliser --dry-run"

log_info "Dry-run backup : ${source_path} → ${output_path}"
