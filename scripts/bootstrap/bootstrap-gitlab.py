#!/usr/bin/env python3
"""Squelette de configuration initiale du projet GitLab MicroCRM.

La future implémentation devra vérifier les variables CI/CD et la protection
des tags ``v*`` sans journaliser de secret ni écraser une règle existante.
"""

PROTECTED_VARIABLES = ("AWS_PLAN_ROLE_ARN", "AWS_APPLY_ROLE_ARN")
MASKED_PROTECTED_SECRETS = (
    "GITLAB_AGENT_TOKEN",
    "SLACK_WEBHOOK_URL",
    "KUBERNETES_DATABASE_PASSWORD",
)
MASKED_SECRETS = ("SONAR_TOKEN", "DORA_GITLAB_TOKEN", "CI_DEPLOY_PASSWORD")
DEPLOY_TOKEN_VARIABLES = ("CI_DEPLOY_USER", "CI_DEPLOY_PASSWORD")


def main() -> int:
    """Ne modifier aucun projet tant que le bootstrap n'est pas implémenté."""
    print("Bootstrap GitLab non implémenté : aucune configuration modifiée.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
