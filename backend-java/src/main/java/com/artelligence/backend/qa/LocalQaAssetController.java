package com.artelligence.backend.qa;

import java.util.Set;
import org.springframework.context.annotation.Profile;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Profile("local-qa")
public class LocalQaAssetController {
    private static final Set<String> SAMPLE_IDS = Set.of(
            "11111111-1111-4111-8111-111111111111.png",
            "22222222-2222-4222-8222-222222222222.png",
            "33333333-3333-4333-8333-333333333333.png");
    private static final byte[] PNG = java.util.Base64.getDecoder().decode(
            "iVBORw0KGgoAAAANSUhEUgAAADAAAABACAIAAADTQmMRAAAAbUlEQVR4nO3OQQ2AQBRDwfWEBHzgAX/IQgAGtkfyD52kx5d01vvc213nsd3f/QICAqoDTR2nHggIqA80dZx6ICCgPtDUceqBgID6QFPHqQcCAuoDTR2nHggIqA80dZx6ICCgPtDUceqBgIDqQB/RNr8AfvNlPgAAAABJRU5ErkJggg==");

    @GetMapping(value = "/qa-assets/{asset}", produces = MediaType.IMAGE_PNG_VALUE)
    public ResponseEntity<byte[]> sampleAsset(@PathVariable String asset) {
        if (!SAMPLE_IDS.contains(asset)) return ResponseEntity.notFound().build();
        return ResponseEntity.ok().contentType(MediaType.IMAGE_PNG).body(PNG);
    }
}
