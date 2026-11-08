package com.artelligence.backend;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.artelligence.backend.generation.GeneratedImage;
import com.artelligence.backend.generation.GeneratedImageStore;
import com.artelligence.backend.generation.GenerationException;
import com.artelligence.backend.generation.GenerationStorageException;
import com.artelligence.backend.generation.ImageGenerator;
import com.artelligence.backend.generation.StoredImage;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.WebSocket;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
@Import(TestcontainersConfiguration.class)
class GenerationWebSocketIntegrationTest {
    @LocalServerPort int port;
    @Autowired ObjectMapper mapper;
    @Autowired ImageGenerator generator;
    @Autowired GeneratedImageStore store;

    @BeforeEach void resetMocks() {
        reset(generator, store);
        when(generator.generate(anyString(), anyString(), anyString())).thenReturn(new GeneratedImage(new byte[] {1, 2, 3}));
        when(store.save(anyString(), anyString(), any(), anyString(), any(), any()))
                .thenReturn(new StoredImage("20261108/test.png", "https://storage.test/image?test-sas"));
    }

    @Test void publishesLegacyStatusOrderAndCompletionFieldsOverRealWebSocket() throws Exception {
        try (Socket socket = connect("normal-client")) {
            socket.send(generate("a sufficiently long prompt", "Forest", "scene"));
            JsonNode processing = socket.receive(mapper);
            JsonNode saving = socket.receive(mapper);
            JsonNode completed = socket.receive(mapper);

            assertEquals("processing", processing.get("status").asText());
            assertEquals("saving", saving.get("status").asText());
            assertEquals("completed", completed.get("status").asText());
            assertEquals("20261108/test.png", completed.get("image_id").asText());
            assertEquals("https://storage.test/image?test-sas", completed.get("image_url").asText());
            assertEquals(completed.get("image_url"), completed.get("blob_url"));
            assertEquals("Forest", completed.get("work_title").asText());
            assertEquals("scene", completed.get("excerpt").asText());
            assertEquals("이미지 생성 완료!", completed.get("message").asText());
            assertEquals(List.of("status", "image_id", "image_url", "blob_url", "work_title", "excerpt", "message"),
                    fieldNames(completed));
            verify(generator, times(1)).generate(anyString(), anyString(), anyString());
            verify(store, times(1)).save(anyString(), anyString(), any(), anyString(), any(), any());
        }
    }

    @Test void invalidRequestReturnsSafeCodeWithoutCallingGenerator() throws Exception {
        try (Socket socket = connect("invalid-client")) {
            socket.send(generate("short", null, null));
            JsonNode error = socket.receive(mapper);
            assertEquals("error", error.get("status").asText());
            assertEquals("INVALID_REQUEST", error.get("error_code").asText());
            assertFalse(error.get("message").asText().contains("short"));
            socket.send(generate("a sufficiently long prompt after validation error", null, null));
            assertEquals("processing", socket.receive(mapper).get("status").asText());
            assertEquals("saving", socket.receive(mapper).get("status").asText());
            assertEquals("completed", socket.receive(mapper).get("status").asText());
            verify(generator, times(1)).generate(anyString(), anyString(), anyString());
            verify(store, times(1)).save(anyString(), anyString(), any(), anyString(), any(), any());
        }
    }

    @Test void allowsConfiguredBrowserOriginAndRejectsUnknownOrigin() throws Exception {
        String allowed = handshakeStatus("https://www.artelligence.store");
        String rejected = handshakeStatus("https://untrusted.example");
        String nativeClient = handshakeStatus(null);
        assertTrue(allowed.contains(" 101 "), allowed);
        assertTrue(rejected.contains(" 403 "), rejected);
        assertTrue(nativeClient.contains(" 101 "), nativeClient);
    }

    @Test void oversizedTextMessageIsClosedByContainerBeforeGeneration() throws Exception {
        try (Socket socket = connect("large-frame-client")) {
            socket.webSocket.sendText("x".repeat(33 * 1024), true).join();
            assertTrue(socket.closed.await(3, TimeUnit.SECONDS));
            assertEquals(1009, socket.closeCode);
            verifyNoInteractions(generator, store);
        }
    }

