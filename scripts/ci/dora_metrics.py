#!/usr/bin/env python3
"""Calcule les quatre métriques DORA depuis l'historique GitLab du projet."""

from __future__ import annotations

import argparse
import csv
import html
import json
import os
import re
import statistics
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

INCIDENT_DEPLOYMENT_PATTERN = re.compile(
    r"^DORA_DEPLOYMENT_ID:\s*(\d+)\s*$", re.IGNORECASE | re.MULTILINE
)


def parse_timestamp(value: str | None) -> datetime | None:
    """Convertit un horodatage ISO 8601 GitLab en datetime UTC."""
    if not value:
        return None
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def isoformat(value: datetime) -> str:
    """Produit un horodatage UTC stable pour les rapports."""
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


class GitLabClient:
    """Client REST minimal avec pagination et sans dépendance externe."""

    def __init__(self, api_url: str, project_id: str, token: str) -> None:
        self.api_url = api_url.rstrip("/")
        self.project_id = urllib.parse.quote(project_id, safe="")
        self.token = token

    def get_all(self, endpoint: str, parameters: dict[str, str]) -> list[dict[str, Any]]:
        page = "1"
        results: list[dict[str, Any]] = []
        while page:
            query = urllib.parse.urlencode({**parameters, "per_page": "100", "page": page})
            url = f"{self.api_url}/projects/{self.project_id}/{endpoint}?{query}"
            request = urllib.request.Request(
                url,
                headers={"PRIVATE-TOKEN": self.token, "Accept": "application/json"},
            )
            try:
                with urllib.request.urlopen(request, timeout=30) as response:
                    payload = json.load(response)
                    page = response.headers.get("X-Next-Page", "")
            except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
                raise RuntimeError(f"Échec de lecture de l'API GitLab ({endpoint})") from error
            if not isinstance(payload, list):
                raise RuntimeError(f"Réponse GitLab inattendue ({endpoint})")
            results.extend(payload)
        return results


def deployment_finished_at(deployment: dict[str, Any]) -> datetime | None:
    """Retourne la date de fin utile, avec repli compatible API GitLab."""
    deployable = deployment.get("deployable") or {}
    return parse_timestamp(
        deployment.get("finished_at")
        or deployable.get("finished_at")
        or deployment.get("updated_at")
    )


def collect_gitlab_data(
    client: GitLabClient, environment: str, start: datetime
) -> dict[str, Any]:
    """Collecte les sources brutes nécessaires aux calculs."""
    deployments = client.get_all(
        "deployments",
        {
            "environment": environment,
            "status": "success",
            "finished_after": isoformat(start),
            "order_by": "finished_at",
            "sort": "asc",
        },
    )
    deployment_merge_requests: dict[str, list[dict[str, Any]]] = {}
    for deployment in deployments:
        if deployment.get("status") != "success":
            continue
        deployment_id = str(deployment["id"])
        deployment_merge_requests[deployment_id] = client.get_all(
            f"deployments/{deployment_id}/merge_requests", {}
        )

    incidents = client.get_all(
        "issues",
        {
            "issue_type": "incident",
            "labels": "dora",
            "scope": "all",
            "created_after": isoformat(start),
            "order_by": "created_at",
            "sort": "asc",
        },
    )
    return {
        "deployments": deployments,
        "deployment_merge_requests": deployment_merge_requests,
        "incidents": incidents,
    }


