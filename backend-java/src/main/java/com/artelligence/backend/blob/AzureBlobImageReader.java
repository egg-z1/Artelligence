package com.artelligence.backend.blob;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.Clock;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import com.azure.core.exception.ResourceNotFoundException;
import com.azure.storage.blob.BlobContainerClient;
import com.azure.storage.blob.BlobServiceClient;
import com.azure.storage.blob.BlobServiceClientBuilder;
import com.azure.storage.blob.models.BlobItem;
import com.azure.storage.blob.sas.BlobSasPermission;
import com.azure.storage.blob.sas.BlobServiceSasSignatureValues;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.context.annotation.Profile;

@Component
@Profile("!test")
public class AzureBlobImageReader implements BlobImageReader {
    private final BlobContainerClient container;
    private final ObjectMapper mapper;
    private final Clock clock;

    public AzureBlobImageReader(@Value("${azure.storage.connection-string:}") String connectionString,
            @Value("${azure.storage.container:generated-images}") String containerName, ObjectMapper mapper) {
        if (connectionString.isBlank()) throw new IllegalStateException("azure.storage.connection-string must be configured");
        this.container = new BlobServiceClientBuilder().connectionString(connectionString).buildClient().getBlobContainerClient(containerName);
        this.mapper = mapper;
        this.clock = Clock.systemUTC();
    }

    AzureBlobImageReader(BlobContainerClient container, ObjectMapper mapper) { this(container, mapper, Clock.systemUTC()); }
    AzureBlobImageReader(BlobContainerClient container, ObjectMapper mapper, Clock clock) { this.container = container; this.mapper = mapper; this.clock = clock; }

    @Override public List<BlobImage> listImages() {
        try {
            if (!container.exists()) throw new BlobStorageException("Configured Azure Blob container does not exist");
            List<BlobImage> result = new ArrayList<>();
            for (BlobItem blob : container.listBlobs()) {
                if (blob.getName().endsWith(".json")) continue;
                result.add(read(blob.getName(), blob.getProperties().getCreationTime(), blob.getProperties().getContentLength(), blob.getProperties().getContentType()));
            }
            return result;
        } catch (BlobStorageException e) { throw e; }
        catch (RuntimeException e) { throw new BlobStorageException("Azure Blob listing failed", e); }
    }

    @Override public Optional<BlobImage> getImage(String name) {
        try {
            if (!container.exists()) throw new BlobStorageException("Configured Azure Blob container does not exist");
            var blob = container.getBlobClient(name);
            if (!blob.exists()) return Optional.empty();
            var properties = blob.getProperties();
            return Optional.of(read(name, properties.getCreationTime(), properties.getBlobSize(), properties.getContentType()));
        } catch (BlobStorageException e) { throw e; }
        catch (RuntimeException e) { throw new BlobStorageException("Azure Blob lookup failed", e); }
    }

    private BlobImage read(String name, OffsetDateTime created, long size, String contentType) {
        String prompt = null, title = null, excerpt = null;
        try {
            var sidecar = container.getBlobClient(name + ".json");
            if (sidecar.exists()) {
                var node = mapper.readTree(sidecar.openInputStream());
                prompt = text(node, "prompt"); title = text(node, "work_title"); excerpt = text(node, "excerpt");
            }
        } catch (ResourceNotFoundException ignored) {
            // Sidecar absence is backward-compatible and yields empty metadata.
        } catch (Exception e) {
            throw new BlobStorageException("Malformed or unreadable sidecar JSON for " + name, e);
        }
        var imageBlob = container.getBlobClient(name);
        String url = imageBlob.generateSas(new BlobServiceSasSignatureValues(
                OffsetDateTime.now(clock).plusHours(24), new BlobSasPermission().setReadPermission(true)));
        String endpoint = imageBlob.getBlobUrl();
        return new BlobImage(name, endpoint + "?" + url, created, size, contentType, prompt, title, excerpt);
    }

    private String text(com.fasterxml.jackson.databind.JsonNode node, String field) { return node.hasNonNull(field) ? node.get(field).asText() : null; }
}
