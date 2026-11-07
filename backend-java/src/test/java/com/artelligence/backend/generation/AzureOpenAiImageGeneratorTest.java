package com.artelligence.backend.generation;

import static org.junit.jupiter.api.Assertions.*;

import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

class AzureOpenAiImageGeneratorTest {
    @Test void sdkMakesSingleRequestOnProviderFailureAndDoesNotRetry() throws Exception {
        var calls = new AtomicInteger();
        var server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/", exchange -> {
            calls.incrementAndGet();
            exchange.getRequestBody().readAllBytes();
            byte[] body = "{\"error\":{\"message\":\"mock failure\",\"type\":\"server_error\"}}".getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().add("Content-Type", "application/json");
            exchange.sendResponseHeaders(500, body.length);
            exchange.getResponseBody().write(body);
            exchange.close();
        });
        server.start();
        try {
            var generator = new AzureOpenAiImageGenerator("http://127.0.0.1:" + server.getAddress().getPort(), "test-key", "test-deployment");
            var failure = assertThrows(GenerationException.class, () -> generator.generate("a test prompt", "1024x1024", "medium"));
            assertFalse(failure.isTimeout());
            assertEquals(1, calls.get(), "SDK retry count must be zero");
        } finally { server.stop(0); }
    }

    @Test void decodesImageFromLocalMockEndpointWithoutAzureCredentials() throws Exception {
        var path = new AtomicReference<String>();
        var query = new AtomicReference<String>();
        var apiKey = new AtomicReference<String>();
        var requestBody = new AtomicReference<String>();
        var server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/", exchange -> {
            path.set(exchange.getRequestURI().getPath());
            query.set(exchange.getRequestURI().getRawQuery());
            apiKey.set(exchange.getRequestHeaders().getFirst("api-key"));
            requestBody.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            byte[] body = "{\"created\":1,\"data\":[{\"b64_json\":\"AQID\"}]}".getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().add("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, body.length);
            exchange.getResponseBody().write(body);
            exchange.close();
        });
        server.start();
        try {
            var generator = new AzureOpenAiImageGenerator("http://127.0.0.1:" + server.getAddress().getPort(), "test-key", "gpt-image-test-deployment");
            assertArrayEquals(new byte[] {1, 2, 3}, generator.generate("a test prompt", "1024x1024", "medium").bytes());
            assertEquals("/openai/v1/images/generations", path.get());
            assertNull(query.get(), "Azure v1 endpoint defaults to v1 without the legacy api-version query");
            assertEquals("test-key", apiKey.get());
            var body = new ObjectMapper().readTree(requestBody.get());
            assertEquals("gpt-image-test-deployment", body.get("model").asText());
            assertEquals("a test prompt", body.get("prompt").asText());
            assertEquals("1024x1024", body.get("size").asText());
            assertEquals("medium", body.get("quality").asText());
            assertEquals(1, body.get("n").asInt());
        } finally { server.stop(0); }
    }
}