    @Test void rejectsSecondSubmissionOnSameConnectionWhileFirstIsRunning() throws Exception {
        CountDownLatch generationStarted = new CountDownLatch(1);
        CountDownLatch releaseGeneration = new CountDownLatch(1);
        when(generator.generate(anyString(), anyString(), anyString())).thenAnswer(invocation -> {
            generationStarted.countDown();
            assertTrue(releaseGeneration.await(5, TimeUnit.SECONDS));
            return new GeneratedImage(new byte[] {1});
        });
        try (Socket socket = connect("duplicate-client")) {
            socket.send(generate("a sufficiently long prompt", null, null));
            assertEquals("processing", socket.receive(mapper).get("status").asText());
            assertTrue(generationStarted.await(3, TimeUnit.SECONDS));
            socket.send(generate("another sufficiently long prompt", null, null));
            JsonNode duplicate = socket.receive(mapper);
            assertEquals("DUPLICATE_REQUEST", duplicate.get("error_code").asText());
            releaseGeneration.countDown();
            assertEquals("saving", socket.receive(mapper).get("status").asText());
            assertEquals("completed", socket.receive(mapper).get("status").asText());
            verify(generator, times(1)).generate(anyString(), anyString(), anyString());
        } finally {
            releaseGeneration.countDown();
        }
    }

    @Test void generationAndStorageFailuresHaveDistinctSafeCodes() throws Exception {
        AtomicInteger generationCalls = new AtomicInteger();
        when(generator.generate(anyString(), anyString(), anyString())).thenAnswer(invocation -> {
            if (generationCalls.getAndIncrement() == 0)
                throw new GenerationException("private provider detail", true, null);
            return new GeneratedImage(new byte[] {1});
        });
        try (Socket socket = connect("generation-error-client")) {
            socket.send(generate("a sufficiently long prompt", null, null));
            assertEquals("processing", socket.receive(mapper).get("status").asText());
            JsonNode error = socket.receive(mapper);
            assertEquals("GENERATION_TIMEOUT", error.get("error_code").asText());
            assertFalse(error.get("message").asText().contains("private"));
            socket.send(generate("a sufficiently long retry prompt", null, null));
            assertEquals("processing", socket.receive(mapper).get("status").asText());
            assertEquals("saving", socket.receive(mapper).get("status").asText());
            assertEquals("completed", socket.receive(mapper).get("status").asText());
            verify(generator, times(2)).generate(anyString(), anyString(), anyString());
            verify(store, times(1)).save(anyString(), anyString(), any(), anyString(), any(), any());
        }

        reset(generator, store);
        when(generator.generate(anyString(), anyString(), anyString())).thenReturn(new GeneratedImage(new byte[] {1}));
        AtomicInteger saveCalls = new AtomicInteger();
        when(store.save(anyString(), anyString(), any(), anyString(), any(), any())).thenAnswer(invocation -> {
            if (saveCalls.getAndIncrement() == 0)
                throw new GenerationStorageException("private storage detail", false, null);
            return new StoredImage("20261108/retry.png", "https://storage.test/retry.png?sas");
        });
        try (Socket socket = connect("storage-error-client")) {
            socket.send(generate("a sufficiently long prompt", null, null));
            assertEquals("processing", socket.receive(mapper).get("status").asText());
            assertEquals("saving", socket.receive(mapper).get("status").asText());
            JsonNode error = socket.receive(mapper);
            assertEquals("STORAGE_FAILED", error.get("error_code").asText());
            assertFalse(error.get("message").asText().contains("private"));
            socket.send(generate("a sufficiently long retry prompt", null, null));
            assertEquals("processing", socket.receive(mapper).get("status").asText());
            assertEquals("saving", socket.receive(mapper).get("status").asText());
            assertEquals("completed", socket.receive(mapper).get("status").asText());
            verify(generator, times(2)).generate(anyString(), anyString(), anyString());
            verify(store, times(2)).save(anyString(), anyString(), any(), anyString(), any(), any());
        }
    }

