# Scripts CI/CD

Référence technique des scripts utilisés par la chaîne CI/CD de MicroCRM.

> Pour l'ordre des stages, jobs et conditions d'exécution de la pipeline, voir `docs/ci-cd/pipeline.md`.

## Vue d'ensemble

| Script                | Responsabilité                                            | Exécution           |
| --------------------- | --------------------------------------------------------- | ------------------- |
| `build.sh`            | Build du projet                                           | CI/CD               |
| `test.sh`             | Exécution des tests applicatifs                           | CI/CD               |
| `smoke.sh`            | Smoke tests après déploiement                             | CI/CD               |
| `dependencies.sh`     | Contrôle des dépendances                                  | CI/CD               |
| `backup.sh`           | Sauvegarde liée au processus de déploiement / maintenance | CI/CD / maintenance |
| `dora_metrics.py`     | Collecte ou calcul des métriques DORA                     | CI/CD               |
| `release_manifest.py` | Gestion des informations de release                       | CI/CD               |
| `notify.py`           | Notifications liées à la pipeline                         | CI/CD               |
| `common.sh`           | Fonctions communes aux scripts shell                      | Scripts CI          |

> Les rôles doivent être ajustés selon le comportement réel des scripts.

---

## `build.sh`

### Rôle

TODO : décrire précisément les composants construits.

### Dépendances

TODO

### Entrées

TODO : variables CI/CD, arguments ou fichiers utilisés.

### Fonctionnement

TODO : décrire les principales étapes exécutées.

### Sorties

TODO : artefacts, images ou fichiers générés.

### Conditions d'exécution

TODO : stage, job, branche ou tag concerné.

---

## `test.sh`

### Rôle

TODO : décrire les tests applicatifs exécutés par le script.

### Dépendances

TODO

### Entrées

TODO

### Fonctionnement

TODO

### Sorties

TODO : rapports, résultats ou codes de retour.

### Conditions d'exécution

TODO

---

## `smoke.sh`

### Rôle

Valide rapidement le fonctionnement du service après déploiement.

### Dépendances

TODO

### Entrées

TODO : URL, endpoint ou variables nécessaires.

### Vérifications

TODO : endpoints ou comportements réellement contrôlés.

### Critères de réussite

TODO

### Conditions d'exécution

TODO

---

## `dependencies.sh`

### Rôle

Contrôle les dépendances utilisées par le projet.

### Dépendances

TODO

### Entrées

TODO

### Contrôles

TODO : versions, vulnérabilités ou autres vérifications réellement effectuées.

### Sorties

TODO

### Conditions d'exécution

TODO

> La stratégie de maintenance des dépendances est documentée dans `docs/Maintenance/dependency-updates.md`.

---

## `backup.sh`

### Rôle

TODO : décrire précisément ce qui est sauvegardé et à quel moment.

### Dépendances

TODO

### Entrées

TODO

### Fonctionnement

TODO

### Sorties

TODO : emplacement, format ou artefact de sauvegarde généré.

### Conditions d'exécution

TODO

> La stratégie de sauvegarde et de restauration est documentée dans `docs/Maintenance/backup-recovery.md`.

---

## `dora_metrics.py`

### Rôle

Collecte ou calcule les métriques DORA utilisées pour suivre la performance de la chaîne de livraison.

### Dépendances

TODO

### Entrées

TODO : données GitLab, historique des pipelines, variables ou fichiers utilisés.

### Métriques produites

TODO : lister uniquement les métriques réellement calculées.

### Fonctionnement

TODO

### Sorties

TODO : JSON, artefact, logs ou autres données générées.

### Conditions d'exécution

TODO

> L'interprétation des métriques DORA est documentée dans `docs/quality/performance.md`.

---

## `release_manifest.py`

### Rôle

TODO : décrire le rôle du manifeste de release.

### Dépendances

TODO

### Entrées

TODO

