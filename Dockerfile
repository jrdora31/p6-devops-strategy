# ATTENTION : ce Dockerfile historique propose plusieurs cibles dans un seul
# fichier. Le pipeline GitLab actuel utilise à la place les Dockerfiles runtime
# spécialisés `misc/docker/frontend.Dockerfile` et `backend.Dockerfile`.
#
# Une instruction `FROM ... AS nom` ouvre une étape indépendante. Une commande
# `docker build --target front|back|standalone` choisit la cible finale souhaitée.

# Étape de compilation Angular : Node et npm sont nécessaires pour produire les
# fichiers HTML, JavaScript et CSS, mais ne seront pas copiés dans l'image runtime.
FROM node as front-build

# Copie le projet frontend dans le système de fichiers temporaire de cette étape.
COPY ./front /src

# Toutes les instructions RUN suivantes partent maintenant de `/src`.
WORKDIR /src

# `npm ci` installe exactement le lockfile ; Angular compile ensuite l'application
# optimisée dans `dist/microcrm/browser`.
RUN npm ci \
    && npx @angular/cli build --optimization

# Étape de compilation Spring : cette image contient Gradle et un JDK complet.
FROM gradle:jdk17 as back-build

COPY ./back /src

WORKDIR /src

# Le Wrapper du dépôt choisit la version réelle de Gradle et produit le JAR.
RUN ./gradlew build

# Cible runtime frontend : repart d'une petite image Alpine sans Node.js.
FROM alpine:3.19 as front

# `--from` copie uniquement le résultat compilé depuis une étape précédente.
COPY --from=front-build /src/dist/microcrm/browser /app/front
# Caddy sert les fichiers statiques et transfère les appels `/api` au backend.
COPY misc/docker/Caddyfile /app/Caddyfile

# Installe Caddy avec le gestionnaire de paquets d'Alpine.
RUN apk add caddy

WORKDIR /app

# `EXPOSE` documente les ports prévus ; il ne publie aucun port sur l'hôte.
EXPOSE 80
EXPOSE 443

# Forme JSON : Caddy devient le processus principal du conteneur sans shell intermédiaire.
CMD ["/usr/sbin/caddy", "run"]

# Cible runtime backend : repart également d'Alpine et reçoit seulement le JAR.
FROM alpine:3.19 as back

COPY --from=back-build /src/build/libs/microcrm-0.0.1-SNAPSHOT.jar /app/back/microcrm-0.0.1-SNAPSHOT.jar

# Une JRE suffit à exécuter le JAR ; le compilateur du JDK n'est plus nécessaire.
RUN apk add openjdk21-jre-headless

WORKDIR /app

# Ce port appartient à cette variante historique. Le backend Dockerfile utilisé
# par la CI expose actuellement 8080 : il ne faut pas confondre les deux contrats.
EXPOSE 4200

CMD ["java", "-jar", "/app/back/microcrm-0.0.1-SNAPSHOT.jar"]

# Cible tout-en-un : fusionne les systèmes de fichiers frontend et backend.
# Cette approche lance plusieurs processus dans un conteneur et n'est pas celle
# retenue par le pipeline actuel, qui teste deux images séparées sur un réseau.
FROM alpine:3.19 as standalone

COPY --from=front / /
COPY --from=back / /
# Supervisor sert ici de processus parent pour démarrer Caddy et Java ensemble.
COPY misc/docker/supervisor.ini /app/supervisor.ini

RUN apk add supervisor

WORKDIR /app

# `-c` indique explicitement le fichier de configuration à supervisord.
CMD ["/usr/bin/supervisord", "-c", "/app/supervisor.ini"]



