# Déploiement Helm et plan de conteneurs

Ce document décrit les conteneurs qui composent MicroCRM et la manière dont
Helm les configure et les déploie dans K3s.

## 1. Rôle de Helm dans MicroCRM

TODO : expliquer le rôle du chart `helm/microcrm` et préciser ce qui relève de
Helm, de Docker, d'Ansible et de GitLab CI/CD.

## 2. Architecture des conteneurs

TODO : présenter les conteneurs et leurs relations.

```text
Utilisateur
    ↓
Frontend Caddy
    ↓
Backend Spring Boot
    ↓
PostgreSQL
```

TODO : accompagner tout diagramme d'une description textuelle accessible.

## 3. Conteneur frontend

TODO : documenter :

- le rôle du frontend ;
- l'image utilisée ;
- le nombre de réplicas ;
- le port exposé ;
- les ressources CPU et mémoire ;
- les vérifications de santé ;
- la communication avec le backend.

## 4. Conteneur backend

TODO : documenter :

- le rôle du backend ;
- l'image et la version Java utilisées ;
- le nombre de réplicas ;
- le port exposé ;
- les ressources CPU et mémoire ;
- les vérifications de santé ;
- la connexion à PostgreSQL.

## 5. Conteneur PostgreSQL

TODO : documenter :

- l'image utilisée ;
- le StatefulSet et le Service ;
- le port exposé ;
- le volume persistant ;
- les ressources CPU et mémoire ;
- les vérifications de santé ;
- la gestion des identifiants par Secret ;
- les limites actuelles de sauvegarde et de restauration.

## 6. Services et communications

TODO : expliquer :

- les Services frontend, backend et PostgreSQL ;
- le routage réalisé par l'Ingress ;
- les flux autorisés entre les conteneurs ;
- les restrictions définies par les NetworkPolicies.

## 7. Gestion des images

TODO : préciser :

- les repositories du GitLab Container Registry ;
- l'identification des images par commit ;
- le déploiement par digest ;
- la politique de récupération des images ;
- le Secret utilisé pour accéder au registre.

La construction, les scans et la publication des images sont décrits dans la
documentation CI/CD. Cette section couvre uniquement leur utilisation par
Helm.

## 8. Configuration des environnements

TODO : distinguer clairement :

- les valeurs communes de `values.yaml` ;
- les valeurs de staging ;
- les valeurs de production ;
- les namespaces ;
- les noms de release et les hôtes ;
- les éléments identiques et différents entre les environnements.

## 9. Déploiement et mise à jour

TODO : expliquer le déroulement du déploiement Helm :

1. récupération du package Helm ;
2. injection des images et Secrets attendus ;
3. exécution de `helm upgrade --install` ;
4. attente de l'état opérationnel ;
5. création d'une nouvelle révision Helm ;
6. comportement de `--atomic` en cas d'échec.

## 10. Vérification du déploiement

TODO : ajouter uniquement les commandes réellement utilisées pour vérifier :

- l'état de la release Helm ;
- l'historique des révisions ;
- l'état des pods ;
- les Services et l'Ingress ;
- les événements Kubernetes ;
- les vérifications de santé applicatives.

## 11. Limites du POC actuel

TODO : documenter sans les présenter comme des fonctionnalités réalisées :

- l'absence de haute disponibilité ;
- le nombre actuel de réplicas ;
- le stockage PostgreSQL local ;
- l'état réel de la sauvegarde et de la restauration ;
- les limites réseau et TLS ;
- les mécanismes prévus mais non encore implémentés.

## 12. Évolutions envisagées

TODO : présenter séparément les évolutions validées ou proposées, avec leurs
conditions préalables, notamment :

- l'évolution du nombre de réplicas ;
- la stratégie de déploiement progressive ;
- la promotion d'images immuables entre environnements ;
- les mécanismes de disponibilité et de restauration.

Ne pas confondre ces évolutions avec l'état réellement implémenté dans le POC.

## 13. Références techniques

TODO : ajouter les liens relatifs vers :

- le chart et ses fichiers de valeurs ;
- la pipeline de déploiement ;
- la stratégie de release ;
- la procédure de rollback ;
- la procédure de sauvegarde et de restauration.

plan de conteneur à faire ici aussi.
