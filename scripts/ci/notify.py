#!/usr/bin/env python3

"""Prépare un résultat de pipeline et peut l'envoyer à un webhook."""

import argparse
import json
import os
import urllib.request
from pathlib import Path
from typing import Any

ALLOWED_STATUSES = ("success", "failed", "canceled", "running")


def parse_args() -> argparse.Namespace:
    """Déclare les informations nécessaires pour décrire le pipeline."""
    parser = argparse.ArgumentParser(
        description="Normalise et transmet éventuellement un résultat de pipeline."
    )
    parser.add_argument("--status", required=True, choices=ALLOWED_STATUSES)
    parser.add_argument("--pipeline-id", required=True)
    parser.add_argument("--pipeline-url", required=True)
    parser.add_argument("--ref", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument(
        "--send-webhook-env",
        help="Nom de la variable contenant le webhook ; sans cette option, aucun envoi.",
    )
    return parser.parse_args()


def build_payload(args: argparse.Namespace) -> dict[str, Any]:
    """Construit un message indépendant du futur canal de notification."""
    return {
        "status": args.status,
        "pipeline": {
            "id": args.pipeline_id,
            "url": args.pipeline_url,
        },
        "ref": args.ref,
        "commit": args.commit,
        "text": (
            f"Pipeline {args.pipeline_id} {args.status} "
            f"sur {args.ref} ({args.commit[:8]})"
        ),
    }


def resolve_output_path(output: Path) -> Path:
    """Refuse d'écrire en dehors du répertoire depuis lequel le script est lancé."""
    working_directory = os.path.realpath(os.getcwd())
    resolved_output = os.path.realpath(output)
    if (
        resolved_output != working_directory
        and not resolved_output.startswith(working_directory + os.sep)
    ):
        raise ValueError("Le fichier de sortie doit rester dans le répertoire de travail")
    return Path(resolved_output)


def send_webhook(payload: dict[str, Any], variable_name: str) -> None:
    """Envoie le message sans afficher l'adresse secrète du webhook."""
    # Seul le nom de la variable est passé au script. Son contenu reste dans
    # l'environnement local ou dans les variables protégées de GitLab.
    endpoint = os.environ.get(variable_name)
    if not endpoint:
        raise ValueError(f"Variable de webhook absente : {variable_name}")

    # urllib appartient à Python : aucune dépendance supplémentaire n'est requise.
    request = urllib.request.Request(
        endpoint,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        if not 200 <= response.status < 300:
            raise RuntimeError(f"Webhook refusé : HTTP {response.status}")


def main() -> int:
    args = parse_args()
    payload = build_payload(args)
    output = json.dumps(payload, indent=2, sort_keys=True) + "\n"

    try:
        output_path = resolve_output_path(args.output) if args.output else None
    except ValueError as error:
        raise SystemExit(str(error)) from error

    # Sans --output, le JSON est seulement affiché dans le terminal. Cela permet
    # de tester le script sans contacter un service externe.
    if output_path:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(output, encoding="utf-8")
        print(f"Notification générée : {output_path}")
    else:
        print(output, end="")

    # L'envoi reste facultatif tant que le canal n'a pas été choisi (ARB-07).
    if args.send_webhook_env:
        try:
            send_webhook(payload, args.send_webhook_env)
        except (ValueError, OSError, RuntimeError) as error:
            raise SystemExit(str(error)) from error
        print("Notification envoyée")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
