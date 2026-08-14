# Mise à jour des dépendances

Ce document décrit la maintenance des dépendances de MicroCRM : fréquence des contrôles, ordre de priorité, procédure de mise à jour et validations à effectuer.

## Fréquence de contrôle

| Moment                        | Objectif                                       | Actions                                               |
| ----------------------------- | ---------------------------------------------- | ----------------------------------------------------- |
| Pendant le développement      | Détecter les régressions liées aux dépendances | Tests concernés                                       |
| Avant une livraison           | Valider un état stable                         | Tests, builds et scans                                |
| Périodiquement                | Éviter l'accumulation de dette technique       | Vérification des dépendances obsolètes et vulnérables |
| Avant une mise à jour majeure | Identifier les impacts potentiels              | Documentation de version, compatibilités et tests     |

TODO : définir la fréquence périodique retenue pour MicroCRM.

## Périmètre

Les dépendances à maintenir concernent notamment :

* Frontend : Angular, TypeScript, npm et dépendances associées ;
* Backend : Java, Spring Boot, Gradle et dépendances associées ;
* Infrastructure : Terraform et providers ;
* Configuration : Ansible et collections/rôles éventuels ;
* Déploiement : Helm, charts et K3s ;
* images Docker utilisées par le projet ;
* outils CI/CD et de qualité.

## Diagnostic

### Frontend

Depuis `front/` :

```bash
npm outdated
npm audit
```

TODO : compléter avec les contrôles réellement utilisés par MicroCRM.

### Backend

Depuis `back/` :

```text
TODO : commande permettant d'identifier les dépendances Gradle obsolètes.
```

### Infrastructure

TODO : documenter les contrôles de versions réellement utilisés pour :

* Terraform ;
* providers Terraform ;
* Ansible ;
* Helm ;
* K3s ;
* images Docker.

## Ordre de priorité

Traiter les mises à jour dans l'ordre suivant :

1. vulnérabilités critiques ou élevées affectant la production ;
2. vulnérabilités affectant les outils de développement ou la CI/CD ;
3. correctifs de sécurité ;
4. mises à jour patch ;
5. mises à jour mineures ;
6. mises à jour majeures.

Les mises à jour majeures doivent être isolées et validées séparément.

## Procédure de mise à jour

### 1. Isoler le changement

Pour une mise à jour importante, utiliser une branche dédiée.

```bash
git checkout -b maintenance/update-dependencies-YYYY-MM-DD
```

### 2. Identifier les changements

* identifier la version actuelle ;
* identifier la version cible ;
* consulter les changements incompatibles éventuels ;
* vérifier les dépendances liées ;
* déterminer les composants MicroCRM impactés.

### 3. Effectuer la mise à jour

Mettre à jour un composant ou un groupe cohérent de dépendances à la fois.

Éviter de regrouper plusieurs mises à jour majeures indépendantes dans une même modification.

TODO : ajouter les commandes propres à chaque composant lorsque la procédure sera vérifiée.

## Validation

Après une mise à jour, vérifier au minimum :

### Frontend

TODO : tests et build Angular réellement utilisés.

### Backend

TODO : tests et build Spring Boot/Gradle réellement utilisés.

### Infrastructure

Selon le composant modifié :

```text
Terraform  → terraform validate / plan
Ansible    → TODO
Helm       → TODO
```

### CI/CD

Vérifier que la pipeline complète reste valide lorsque la modification est destinée à être intégrée.

### Sécurité

Vérifier que les scans de sécurité ne remontent pas de nouvelle vulnérabilité bloquante.

Voir [`../quality/security.md`](../quality/security.md).

## Risques principaux

| Composant                   | Risque principal                                   | Vérification                 |
| --------------------------- | -------------------------------------------------- | ---------------------------- |
| Angular / TypeScript        | incompatibilité ou régression frontend             | tests + build frontend       |
| Spring Boot / Java / Gradle | incompatibilité API ou compilation                 | tests + build backend        |
| Terraform / providers       | modification du plan d'infrastructure              | `terraform plan`             |
| Ansible                     | changement de configuration des instances/K3s      | validation du déploiement    |
| Helm                        | modification involontaire des workloads Kubernetes | vérification Helm/K3s        |
| K3s                         | incompatibilité cluster / workloads                | vérification nodes et pods   |
| Images Docker               | changement de runtime ou de comportement           | build + exécution + pipeline |

## Après mise à jour

Une mise à jour est considérée comme validée lorsque :

* les tests concernés passent ;
* les builds concernés passent ;
* les contrôles de sécurité sont acceptables ;
* aucune modification d'infrastructure inattendue n'apparaît ;
* le déploiement reste fonctionnel si la dépendance concerne l'infrastructure ou la CI/CD.

## État connu

TODO : renseigner uniquement lorsqu'un contrôle complet des dépendances MicroCRM aura été réalisé.

Exemple :

```text
Dernier contrôle : YYYY-MM-DD

Frontend :
- ...

Backend :
- ...

Infrastructure :
- ...

Vulnérabilités connues :
- ...
```
