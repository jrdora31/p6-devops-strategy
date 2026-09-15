#!/usr/bin/env python3
"""Squelette de l'orchestrateur du bootstrap MicroCRM.

PURPOSE
    Montrer le point d'entrée qui coordonnerait une reprise du projet sans
    confondre les responsabilités AWS et GitLab.
INPUTS
    À terme : configuration non secrète du projet et références de credentials
    fournies par l'environnement, jamais codées en dur.
OUTPUTS
    Un compte rendu des contrôles et changements réalisés par chaque étape.
DEPENDENCIES
    Les futurs modules ``bootstrap-aws`` puis ``bootstrap-gitlab`` ainsi que
    des clients API authentifiés avec des droits minimaux.
EXECUTION FLOW
    Vérifier les prérequis, préparer les accès AWS OIDC, puis configurer les
    variables et protections GitLab qui référencent ces accès.
FAILURE BEHAVIOUR
    L'orchestrateur doit s'arrêter au premier échec, sans poursuivre avec une
    configuration partielle ni afficher de secret.

Ce POC conserve volontairement ce fichier non opérationnel : l'exécuter ne
modifie aujourd'hui aucune ressource externe.
"""


def main() -> int:
    """Signaler explicitement que l'orchestration reste à implémenter."""
    print("Bootstrap MicroCRM non implémenté : consulter bootstrap.md.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
