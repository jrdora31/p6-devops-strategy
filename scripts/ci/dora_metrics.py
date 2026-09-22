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

OUTPUT_DIRECTORY = Path("public")
DEFAULT_ENVIRONMENT_SPEC = (
    "staging=aws-poc-staging,production=aws-poc-production"
)
METRIC_LABELS = {
    "deployment_frequency": "Fréquence de déploiement",
    "lead_time_for_changes": "Délai des changements",
    "change_failure_rate": "Taux d'échec des changements",
    "time_to_restore_service": "Temps moyen de restauration",
}

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


def parse_environment_mapping(specification: str) -> dict[str, str]:
    """Convertit ``staging=nom,production=nom`` en mapping validé."""
    mapping: dict[str, str] = {}
    for raw_item in specification.split(","):
        item = raw_item.strip()
        if not item or "=" not in item:
            raise ValueError(
                "--environments doit utiliser le format "
                "staging=nom,production=nom"
            )
        logical_name, gitlab_name = (part.strip() for part in item.split("=", 1))
        if not logical_name or not gitlab_name or logical_name in mapping:
            raise ValueError("Mapping d'environnements invalide ou dupliqué")
        mapping[logical_name] = gitlab_name
    if len(set(mapping.values())) != len(mapping):
        raise ValueError("Chaque environnement GitLab doit être unique")
    return mapping


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
            query = urllib.parse.urlencode(
                {**parameters, "per_page": "100", "page": page}
            )
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
                raise RuntimeError(
                    f"Échec de lecture de l'API GitLab ({endpoint})"
                ) from error
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


def collect_environment_data(
    client: GitLabClient, environment: str, start: datetime
) -> dict[str, Any]:
    """Collecte deployments et MR pour un environnement paramétré."""
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
    return {
        "deployments": deployments,
        "deployment_merge_requests": deployment_merge_requests,
    }


def collect_gitlab_data(
    client: GitLabClient, environments: dict[str, str], start: datetime
) -> dict[str, Any]:
    """Collecte chaque environnement et les incidents communs une seule fois."""
    environment_sources = {
        gitlab_name: collect_environment_data(client, gitlab_name, start)
        for gitlab_name in environments.values()
    }
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
    return {"environments": environment_sources, "incidents": incidents}


def successful_deployments(
    source: dict[str, Any], start: datetime, end: datetime
) -> list[dict[str, Any]]:
    """Sélectionne les deployments réussis terminés dans la période."""
    selected = []
    for deployment in source.get("deployments", []):
        if deployment.get("status") != "success":
            continue
        finished = deployment_finished_at(deployment)
        if finished is None or not start <= finished <= end:
            continue
        selected.append(deployment)
    return sorted(selected, key=lambda item: deployment_finished_at(item) or start)


def lead_time_samples(
    deployments: list[dict[str, Any]], merge_requests: dict[str, list[dict[str, Any]]]
) -> list[float]:
    """Retourne les délais MR fusionnée -> premier deployment réussi."""
    first_delivery_by_mr: dict[str, tuple[datetime, datetime]] = {}
    for deployment in deployments:
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
    return [
        (finished - merged).total_seconds()
        for merged, finished in first_delivery_by_mr.values()
    ]


def incident_deployment_id(incident: dict[str, Any]) -> int | None:
    """Extrait l'IID du deployment relié par le contrat DORA de l'incident."""
    match = INCIDENT_DEPLOYMENT_PATTERN.search(incident.get("description") or "")
    return int(match.group(1)) if match else None


def tracked_incidents(
    incidents_source: list[dict[str, Any]], stability_start: datetime, end: datetime
) -> list[dict[str, Any]]:
    """Sélectionne et annote les incidents suivis sur la période."""
    incidents = []
    for incident in incidents_source:
        created = parse_timestamp(incident.get("created_at"))
        if created is None or not stability_start <= created <= end:
            continue
        incidents.append(
            {**incident, "dora_deployment_id": incident_deployment_id(incident)}
        )
    return incidents


def incidents_for_deployments(
    incidents: list[dict[str, Any]], deployment_ids: set[int]
) -> list[dict[str, Any]]:
    """Isole les incidents attribuables aux deployments d'un environnement."""
    return [
        incident
        for incident in incidents
        if incident["dora_deployment_id"] in deployment_ids
    ]


