#!/usr/bin/env python3
"""Squelette de préparation des accès AWS de MicroCRM.

La future implémentation devra préparer les rôles OIDC utilisés par GitLab CI
pour le plan et l'application Terraform. Elle ne devra ni stocker des
credentials statiques ni recréer les ressources gérées par Terraform.
"""

OIDC_ROLE_VARIABLES = ("AWS_PLAN_ROLE_ARN", "AWS_APPLY_ROLE_ARN")


def main() -> int:
    """Ne créer aucune ressource tant que le bootstrap n'est pas implémenté."""
    print("Bootstrap AWS non implémenté : aucune ressource créée.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