    @Test void replacementSocketDoesNotReceiveOldTaskAndOldCloseDoesNotRemoveNewSocket() throws Exception {
        CountDownLatch firstGenerationStarted = new CountDownLatch(1);
        CountDownLatch releaseFirst = new CountDownLatch(1);
        CountDownLatch savesCompleted = new CountDownLatch(2);
        when(generator.generate(anyString(), anyString(), anyString())).thenAnswer(invocation -> {
            String prompt = invocation.getArgument(0);
            if (prompt.contains("old request")) {
                firstGenerationStarted.countDown();
                assertTrue(releaseFirst.await(5, TimeUnit.SECONDS));
            }
            return new GeneratedImage(new byte[] {1});
        });
        when(store.save(anyString(), anyString(), any(), anyString(), any(), any()))
                .thenAnswer(invocation -> {
                    savesCompleted.countDown();
                    String prompt = invocation.getArgument(3);
                    String id = prompt.contains("old request") ? "old.png" : "new.png";
                    return new StoredImage(id, "https://storage.test/" + id + "?sas");
                });

        Socket oldSocket = connect("reused-client-id");
        try {
            oldSocket.send(generate("a sufficiently long old request", null, null));
            assertEquals("processing", oldSocket.receive(mapper).get("status").asText());
            assertTrue(firstGenerationStarted.await(3, TimeUnit.SECONDS));

            try (Socket newSocket = connect("reused-client-id")) {
                assertTrue(oldSocket.closed.await(3, TimeUnit.SECONDS));
                releaseFirst.countDown();
                // The replacement connection must not receive saving/completed for the old request.
                assertNull(newSocket.messages.poll(300, TimeUnit.MILLISECONDS));

                newSocket.send(generate("a sufficiently long new request", null, null));
                assertEquals("processing", newSocket.receive(mapper).get("status").asText());
                assertEquals("saving", newSocket.receive(mapper).get("status").asText());
                JsonNode newCompleted = newSocket.receive(mapper);
                assertEquals("new.png", newCompleted.get("image_id").asText());
                assertEquals("https://storage.test/new.png?sas", newCompleted.get("image_url").asText());
                assertTrue(savesCompleted.await(3, TimeUnit.SECONDS));
                verify(store, times(2)).save(anyString(), anyString(), any(), anyString(), any(), any());
                verify(store, never()).compensate(anyString(), anyString());
            }
        } finally {
            releaseFirst.countDown();
            oldSocket.close();
        }
    }

    @Test void rejectsWhenBoundedExecutorAndQueueAreSaturatedBeforeMoreGenerationStarts() throws Exception {
        CountDownLatch started = new CountDownLatch(2);
        CountDownLatch release = new CountDownLatch(1);
        CountDownLatch saved = new CountDownLatch(10);
        when(generator.generate(anyString(), anyString(), anyString())).thenAnswer(invocation -> {
            started.countDown();
            assertTrue(release.await(8, TimeUnit.SECONDS));
            return new GeneratedImage(new byte[] {1});
        });
        when(store.save(anyString(), anyString(), any(), anyString(), any(), any())).thenAnswer(invocation -> {
            saved.countDown();
            return new StoredImage("queued.png", "https://storage.test/queued.png?sas");
        });

        List<Socket> sockets = new ArrayList<>();
        try {
            for (int i = 0; i < 11; i++) {
                Socket socket = connect("capacity-client-" + i);
                sockets.add(socket);
                socket.send(generate("a sufficiently long prompt number " + i, null, null));
            }
            assertTrue(started.await(3, TimeUnit.SECONDS));

            int processing = 0;
            int busy = 0;
            for (Socket socket : sockets) {
                JsonNode first = socket.receive(mapper);
                if ("processing".equals(first.path("status").asText())) processing++;
                if ("SERVER_BUSY".equals(first.path("error_code").asText())) busy++;
            }
            assertEquals(10, processing);
            assertEquals(1, busy);
            verify(generator, times(2)).generate(anyString(), anyString(), anyString());

            release.countDown();
            assertTrue(saved.await(8, TimeUnit.SECONDS));
            verify(generator, times(10)).generate(anyString(), anyString(), anyString());
            verify(store, times(10)).save(anyString(), anyString(), any(), anyString(), any(), any());
            for (int i = 0; i < 10; i++) {
                assertEquals("saving", sockets.get(i).receive(mapper).get("status").asText());
                assertEquals("completed", sockets.get(i).receive(mapper).get("status").asText());
            }
            Socket previouslyRejected = sockets.get(10);
            previouslyRejected.send(generate("a sufficiently long prompt after capacity release", null, null));
            assertEquals("processing", previouslyRejected.receive(mapper).get("status").asText());
            assertEquals("saving", previouslyRejected.receive(mapper).get("status").asText());
            assertEquals("completed", previouslyRejected.receive(mapper).get("status").asText());
            verify(generator, times(11)).generate(anyString(), anyString(), anyString());
        } finally {
            release.countDown();
            for (Socket socket : sockets) socket.close();
        }
    }

