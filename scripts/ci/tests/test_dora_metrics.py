"""Tests hors ligne du calcul et des exports DORA comparatifs."""

import csv
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

ENVIRONMENTS = {
    "staging": "aws-poc-staging",
    "production": "aws-poc-production",
}
START = datetime(2026, 8, 1, tzinfo=timezone.utc)
END = datetime(2026, 8, 11, tzinfo=timezone.utc)


def fixture() -> dict:
    return {
        "environments": {
            "aws-poc-staging": {
                "deployments": [
                    {
                        "id": 1010,
                        "iid": 10,
                        "status": "success",
                        "finished_at": "2026-08-02T12:00:00Z",
                    },
                    {
                        "id": 1011,
                        "iid": 11,
                        "status": "failed",
                        "finished_at": "2026-08-03T12:00:00Z",
                    },
                    {
                        "id": 1012,
                        "iid": 12,
                        "status": "success",
                        "finished_at": "2026-08-06T12:00:00Z",
                    },
                ],
                "deployment_merge_requests": {
                    "1010": [{"id": 100, "merged_at": "2026-08-01T12:00:00Z"}],
                    "1012": [{"id": 101, "merged_at": "2026-08-06T06:00:00Z"}],
                },
            },
            "aws-poc-production": {
                "deployments": [
                    {
                        "id": 1020,
                        "iid": 20,
                        "status": "success",
                        "finished_at": "2026-08-04T12:00:00Z",
                    }
                ],
                "deployment_merge_requests": {
                    "1020": [{"id": 200, "merged_at": "2026-08-02T12:00:00Z"}]
                },
            },
        },
        "incidents": [
            {
                "id": 300,
                "created_at": "2026-08-06T13:00:00Z",
                "closed_at": "2026-08-06T15:00:00Z",
                "description": "DORA_DEPLOYMENT_ID: 12",
            }
        ],
    }


def calculate(source: dict | None = None) -> dict:
    return dora_metrics.calculate_report(
        source or fixture(),
        ENVIRONMENTS,
        START,
        END,
        START,
    )


def test_collects_each_environment_and_fetches_incidents_once() -> None:
    class FakeClient:
        def __init__(self) -> None:
            self.calls: list[tuple[str, dict[str, str]]] = []

        def get_all(
            self, endpoint: str, parameters: dict[str, str]
        ) -> list[dict]:
            self.calls.append((endpoint, parameters))
            return []

    client = FakeClient()
    source = dora_metrics.collect_gitlab_data(client, ENVIRONMENTS, START)

    deployment_environments = {
        parameters["environment"]
        for endpoint, parameters in client.calls
        if endpoint == "deployments"
    }
    assert deployment_environments == {
        "aws-poc-staging",
        "aws-poc-production",
    }
    assert sum(endpoint == "issues" for endpoint, _ in client.calls) == 1
    assert set(source["environments"]) == {
        "aws-poc-staging",
        "aws-poc-production",
    }


def test_calculates_staging_and_production_with_shared_logic() -> None:
    report = calculate()
    staging = report["environments"]["staging"]["metrics"]
    production = report["environments"]["production"]["metrics"]

    assert report["schema_version"] == 2
    assert staging["deployment_frequency"]["successful_deployments"] == 2
    assert staging["deployment_frequency"]["value"] == 1.4
    assert staging["lead_time_for_changes"]["value"] == 54000
    assert staging["change_failure_rate"]["value"] == 50
    assert staging["time_to_restore_service"]["value"] == 7200

    assert production["deployment_frequency"]["successful_deployments"] == 1
    assert production["deployment_frequency"]["value"] == 0.7
    assert production["lead_time_for_changes"]["value"] == 172800
    assert production["change_failure_rate"]["value"] == 0


def test_environment_without_incident_has_na_mttr() -> None:
    report = calculate()
    production_mttr = report["environments"]["production"]["metrics"][
        "time_to_restore_service"
    ]

    assert production_mttr["value"] is None
    assert production_mttr["sample_size"] == 0
    assert production_mttr["status"] == "not_calculable"
    assert dora_metrics.display_value(production_mttr) == "N/A"


def test_environment_without_deployment_has_no_zero_metric() -> None:
    source = fixture()
    source["environments"]["aws-poc-production"] = {
        "deployments": [],
        "deployment_merge_requests": {},
    }
    metrics = calculate(source)["environments"]["production"]["metrics"]

    assert all(metric["value"] is None for metric in metrics.values())
    assert all(metric["sample_size"] == 0 for metric in metrics.values())
    assert metrics["deployment_frequency"]["status"] == "not_calculable"
    assert metrics["change_failure_rate"]["status"] == "not_calculable"


def test_incidents_never_contaminate_the_other_environment_mttr() -> None:
    source = fixture()
    source["incidents"].append(
        {
            "id": 301,
            "created_at": "2026-08-07T08:00:00Z",
            "closed_at": "2026-08-07T14:00:00Z",
            "description": "DORA_DEPLOYMENT_ID: 20",
        }
    )
    report = calculate(source)

    staging = report["environments"]["staging"]["metrics"]
    production = report["environments"]["production"]["metrics"]
    assert staging["time_to_restore_service"]["value"] == 7200
    assert staging["time_to_restore_service"]["sample_size"] == 1
    assert production["time_to_restore_service"]["value"] == 21600
    assert production["time_to_restore_service"]["sample_size"] == 1
    assert staging["change_failure_rate"]["value"] == 50
    assert production["change_failure_rate"]["value"] == 100


def test_cli_writes_comparative_html_json_and_csv(tmp_path: Path) -> None:
    fixture_path = tmp_path / "fixture.json"
    output = tmp_path / "public"
    fixture_path.write_text(json.dumps(fixture()), encoding="utf-8")

    result = subprocess.run(
        [
            sys.executable,
            str(DORA_SCRIPT),
            "--fixture",
            str(fixture_path),
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
    html_output = (output / "index.html").read_text(encoding="utf-8")
    json_output = json.loads((output / "dora-metrics.json").read_text(encoding="utf-8"))
    with (output / "dora-metrics.csv").open(encoding="utf-8", newline="") as stream:
        csv_rows = list(csv.DictReader(stream))

    assert "STAGING" in html_output
    assert "PRODUCTION" in html_output
    assert html_output.count('class="metric"') == 4
    assert 'class="dashboard"' in html_output
    assert "Périmètre" not in html_output
    assert "<th>Note</th>" not in html_output
    assert "Mesure calculée" not in html_output
    assert "N/A" in html_output
    assert set(json_output["environments"]) == {"staging", "production"}
    assert len(csv_rows) == 8
    assert {row["environment"] for row in csv_rows} == {"staging", "production"}
    assert any(row["display_value"] == "N/A" for row in csv_rows)


def test_safe_path_rejects_path_outside_working_directory(
    tmp_path: Path, monkeypatch
) -> None:
    monkeypatch.chdir(tmp_path)
    outside_path = tmp_path.parent / "outside.json"

    try:
        dora_metrics.safe_path(outside_path)
    except ValueError as error:
        assert "hors du répertoire autorisé" in str(error)
    else:
        raise AssertionError(
            "Un chemin extérieur au répertoire de travail doit être refusé"
        )