def restore_samples(incidents: list[dict[str, Any]]) -> list[float]:
    """Retourne les durées des incidents attribués et clôturés."""
    samples = []
    for incident in incidents:
        created = parse_timestamp(incident.get("created_at"))
        closed = parse_timestamp(incident.get("closed_at"))
        if created is not None and closed is not None and closed >= created:
            samples.append((closed - created).total_seconds())
    return samples


def stability_deployments(
    deployments: list[dict[str, Any]], stability_start: datetime, start: datetime
) -> list[dict[str, Any]]:
    """Sélectionne les deployments du dénominateur de stabilité."""
    return [
        deployment
        for deployment in deployments
        if (deployment_finished_at(deployment) or start) >= stability_start
    ]


def deployment_ids(deployments: list[dict[str, Any]]) -> set[int]:
    """Retourne les IID visibles dans l'historique GitLab des deployments."""
    return {
        int(deployment.get("iid", deployment["id"])) for deployment in deployments
    }


def failure_ids(incidents: list[dict[str, Any]], valid_ids: set[int]) -> set[int]:
    """Retourne les deployments réussis ayant causé un incident suivi."""
    return {
        incident["dora_deployment_id"]
        for incident in incidents
        if incident["dora_deployment_id"] in valid_ids
    }


def frequency_metric(successful_count: int, period_days: float) -> dict[str, Any]:
    """Construit la fréquence sans convertir une absence de données en zéro."""
    if not successful_count:
        return {
            "value": None,
            "unit": "successful_deployments_per_week",
            "successful_deployments": 0,
            "sample_size": 0,
            "status": "not_calculable",
            "limit": "Aucun deployment réussi sur la période.",
        }
    return {
        "value": round(successful_count * 7 / period_days, 2),
        "unit": "successful_deployments_per_week",
        "successful_deployments": successful_count,
        "sample_size": successful_count,
        "status": "measured",
        "limit": None,
    }


def median_metric(
    samples: list[float], unit: str, unavailable_message: str
) -> dict[str, Any]:
    """Construit une métrique médiane avec un état non calculable explicite."""
    if samples:
        return {
            "value": round(statistics.median(samples), 2),
            "unit": unit,
            "sample_size": len(samples),
            "status": "measured",
            "limit": None,
        }
    return {
        "value": None,
        "unit": unit,
        "sample_size": 0,
        "status": "not_calculable",
        "limit": unavailable_message,
    }


def failure_metric(failed_count: int, deployment_count: int) -> dict[str, Any]:
    """Construit le taux d'échec des changements."""
    if not deployment_count:
        return {
            "value": None,
            "unit": "percent",
            "failed_deployments": failed_count,
            "deployment_denominator": 0,
            "sample_size": 0,
            "status": "not_calculable",
            "limit": "Aucun deployment réussi depuis le début du suivi des incidents.",
        }
    return {
        "value": round(failed_count / deployment_count * 100, 2),
        "unit": "percent",
        "failed_deployments": failed_count,
        "deployment_denominator": deployment_count,
        "sample_size": deployment_count,
        "status": "measured",
        "limit": None,
    }


def calculate_environment_metrics(
    source: dict[str, Any],
    incidents_source: list[dict[str, Any]],
    environment: str,
    start: datetime,
    end: datetime,
    incident_tracking_start: datetime,
) -> dict[str, Any]:
    """Calcule les quatre métriques avec la même logique pour chaque environnement."""
    successful = successful_deployments(source, start, end)
    period_days = max((end - start).total_seconds() / 86400, 1)
    lead_samples = lead_time_samples(
        successful, source.get("deployment_merge_requests", {})
    )
    stability_start = max(start, incident_tracking_start)
    stable_deployments = stability_deployments(successful, stability_start, start)
    stable_ids = deployment_ids(stable_deployments)
    incidents = tracked_incidents(incidents_source, stability_start, end)
    environment_incidents = incidents_for_deployments(incidents, stable_ids)
    failed_change_ids = failure_ids(environment_incidents, stable_ids)
    restore_duration_samples = restore_samples(environment_incidents)

    return {
        "gitlab_environment": environment,
        "metrics": {
            "deployment_frequency": frequency_metric(len(successful), period_days),
            "lead_time_for_changes": median_metric(
                lead_samples,
                "seconds",
                "Aucune MR fusionnée reliée aux deployments de cet environnement.",
            ),
            "change_failure_rate": failure_metric(
                len(failed_change_ids), len(stable_deployments)
            ),
            "time_to_restore_service": median_metric(
                restore_duration_samples,
                "seconds",
                "Aucun incident clôturé relié à un deployment de cet environnement.",
            ),
        },
        "quality": {
            "successful_deployments": len(successful),
            "stability_deployments": len(stable_deployments),
            "linked_incidents": len(environment_incidents),
            "closed_linked_incidents": len(restore_duration_samples),
        },
    }


