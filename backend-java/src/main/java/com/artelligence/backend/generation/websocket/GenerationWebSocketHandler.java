package com.artelligence.backend.generation.websocket;

import com.artelligence.backend.generation.GenerateImageRequest;
import com.artelligence.backend.generation.GenerateImageResponse;
import com.artelligence.backend.generation.GenerationException;
import com.artelligence.backend.generation.GenerationResponseException;
import com.artelligence.backend.generation.GenerationService;
import com.artelligence.backend.generation.GenerationStage;
import com.artelligence.backend.generation.GenerationStorageException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import jakarta.annotation.PreDestroy;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validator;
import java.io.IOException;
import java.net.URI;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Semaphore;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

/** Raw JSON WebSocket contract retained for the existing Flutter client. */
@Component
public class GenerationWebSocketHandler extends TextWebSocketHandler {
    private static final Logger log = LoggerFactory.getLogger(GenerationWebSocketHandler.class);
    private static final int WORKERS = 2;
    private static final int QUEUE_CAPACITY = 8;
    private static final int MAX_ACCEPTED_WORK = WORKERS + QUEUE_CAPACITY;
    private final GenerationService generationService;
    private final ObjectMapper mapper;
    private final Validator validator;
    private final Semaphore capacity = new Semaphore(MAX_ACCEPTED_WORK);
    private final ThreadPoolExecutor executor = new ThreadPoolExecutor(
            WORKERS, WORKERS, 0L, TimeUnit.MILLISECONDS, new ArrayBlockingQueue<>(QUEUE_CAPACITY),
            runnable -> {
                Thread thread = new Thread(runnable, "generation-websocket-worker");
                thread.setDaemon(true);
                return thread;
            }, new ThreadPoolExecutor.AbortPolicy());
    private final Map<String, Connection> connectionsByClient = new ConcurrentHashMap<>();
    private final Map<String, Connection> connectionsBySession = new ConcurrentHashMap<>();

    public GenerationWebSocketHandler(GenerationService generationService, ObjectMapper mapper, Validator validator) {
        this.generationService = generationService;
        this.mapper = mapper;
        this.validator = validator;
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) throws IOException {
        String clientId = clientId(session.getUri());
        if (clientId == null) {
            session.close(CloseStatus.BAD_DATA);
            return;
        }
        Connection connection = new Connection(clientId, session);
        connectionsBySession.put(session.getId(), connection);
        Connection previous = connectionsByClient.put(clientId, connection);
        if (previous != null) {
            closeQuietly(previous.session, new CloseStatus(4001, "Connection replaced"));
        }
    }

    @Override
    public void handleTextMessage(WebSocketSession session, TextMessage message) {
        Connection connection = connectionsBySession.get(session.getId());
        if (connection == null) return;
        if (connectionsByClient.get(connection.clientId) != connection) {
            closeQuietly(session, new CloseStatus(4001, "Connection replaced"));
            return;
        }

        JsonNode json;
        GenerateImageRequest request;
        try {
            json = mapper.readTree(message.getPayload());
            if (json == null || !json.isObject() || !"generate".equals(text(json, "action"))) {
                sendError(connection, "INVALID_REQUEST", "지원하지 않는 요청입니다");
                return;
            }
            ObjectNode requestJson = ((ObjectNode) json).deepCopy();
            requestJson.remove("action");
            request = mapper.treeToValue(requestJson, GenerateImageRequest.class);
            Set<ConstraintViolation<GenerateImageRequest>> violations = validator.validate(request);
            if (!violations.isEmpty()) {
                sendError(connection, "INVALID_REQUEST", "요청 값이 유효하지 않습니다");
                return;
            }
        } catch (Exception e) {
            sendError(connection, "INVALID_REQUEST", "요청 형식 또는 값이 유효하지 않습니다");
            return;
        }

        if (!connection.generationInFlight.compareAndSet(false, true)) {
            sendError(connection, "DUPLICATE_REQUEST", "이 연결에서 생성 작업이 진행 중입니다");
            return;
        }
        if (!capacity.tryAcquire()) {
            connection.generationInFlight.set(false);
            sendError(connection, "SERVER_BUSY", "생성 요청이 많아 잠시 후 다시 시도해 주세요");
            return;
        }
        if (!send(connection, Map.of("status", "processing", "message", "이미지 생성 중..."))) {
            release(connection);
            return;
        }

        try {
            executor.execute(() -> runGeneration(connection, request));
        } catch (RuntimeException e) {
            release(connection);
            sendError(connection, "SERVER_BUSY", "생성 요청이 많아 잠시 후 다시 시도해 주세요");
        }
    }

