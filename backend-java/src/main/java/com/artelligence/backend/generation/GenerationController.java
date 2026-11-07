package com.artelligence.backend.generation;

import jakarta.validation.Valid;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class GenerationController {
    private final GenerationService service;
    public GenerationController(GenerationService service) { this.service = service; }
    @PostMapping(value = "/generate", consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<byte[]> generate(@Valid @RequestBody GenerateImageRequest request) {
        return ResponseEntity.ok().contentType(MediaType.APPLICATION_JSON).body(service.generate(request));
    }
}