def display_value(metric: dict[str, Any]) -> str:
    """Formate une valeur pour HTML, CSV et interprétation."""
    if metric["value"] is None:
        return "N/A"
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


def environment_metric_summary(
    logical_name: str, metric_name: str, metric: dict[str, Any]
) -> str:
    """Produit une synthèse factuelle d'une métrique et de son échantillon."""
    label = logical_name.upper()
    if metric["value"] is None:
        return f"{label} : N/A ({metric['limit']})"
    value = display_value(metric)
    if metric_name == "deployment_frequency":
        return f"{label} : {value}, sur {metric['sample_size']} deployments réussis"
    if metric_name == "lead_time_for_changes":
        return f"{label} : médiane de {value}, sur {metric['sample_size']} MR"
    if metric_name == "change_failure_rate":
        return (
            f"{label} : {value}, soit {metric['failed_deployments']} deployments "
            f"en échec de changement sur {metric['deployment_denominator']}"
        )
    return (
        f"{label} : médiane de {value}, sur {metric['sample_size']} incidents "
        "clôturés et attribués"
    )


def build_interpretation(environments: dict[str, Any]) -> list[str]:
    """Génère quatre constats strictement dérivés des valeurs calculées."""
    interpretation = []
    for metric_name, metric_label in METRIC_LABELS.items():
        summaries = [
            environment_metric_summary(
                logical_name,
                metric_name,
                environment_report["metrics"][metric_name],
            )
            for logical_name, environment_report in environments.items()
        ]
        interpretation.append(f"{metric_label} — " + " ; ".join(summaries) + ".")
    return interpretation


def calculate_report(
    source: dict[str, Any],
    environments: dict[str, str],
    start: datetime,
    end: datetime,
    incident_tracking_start: datetime,
) -> dict[str, Any]:
    """Assemble le rapport comparatif sur une fenêtre temporelle commune."""
    reports: dict[str, Any] = {}
    environment_sources = source.get("environments", {})
    incidents_source = source.get("incidents", [])
    for logical_name, gitlab_name in environments.items():
        if gitlab_name not in environment_sources:
            raise ValueError(f"Données absentes pour l'environnement {gitlab_name}")
        reports[logical_name] = calculate_environment_metrics(
            environment_sources[gitlab_name],
            incidents_source,
            gitlab_name,
            start,
            end,
            incident_tracking_start,
        )

    stability_start = max(start, incident_tracking_start)
    incidents = tracked_incidents(incidents_source, stability_start, end)
    report = {
        "schema_version": 2,
        "generated_at": isoformat(end),
        "scope": {
            "environment_kind": "microcrm_poc_comparison",
            "environments": [
                {"name": logical_name, "gitlab_environment": gitlab_name}
                for logical_name, gitlab_name in environments.items()
            ],
            "period_start": isoformat(start),
            "period_end": isoformat(end),
            "incident_tracking_start": isoformat(incident_tracking_start),
            "stability_period_start": isoformat(stability_start),
            "warning": (
                "Mesures des environnements logiques staging et production du POC "
                "MicroCRM ; elles ne représentent pas une production utilisée par "
                "de vrais utilisateurs."
            ),
        },
        "environments": reports,
        "quality": {
            "tracked_incidents": len(incidents),
            "incidents_without_deployment_id": sum(
                incident["dora_deployment_id"] is None for incident in incidents
            ),
        },
        "interpretation": build_interpretation(reports),
        "limitations": [
            (
                "Le périmètre couvre staging et l'environnement logique production "
                "du POC MicroCRM, pas un historique réel de production utilisé par "
                "des clients."
            ),
            (
                "Les petits échantillons rendent les médianes et pourcentages "
                "sensibles à chaque deployment ou incident."
            ),
            (
                "Le Change Failure Rate est le nombre de deployments réussis "
                "distincts référencés par au moins un incident GitLab dora via "
                "DORA_DEPLOYMENT_ID, divisé par les deployments réussis de "
                "l'environnement sur la période de stabilité."
            ),
            (
                "Le MTTR est la médiane création-clôture des incidents dora clôturés "
                "dont DORA_DEPLOYMENT_ID correspond à un deployment réussi du même "
                "environnement sur la période de stabilité. Sans incident clôturé "
                "attribuable, la valeur est N/A."
            ),
        ],
    }
    return report


