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

The app listens on `http://localhost:8080`. Flyway applies migrations on startup. Hibernate uses `ddl-auto=validate` and does not create the schema. The `.env.example` PostgreSQL credentials are local defaults only.

- `/health` is a lightweight application liveness response and does not report database connectivity.
- `/actuator/health` is the Spring Actuator health endpoint and includes the configured database health indicator.

Stop the local database with `docker compose down`. Remove its persisted local data with `docker compose down -v`.

## Containerized local QA

The `local-qa` Compose profile builds and starts a Spring image and an isolated PostgreSQL 17.11 service. Inside the Spring container, `DB_URL` uses the Compose service DNS name `postgres`; the host `localhost` URL in `.env.example` is for `bootRun` only. The app listens on port 8080 in both the JVM and container.

Only explicitly enabling the Compose profile activates deterministic sample responses. In `local-qa`, the Azure Blob reader is replaced with three static sample images (two scenes in `QA 서재`, one uncategorized), and Azure image generation, writes, and deletes fail closed. The sample assets are served by a profile-only local endpoint. Normal execution does not activate these substitutes; the production Azure adapters remain selected and require their normal settings.

```sh
docker compose --env-file .env.example --profile local-qa -p artelligence-spring-qa up --build -d
until curl -fsS http://localhost:8080/health >/dev/null; do sleep 2; done
curl -i http://localhost:8080/health
curl -i http://localhost:8080/actuator/health
curl -i 'http://localhost:8080/api/v1/images?limit=10&offset=0'
curl -i http://localhost:8080/api/v1/works
curl -i -X OPTIONS http://localhost:8080/api/v1/works \
  -H 'Origin: http://localhost:5000' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: content-type'
docker compose --env-file .env.example --profile local-qa -p artelligence-spring-qa logs app
docker compose --env-file .env.example --profile local-qa -p artelligence-spring-qa down
```

The default REST CORS allowlist and WebSocket Origin allowlist contain `http://localhost:5000`. Set `REST_CORS_ALLOWED_ORIGINS` and `WEBSOCKET_ALLOWED_ORIGINS` independently to comma-separated exact origins when using another local Flutter web origin. REST CORS does not configure WebSocket handshakes. Port mappings can be changed with `APP_PORT`; `SERVER_PORT` stays 8080 inside the container and QA sample image URLs follow the host mapping.

Build the Flutter QA artifact with the local backend addresses, then serve `build/web` from an origin present in both allowlists:

```sh
cd ../client/artelligence
flutter build web --release \
  --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=WS_BASE_URL=ws://localhost:8080
python3 -m http.server 5000 --directory build/web
```

The current Flutter library loads health and works over REST. The generator screen still submits generation via REST; the WebSocket contract is not used by that screen. Local QA substitutes sample listing data only and deliberately disables generation and deletion. Container Apps ingress WebSocket upgrade and ingress handling of encoded delete paths remain for the later test deployment checklist.

To stop only this named QA Compose project, use its `down` command above. This removes its app/PostgreSQL containers and network while leaving the named PostgreSQL data volume. It does not stop other Compose projects or remove their containers.

### Container QA verification record

Local verification completed on 2026-11-08 with Docker Desktop and the `local-qa` profile:

- The Java 21 multi-stage image built successfully; PostgreSQL 17.11 became healthy, the app connected through Compose DNS `postgres`, and Flyway recorded migration `1:initial schema:success`.
- `/health` returned 200 with the Flutter-required `status`, `timestamp` (UTC `Z`), and `service` fields; `/actuator/health` returned `UP`. `/api/v1/images` returned three sample records, and `/api/v1/works` returned two works with three scenes total. Chrome showed both work cards and scene counts of one and two. Thumbnail areas appeared black in this browser session; direct GET returned a valid 48×64 PNG (166 bytes), and a Java `ImageIO` test decoded it successfully.
- REST CORS preflight returned 200 with the exact allowed origin and 403 for a disallowed origin. A real WebSocket handshake returned 101 for the allowed origin and 403 for the disallowed origin.
- `flutter build web --release` completed with `API_BASE_URL=http://localhost:8080` and `WS_BASE_URL=ws://localhost:8080`. The Flutter `ApiService` decoded two works and three images. Chrome showed the work counts, and its WebSocket connected successfully once the container was ready. A WebSocket reconnect error was also observed during container restart; this was transient and not treated as an ingress test. The REST CORS preflight and WebSocket Origin allow/deny handshakes were verified separately.
- `local-qa` generation returned 502 from its explicit fail-closed substitute and deletion returned 503; neither uses Azure. The complete `./gradlew test` suite passed, including PostgreSQL Testcontainers integration tests and PNG fixture decoding.

The machine's port 5000 was already occupied, so this run used `http://localhost:5101` as the Flutter Origin and overrode both origin variables independently. No Azure credentials or Azure calls were used. This local check does not verify Azure Container Apps ingress, WebSocket forwarding through ingress, or encoded delete path normalization there.

## Tests

```sh
./gradlew test
```

