package com.artelligence.backend;

import static org.junit.jupiter.api.Assertions.*;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
@Import(TestcontainersConfiguration.class)
class BlobDeleteServletPathIntegrationTest {
    private static final String PATH = "20260102/550e8400-e29b-41d4-a716-446655440000.png";

    @LocalServerPort int port;
    @Autowired ObjectMapper mapper;

    private final HttpClient client = HttpClient.newHttpClient();

    @Test void encodedSlashIsAcceptedAndRespondsWithCanonicalBlobPath() throws Exception {
        HttpResponse<String> response = delete("20260102%2F550e8400-e29b-41d4-a716-446655440000.png");
        assertEquals(200, response.statusCode(), response.body());
        JsonNode body = mapper.readTree(response.body());
        assertEquals(PATH, body.get("image_id").asText());
        assertEquals("이미지가 성공적으로 삭제되었습니다", body.get("message").asText());
    }

    @Test void doubleEncodingAndTraversalAreRejectedBeforeDelete() throws Exception {
        HttpResponse<String> doubleEncoded = delete("20260102%252F550e8400-e29b-41d4-a716-446655440000.png");
        assertEquals(400, doubleEncoded.statusCode(), doubleEncoded.body());

        HttpResponse<String> traversal = delete("20260102%2F..%2F550e8400-e29b-41d4-a716-446655440000.png");
        assertTrue(traversal.statusCode() >= 400 && traversal.statusCode() < 500,
                "Traversal should be rejected, got " + traversal.statusCode());
    }

    private HttpResponse<String> delete(String path) throws Exception {
        HttpRequest request = HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/api/v1/images/" + path))
                .DELETE().build();
        return client.send(request, HttpResponse.BodyHandlers.ofString());
    }
}