def render_html(report: dict[str, Any]) -> str:
    """Produit un dashboard GitLab Pages compact et autonome."""
    metric_cards = []
    environment_order = sorted(
        report["environments"],
        key=lambda name: (name != "production", name),
    )
    for metric_name, metric_label in METRIC_LABELS.items():
        environment_blocks = []
        for logical_name in environment_order:
            environment_report = report["environments"][logical_name]
            metric = environment_report["metrics"][metric_name]
            environment_blocks.append(
                "<div class=\"environment\">"
                f"<span class=\"environment-name\">{html.escape(logical_name.upper())}</span>"
                f"<strong class=\"value\">{html.escape(display_value(metric))}</strong>"
                f"<span class=\"sample\">Échantillon : {metric['sample_size']}</span>"
                "</div>"
            )
        metric_cards.append(
            "<section class=\"metric\">"
            f"<h2>DORA — {html.escape(metric_label)}</h2>"
            f"<div class=\"metric-values\">{''.join(environment_blocks)}</div>"
            "</section>"
        )

    scope = report["scope"]
    environment_list = ", ".join(
        f"{item['name'].upper()} = {item['gitlab_environment']}"
        for item in scope["environments"]
    )
    return f"""<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>MicroCRM — métriques DORA</title>
<style>
*{{box-sizing:border-box}}html,body{{height:100%;margin:0}}body{{font-family:Inter,system-ui,sans-serif;background:#eef1f5;color:#252a34}}
main{{height:100%;padding:14px 16px;display:grid;grid-template-rows:auto minmax(0,1fr) auto;gap:12px;overflow:hidden}}
header{{display:flex;align-items:end;justify-content:space-between;gap:20px}}h1{{font-size:1.35rem;margin:0}}.period{{margin:0;color:#667085;font-size:.82rem;text-align:right}}
.dashboard{{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;min-height:0}}
.metric{{min-width:0;background:#fff;border:1px solid #d8dde6;border-radius:7px;box-shadow:0 1px 3px #1018281a;overflow:hidden;display:grid;grid-template-rows:auto minmax(0,1fr)}}
.metric h2{{font-size:.78rem;line-height:1.2;margin:0;padding:10px 11px;border-bottom:1px solid #eaecf0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}}
.metric-values{{display:grid;grid-template-rows:repeat(2,minmax(0,1fr));min-height:0}}
.environment{{display:flex;flex-direction:column;align-items:center;justify-content:center;padding:8px;text-align:center;min-height:0}}
.environment+ .environment{{border-top:1px solid #eaecf0}}.environment-name{{font-size:.7rem;font-weight:700;letter-spacing:.08em;color:#667085}}
.value{{font-size:clamp(1.55rem,3.1vw,3.2rem);line-height:1.05;margin:.18em 0;font-weight:750;color:#303540;white-space:nowrap}}
.sample{{font-size:.7rem;color:#7b8190}}footer{{display:flex;justify-content:space-between;align-items:center;gap:16px;color:#667085;font-size:.72rem;white-space:nowrap}}
footer p{{margin:0;overflow:hidden;text-overflow:ellipsis}}a{{color:#175cd3;text-decoration:none}}a:hover{{text-decoration:underline}}
@media(max-width:900px){{main{{overflow:auto;height:auto;min-height:100%}}.dashboard{{grid-template-columns:repeat(2,minmax(0,1fr))}}.metric{{min-height:250px}}}}
</style></head><body><main>
<header><h1>MicroCRM — DORA</h1><p class="period">{html.escape(scope['period_start'][:10])} → {html.escape(scope['period_end'][:10])}</p></header>
<div class="dashboard">{''.join(metric_cards)}</div>
<footer><p>{html.escape(environment_list)} · Généré le {html.escape(report['generated_at'])}</p><p><a href="dora-metrics.json">JSON</a> · <a href="dora-metrics.csv">CSV</a></p></footer>
</main></body></html>"""