The integration tests use Testcontainers and a real PostgreSQL 17.11 container. Docker Desktop or another available Docker daemon must be running. They verify Flyway migration, connectivity, successful inserts, and rejection of UNIQUE, FK, and CHECK violations.

## Image generation API (development scope)

`POST /api/v1/generate` accepts the existing Flutter request fields: `prompt`, `size`, `quality`, `style`, `work_title`, and `excerpt`. The prompt is trimmed before checking its 10–4000 character range. `style` remains accepted for request compatibility but is deliberately ignored by generation. Idempotency is deferred to the later generation-job work, so retrying the same request can create another image and another provider charge.

Supported values follow the Flutter contract:

| Field | Values | Default | Provider mapping |
| --- | --- | --- | --- |
| `size` | `1024x1024`, `1792x1024`, `1024x1792` | `1024x1024` | `1024x1024`, `1536x1024`, `1024x1536` |
| `quality` | `standard`, `hd` | `standard` | `medium`, `high` |

Other `size` or `quality` values receive HTTP 422. The response retains the Flutter fields (`image_id`, `image_url`, `blob_url`, `prompt`, `work_title`, `excerpt`, `created_at`, `status`). `created_at` is emitted as UTC ISO-8601 with `Z`; Flutter parses it as `DateTime` and formats it in local time. Error responses retain the JSON `detail` field parsed by Flutter: validation is 422, generation/provider failure is 502, generation timeout is 504, and storage unavailability is 503 (storage timeout is 504).

The provider call has a 120-second timeout and SDK retries disabled (`maxRetries(0)`). Each Blob operation has a 15-second request timeout and one SDK attempt. The normal path has three Blob calls (container existence, image upload, sidecar upload), so its configured call budget plus generation is about 165 seconds. A failed sidecar write can trigger up to roughly 85 seconds of ownership checks and conditional cleanup on top of the normal work, for an estimated upper call budget around 250 seconds. Multipart uploads and remote completion after timeout are not bounded by one application-wide deadline. Flutter's request timeout is 3 minutes, so it can stop waiting before compensation finishes. An SDK timeout or thread interruption does not prove Azure canceled a request; a late Blob commit can outlive the immediate cleanup check. There is no durable reconciliation worker yet, so such a late commit may leave an orphan. The configured Blob container must already exist; requests never create it. A request UUID identifies the image path and ownership metadata. The image and JSON sidecar use that path, and a failed or uncertain save triggers a best-effort cleanup of only blobs whose ownership metadata matches that request UUID. Deletes also use the observed ETag as an `If-Match` condition. Cleanup failures log only the request ID and blob path and never return success.

The response is serialized before Spring begins writing the HTTP body. If SAS issuance fails after both writes, the request is treated as a storage-stage failure and cleanup is attempted. If local response serialization fails after both writes and SAS creation, the API returns a safe 500 and preserves the completed image. If the client disconnects while Spring is sending the already-serialized bytes, that occurs outside the generation service; the image is also preserved and the server cannot reliably know whether the client received the full response.

The local Azure settings use a GPT-image deployment family. Spring therefore uses the Azure `/openai/v1/images/generations` route, with the deployment in the request body and Azure API-key authentication. The existing FastAPI still configures the legacy `2024-02-01` API version; that legacy version/path differs from the documented GPT-image v1 route. Spring intentionally follows the GPT-image v1 contract. The exact remote deployment availability and account access were not exercised.

Set `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_API_KEY`, `AZURE_OPENAI_DEPLOYMENT_NAME`, and the existing `AZURE_STORAGE_CONNECTION_STRING` / `AZURE_STORAGE_CONTAINER_NAME` to use the API locally. Do not put credentials in source control. Automated tests use a local HTTP mock server and SDK mocks; they do not call Azure. No actual image-generation request has been made as part of this change.

Member authentication and database-backed generation jobs/credits are not implemented. The generation endpoint does not yet provide idempotency or durable tracking of ambiguous provider outcomes.

## Image deletion API (development scope)

`DELETE /api/v1/images/{image_path}` supports the existing generated path shape `YYYYMMDD/<UUID>.png`, including slash-containing and URL-encoded paths. Embedded Tomcat decodes an encoded slash once; the application validator does not decode a second time and rejects any residual `%`. It validates the canonical path before deriving the sidecar name; direct `.json` paths and other extensions are rejected. Validation limits the target path but does not verify member ownership. Authentication and per-member ownership checks remain future work. A production reverse proxy or ingress was not tested and must preserve compatible path decoding before this endpoint is exposed.

The API deletes the image first and then its derived `.json` sidecar. If only one exists, it deletes that one; if neither exists, it returns 404. Container, authentication, and transport failures return 503, and an ETag precondition conflict returns 409 without deleting the changed Blob. An uncertain/partial deletion is not reported as success; retrying the same path re-reads both exact targets and can clean up the remainder. Unit and HTTP tests use mocks and do not delete Azure data. Any real Azure deletion check must be separately limited to an explicitly designated test image.
