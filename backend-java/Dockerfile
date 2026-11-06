# Сборка: Maven → один исполняемый jar
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml ./
RUN mvn -B -q dependency:go-offline
COPY src ./src
RUN mvn -B -q -DskipTests package

# Рабочий образ: только JRE и jar. Миграции (Flyway) лежат внутри jar и применяются при старте
FROM eclipse-temurin:21-jre
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/* \
    && useradd --system --uid 1001 app
# UTF-8 обязателен: иначе файлы с кириллицей в названии не открываются
ENV LANG=C.UTF-8 \
    APP_ENV=production \
    JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75"
WORKDIR /app
COPY --from=build /app/target/mumusic-api.jar ./mumusic-api.jar
USER app
EXPOSE 5050
HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=3 \
  CMD curl -fs http://127.0.0.1:5050/health || exit 1
ENTRYPOINT ["java", "-jar", "/app/mumusic-api.jar"]