def calculate_metrics(
    source: dict[str, Any],
    environment: str,
    start: datetime,
    end: datetime,
    incident_tracking_start: datetime,
) -> dict[str, Any]:
    """Calcule les métriques selon les conventions documentées du projet."""
    deployments = source.get("deployments", [])
    successful = [
        deployment
        for deployment in deployments
        if deployment.get("status") == "success"
        and (finished := deployment_finished_at(deployment)) is not None
        and start <= finished <= end
    ]
    successful.sort(key=lambda item: deployment_finished_at(item) or start)

    period_days = max((end - start).total_seconds() / 86400, 1)
    frequency_per_week = len(successful) * 7 / period_days

    first_delivery_by_mr: dict[str, tuple[datetime, datetime]] = {}
    merge_requests = source.get("deployment_merge_requests", {})
    for deployment in successful:
        finished = deployment_finished_at(deployment)
        if finished is None:
            continue
        for merge_request in merge_requests.get(str(deployment["id"]), []):
            merged = parse_timestamp(merge_request.get("merged_at"))
            if merged is None or merged > finished:
                continue
            key = str(merge_request.get("id") or merge_request.get("iid"))
            previous = first_delivery_by_mr.get(key)
            if previous is None or finished < previous[1]:
                first_delivery_by_mr[key] = (merged, finished)
    lead_samples = [
        (finished - merged).total_seconds()
        for merged, finished in first_delivery_by_mr.values()
    ]

    stability_start = max(start, incident_tracking_start)
    stability_deployments = [
        deployment
        for deployment in successful
        if (deployment_finished_at(deployment) or start) >= stability_start
    ]
    stability_ids = {int(deployment["id"]) for deployment in stability_deployments}
    incidents = []
    for incident in source.get("incidents", []):
        created = parse_timestamp(incident.get("created_at"))
        if created is None or not stability_start <= created <= end:
            continue
        match = INCIDENT_DEPLOYMENT_PATTERN.search(incident.get("description") or "")
        deployment_id = int(match.group(1)) if match else None
        incidents.append({**incident, "dora_deployment_id": deployment_id})

    failed_change_ids = {
        incident["dora_deployment_id"]
        for incident in incidents
        if incident["dora_deployment_id"] in stability_ids
    }
    change_failure_rate = (
        len(failed_change_ids) / len(stability_deployments) * 100
        if stability_deployments
        else None
    )
    restore_samples = []
    for incident in incidents:
        created = parse_timestamp(incident.get("created_at"))
        closed = parse_timestamp(incident.get("closed_at"))
        if created is not None and closed is not None and closed >= created:
            restore_samples.append((closed - created).total_seconds())

    return {
        "schema_version": 1,
        "generated_at": isoformat(end),
        "scope": {
            "environment": environment,
            "environment_kind": "staging_poc_proxy",
            "period_start": isoformat(start),
            "period_end": isoformat(end),
            "incident_tracking_start": isoformat(incident_tracking_start),
            "warning": (
                "Mesures du POC sur staging ; elles ne représentent pas "
                "un historique de production réel."
            ),
        },
        "metrics": {
            "deployment_frequency": {
                "value": round(frequency_per_week, 2),
                "unit": "successful_deployments_per_week",
                "successful_deployments": len(successful),
                "sample_size": len(successful),
                "status": "measured",
            },
            "lead_time_for_changes": {
                "value": round(statistics.median(lead_samples), 2) if lead_samples else None,
                "unit": "seconds",
                "sample_size": len(lead_samples),
                "status": "measured" if lead_samples else "not_calculable",
                "limit": None if lead_samples else "Aucune MR fusionnée reliée aux déploiements.",
            },
            "change_failure_rate": {
                "value": round(change_failure_rate, 2) if change_failure_rate is not None else None,
                "unit": "percent",
                "failed_deployments": len(failed_change_ids),
                "deployment_denominator": len(stability_deployments),
                "sample_size": len(stability_deployments),
                "status": "measured" if change_failure_rate is not None else "not_calculable",
                "limit": (
                    None
                    if change_failure_rate is not None
                    else "Aucun déploiement réussi depuis le début du suivi des incidents."
                ),
            },
            "time_to_restore_service": {
                "value": round(statistics.median(restore_samples), 2) if restore_samples else None,
                "unit": "seconds",
                "sample_size": len(restore_samples),
                "status": "measured" if restore_samples else "not_calculable",
                "limit": None if restore_samples else "Aucun incident clôturé sur la période suivie.",
            },
        },
        "quality": {
            "incidents_total": len(incidents),
            "incidents_without_deployment_id": sum(
                incident["dora_deployment_id"] is None for incident in incidents
            ),
        },
    }


def display_value(metric: dict[str, Any]) -> str:
    if metric["value"] is None:
        return "Non calculable"
    if metric["unit"] == "seconds":
        seconds = float(metric["value"])
        if seconds >= 86400:
            return f"{seconds / 86400:.2f} jours"
        if seconds >= 3600:
            return f"{seconds / 3600:.2f} heures"
        return f"{seconds / 60:.2f} minutes"
    if metric["unit"] == "percent":
        return f"{metric['value']:.2f} %"
    return f"{metric['value']:.2f} / semaine"


