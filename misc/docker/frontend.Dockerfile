# Image runtime déjà équipée de Caddy. Le tag donne une version lisible et le
# digest garantit que le contenu téléchargé restera strictement identique.
FROM caddy:2.11.4-alpine@sha256:5f5c8640aae01df9654968d946d8f1a56c497f1dd5c5cda4cf95ab7c14d58648

# Le job `build:frontend` a déjà compilé Angular : cette image ne contient donc
# ni Node.js, ni npm, ni le code source TypeScript.
COPY front/dist/microcrm/browser/ /app/front/
# Remplace la configuration Caddy par celle du projet : fichiers statiques pour
# le frontend et reverse proxy `/api` vers le conteneur nommé `backend`.
COPY misc/docker/Caddyfile /etc/caddy/Caddyfile

# Dossier de travail par défaut pour les commandes lancées dans le conteneur.
WORKDIR /app

# Métadonnée indiquant que l'application écoute en HTTP sur le port 80.
# Le port n'est réellement publié que par `docker run -p` ou un orchestrateur.
EXPOSE 80

# Docker vérifie périodiquement que Caddy répond depuis l'intérieur du conteneur.
# - interval : délai entre deux contrôles ; timeout : durée maximale d'un contrôle ;
# - start-period : temps de démarrage toléré ; retries : échecs avant `unhealthy` ;
# - `wget` jette le contenu de la page : seul son code retour est utilisé ;
# - `exit 1` transforme tout échec HTTP ou réseau en échec du contrôle de santé.
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --output-document=- http://127.0.0.1/ >/dev/null || exit 1