    private Socket connect(String clientId) throws Exception {
        Socket socket = new Socket();
        WebSocket webSocket = HttpClient.newHttpClient().newWebSocketBuilder()
                .connectTimeout(Duration.ofSeconds(5))
                .buildAsync(URI.create("ws://localhost:" + port + "/ws/" + clientId), socket).join();
        socket.webSocket = webSocket;
        return socket;
    }

    private String handshakeStatus(String origin) throws Exception {
        try (java.net.Socket raw = new java.net.Socket("localhost", port)) {
            raw.setSoTimeout(3000);
            String request = "GET /ws/origin-check HTTP/1.1\r\n"
                    + "Host: localhost:" + port + "\r\n"
                    + "Upgrade: websocket\r\nConnection: Upgrade\r\n"
                    + "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"
                    + "Sec-WebSocket-Version: 13\r\n"
                    + (origin == null ? "" : "Origin: " + origin + "\r\n") + "\r\n";
            raw.getOutputStream().write(request.getBytes(StandardCharsets.US_ASCII));
            raw.getOutputStream().flush();
            return new BufferedReader(new InputStreamReader(raw.getInputStream(), StandardCharsets.US_ASCII)).readLine();
        }
    }

    private String generate(String prompt, String title, String excerpt) throws Exception {
        var request = mapper.createObjectNode().put("action", "generate").put("prompt", prompt)
                .put("size", "1024x1024").put("quality", "standard").put("style", "vivid");
        if (title != null) request.put("work_title", title);
        if (excerpt != null) request.put("excerpt", excerpt);
        return mapper.writeValueAsString(request);
    }

    private List<String> fieldNames(JsonNode node) {
        List<String> names = new ArrayList<>();
        node.fieldNames().forEachRemaining(names::add);
        return names;
    }

    private static final class Socket implements WebSocket.Listener, AutoCloseable {
        private final BlockingQueue<String> messages = new LinkedBlockingQueue<>();
        private final CountDownLatch closed = new CountDownLatch(1);
        private volatile WebSocket webSocket;
        private volatile int closeCode = -1;

        @Override public void onOpen(WebSocket webSocket) { webSocket.request(1); }
        @Override public java.util.concurrent.CompletionStage<?> onText(WebSocket webSocket, CharSequence data, boolean last) {
            messages.add(data.toString());
            webSocket.request(1);
            return null;
        }
        @Override public java.util.concurrent.CompletionStage<?> onClose(WebSocket webSocket, int statusCode, String reason) {
            closeCode = statusCode;
            closed.countDown();
            return null;
        }
        JsonNode receive(ObjectMapper mapper) throws Exception {
            String message = messages.poll(5, TimeUnit.SECONDS);
            assertNotNull(message, "Timed out waiting for WebSocket message");
            return mapper.readTree(message);
        }
        void send(String message) { webSocket.sendText(message, true).join(); }
        @Override public void close() { if (webSocket != null && !webSocket.isOutputClosed()) webSocket.sendClose(WebSocket.NORMAL_CLOSURE, "test").join(); }
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class AzureMocks {
        @Bean @Primary ImageGenerator mockedImageGenerator() { return mock(ImageGenerator.class); }
        @Bean @Primary GeneratedImageStore mockedGeneratedImageStore() { return mock(GeneratedImageStore.class); }
    }
}