def write_outputs(report: dict[str, Any], output_directory: Path) -> None:
    """Écrit les trois formats en conservant les noms utilisés par GitLab Pages."""
    output_directory.mkdir(parents=True, exist_ok=True)
    json_path = safe_path(output_directory / "dora-metrics.json")
    with open(json_path, "w", encoding="utf-8") as stream:
        stream.write(json.dumps(report, ensure_ascii=False, indent=2) + "\n")

    csv_path = safe_path(output_directory / "dora-metrics.csv")
    with open(csv_path, "w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(
            [
                "environment",
                "gitlab_environment",
                "metric",
                "value",
                "display_value",
                "unit",
                "sample_size",
                "status",
                "limit",
            ]
        )
        for logical_name, environment_report in report["environments"].items():
            for metric_name, metric in environment_report["metrics"].items():
                writer.writerow(
                    [
                        logical_name,
                        environment_report["gitlab_environment"],
                        metric_name,
                        metric["value"] if metric["value"] is not None else "",
                        display_value(metric),
                        metric["unit"],
                        metric["sample_size"],
                        metric["status"],
                        metric.get("limit") or "",
                    ]
                )

    html_path = safe_path(output_directory / "index.html")
    with open(html_path, "w", encoding="utf-8") as stream:
        stream.write(render_html(report))


def safe_path(path: Path) -> Path:
    """Garantir que le chemin canonique reste dans le répertoire de travail."""
    resolved = os.path.realpath(path)
    base_directory = os.path.realpath(os.getcwd())
    if resolved != base_directory and not resolved.startswith(base_directory + os.sep):
        raise ValueError(f"Chemin hors du répertoire autorisé : {path}")
    return Path(resolved)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Génère le rapport DORA comparatif de MicroCRM."
    )
    parser.add_argument(
        "--environments",
        default=os.getenv("DORA_ENVIRONMENTS", DEFAULT_ENVIRONMENT_SPEC),
        help="Mapping logique=GitLab séparé par des virgules.",
    )
    parser.add_argument(
        "--days", type=int, default=int(os.getenv("DORA_PERIOD_DAYS", "90"))
    )
    parser.add_argument(
        "--incident-tracking-start",
        default=os.getenv("DORA_INCIDENT_TRACKING_START", "2026-08-11T00:00:00Z"),
    )
    parser.add_argument(
        "--fixture", type=Path, help="Données locales de test, sans appel réseau."
    )
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

    try:
        environments = parse_environment_mapping(arguments.environments)
        output_directory = safe_path(OUTPUT_DIRECTORY)
        if arguments.fixture:
            fixture_path = safe_path(arguments.fixture)
            source = json.loads(fixture_path.read_text(encoding="utf-8"))
        else:
            token = os.getenv("DORA_GITLAB_TOKEN")
            api_url = os.getenv("CI_API_V4_URL")
            project_id = os.getenv("CI_PROJECT_ID")
            if not token or not api_url or not project_id:
                print(
                    "DORA_GITLAB_TOKEN, CI_API_V4_URL et CI_PROJECT_ID sont requis",
                    file=sys.stderr,
                )
                return 2
            source = collect_gitlab_data(
                GitLabClient(api_url, project_id, token), environments, start
            )
        report = calculate_report(
            source, environments, start, end, incident_start
        )
        write_outputs(report, output_directory)
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as error:
        print(str(error), file=sys.stderr)
        return 1

    print(f"Rapport DORA généré dans {output_directory}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
