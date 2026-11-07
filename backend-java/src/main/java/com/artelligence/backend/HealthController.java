package com.artelligence.backend;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HealthController {
    @GetMapping("/health")
    public HealthResponse health() {
        return new HealthResponse("healthy", "artelligence-backend-java");
    }

    public record HealthResponse(String status, String service) {}
}
