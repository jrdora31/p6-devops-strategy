# Image runtime déjà équipée de Caddy. Le tag donne une version lisible et le
# digest garantit que le contenu téléchargé restera strictement identique.
FROM caddy:2.11.4-alpine@sha256:5f5c8640aae01df9654968d946d8f1a56c497f1dd5c5cda4cf95ab7c14d58648

# L'image officielle ne définit pas d'utilisateur applicatif. Celui-ci est créé
# explicitement afin que Caddy ne s'exécute pas avec l'identité root. Le binaire
# Caddy fourni par l'image possède déjà la capacité nécessaire pour écouter sur
# le port privilégié 80.
RUN addgroup -S microcrm \
    && adduser -S -D -H -G microcrm microcrm

# Le job `build:frontend` a déjà compilé Angular : cette image ne contient donc
# ni Node.js, ni npm, ni le code source TypeScript.
COPY --chown=microcrm:microcrm front/dist/microcrm/browser/ /app/front/
# Remplace la configuration Caddy par celle du projet : fichiers statiques pour
# le frontend et reverse proxy `/api` vers le conteneur nommé `backend`.
COPY --chown=microcrm:microcrm misc/docker/Caddyfile /etc/caddy/Caddyfile

# Dossier de travail par défaut pour les commandes lancées dans le conteneur.
WORKDIR /app

# Les commandes suivantes, le healthcheck et le processus Caddy utilisent ce
# compte sans privilège. Les dossiers `/data` et `/config` de l'image officielle
# sont déjà accessibles en écriture et le contenu statique reste lisible.
USER microcrm

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
