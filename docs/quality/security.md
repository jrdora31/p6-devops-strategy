# TO DO TOUT LE FICHIER

→ comment la sécurité fonctionne : Trivy, scans, rapports, vulnérabilités, procédure de correction.

TO DO



## Rapports de sécurité

Les contrôles de sécurité sont exécutés automatiquement par la CI :
- Gitleaks recherche les secrets dans l'historique Git accessible depuis la ref ;
- Trivy recherche les vulnérabilités dans les dépendances du dépôt ;
- les images Docker ;
- l'IaC ;
- les manifests Kubernetes.

Le job `quality:gitleaks` utilise Gitleaks `v8.30.1`, bloque la pipeline lorsqu'un
secret est détecté et conserve un rapport JSON expurgé pendant 30 jours. Il
s'exécute sur les merge requests, `dev`, la branche par défaut et les tags. Les
pipelines planifiées et Web n'incluent pas les jobs `quality` généraux.

Gitleaks remplace uniquement le scan de secrets du dépôt auparavant effectué par
Trivy. Trivy reste responsable des vulnérabilités, de l'IaC, de Kubernetes et des
secrets incorporés aux images Docker ; ces derniers ne dupliquent pas le scan de
l'historique Git.

Aucune exception Gitleaks n'est configurée. Toute exception future doit viser un
faux positif précis, être justifiée en revue et ne jamais contenir de secret réel.

Les rapports sont disponibles dans les artifacts GitLab des jobs concernés
et conservés 30 jours.

En cas de secret ou de vulnérabilité détecté :
1. ouvrir le job concerné ;
2. consulter le rapport Gitleaks ou Trivy ;
3. identifier le package/fichier et la sévérité ;
4. corriger puis relancer la pipeline.
