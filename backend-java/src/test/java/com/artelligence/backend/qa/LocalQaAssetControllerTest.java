package com.artelligence.backend.qa;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

import java.io.ByteArrayInputStream;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;

class LocalQaAssetControllerTest {
    @Test
    void servesDecodablePngForKnownQaAsset() throws Exception {
        ResponseEntity<byte[]> response = new LocalQaAssetController().sampleAsset(
                "11111111-1111-4111-8111-111111111111.png");

        assertEquals(200, response.getStatusCode().value());
        assertEquals("image/png", response.getHeaders().getContentType().toString());
        var image = ImageIO.read(new ByteArrayInputStream(response.getBody()));
        assertNotNull(image);
        assertEquals(48, image.getWidth());
        assertEquals(64, image.getHeight());
    }
}
