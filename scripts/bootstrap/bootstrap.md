# Bootstrap

Référence technique des scripts utilisés pour initialiser les accès AWS et la configuration GitLab nécessaires à MicroCRM.

> Pour la procédure complète d'initialisation du projet, voir `docs/GET_STARTED.md`.

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
* TODO : autres prérequis réels.

### Entrées

* TODO : arguments CLI ;
* TODO : variables d'environnement ;
* TODO : fichiers de configuration éventuels.

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

* permissions et rôles AWS nécessaires disponibles ;
* valeurs AWS nécessaires récupérées ;
* variables CI/CD GitLab configurées ;
* TODO : autres sorties.

---

## `bootstrap-aws.py`

### Rôle

Provisionne les permissions, rôles ou ressources IAM nécessaires au fonctionnement de MicroCRM et de sa chaîne CI/CD.

### Dépendances

* authentification AWS ;
* TODO : Terraform bootstrap / AWS CLI / bibliothèques Python réellement utilisées.

### Entrées

* TODO : compte / région AWS ;
* TODO : arguments ;
* TODO : variables d'environnement.

### Fonctionnement

TODO : décrire brièvement les étapes réellement exécutées par le script.

### Ressources créées

TODO : lister les rôles, policies ou autres ressources réellement provisionnés.

### Sorties

TODO : ARN, identifiants ou valeurs transmises au bootstrap GitLab.

---

## `bootstrap-gitlab.py`

### Rôle

Configure les variables CI/CD nécessaires au projet GitLab à partir des informations générées ou récupérées pendant le bootstrap AWS.

### Dépendances

* accès au projet GitLab ;
* authentification permettant l'utilisation de l'API GitLab ;
* valeurs AWS nécessaires disponibles.

### Entrées

* TODO : URL / identifiant du projet GitLab ;
* TODO : token GitLab ;
* TODO : ARN et autres valeurs AWS ;
* TODO : arguments ou variables d'environnement.

### Fonctionnement

TODO : décrire brièvement les appels réalisés et leur ordre.

### Variables GitLab créées

TODO : lister uniquement les variables réellement créées par le script.

### Sorties

* variables CI/CD créées ou mises à jour ;
* TODO : résultat / journal de validation éventuel.

---

## Rejouer le bootstrap

TODO : préciser :

* si les scripts sont idempotents ;
* dans quels cas ils peuvent être rejoués ;
* dans quels cas il ne faut pas les rejouer ;
* comportement lorsqu'une ressource ou variable existe déjà.

## Sécurité

* aucun secret ne doit être écrit dans les logs ;
* aucun token ou credential ne doit être versionné ;
* les permissions AWS doivent rester limitées aux besoins du projet ;
* TODO : règles réellement appliquées par les scripts.
