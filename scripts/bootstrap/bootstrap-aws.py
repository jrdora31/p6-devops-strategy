#!/usr/bin/env python3
"""Squelette de préparation des accès AWS de MicroCRM.

PURPOSE
    Décrire la création contrôlée de la confiance OIDC GitLab et des rôles
    distincts utilisés par ``terraform plan`` et ``terraform apply``.
INPUTS
    Compte/région AWS, identité du projet et des refs GitLab autorisées, plus
    une session humaine temporaire capable de gérer IAM et le fournisseur OIDC.
OUTPUTS
    ARN des deux rôles à transmettre ensuite aux variables GitLab protégées.
DEPENDENCIES
    API AWS IAM/STS et permissions minimales pour lire puis créer ou mettre à
    jour la confiance OIDC et les policies attendues.
EXECUTION FLOW
    Vérifier l'identité AWS, lire l'existant, créer uniquement les éléments
    manquants, contrôler les conditions ``sub``/``aud``, puis retourner les ARN.
FAILURE BEHAVIOUR
    Échouer sur un compte inattendu, une confiance trop large ou une policy
    divergente; ne jamais créer de clé d'accès statique ni toucher aux ressources
    applicatives qui appartiennent à Terraform.

Ces appels IAM restent volontairement non implémentés dans le POC : une erreur
de bootstrap pourrait élargir des permissions réelles et exige une validation
humaine préalable.
"""

OIDC_ROLE_VARIABLES = ("AWS_PLAN_ROLE_ARN", "AWS_APPLY_ROLE_ARN")


def main() -> int:
    """Ne créer aucune ressource tant que le bootstrap n'est pas implémenté."""
    print("Bootstrap AWS non implémenté : aucune ressource créée.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
