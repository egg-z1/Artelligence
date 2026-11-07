# Artelligence Java backend bootstrap

Java 21, Spring Boot 4.1.2, Gradle Wrapper 9.8.2, and PostgreSQL 17.11.
The PostgreSQL credentials below are local development defaults only; do not use them outside a local development environment.

## Local development

```sh
cp .env.example .env
docker compose up -d postgres
set -a && . ./.env && set +a
./gradlew bootRun
```

The app listens on `http://localhost:8081`. Flyway applies migrations on startup. Hibernate uses `ddl-auto=validate` and does not create the schema.

- `/health` is a lightweight application liveness response and does not report database connectivity.
- `/actuator/health` is the Spring Actuator health endpoint and includes the configured database health indicator.

Stop the local database with `docker compose down`. Remove its persisted local data with `docker compose down -v`.

## Tests

```sh
./gradlew test
```

The integration tests use Testcontainers and a real PostgreSQL 17.11 container. Docker Desktop or another available Docker daemon must be running. They verify Flyway migration, connectivity, successful inserts, and rejection of UNIQUE, FK, and CHECK violations.

No image generation, member authentication, or application API migration is implemented in this bootstrap.