### Fonctionnement

TODO

### Sorties

TODO

### Conditions d'exécution

TODO

---

## `notify.py`

### Rôle

TODO : préciser les événements concernés et le type de notification produit.

### Dépendances

TODO

### Entrées

TODO

### Fonctionnement

TODO

### Sorties

TODO

### Conditions d'exécution

TODO

---

## `common.sh`

### Rôle

Centralise les fonctions et comportements communs utilisés par les scripts shell de la CI/CD.

### Utilisé par

TODO : lister les scripts qui chargent réellement `common.sh`.

### Fonctions principales

TODO : lister uniquement les fonctions utiles à connaître.

### Variables communes

TODO

---

# Tests des scripts CI/CD

Les tests automatisés des scripts CI/CD sont regroupés dans :

```text
scripts/ci/tests/
```

## Vue d'ensemble

| Fichier                        | Responsabilité                                         |
| ------------------------------ | ------------------------------------------------------ |
| `tests/test_dora_metrics.py`   | Tests automatisés de `dora_metrics.py`                 |
| `tests/test_python_scripts.py` | Tests des scripts Python de la CI/CD                   |
| `tests/test_scripts.sh`        | Tests des scripts shell de la CI/CD                    |
| `requirements-test.txt`        | Dépendances Python nécessaires à l'exécution des tests |

---

## `tests/test_dora_metrics.py`

### Rôle

Valide le comportement du calcul et de la génération des métriques DORA.

### Cible

```text
dora_metrics.py
```

### Scénarios testés

TODO : lister les comportements réellement vérifiés.

### Dépendances

TODO

### Exécution

```bash
TODO
```

### Critères de réussite

TODO

---

## `tests/test_python_scripts.py`

### Rôle

Valide le comportement des scripts Python utilisés par la CI/CD.

### Scripts couverts

TODO : confirmer les scripts réellement couverts, par exemple :

* `notify.py`
* `release_manifest.py`

### Scénarios testés

TODO

### Dépendances

TODO

### Exécution

```bash
TODO
```

### Critères de réussite

TODO

---

## `tests/test_scripts.sh`

### Rôle

Valide le comportement des scripts shell utilisés par la CI/CD.

### Scripts couverts

TODO : confirmer les scripts réellement couverts, par exemple :

* `build.sh`
* `test.sh`
* `smoke.sh`
* `dependencies.sh`
* `backup.sh`
* `common.sh`

### Scénarios testés

TODO

### Dépendances

TODO

### Exécution

```bash
TODO
```

### Critères de réussite

TODO

---

# Dépendances de test

## `requirements-test.txt`

### Rôle

Déclare les dépendances Python nécessaires à l'exécution des tests des scripts CI/CD.

Ces dépendances concernent uniquement les tests des scripts et ne font pas partie des dépendances applicatives de MicroCRM.

### Installation

Depuis `scripts/ci/` :

```bash
pip install -r requirements-test.txt
```

TODO : confirmer le dossier d'exécution réel.

### Utilisation

TODO : préciser quels fichiers de tests utilisent ces dépendances.

---

# Validation des scripts

Les scripts sont considérés comme valides lorsque :

* les tests Python réussissent ;
* les tests shell réussissent ;
* les erreurs attendues provoquent un code de sortie non nul ;
* les cas critiques sont couverts ;
* aucun secret n'est exposé dans les logs ou les sorties de test ;
* la pipeline utilisant ces scripts reste fonctionnelle.

---

# Conventions

* ne jamais écrire de secret dans les logs ;
* échouer explicitement lorsqu'une dépendance ou une variable obligatoire manque ;
* retourner un code de sortie non nul en cas d'échec ;
* centraliser dans `common.sh` les fonctions shell réellement partagées ;
* documenter les paramètres obligatoires et leurs valeurs attendues ;
* TODO : ajouter les autres conventions réellement appliquées dans MicroCRM.
