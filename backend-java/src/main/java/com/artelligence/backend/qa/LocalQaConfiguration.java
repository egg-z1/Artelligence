package com.artelligence.backend.qa;

import com.artelligence.backend.blob.BlobImageDeleter;
import com.artelligence.backend.blob.BlobImageReader;
import com.artelligence.backend.blob.BlobStorageException;
import com.artelligence.backend.generation.GeneratedImageStore;
import com.artelligence.backend.generation.GenerationException;
import com.artelligence.backend.generation.GenerationStorageException;
import com.artelligence.backend.generation.ImageGenerator;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

/** Deterministic, non-Azure fixtures enabled only by explicitly selecting local-qa. */
@Configuration(proxyBeanMethods = false)
@Profile("local-qa")
public class LocalQaConfiguration {
    @Bean
    BlobImageReader localQaBlobImageReader(
            @Value("${LOCAL_QA_PUBLIC_BASE_URL:http://localhost:8080}") String publicBaseUrl) {
        List<BlobImageReader.BlobImage> images = List.of(
                new BlobImageReader.BlobImage("20261108/11111111-1111-4111-8111-111111111111.png",
                        publicBaseUrl + "/qa-assets/11111111-1111-4111-8111-111111111111.png",
                        OffsetDateTime.parse("2026-11-08T09:00:00Z"), 166, "image/png",
                        "QA sample scene one", "QA 서재", "첫 번째 QA 장면"),
                new BlobImageReader.BlobImage("20261108/22222222-2222-4222-8222-222222222222.png",
                        publicBaseUrl + "/qa-assets/22222222-2222-4222-8222-222222222222.png",
                        OffsetDateTime.parse("2026-11-08T10:00:00Z"), 166, "image/png",
                        "QA sample scene two", "QA 서재", "두 번째 QA 장면"),
                new BlobImageReader.BlobImage("20261108/33333333-3333-4333-8333-333333333333.png",
                        publicBaseUrl + "/qa-assets/33333333-3333-4333-8333-333333333333.png",
                        OffsetDateTime.parse("2026-11-08T11:00:00Z"), 166, "image/png",
                        "QA uncategorized scene", null, null));
        return new BlobImageReader() {
            @Override public List<BlobImage> listImages() { return images; }
            @Override public Optional<BlobImage> getImage(String blobName) {
                return images.stream().filter(image -> image.blobName().equals(blobName)).findFirst();
            }
        };
    }

    @Bean
    BlobImageDeleter localQaBlobImageDeleter() {
        return imagePath -> { throw new BlobStorageException("Deletion is disabled in local QA mode"); };
    }

    @Bean
    ImageGenerator localQaImageGenerator() {
        return (prompt, size, quality) -> {
            throw new GenerationException("Image generation is disabled in local QA mode", false, null);
        };
    }

    @Bean
    GeneratedImageStore localQaGeneratedImageStore() {
        return new GeneratedImageStore() {
            @Override public com.artelligence.backend.generation.StoredImage save(String requestId, String blobName,
                    byte[] bytes, String prompt, String workTitle, String excerpt) {
                throw new GenerationStorageException("Image storage is disabled in local QA mode", false, null);
            }
            @Override public void compensate(String requestId, String blobName) {
                throw new GenerationStorageException("Image storage is disabled in local QA mode", false, null);
            }
        };
    }
}
