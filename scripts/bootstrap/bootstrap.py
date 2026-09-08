#!/usr/bin/env python3
"""Squelette de l'orchestrateur du bootstrap MicroCRM.

Une implémentation future appellera d'abord la préparation AWS, puis la
configuration GitLab. Aucun changement externe n'est effectué actuellement.
"""


def main() -> int:
    """Signaler explicitement que l'orchestration reste à implémenter."""
    print("Bootstrap MicroCRM non implémenté : consulter bootstrap.md.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