    private void runGeneration(Connection connection, GenerateImageRequest request) {
        try {
            byte[] responseJson = generationService.generate(request, stage -> {
                if (stage == GenerationStage.SAVING) {
                    send(connection, Map.of("status", "saving", "message", "이미지 저장 중..."));
                }
            });
            GenerateImageResponse response = mapper.readValue(responseJson, GenerateImageResponse.class);
            Map<String, Object> completed = new LinkedHashMap<>();
            completed.put("status", "completed");
            completed.put("image_id", response.imageId());
            completed.put("image_url", response.imageUrl());
            completed.put("blob_url", response.blobUrl());
            completed.put("work_title", response.workTitle());
            completed.put("excerpt", response.excerpt());
            completed.put("message", "이미지 생성 완료!");
            // Make the completed request reusable as soon as its work is done, before
            // the client can receive the terminal frame and submit the next request.
            release(connection);
            send(connection, completed);
        } catch (GenerationStorageException e) {
            release(connection);
            sendError(connection, e.isTimeout() ? "STORAGE_TIMEOUT" : "STORAGE_FAILED",
                    e.isTimeout() ? "이미지 저장 시간이 초과되었습니다" : "이미지 저장소에 연결할 수 없습니다");
        } catch (GenerationException e) {
            release(connection);
            sendError(connection, e.isTimeout() ? "GENERATION_TIMEOUT" : "GENERATION_FAILED",
                    e.isTimeout() ? "이미지 생성 시간이 초과되었습니다" : "이미지 생성에 실패했습니다");
        } catch (GenerationResponseException e) {
            release(connection);
            sendError(connection, "RESPONSE_FAILED", "이미지는 저장됐지만 응답을 만들지 못했습니다");
        } catch (Exception e) {
            log.error("websocket_generation_failed stage=response_or_transport");
            release(connection);
            sendError(connection, "INTERNAL_ERROR", "요청을 처리하지 못했습니다");
        } finally {
            release(connection);
        }
    }

    private boolean send(Connection connection, Object payload) {
        try {
            String serialized = mapper.writeValueAsString(payload);
            synchronized (connection.sendLock) {
                if (!connection.session.isOpen()) return false;
                connection.session.sendMessage(new TextMessage(serialized));
            }
            return true;
        } catch (Exception e) {
            // The target is always the socket that submitted the request. Never route via client_id.
            return false;
        }
    }

    private void sendError(Connection connection, String code, String message) {
        send(connection, Map.of("status", "error", "error_code", code, "message", message));
    }

    private void release(Connection connection) {
        if (connection.generationInFlight.compareAndSet(true, false)) capacity.release();
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        Connection connection = connectionsBySession.remove(session.getId());
        if (connection != null) connectionsByClient.remove(connection.clientId, connection);
    }

    @Override
    public void handleTransportError(WebSocketSession session, Throwable exception) {
        Connection connection = connectionsBySession.get(session.getId());
        if (connection != null) {
            connectionsBySession.remove(session.getId(), connection);
            connectionsByClient.remove(connection.clientId, connection);
        }
        closeQuietly(session, CloseStatus.SERVER_ERROR);
    }

    private String clientId(URI uri) {
        if (uri == null) return null;
        String path = uri.getPath();
        if (path == null || !path.startsWith("/ws/")) return null;
        String id = path.substring(4);
        return id.matches("[A-Za-z0-9._-]{1,100}") ? id : null;
    }

    private String text(JsonNode node, String field) {
        JsonNode value = node.get(field);
        return value != null && value.isTextual() ? value.asText() : null;
    }

    private void closeQuietly(WebSocketSession session, CloseStatus status) {
        try { if (session.isOpen()) session.close(status); }
        catch (IOException ignored) { }
    }

    @PreDestroy
    void stopExecutor() {
        executor.shutdownNow();
    }

    private static final class Connection {
        private final String clientId;
        private final WebSocketSession session;
        private final Object sendLock = new Object();
        private final AtomicBoolean generationInFlight = new AtomicBoolean();

        private Connection(String clientId, WebSocketSession session) {
            this.clientId = clientId;
            this.session = session;
        }
    }
}
