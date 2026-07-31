#!/usr/bin/env python3

"""Génère la fiche JSON qui relie une release à ses éléments techniques."""

import argparse
import json
import re
from pathlib import Path

# Ces expressions refusent les versions, commits et images qui ne respectent
# pas les formats attendus avant d'écrire le manifeste.
SEMVER_PATTERN = re.compile(
    r"^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
    r"(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$"
)
COMMIT_PATTERN = re.compile(r"^[0-9a-f]{7,40}$")
DIGEST_PATTERN = re.compile(r"^.+@sha256:[0-9a-f]{64}$")


def parse_args() -> argparse.Namespace:
    """Déclare les informations obligatoires reçues depuis la ligne de commande."""
    parser = argparse.ArgumentParser(
        description="Génère le manifeste JSON traçant une release MicroCRM."
    )
    parser.add_argument("--version", required=True, help="Version SemVer, ex. v1.2.0")
    parser.add_argument("--commit", required=True, help="Commit SHA de la release")
    parser.add_argument("--pipeline-id", required=True)
    parser.add_argument("--pipeline-url", required=True)
    parser.add_argument("--frontend-image", required=True, help="Image avec digest")
    parser.add_argument("--backend-image", required=True, help="Image avec digest")
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def validate(args: argparse.Namespace) -> None:
    """Vérifie les valeurs qui doivent identifier une release sans ambiguïté."""
    if not SEMVER_PATTERN.fullmatch(args.version):
        raise ValueError(f"Version SemVer invalide : {args.version}")
    if not COMMIT_PATTERN.fullmatch(args.commit):
        raise ValueError("Commit SHA invalide")
    for image in (args.frontend_image, args.backend_image):
        if not DIGEST_PATTERN.fullmatch(image):
            raise ValueError(f"Référence d'image sans digest valide : {image}")


def main() -> int:
    args = parse_args()
    try:
        validate(args)
    except ValueError as error:
        raise SystemExit(str(error)) from error

    # Ce document permet de retrouver le code, le pipeline et les deux images
    # correspondant exactement à une version donnée.
    manifest = {
        "version": args.version,
        "commit": args.commit,
        "pipeline": {
            "id": args.pipeline_id,
            "url": args.pipeline_url,
        },
        "images": {
            "frontend": args.frontend_image,
            "backend": args.backend_image,
        },
    }

    # Crée uniquement le dossier de sortie demandé, puis écrit un JSON lisible.
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"Manifeste généré : {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
