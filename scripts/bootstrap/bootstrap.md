# Bootstrap initial

Ces scripts préparent les accès AWS et la configuration GitLab nécessaires à
la première mise en service de MicroCRM. Les secrets sont lus depuis
l'environnement d'exécution et ne sont ni écrits dans le dépôt ni affichés.

## Vue d'ensemble

```text
bootstrap.py
    ├── bootstrap-aws.py
    │     └── rôles AWS IAM/OIDC et ARN associés
    └── bootstrap-gitlab.py
          └── variables CI/CD et protection des tags
```

| Script | Responsabilité | Appelé par |
| --- | --- | --- |
| `bootstrap.py` | Contrôle les prérequis et orchestre le bootstrap complet | administrateur du projet |
| `bootstrap-aws.py` | Prépare la confiance OIDC et les rôles AWS de plan/application | `bootstrap.py` |
| `bootstrap-gitlab.py` | Configure les variables CI/CD et la protection des releases | `bootstrap.py` |

## Orchestrateur : `bootstrap.py`

```bash
python scripts/bootstrap/bootstrap.py
```

| Élément | Détail |
| --- | --- |
| Fonction | Fournir un point d'entrée unique pour préparer les accès AWS puis configurer GitLab dans le bon ordre. |
| Paramètres | Aucun argument en ligne de commande. |
| Variables | Reprend les variables AWS et GitLab décrites dans les deux scripts spécialisés. |
| Prérequis | Python 3, authentification AWS valide, accès administrateur au projet GitLab et clients API disposant de droits minimaux. |
| Fonctionnement | Vérifie les prérequis, exécute le bootstrap AWS, transmet les ARN obtenus au bootstrap GitLab puis contrôle le résultat global. |
| Effets et sorties | Produit un compte rendu des ressources lues, créées ou déjà conformes, sans afficher de secret. |
| Erreurs | Code `0` si les deux étapes aboutissent ; code non nul au premier échec afin d'éviter une configuration partielle. |

## Accès AWS : `bootstrap-aws.py`

```bash
AWS_REGION=eu-west-3 \
AWS_ACCOUNT_ID=123456789012 \
GITLAB_PROJECT_PATH=groupe/microcrm \
python scripts/bootstrap/bootstrap-aws.py
```

| Élément | Détail |
| --- | --- |
| Fonction | Permettre aux jobs Terraform de s'authentifier sur AWS avec des rôles séparés, sans clé d'accès statique. |
| Paramètres | Aucun argument ; la configuration est fournie par l'environnement. |
| Variables d'entrée | `AWS_REGION`, `AWS_ACCOUNT_ID` et `GITLAB_PROJECT_PATH`. Les credentials AWS temporaires suivent la chaîne standard du SDK/CLI AWS. |
| Prérequis | Python 3, API AWS IAM/STS, session AWS autorisée à lire l'identité, le fournisseur OIDC, les rôles et leurs policies. |
| Fonctionnement | Vérifie le compte AWS, crée ou contrôle la confiance OIDC GitLab, limite les conditions `sub`/`aud`, puis prépare deux rôles distincts pour `terraform plan` et `terraform apply`. |
| Effets et sorties | Retourne les ARN destinés à `AWS_PLAN_ROLE_ARN` et `AWS_APPLY_ROLE_ARN`. Ne crée aucune clé d'accès statique et ne gère pas les ressources applicatives Terraform. |
| Erreurs | Code non nul si l'identité AWS est inattendue, si une permission manque, si la confiance OIDC est trop large ou si une policy existante diverge. |

## Configuration GitLab : `bootstrap-gitlab.py`

```bash
GITLAB_URL=https://gitlab.com \
GITLAB_PROJECT_ID=12345678 \
GITLAB_TOKEN='***' \
AWS_PLAN_ROLE_ARN='arn:aws:iam::123456789012:role/...' \
AWS_APPLY_ROLE_ARN='arn:aws:iam::123456789012:role/...' \
python scripts/bootstrap/bootstrap-gitlab.py
```

| Élément | Détail |
| --- | --- |
| Fonction | Centraliser dans GitLab les accès et secrets nécessaires à la CI/CD, puis protéger la création des tags de release. |
| Paramètres | Aucun argument ; l'URL, le projet, le token et les valeurs CI/CD sont fournis par l'environnement. |
| Variables d'accès | `GITLAB_URL`, `GITLAB_PROJECT_ID` et `GITLAB_TOKEN`. Le token doit permettre la gestion des variables et des tags protégés du projet. |
| Prérequis | Python 3, accès HTTPS à l'API GitLab, projet existant et ARN AWS disponibles. |
| Fonctionnement | Lit les variables/protections existantes, crée les éléments absents, vérifie leur masquage/protection et conserve les éléments déjà conformes. |
| Effets et sorties | Configure les variables listées ci-dessous et garantit que seuls les Maintainers peuvent créer les tags `v*`. Le rapport final indique les créations, conformités et écarts sans révéler les valeurs. |
| Erreurs | Code non nul si le token est insuffisant, si une valeur requise manque, si un secret ne peut pas être masqué ou si une règle existante est conflictuelle. Aucune protection n'est supprimée automatiquement. |

### Variables CI/CD gérées

| Variable | Traitement |
| --- | --- |
| `AWS_PLAN_ROLE_ARN`, `AWS_APPLY_ROLE_ARN` | variables protégées contenant les ARN OIDC |
| `GITLAB_AGENT_TOKEN` | secret masqué et protégé |
| `SLACK_WEBHOOK_URL` | secret masqué et protégé |
| `KUBERNETES_DATABASE_PASSWORD` | secret masqué et protégé |
| `KUBERNETES_MONITORING_PASSWORD` | secret masqué et protégé |
| `SONAR_TOKEN`, `DORA_GITLAB_TOKEN` | secrets masqués, protégés selon les refs autorisées |
| `CI_DEPLOY_USER`, `CI_DEPLOY_PASSWORD` | identifiants du deploy token Registry ; mot de passe masqué |

Les variables prédéfinies GitLab et les options non secrètes déjà déclarées
dans `.gitlab-ci.yml` ne sont pas dupliquées.

## Rejouabilité et sécurité

- Chaque étape lit l'existant avant de créer ou modifier une configuration.
- Une ressource conforme est conservée ; un écart est signalé sans suppression
  automatique.
- Aucun token, credential ou contenu de webhook n'est écrit dans les logs.
- Les permissions AWS sont séparées entre lecture/plan et application.
- Les variables sensibles sont masquées et protégées selon leur périmètre.
- La protection `v*` limite la création des releases aux Maintainers.

## Séquence d'exécution

1. Authentifier la session d'administration AWS et GitLab.
2. Exécuter `bootstrap.py` depuis la racine du dépôt.
3. Contrôler les ARN, variables, attributs de protection et règle `v*` dans le
   rapport final.
4. Lancer une pipeline de validation sans afficher les valeurs sensibles.

La procédure complète de déploiement est décrite dans
[Démarrer MicroCRM](../../docs/GET-STARTED.md).
