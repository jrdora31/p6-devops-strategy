#!/usr/bin/env python3

"""Prépare une notification CI et peut l'envoyer à Slack.

Le comportement par défaut reste sans effet externe : le script construit un
JSON et l'écrit sur stdout. L'appel réseau n'est activé que si l'utilisateur
fournit explicitement le nom d'une variable d'environnement contenant l'URL.
"""

import argparse
import json
import os
import urllib.request
# `Any` décrit ici les valeurs hétérogènes contenues dans le dictionnaire JSON.
from typing import Any

# `choices` dans argparse refusera tout état hors de cette liste avant même
# l'exécution de la logique métier.
ALLOWED_STATUSES = ("success", "failed", "canceled", "running")
ALLOWED_EVENTS = ("pipeline", "deployment", "vulnerability", "rollback")

EVENT_LABELS = {
    "pipeline": "Pipeline",
    "deployment": "Déploiement",
    "vulnerability": "Contrôle de vulnérabilités",
    "rollback": "Rollback",
}

STATUS_ICONS = {
    "success": ":white_check_mark:",
    "failed": ":red_circle:",
    "canceled": ":black_circle:",
    "running": ":large_blue_circle:",
}


def parse_args() -> argparse.Namespace:
    """Déclarer et valider les arguments nécessaires au résumé du pipeline.

    `argparse` génère aussi automatiquement l'aide `--help` et retourne un code
    non nul si un argument obligatoire manque ou si le statut est inconnu.
    """
    parser = argparse.ArgumentParser(
        description="Normalise et transmet éventuellement un résultat de pipeline."
    )
    parser.add_argument("--status", required=True, choices=ALLOWED_STATUSES)
    parser.add_argument("--event", default="pipeline", choices=ALLOWED_EVENTS)
    parser.add_argument("--job", default="", help="Nom du job GitLab concerné.")
    parser.add_argument("--pipeline-id", required=True)
    parser.add_argument("--pipeline-url", required=True)
    parser.add_argument("--ref", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument(
        "--send-webhook-env",
        help="Nom de la variable contenant le webhook ; sans cette option, aucun envoi.",
    )
    return parser.parse_args()


def build_payload(args: argparse.Namespace) -> dict[str, Any]:
    """Construire le JSON attendu par un Incoming Webhook Slack.

    Slack utilise le champ ``text`` comme message principal et comme texte de
    remplacement pour les lecteurs d'écran. Les détails restent volontairement
    courts : le lien GitLab donne accès aux logs complets sans les recopier dans
    le canal.
    """
    event_label = EVENT_LABELS[args.event]
    job_suffix = f" — job `{args.job}`" if args.job else ""
    text = (
        f"{STATUS_ICONS[args.status]} {event_label} *{args.status}*{job_suffix}\n"
        f"Pipeline <{args.pipeline_url}|#{args.pipeline_id}> sur `{args.ref}` "
        f"(`{args.commit[:8]}`)"
    )
    return {
        # Ne jamais ajouter le webhook à ce dictionnaire : ce contenu est affiché
        # dans les logs CI avant l'envoi et ne doit contenir aucun secret.
        "text": text,
    }


def send_webhook(payload: dict[str, Any], variable_name: str) -> None:
    """Envoyer le message sans afficher l'adresse secrète du webhook.

    Args:
        payload: dictionnaire sérialisable en JSON construit par `build_payload`.
        variable_name: nom de la variable d'environnement, jamais son contenu.

    Raises:
        ValueError: si la variable demandée n'existe pas ou est vide.
        OSError: si la connexion réseau échoue.
        RuntimeError: si le serveur répond avec un statut HTTP hors 2xx.
    """
    # Seul le nom de la variable est passé au script. Son contenu reste dans
    # l'environnement local ou dans les variables protégées de GitLab.
    endpoint = os.environ.get(variable_name)
    if not endpoint:
        raise ValueError(f"Variable de webhook absente : {variable_name}")

    # urllib appartient à Python : aucune dépendance supplémentaire n'est requise.
    request = urllib.request.Request(
        endpoint,
        # Les webhooks attendent des octets : le dictionnaire est d'abord converti
        # en texte JSON, puis encodé explicitement en UTF-8.
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    # Le context manager ferme la réponse même si sa lecture déclenche une erreur.
    # Le timeout borne à dix secondes l'attente d'un service indisponible.
    with urllib.request.urlopen(request, timeout=10) as response:
        if not 200 <= response.status < 300:
            raise RuntimeError(f"Webhook refusé : HTTP {response.status}")


def main() -> int:
    """Orchestrer la préparation, l'affichage et l'envoi facultatif."""
    args = parse_args()
    payload = build_payload(args)
    # L'indentation rend le résultat lisible ; `sort_keys` stabilise son ordre pour
    # les logs et les tests ; le saut final respecte les conventions des fichiers texte.
    output = json.dumps(payload, indent=2, sort_keys=True) + "\n"

    # Le résultat est écrit sur stdout : le job GitLab peut ainsi le journaliser
    # sans permettre à un argument CLI de choisir un fichier du système.
    print(output, end="")

    # L'envoi reste facultatif tant que le canal n'a pas été choisi (ARB-07).
    if args.send_webhook_env:
        try:
            send_webhook(payload, args.send_webhook_env)
        except (ValueError, OSError, RuntimeError) as error:
            # SystemExit transmet un message propre sur stderr et un code non nul,
            # sans exposer une trace Python inutile dans les logs CI.
            raise SystemExit(str(error)) from error
        print("Notification envoyée")

    return 0


if __name__ == "__main__":
    # Ce garde empêche l'exécution de `main` si le fichier est importé dans un test.
    # `SystemExit` restitue au shell le code entier renvoyé par `main`.
    raise SystemExit(main())
