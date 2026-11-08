package com.artelligence.backend.generation;

import java.time.Clock;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.UUID;
import java.util.function.Consumer;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class GenerationService {
    private static final Logger log = LoggerFactory.getLogger(GenerationService.class);
    private static final DateTimeFormatter DAY = DateTimeFormatter.ofPattern("yyyyMMdd").withZone(ZoneOffset.UTC);
    private final ImageGenerator generator;
    private final GeneratedImageStore store;
    private final PromptPreprocessor preprocessor;
    private final ObjectMapper mapper;
    private final Clock clock;

    @Autowired
    public GenerationService(ImageGenerator generator, GeneratedImageStore store, PromptPreprocessor preprocessor, ObjectMapper mapper) {
        this(generator, store, preprocessor, mapper, Clock.systemUTC());
    }
    GenerationService(ImageGenerator generator, GeneratedImageStore store, PromptPreprocessor preprocessor, ObjectMapper mapper, Clock clock) {
        this.generator = generator; this.store = store; this.preprocessor = preprocessor; this.mapper = mapper; this.clock = clock;
    }

    public byte[] generate(GenerateImageRequest request) {
        return generate(request, ignored -> { });
    }

    /** Runs the same generation and storage pipeline as REST, publishing stage events when requested. */
    public byte[] generate(GenerateImageRequest request, Consumer<GenerationStage> progress) {
        String id = UUID.randomUUID().toString();
        String blob = DAY.format(clock.instant()) + "/" + id + ".png";
        GeneratedImage image;
        try {
            image = generator.generate(preprocessor.process(request.getPrompt()), mapSize(request.getSize()), mapQuality(request.getQuality()));
        } catch (GenerationException e) {
            log.error("generation_request_failed request_id={} blob_name={} stage=generation outcome={}", id, blob, e.isTimeout() ? "timeout" : "failure");
            throw e;
        } catch (RuntimeException e) {
            log.error("generation_request_failed request_id={} blob_name={} stage=generation outcome=failure", id, blob);
            throw new GenerationException("이미지 생성에 실패했습니다", false, e);
        }
        try {
            progress.accept(GenerationStage.SAVING);
        } catch (RuntimeException e) {
            // A progress transport failure must not turn into a storage failure or skip persistence.
            log.warn("generation_progress_notification_failed request_id={} stage=saving", id);
        }
        StoredImage stored;
        try {
            stored = store.save(id, blob, image.bytes(), request.getPrompt(), request.getWorkTitle(), request.getExcerpt());
        } catch (RuntimeException e) {
            boolean timeout = e instanceof GenerationStorageException storage && storage.isTimeout();
            log.error("generation_request_failed request_id={} blob_name={} stage=storage outcome={}", id, blob, timeout ? "timeout_or_unknown" : "failure_or_unknown");
            compensate(id, blob);
            throw new GenerationStorageException("Azure Blob save failed or has an unknown outcome", timeout, e);
        }
        try {
            var response = new GenerateImageResponse(stored.imageId(), stored.imageUrl(), stored.imageUrl(), request.getPrompt(),
                    request.getWorkTitle(), request.getExcerpt(), clock.instant().toString(), "completed");
            // Serialize before sending headers so a local serialization failure can still be compensated.
            return mapper.writeValueAsBytes(response);
        } catch (Exception e) {
            log.error("generation_request_failed request_id={} blob_name={} stage=response outcome=failure", id, blob);
            // Both blobs and the SAS already exist; preserve the completed generation.
            throw new GenerationResponseException("이미지는 저장됐지만 응답을 만들지 못했습니다", e);
        }
    }

    private void compensate(String id, String blob) {
        try { store.compensate(id, blob); }
        catch (Exception cleanup) { log.error("generation_compensation_failed request_id={} blob_name={} stage=compensation", id, blob); }
    }

    static String mapSize(String size) { return switch (size == null ? "1024x1024" : size) { case "1792x1024" -> "1536x1024"; case "1024x1792" -> "1024x1536"; default -> "1024x1024"; }; }
    static String mapQuality(String q) { return "hd".equals(q) ? "high" : "medium"; }
}
