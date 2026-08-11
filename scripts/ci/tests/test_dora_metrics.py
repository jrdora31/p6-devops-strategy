"""Tests hors ligne du calcul et des exports DORA."""

import importlib.util
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

CI_DIRECTORY = Path(__file__).resolve().parents[1]
DORA_SCRIPT = CI_DIRECTORY / "dora_metrics.py"
SPEC = importlib.util.spec_from_file_location("dora_metrics", DORA_SCRIPT)
assert SPEC is not None
assert SPEC.loader is not None
dora_metrics = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(dora_metrics)


def fixture() -> dict:
    return {
        "deployments": [
            {"id": 10, "status": "success", "finished_at": "2026-08-02T12:00:00Z"},
            {"id": 11, "status": "failed", "finished_at": "2026-08-03T12:00:00Z"},
            {"id": 12, "status": "success", "finished_at": "2026-08-06T12:00:00Z"},
        ],
        "deployment_merge_requests": {
            "10": [{"id": 100, "merged_at": "2026-08-01T12:00:00Z"}],
            "12": [{"id": 101, "merged_at": "2026-08-06T06:00:00Z"}],
        },
        "incidents": [
            {
                "id": 200,
                "created_at": "2026-08-06T13:00:00Z",
                "closed_at": "2026-08-06T15:00:00Z",
                "description": "DORA_DEPLOYMENT_ID: 12",
            }
        ],
    }


def test_calculates_only_successful_deployments_and_linked_incidents() -> None:
    report = dora_metrics.calculate_metrics(
        fixture(),
        "aws-poc-staging",
        datetime(2026, 8, 1, tzinfo=timezone.utc),
        datetime(2026, 8, 11, tzinfo=timezone.utc),
        datetime(2026, 8, 1, tzinfo=timezone.utc),
    )

    assert report["metrics"]["deployment_frequency"]["successful_deployments"] == 2
    assert report["metrics"]["deployment_frequency"]["value"] == 1.4
    assert report["metrics"]["lead_time_for_changes"]["value"] == 54000
    assert report["metrics"]["change_failure_rate"]["value"] == 50
    assert report["metrics"]["time_to_restore_service"]["value"] == 7200


def test_reports_missing_incident_history_without_inventing_mttr() -> None:
    source = fixture()
    source["incidents"] = []
    report = dora_metrics.calculate_metrics(
        source,
        "aws-poc-staging",
        datetime(2026, 8, 1, tzinfo=timezone.utc),
        datetime(2026, 8, 11, tzinfo=timezone.utc),
        datetime(2026, 8, 11, tzinfo=timezone.utc),
    )

    assert report["metrics"]["change_failure_rate"]["status"] == "not_calculable"
    assert report["metrics"]["time_to_restore_service"]["value"] is None


def test_cli_writes_html_json_and_csv(tmp_path: Path) -> None:
    fixture_path = tmp_path / "fixture.json"
    output = tmp_path / "public"
    fixture_path.write_text(json.dumps(fixture()), encoding="utf-8")

    result = subprocess.run(
        [
            sys.executable,
            str(DORA_SCRIPT),
            "--fixture",
            str(fixture_path),
            "--output",
            str(output),
            "--days",
            "10",
            "--now",
            "2026-08-11T00:00:00Z",
            "--incident-tracking-start",
            "2026-08-01T00:00:00Z",
        ],
        check=False,
        capture_output=True,
        text=True,
        cwd=tmp_path,
    )

    assert result.returncode == 0, result.stderr
    assert (output / "index.html").is_file()
    assert (output / "dora-metrics.json").is_file()
    assert (output / "dora-metrics.csv").is_file()
    assert "staging" in (output / "index.html").read_text(encoding="utf-8")


def test_safe_path_rejects_path_outside_working_directory(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.chdir(tmp_path)

    outside_path = tmp_path.parent / "outside.json"

    try:
        dora_metrics.safe_path(outside_path)
    except ValueError as error:
        assert "hors du répertoire autorisé" in str(error)
    else:
        raise AssertionError("Un chemin extérieur au répertoire de travail doit être refusé")
