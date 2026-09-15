#!/usr/bin/env python3
"""Squelette de configuration initiale du projet GitLab MicroCRM.

PURPOSE
    Décrire l'automatisation GitLab nécessaire après la création des rôles AWS.
INPUTS
    URL et identifiant du projet, token GitLab fourni hors dépôt, ARN des rôles
    OIDC, secrets Kubernetes et éventuels tokens Sonar/DORA/déploiement.
OUTPUTS
    Variables CI/CD correctement masquées/protégées et règle de protection
    idempotente pour les tags de release ``v*``.
DEPENDENCIES
    API GitLab et token doté uniquement des droits de gestion du projet requis.
EXECUTION FLOW
    Lire l'existant, comparer chaque variable et protection, créer les éléments
    absents et laisser intacts ceux qui sont déjà conformes.
FAILURE BEHAVIOUR
    Refuser un token insuffisant, une valeur absente ou une règle conflictuelle;
    ne jamais écraser silencieusement une protection ni journaliser un secret.

Les appels API restent volontairement non implémentés dans ce POC afin que ce
fichier demeure un exemple sûr et explicable, sans modifier un vrai projet.
"""

# Les ARN ne sont pas des secrets, mais leur protection empêche une branche non
# protégée de détourner les rôles OIDC utilisés par Terraform.
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
