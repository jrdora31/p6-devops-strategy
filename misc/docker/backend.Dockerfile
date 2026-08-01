FROM eclipse-temurin:21.0.11_10-jre-alpine-3.23@sha256:3f08b13888f595cc49edabea7250ba69499ba25602b267da591720769400e08c

RUN addgroup -S microcrm \
    && adduser -S -G microcrm microcrm

COPY --chown=microcrm:microcrm back/build/libs/microcrm-0.0.1-SNAPSHOT.jar /app/microcrm.jar

USER microcrm
WORKDIR /app

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=3 \
    CMD wget --quiet --output-document=- http://127.0.0.1:8080/ >/dev/null || exit 1

ENTRYPOINT ["java", "-jar", "/app/microcrm.jar"]
