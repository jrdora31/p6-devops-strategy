"""Tests des scripts Python de release et de notification."""

import json
import os
import subprocess
import sys
from pathlib import Path

CI_DIRECTORY = Path(__file__).resolve().parents[1]
RELEASE_SCRIPT = CI_DIRECTORY / "release_manifest.py"
NOTIFY_SCRIPT = CI_DIRECTORY / "notify.py"

COMMIT_SHA = "a" * 40
FRONTEND_IMAGE = f"registry.example/microcrm/frontend@sha256:{'b' * 64}"
BACKEND_IMAGE = f"registry.example/microcrm/backend@sha256:{'c' * 64}"


def run_script(
    script: Path,
    *arguments: str,
    environment: dict[str, str] | None = None,
    working_directory: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    """Exécute un script comme le ferait un job GitLab et capture son résultat."""
    return subprocess.run(
        [sys.executable, str(script), *arguments],
        check=False,
        capture_output=True,
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
    output = tmp_path / ".ci" / "release" / "release-manifest.json"

    result = run_script(
        RELEASE_SCRIPT,
        *manifest_arguments(),
        working_directory=tmp_path,
    )

    assert result.returncode == 0, result.stderr
    manifest = json.loads(output.read_text(encoding="utf-8"))
    assert manifest["version"] == "v1.2.3"
    assert manifest["commit"] == COMMIT_SHA
    assert manifest["images"]["frontend"] == FRONTEND_IMAGE
    assert manifest["images"]["backend"] == BACKEND_IMAGE


def test_release_manifest_rejects_invalid_semver(tmp_path: Path) -> None:
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
    result = run_script(NOTIFY_SCRIPT, *notification_arguments())

    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    assert payload["status"] == "success"
    assert payload["pipeline"]["id"] == "12345"


def test_notification_rejects_missing_webhook_variable() -> None:
    environment = os.environ.copy()
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
    environment = os.environ.copy()
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
    assert endpoint not in result.stdout
    assert endpoint not in result.stderr