def render_html(report: dict[str, Any]) -> str:
    labels = {
        "deployment_frequency": "Fréquence de déploiement",
        "lead_time_for_changes": "Lead time des changements",
        "change_failure_rate": "Taux d'échec des changements",
        "time_to_restore_service": "Temps de restauration",
    }
    cards = []
    for key, label in labels.items():
        metric = report["metrics"][key]
        limit = f"<p class=\"limit\">{html.escape(metric['limit'])}</p>" if metric.get("limit") else ""
        cards.append(
            f"<article><h2>{html.escape(label)}</h2>"
            f"<p class=\"value\">{html.escape(display_value(metric))}</p>"
            f"<p>Échantillon : {metric['sample_size']}</p>{limit}</article>"
        )
    scope = report["scope"]
    return f"""<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>MicroCRM — métriques DORA</title>
<style>
body{{margin:0;font-family:system-ui,sans-serif;background:#f4f6f8;color:#17202a}}main{{max-width:1100px;margin:auto;padding:2rem}}
.warning{{padding:1rem;border-left:5px solid #d97706;background:#fff7ed}}.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:1rem;margin:2rem 0}}
article{{background:white;border-radius:10px;padding:1.25rem;box-shadow:0 2px 8px #0001}}h2{{font-size:1rem}}.value{{font-size:1.7rem;font-weight:700;color:#5b21b6}}.limit{{color:#9a3412}}
table{{border-collapse:collapse;width:100%;background:white}}th,td{{padding:.7rem;border:1px solid #d1d5db;text-align:left}}code{{background:#e5e7eb;padding:.1rem .3rem}}
</style></head><body><main><h1>MicroCRM — métriques DORA</h1>
<p>Généré le {html.escape(report['generated_at'])} depuis l’API GitLab.</p>
<p class="warning"><strong>Périmètre :</strong> {html.escape(scope['warning'])}</p>
<div class="grid">{''.join(cards)}</div>
<h2>Méthode</h2><table><tr><th>Élément</th><th>Valeur</th></tr>
<tr><td>Environnement</td><td><code>{html.escape(scope['environment'])}</code></td></tr>
<tr><td>Période</td><td>{html.escape(scope['period_start'])} → {html.escape(scope['period_end'])}</td></tr>
<tr><td>Début du suivi des incidents</td><td>{html.escape(scope['incident_tracking_start'])}</td></tr></table>
<p><a href="dora-metrics.json">Données JSON</a> · <a href="dora-metrics.csv">Export CSV</a></p>
</main></body></html>"""


def write_outputs(report: dict[str, Any], output_directory: Path) -> None:
    output_directory.mkdir(parents=True, exist_ok=True)
    (output_directory / "dora-metrics.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    with (output_directory / "dora-metrics.csv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["metric", "value", "unit", "sample_size", "status", "limit"])
        for name, metric in report["metrics"].items():
            writer.writerow(
                [name, metric["value"], metric["unit"], metric["sample_size"], metric["status"], metric.get("limit") or ""]
            )
    (output_directory / "index.html").write_text(render_html(report), encoding="utf-8")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Génère le rapport DORA statique de MicroCRM.")
    parser.add_argument("--environment", default=os.getenv("DORA_ENVIRONMENT", "aws-poc-staging"))
    parser.add_argument("--days", type=int, default=int(os.getenv("DORA_PERIOD_DAYS", "90")))
    parser.add_argument("--incident-tracking-start", default=os.getenv("DORA_INCIDENT_TRACKING_START", "2026-08-11T00:00:00Z"))
    parser.add_argument("--output", type=Path, default=Path("public"))
    parser.add_argument("--fixture", type=Path, help="Données locales de test, sans appel réseau.")
    parser.add_argument("--now", help="Date de fin forcée pour un test reproductible.")
    return parser


def main() -> int:
    arguments = build_parser().parse_args()
    if arguments.days <= 0:
        print("--days doit être strictement positif", file=sys.stderr)
        return 2
    end = parse_timestamp(arguments.now) if arguments.now else datetime.now(timezone.utc)
    incident_start = parse_timestamp(arguments.incident_tracking_start)
    if end is None or incident_start is None:
        print("Horodatage invalide", file=sys.stderr)
        return 2
    start = end - timedelta(days=arguments.days)

    if arguments.fixture:
        source = json.loads(arguments.fixture.read_text(encoding="utf-8"))
    else:
        token = os.getenv("DORA_GITLAB_TOKEN")
        api_url = os.getenv("CI_API_V4_URL")
        project_id = os.getenv("CI_PROJECT_ID")
        if not token or not api_url or not project_id:
            print("DORA_GITLAB_TOKEN, CI_API_V4_URL et CI_PROJECT_ID sont requis", file=sys.stderr)
            return 2
        try:
            source = collect_gitlab_data(GitLabClient(api_url, project_id, token), arguments.environment, start)
        except RuntimeError as error:
            print(str(error), file=sys.stderr)
            return 1

    report = calculate_metrics(source, arguments.environment, start, end, incident_start)
    write_outputs(report, arguments.output)
    print(f"Rapport DORA généré dans {arguments.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
