package com.artelligence.backend.generation;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.core.JsonProcessingException;
import org.junit.jupiter.api.Test;

class GenerationServiceTest {
    ImageGenerator generator = mock(ImageGenerator.class);
    GeneratedImageStore store = mock(GeneratedImageStore.class);
    ObjectMapper mapper = new ObjectMapper();
    GenerationService service = new GenerationService(generator, store, new PromptPreprocessor(), mapper,
            Clock.fixed(Instant.parse("2026-11-07T02:03:04Z"), ZoneOffset.UTC));

    @Test void sendsMappedValuesIgnoresStyleAndReturnsFlutterContractWithUtcZ() throws Exception {
        var request = request("  a fox in a forest  ", "1792x1024", "hd", "watercolor", "Forest", "night");
        when(generator.generate(anyString(), anyString(), anyString())).thenReturn(new GeneratedImage(new byte[] {1, 2}));
        when(store.save(anyString(), anyString(), any(), any(), any(), any())).thenAnswer(invocation -> {
            String id = invocation.getArgument(0); String path = invocation.getArgument(1);
            assertEquals(path.substring(path.lastIndexOf('/') + 1, path.length() - 4), id);
            return new StoredImage(path, "https://storage/image?mock-sas");
        });
        var json = mapper.readTree(service.generate(request));
        assertEquals("a fox in a forest", json.get("prompt").asText());
        assertEquals("2026-11-07T02:03:04Z", json.get("created_at").asText());
        assertEquals("completed", json.get("status").asText());
        assertEquals("https://storage/image?mock-sas", json.get("blob_url").asText());
        verify(generator).generate("A detailed illustration of: a fox in a forest", "1536x1024", "high");
        verify(store).save(anyString(), contains("/"), eq(new byte[] {1, 2}), eq("a fox in a forest"), eq("Forest"), eq("night"));
        verify(store, never()).compensate(anyString(), anyString());
    }

    @Test void defaultsMapToLegacySquareAndStandard() {
        assertEquals("1024x1024", GenerationService.mapSize(null));
        assertEquals("medium", GenerationService.mapQuality("standard"));
        assertEquals("1024x1536", GenerationService.mapSize("1024x1792"));
    }

    @Test void saveFailureCompensatesAndNeverReturnsSuccess() {
        when(generator.generate(anyString(), anyString(), anyString())).thenReturn(new GeneratedImage(new byte[] {1}));
        when(store.save(anyString(), anyString(), any(), any(), any(), any())).thenThrow(new GenerationStorageException("unknown", null));
        assertThrows(GenerationStorageException.class, () -> service.generate(request("a sufficiently long prompt", null, null, null, null, null)));
        verify(store).compensate(anyString(), contains(".png"));
    }

    @Test void compensationFailureStillFailsRequest() {
        when(generator.generate(anyString(), anyString(), anyString())).thenReturn(new GeneratedImage(new byte[] {1}));
        when(store.save(anyString(), anyString(), any(), any(), any(), any())).thenThrow(new RuntimeException());
        doThrow(new RuntimeException()).when(store).compensate(anyString(), anyString());
        assertThrows(GenerationStorageException.class, () -> service.generate(request("a sufficiently long prompt", null, null, null, null, null)));
    }

    @Test void responseSerializationFailureDoesNotDeleteCompletedImage() throws Exception {
        when(generator.generate(anyString(), anyString(), anyString())).thenReturn(new GeneratedImage(new byte[] {1}));
        when(store.save(anyString(), anyString(), any(), any(), any(), any())).thenReturn(new StoredImage("p.png", "mock-url"));
        var brokenMapper = mock(ObjectMapper.class);
        when(brokenMapper.writeValueAsBytes(any())).thenThrow(new JsonProcessingException("mock serialization failure") { });
        var serviceWithBrokenMapper = new GenerationService(generator, store, new PromptPreprocessor(), brokenMapper,
                Clock.fixed(Instant.parse("2026-11-07T02:03:04Z"), ZoneOffset.UTC));

        assertThrows(GenerationResponseException.class,
                () -> serviceWithBrokenMapper.generate(request("a sufficiently long prompt", null, null, null, null, null)));
        verify(store).save(anyString(), anyString(), any(), any(), any(), any());
        verify(store, never()).compensate(anyString(), anyString());
    }

    private GenerateImageRequest request(String prompt, String size, String quality, String style, String title, String excerpt) {
        var r = new GenerateImageRequest(); r.setPrompt(prompt); if (size != null) r.setSize(size); if (quality != null) r.setQuality(quality);
        if (style != null) r.setStyle(style); r.setWorkTitle(title); r.setExcerpt(excerpt); return r;
    }
}
