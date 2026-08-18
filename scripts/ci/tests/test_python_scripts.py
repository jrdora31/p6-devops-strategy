"""Tests des scripts Python de release et de notification.

Les scripts sont lancés comme de vrais programmes plutôt qu'importés. Les tests
couvrent ainsi argparse, les sorties stdout/stderr et les codes retour observés
par GitLab, tout en isolant les écritures dans les dossiers temporaires de pytest.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

# `__file__` est ce fichier ; `parents[1]` remonte de `tests` vers `scripts/ci`.
CI_DIRECTORY = Path(__file__).resolve().parents[1]
RELEASE_SCRIPT = CI_DIRECTORY / "release_manifest.py"
NOTIFY_SCRIPT = CI_DIRECTORY / "notify.py"

# Valeurs factices conformes aux formats attendus. Elles ne pointent vers aucun
# dépôt ou registre réel et peuvent être affichées sans exposer de secret.
COMMIT_SHA = "a" * 40
FRONTEND_IMAGE = f"registry.example/microcrm/frontend@sha256:{'b' * 64}"
BACKEND_IMAGE = f"registry.example/microcrm/backend@sha256:{'c' * 64}"


def run_script(
    script: Path,
    *arguments: str,
    environment: dict[str, str] | None = None,
    working_directory: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    """Exécuter un script comme GitLab et capturer son résultat complet.

    `check=False` est volontaire : plusieurs tests doivent inspecter un échec
    attendu au lieu de laisser `subprocess.run` lever une exception.
    """
    return subprocess.run(
        [sys.executable, str(script), *arguments],
        check=False,
        capture_output=True,
        # Convertit stdout/stderr en chaînes plutôt qu'en octets.
        text=True,
        env=environment,
        cwd=working_directory,
    )


def manifest_arguments(version: str = "v1.2.3") -> list[str]:
    """Construit un jeu d'arguments valide réutilisé dans plusieurs tests."""
    return [
        "--version",
        version,
        "--commit",
        COMMIT_SHA,
        "--pipeline-id",
        "12345",
        "--pipeline-url",
        "https://gitlab.example/pipelines/12345",
        "--frontend-image",
        FRONTEND_IMAGE,
        "--backend-image",
        BACKEND_IMAGE,
    ]


def notification_arguments() -> list[str]:
    """Construit un résultat de pipeline représentatif sans secret."""
    return [
        "--status",
        "success",
        "--event",
        "deployment",
        "--job",
        "deploy:helm:staging",
        "--pipeline-id",
        "12345",
        "--pipeline-url",
        "https://gitlab.example/pipelines/12345",
        "--ref",
        "dev",
        "--commit",
        COMMIT_SHA,
    ]


def test_release_manifest_is_written_and_traceable(tmp_path: Path) -> None:
    """Un jeu valide doit produire le fichier et conserver toutes les identités."""
    # `tmp_path` est propre à ce test et automatiquement nettoyé par pytest.
    output = tmp_path / ".ci" / "release" / "release-manifest.json"

    result = run_script(
        RELEASE_SCRIPT,
        *manifest_arguments(),
        working_directory=tmp_path,
    )

    # Le message stderr est utilisé comme diagnostic si l'assertion échoue.
    assert result.returncode == 0, result.stderr
    manifest = json.loads(output.read_text(encoding="utf-8"))
    assert manifest["version"] == "v1.2.3"
    assert manifest["commit"] == COMMIT_SHA
    assert manifest["images"]["frontend"] == FRONTEND_IMAGE
    assert manifest["images"]["backend"] == BACKEND_IMAGE


def test_release_manifest_rejects_invalid_semver(tmp_path: Path) -> None:
    """Une version non SemVer doit échouer avant toute écriture."""
    output = tmp_path / ".ci" / "release" / "release-manifest.json"

    result = run_script(
        RELEASE_SCRIPT,
        *manifest_arguments(version="release-finale"),
        working_directory=tmp_path,
    )

    assert result.returncode != 0
    assert "SemVer invalide" in result.stderr
    assert not output.exists()


def test_notification_is_only_printed_by_default() -> None:
    """Sans option webhook, le JSON doit être la seule sortie utile."""
    result = run_script(NOTIFY_SCRIPT, *notification_arguments())

    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    assert "Déploiement *success*" in payload["text"]
    assert "deploy:helm:staging" in payload["text"]
    assert "#12345" in payload["text"]
    assert "a" * 8 in payload["text"]


def test_notification_rejects_missing_webhook_variable() -> None:
    """Le nom d'une variable absente doit provoquer un échec explicite."""
    environment = os.environ.copy()
    # Nettoie la copie seulement : l'environnement global du processus de test
    # et celui de la machine ne sont pas modifiés.
    environment.pop("MICROCRM_TEST_WEBHOOK", None)

    result = run_script(
        NOTIFY_SCRIPT,
        *notification_arguments(),
        "--send-webhook-env",
        "MICROCRM_TEST_WEBHOOK",
        environment=environment,
    )

    assert result.returncode != 0
    assert "Variable de webhook absente" in result.stderr


def test_notification_handles_unavailable_service_without_leaking_url() -> None:
    """Une erreur réseau ne doit jamais recopier l'URL secrète dans les logs."""
    environment = os.environ.copy()
    # Le port local 1 est utilisé comme service volontairement indisponible :
    # aucun appel vers Internet ni webhook réel n'est effectué.
    endpoint = "http://127.0.0.1:1/private-webhook"
    environment["MICROCRM_TEST_WEBHOOK"] = endpoint

    result = run_script(
        NOTIFY_SCRIPT,
        *notification_arguments(),
        "--send-webhook-env",
        "MICROCRM_TEST_WEBHOOK",
        environment=environment,
    )

    assert result.returncode != 0
    # La vérification couvre les deux canaux capturés par GitLab.
    assert endpoint not in result.stdout
    assert endpoint not in result.stderr
