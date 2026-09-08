# Bootstrap

Référence technique des scripts utilisés pour initialiser les accès AWS et la configuration GitLab nécessaires à MicroCRM.

> Ces scripts sont des squelettes non exécutés dans le cadre du POC. Ils
> décrivent une piste d'automatisation et ne configurent actuellement aucune
> ressource ni variable. Pour la procédure d'initialisation, voir
> `docs/GET-STARTED.md`.

## Vue d'ensemble

```text
bootstrap.py
    │
    ├── bootstrap-aws.py
    │       └── provisionnement des permissions / rôles AWS
    │
    └── bootstrap-gitlab.py
            └── configuration des variables CI/CD GitLab
```

| Script                | Responsabilité                             | Appelé par     |
| --------------------- | ------------------------------------------ | -------------- |
| `bootstrap.py`        | Orchestre le bootstrap complet             | Utilisateur    |
| `bootstrap-aws.py`    | Provisionne les ressources IAM nécessaires | `bootstrap.py` |
| `bootstrap-gitlab.py` | Configure les variables CI/CD GitLab       | `bootstrap.py` |

---

## `bootstrap.py`

### Rôle

Point d'entrée du bootstrap.

Orchestre successivement l'initialisation AWS puis la configuration GitLab.

### Conditions d'exécution

* authentification AWS valide ;
* accès au projet GitLab ;
* Python et dépendances nécessaires installés ;
* mécanisme d'authentification GitLab à définir sans stocker le token dans le dépôt.

### Entrées

À définir lors de l'implémentation. Le squelette ne lit encore aucune entrée.

### Fonctionnement

```text
bootstrap.py
    ↓
bootstrap-aws.py
    ↓
récupération des valeurs / ARN nécessaires
    ↓
bootstrap-gitlab.py
```

### Sorties

Aucune actuellement : le script s'arrête explicitement comme non implémenté.

---

## `bootstrap-aws.py`

### Rôle

Provisionne les permissions, rôles ou ressources IAM nécessaires au fonctionnement de MicroCRM et de sa chaîne CI/CD.

### Dépendances

* authentification AWS ;
* méthode d'appel AWS à choisir lors de l'implémentation.

### Entrées

Compte et région AWS à fournir sans credentials en dur.

### Fonctionnement

Le futur script devrait préparer les rôles OIDC référencés par
`AWS_PLAN_ROLE_ARN` et `AWS_APPLY_ROLE_ARN`, avec des droits distincts de
lecture/plan et d'application. Terraform crée ensuite le rôle d'instance EC2,
son profil, la policy `AmazonSSMManagedInstanceCore` et, si activée, la policy
CloudWatch du projet.

### Ressources créées

Aucune actuellement. Les noms des rôles OIDC ne sont pas imposés par le dépôt ;
seuls leurs ARN sont consommés par la CI.

### Sorties

À terme : les ARN des rôles OIDC de plan et d'application.

---

## `bootstrap-gitlab.py`

### Rôle

Configure les variables CI/CD nécessaires au projet GitLab à partir des informations générées ou récupérées pendant le bootstrap AWS.

### Dépendances

* accès au projet GitLab ;
* authentification permettant l'utilisation de l'API GitLab ;
* valeurs AWS nécessaires disponibles.

### Entrées

URL et identifiant du projet, moyen d'authentification à l'API GitLab, puis ARN
AWS et secrets fournis hors dépôt.

### Fonctionnement

Le futur script devrait créer ou vérifier les variables sans afficher leur
valeur, puis contrôler leur protection et leur masquage.

### Variables GitLab créées

Le squelette cible uniquement les variables consommées par le dépôt :

* `AWS_PLAN_ROLE_ARN` et `AWS_APPLY_ROLE_ARN` : ARN des rôles OIDC, protégés ;
* `GITLAB_AGENT_TOKEN` : secret protégé et masqué ;
* `SLACK_WEBHOOK_URL` : secret protégé et masqué ;
* `SONAR_TOKEN` et `DORA_GITLAB_TOKEN` : tokens masqués, avec protection
  adaptée aux pipelines visés ;
* `KUBERNETES_DATABASE_PASSWORD` : secret protégé et masqué ;
* `CI_DEPLOY_USER` et `CI_DEPLOY_PASSWORD` : identifiants du deploy token
  Registry, créés par GitLab puis exposés à la CI.

Les variables prédéfinies GitLab et les options non secrètes déclarées dans
`.gitlab-ci.yml` ne sont pas créées par ce bootstrap.

### Protection des releases

Le script doit sécuriser la création des releases en configurant les tags Git
correspondants dans GitLab.

TODO : implémenter les opérations suivantes :

1. rechercher la règle de protection correspondant au motif `v*` ;
2. créer cette règle lorsqu'elle n'existe pas ;
3. autoriser uniquement les Maintainers à créer les tags correspondants ;
4. vérifier la configuration lorsque la règle existe déjà ;
5. signaler toute différence sans supprimer automatiquement une protection
   existante ;
6. confirmer dans le rapport final que les tags de release sont protégés.

Cette protection contrôle les personnes autorisées à créer ou supprimer une
version Git. La pipeline reste responsable de vérifier le format SemVer du tag
et que le commit destiné à la production appartient à la branche `main`.

### Sorties

Aucune actuellement. À terme : variables créées ou vérifiées et protection des
tags `v*` contrôlée.

---

## Rejouer le bootstrap

Les scripts ne sont pas rejouables tant qu'ils restent des squelettes. Une
implémentation future devra être idempotente et signaler les écarts sans
écraser automatiquement une ressource ou une protection existante.

## Sécurité

* aucun secret ne doit être écrit dans les logs ;
* aucun token ou credential ne doit être versionné ;
* les permissions AWS doivent rester limitées aux besoins du projet ;
* les secrets GitLab doivent être masqués et protégés lorsque leur format et
  leur périmètre le permettent.

## Séquence théorique

1. Préparer les rôles et permissions AWS.
2. Préparer le projet et les protections GitLab.
3. Renseigner les ARN, tokens et secrets dans les variables CI/CD.
4. Lancer puis valider la CI.
