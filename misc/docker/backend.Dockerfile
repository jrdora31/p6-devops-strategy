# Image runtime Java 21 : une JRE exécute le JAR sans embarquer les outils de
# compilation du JDK. Le digest rend l'image de base reproductible.
FROM eclipse-temurin:21.0.11_10-jre-alpine-3.23@sha256:3f08b13888f595cc49edabea7250ba69499ba25602b267da591720769400e08c

# Crée un groupe et un utilisateur système sans mot de passe ni session normale.
# L'application n'a ainsi pas besoin des privilèges `root` dans le conteneur.
RUN addgroup -S microcrm \
    && adduser -S -G microcrm microcrm

# Le JAR a déjà été produit par `build:backend`. `--chown` donne immédiatement
# sa propriété à l'utilisateur applicatif, sans ajouter une couche `chown` séparée.
COPY --chown=microcrm:microcrm back/build/libs/microcrm-0.0.1-SNAPSHOT.jar /app/microcrm.jar

# Toutes les instructions d'exécution suivantes et le processus Java utilisent
# l'identité non privilégiée `microcrm`.
USER microcrm
WORKDIR /app

# Documente le port HTTP Spring Boot attendu par Caddy et le smoke test.
EXPOSE 8080

# Interroge la racine HTTP depuis le conteneur. Les temporisations laissent à la
# JVM le temps de démarrer avant de considérer l'image comme défaillante.
HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=3 \
    CMD wget --quiet --output-document=- http://127.0.0.1:8080/ >/dev/null || exit 1

# `ENTRYPOINT` fixe Java comme processus principal (PID 1). Les éventuels
# arguments de `docker run` seraient ajoutés après cette commande.
ENTRYPOINT ["java", "-jar", "/app/microcrm.jar"]
