# TO DO TOUT LE FICHIER

→ comment la sécurité fonctionne : Trivy, scans, rapports, vulnérabilités, procédure de correction.

TO DO



## Rapports de sécurité

Les scans Trivy sont exécutés automatiquement par la CI sur :
- le dépôt ;
- les images Docker ;
- l'IaC ;
- les manifests Kubernetes.

Les rapports sont disponibles dans les artifacts GitLab des jobs concernés
et conservés 30 jours.

En cas de vulnérabilité détectée :
1. ouvrir le job concerné ;
2. consulter le rapport Trivy ;
3. identifier le package/fichier et la sévérité ;
4. corriger puis relancer la pipeline.