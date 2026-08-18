#!/usr/bin/env python3

"""Génère la fiche JSON qui relie une release à ses éléments techniques.

Le manifeste apporte une traçabilité bidirectionnelle : à partir d'une version,
on retrouve le commit, le pipeline et les deux images immuables qui la composent.
Le script valide toutes les identités avant la première écriture sur disque.
"""

import argparse
import json
import os
import re
from pathlib import Path

# Ces expressions refusent les versions, commits et images qui ne respectent
# pas les formats attendus avant d'écrire le manifeste.
# `re.compile` prépare les regex une seule fois au chargement du module.
SEMVER_PATTERN = re.compile(
    # `v` est facultatif ; chaque entier interdit les zéros initiaux inutiles ;
    # prérelease (`-rc.1`) et métadonnées (`+build.4`) restent facultatives.
    r"^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
    r"(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$"
)
COMMIT_PATTERN = re.compile(r"^[0-9a-f]{7,40}$")
# Une image déployable doit inclure son registre/nom puis un digest SHA-256 complet.
DIGEST_PATTERN = re.compile(r"^.+@sha256:[0-9a-f]{64}$")
FINAL_VERSION_PATTERN = re.compile(r"^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")
RC_VERSION_PATTERN = re.compile(
    r"^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)-rc\.([1-9]\d*)$"
)
# Le chemin fixe évite qu'un argument utilisateur choisisse une destination sensible.
OUTPUT_PATH = Path(".ci/release/release-manifest.json")


def parse_args() -> argparse.Namespace:
    """Déclarer les informations obligatoires reçues en ligne de commande."""
    parser = argparse.ArgumentParser(
        description="Génère le manifeste JSON traçant une release MicroCRM."
    )
    parser.add_argument("--version", required=True, help="Version SemVer, ex. v1.2.0")
    parser.add_argument("--commit", required=True, help="Commit SHA de la release")
    parser.add_argument("--pipeline-id", required=True)
    parser.add_argument("--pipeline-url", required=True)
    parser.add_argument("--frontend-image", required=True, help="Image avec digest")
    parser.add_argument("--backend-image", required=True, help="Image avec digest")
    parser.add_argument("--source-version", default="", help="RC promue")
    parser.add_argument("--source-commit", default="", help="Commit de la RC promue")
    return parser.parse_args()


def validate(args: argparse.Namespace) -> None:
    """Vérifier les identifiants avant toute création de dossier ou de fichier."""
    if not SEMVER_PATTERN.fullmatch(args.version):
        raise ValueError(f"Version SemVer invalide : {args.version}")
    if not COMMIT_PATTERN.fullmatch(args.commit):
        raise ValueError("Commit SHA invalide")
    # Une seule boucle applique exactement la même règle aux deux composants.
    for image in (args.frontend_image, args.backend_image):
        if not DIGEST_PATTERN.fullmatch(image):
            raise ValueError(f"Référence d'image sans digest valide : {image}")
    is_final = FINAL_VERSION_PATTERN.fullmatch(args.version) is not None
    is_rc = RC_VERSION_PATTERN.fullmatch(args.version) is not None
    if not (is_final or is_rc):
        raise ValueError("Seules les RC -rc.N et les versions finales sont publiables")
    if is_final:
        source_match = RC_VERSION_PATTERN.fullmatch(args.source_version)
        final_match = FINAL_VERSION_PATTERN.fullmatch(args.version)
        if not source_match or not COMMIT_PATTERN.fullmatch(args.source_commit):
            raise ValueError("Une release finale doit identifier sa RC et son commit source")
        if source_match.groups()[:3] != final_match.groups():
            raise ValueError("La RC source ne correspond pas à la version finale")
    elif args.source_version or args.source_commit:
        raise ValueError("Une RC ne peut pas promouvoir une autre release")


def safe_path(path: Path) -> str:
    """Garantir que le chemin canonique reste dans le répertoire de travail.

    `realpath` résout les segments `..` et les liens symboliques. Une simple
    comparaison textuelle de chemins ne suffirait donc pas contre une sortie du
    workspace par lien symbolique.
    """
    resolved = os.path.realpath(path)
    base_directory = os.path.realpath(os.getcwd())
    # Le séparateur final est important : `/work/project-bis` ne doit pas être
    # accepté simplement parce qu'il commence par la chaîne `/work/project`.
    if resolved != base_directory and not resolved.startswith(
        base_directory + os.sep
    ):
        raise ValueError(f"Chemin hors du répertoire autorisé : {path}")
    return resolved


def main() -> int:
    """Valider les entrées, construire le manifeste puis l'écrire sûrement."""
    args = parse_args()
    try:
        validate(args)
    except ValueError as error:
        raise SystemExit(str(error)) from error

    # Ce document permet de retrouver le code, le pipeline et les deux images
    # correspondant exactement à une version donnée.
    # Un dictionnaire Python reflète directement les objets imbriqués du JSON final.
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
    if args.source_version:
        manifest["promotion"] = {
            "sourceVersion": args.source_version,
            "sourceCommit": args.source_commit,
        }

    # Le chemin est fixe, puis canonicalisé et contrôlé avant tout accès disque.
    try:
        output_path = safe_path(OUTPUT_PATH)
    except ValueError as error:
        raise SystemExit(str(error)) from error

    # `parents=True` crée toute l'arborescence `.ci/release`; `exist_ok=True`
    # rend la commande réexécutable si le dossier existe déjà.
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    # Le context manager ferme toujours le fichier. UTF-8 rend le format explicite
    # et le saut de ligne final facilite les outils Unix et les diffs Git.
    with open(output_path, "w", encoding="utf-8") as output_file:
        output_file.write(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(f"Manifeste généré : {OUTPUT_PATH}")
    return 0


if __name__ == "__main__":
    # Le fichier reste importable sans effet de bord ; l'exécution CLI propage son code retour.
    raise SystemExit(main())
