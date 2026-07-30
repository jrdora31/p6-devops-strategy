FROM eclipse-temurin:21.0.10_7-jre-alpine-3.22

RUN addgroup -S microcrm \
    && adduser -S -G microcrm microcrm

COPY --chown=microcrm:microcrm back/build/libs/microcrm-0.0.1-SNAPSHOT.jar /app/microcrm.jar

USER microcrm
WORKDIR /app

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/microcrm.jar"]
