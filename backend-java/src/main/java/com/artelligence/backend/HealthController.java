package com.artelligence.backend;

import java.time.Instant;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HealthController {
    @GetMapping("/health")
    public HealthResponse health() {
        return new HealthResponse("healthy", Instant.now().toString(), "artelligence-backend-java");
    }

    public record HealthResponse(String status, String timestamp, String service) {}
}
