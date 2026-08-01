#!/usr/bin/env bash

# Tests fonctionnels légers des interfaces Bash.
# Ils vérifient les garde-fous sans relancer les tests Angular ou Spring,
# déjà couverts par leurs jobs GitLab respectifs.

set -Eeuo pipefail

TEST_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIRECTORY
REPOSITORY_ROOT="$(cd "${TEST_DIRECTORY}/../../.." && pwd)"
readonly REPOSITORY_ROOT
TEMP_DIRECTORY="$(mktemp -d)"
readonly TEMP_DIRECTORY

passed=0
failed=0

cleanup() {
  rm -rf -- "${TEMP_DIRECTORY}"
}
trap cleanup EXIT

assert_success() {
  local description="$1"
  shift

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

  if "$@" >"${TEMP_DIRECTORY}/command.log" 2>&1; then
    printf '[FAIL] %s — la commande aurait dû échouer\n' "${description}" >&2
    failed=$((failed + 1))
  else
    printf '[PASS] %s\n' "${description}"
    passed=$((passed + 1))
  fi
}

mkdir -p "${TEMP_DIRECTORY}/source"

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
  "Contrôle des dépendances verrouillées" \
  bash "${REPOSITORY_ROOT}/scripts/ci/dependencies.sh" \
  --component all --action check

assert_success \
  "Simulation de backup sans écriture" \
  bash "${REPOSITORY_ROOT}/scripts/ci/backup.sh" \
  --source "${TEMP_DIRECTORY}/source" \
  --output "${TEMP_DIRECTORY}/backup.tar" \
  --dry-run

assert_failure \
  "Refus d'un composant inconnu" \
  bash "${REPOSITORY_ROOT}/scripts/ci/test.sh" --component invalid

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
[[ "${failed}" -eq 0 ]]
