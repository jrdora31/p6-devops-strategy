#!/usr/bin/env bash

# Tests fonctionnels légers des interfaces Bash.
# Ils vérifient les garde-fous sans relancer les tests Angular ou Spring,
# déjà couverts par leurs jobs GitLab respectifs.

set -Eeuo pipefail

# Résout les chemins depuis ce fichier de test plutôt que depuis le terminal.
TEST_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIRECTORY
# Trois remontées conduisent de `scripts/ci/tests` à la racine MicroCRM.
REPOSITORY_ROOT="$(cd "${TEST_DIRECTORY}/../../.." && pwd)"
readonly REPOSITORY_ROOT
# `mktemp -d` crée un dossier unique : les tests parallèles ne partagent ni logs
# ni fausses données de sauvegarde.
TEMP_DIRECTORY="$(mktemp -d)"
readonly TEMP_DIRECTORY

# Compteurs du mini-runner de tests, sans dépendance à un framework Bash externe.
passed=0
failed=0

cleanup() {
  # La cible vient exclusivement de `mktemp -d` ci-dessus. `--` empêche qu'un
  # chemin commençant par un tiret soit pris pour une option de `rm`.
  rm -rf -- "${TEMP_DIRECTORY}"
}
# Même si une assertion échoue, le dossier temporaire est supprimé à la sortie.
trap cleanup EXIT

assert_success() {
  # Le premier argument décrit le scénario ; `shift` laisse dans `$@` la commande
  # complète à exécuter avec ses arguments intacts.
  local description="$1"
  shift

  # stdout et stderr sont capturés. En cas d'échec inattendu, le log est affiché.
  if "$@" >"${TEMP_DIRECTORY}/command.log" 2>&1; then
    printf '[PASS] %s\n' "${description}"
    passed=$((passed + 1))
  else
    printf '[FAIL] %s\n' "${description}" >&2
    cat "${TEMP_DIRECTORY}/command.log" >&2
    failed=$((failed + 1))
  fi
}

assert_failure() {
  local description="$1"
  shift

  # Ici la logique est inversée : un code 0 signifie que le garde-fou testé n'a
  # pas refusé l'entrée invalide, donc que le test doit échouer.
  if "$@" >"${TEMP_DIRECTORY}/command.log" 2>&1; then
    printf '[FAIL] %s — la commande aurait dû échouer\n' "${description}" >&2
    failed=$((failed + 1))
  else
    printf '[PASS] %s\n' "${description}"
    passed=$((passed + 1))
  fi
}

mkdir -p "${TEMP_DIRECTORY}/source"
mkdir -p "${TEMP_DIRECTORY}/mock-bin"

# Les doublures suivantes valident le parcours nominal du script Kubernetes
# sans exiger un cluster pendant les tests unitaires du dépôt.
cat >"${TEMP_DIRECTORY}/mock-bin/kubectl" <<'EOF'
#!/bin/sh
case "$*" in
  *"get pvc/"*)
    printf 'Bound'
    ;;
  *"get ingress/"*)
    printf 'microcrm.example.invalid'
    ;;
  *"port-forward"*)
    while :; do sleep 1; done
    ;;
esac
EOF
cat >"${TEMP_DIRECTORY}/mock-bin/curl" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "${TEMP_DIRECTORY}/mock-bin/kubectl" "${TEMP_DIRECTORY}/mock-bin/curl"

# Les premiers scénarios prouvent que les interfaces documentées répondent et
# qu'un dry-run de backup reste sans écriture réelle.
assert_success \
  "Aide du script de tests" \
  bash "${REPOSITORY_ROOT}/scripts/ci/test.sh" --help

assert_success \
  "Aide du script de build" \
  bash "${REPOSITORY_ROOT}/scripts/ci/build.sh" --help

assert_success \
  "Aide du script de smoke test" \
  bash "${REPOSITORY_ROOT}/scripts/ci/smoke.sh" --help

assert_success \
  "Aide du script de vérification Kubernetes" \
  sh "${REPOSITORY_ROOT}/scripts/ci/verify_kubernetes.sh" --help

assert_success \
  "Vérification Kubernetes nominale avec commandes simulées" \
  env PATH="${TEMP_DIRECTORY}/mock-bin:${PATH}" \
  sh "${REPOSITORY_ROOT}/scripts/ci/verify_kubernetes.sh" \
  --context test-context

assert_success \
  "Contrôle des dépendances verrouillées" \
  bash "${REPOSITORY_ROOT}/scripts/ci/dependencies.sh" \
  --component all --action check

assert_success \
  "Simulation de backup sans écriture" \
  bash "${REPOSITORY_ROOT}/scripts/ci/backup.sh" \
  --source "${TEMP_DIRECTORY}/source" \
  --output "${TEMP_DIRECTORY}/backup.tar" \
  --dry-run

# Les scénarios suivants injectent volontairement des paramètres invalides. Le
# test réussit uniquement si le script métier retourne un code non nul.
assert_failure \
  "Refus d'un composant inconnu" \
  bash "${REPOSITORY_ROOT}/scripts/ci/test.sh" --component invalid

assert_failure \
  "Refus d'une vérification Kubernetes sans contexte" \
  sh "${REPOSITORY_ROOT}/scripts/ci/verify_kubernetes.sh"

assert_failure \
  "Refus d'un backup sans dry-run" \
  bash "${REPOSITORY_ROOT}/scripts/ci/backup.sh" \
  --source "${TEMP_DIRECTORY}/source" \
  --output "${TEMP_DIRECTORY}/backup.tar"

assert_failure \
  "Refus d'une source identique à la sortie" \
  bash "${REPOSITORY_ROOT}/scripts/ci/backup.sh" \
  --source "${TEMP_DIRECTORY}/source" \
  --output "${TEMP_DIRECTORY}/source" \
  --dry-run

printf '\nRésultat : %d test(s) réussi(s), %d échec(s)\n' "${passed}" "${failed}"
# Cette dernière expression devient le code retour global du fichier de test.
[[ "${failed}" -eq 0 ]]
