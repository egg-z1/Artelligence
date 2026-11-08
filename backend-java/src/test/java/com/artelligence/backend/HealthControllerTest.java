package com.artelligence.backend;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

import java.time.Instant;
import org.junit.jupiter.api.Test;

class HealthControllerTest {
    @Test
    void healthResponseRetainsFlutterContractIncludingUtcTimestamp() {
        HealthController.HealthResponse response = new HealthController().health();

        assertEquals("healthy", response.status());
        assertEquals("artelligence-backend-java", response.service());
        assertNotNull(Instant.parse(response.timestamp()));
        assertEquals('Z', response.timestamp().charAt(response.timestamp().length() - 1));
    }
}
