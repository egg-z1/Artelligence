package com.artelligence.backend.generation;

import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.Map;

import com.azure.core.util.BinaryData;
import com.azure.storage.blob.BlobContainerClient;
import com.azure.storage.blob.BlobServiceClientBuilder;
import com.azure.storage.blob.models.BlobHttpHeaders;
import com.azure.storage.blob.models.BlobRequestConditions;
import com.azure.storage.blob.options.BlobParallelUploadOptions;
import com.azure.storage.common.policy.RequestRetryOptions;
import com.azure.storage.common.policy.RetryPolicyType;
import com.azure.storage.blob.sas.BlobSasPermission;
import com.azure.storage.blob.sas.BlobServiceSasSignatureValues;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

@Component
@Profile("!local-qa")
public class AzureGeneratedImageStore implements GeneratedImageStore {
    private final String connectionString;
    private final String containerName;
    private final ObjectMapper mapper;
    private final Clock clock;
    private final BlobContainerClient injectedContainer;

    @Autowired
    public AzureGeneratedImageStore(@Value("${azure.storage.connection-string:}") String connectionString,
            @Value("${azure.storage.container:generated-images}") String containerName, ObjectMapper mapper) {
        this(connectionString, containerName, mapper, Clock.systemUTC());
    }

    AzureGeneratedImageStore(String connectionString, String containerName, ObjectMapper mapper, Clock clock) {
        this(connectionString, containerName, mapper, clock, null);
    }
    AzureGeneratedImageStore(String connectionString, String containerName, ObjectMapper mapper, Clock clock, BlobContainerClient injectedContainer) {
        this.connectionString = connectionString; this.containerName = containerName; this.mapper = mapper; this.clock = clock; this.injectedContainer = injectedContainer;
    }

    private BlobContainerClient container() {
        if (injectedContainer != null) return injectedContainer;
        if (connectionString.isBlank()) throw new GenerationStorageException("Azure Blob storage is not configured", null);
        return new BlobServiceClientBuilder().connectionString(connectionString)
                .retryOptions(retryOptions())
                .buildClient().getBlobContainerClient(containerName);
    }

    static RequestRetryOptions retryOptions() {
        return new RequestRetryOptions(RetryPolicyType.FIXED, 1, java.time.Duration.ofSeconds(15), null, null, null);
    }

    @Override public StoredImage save(String requestId, String blobName, byte[] bytes, String prompt, String workTitle, String excerpt) {
        BlobContainerClient container = container();
        try {
            if (!container.exists()) throw new GenerationStorageException("Configured Azure Blob container does not exist", null);
            upload(container, blobName, bytes, "image/png", requestId);
            var metadata = new java.util.LinkedHashMap<String, Object>();
            metadata.put("prompt", prompt); metadata.put("work_title", workTitle); metadata.put("excerpt", excerpt);
            upload(container, blobName + ".json", mapper.writeValueAsBytes(metadata), "application/json; charset=utf-8", requestId);
            var image = container.getBlobClient(blobName);
            String sas = image.generateSas(new BlobServiceSasSignatureValues(OffsetDateTime.now(clock).plusHours(24),
                    new BlobSasPermission().setReadPermission(true)));
            return new StoredImage(blobName, image.getBlobUrl() + "?" + sas);
        } catch (GenerationStorageException e) { throw e; }
        catch (Exception e) { throw new GenerationStorageException("Azure Blob save failed or has an unknown outcome", isTimeout(e), e); }
    }

    private void upload(BlobContainerClient container, String name, byte[] bytes, String contentType, String requestId) {
        var conditions = new BlobRequestConditions().setIfNoneMatch("*");
        var options = new BlobParallelUploadOptions(BinaryData.fromBytes(bytes))
                .setHeaders(new BlobHttpHeaders().setContentType(contentType).setCacheControl("no-cache"))
                .setMetadata(Map.of("generation_id", requestId))
                .setRequestConditions(conditions)
                .setTimeout(java.time.Duration.ofSeconds(15));
        container.getBlobClient(name).uploadWithResponse(options, java.time.Duration.ofSeconds(15), null);
    }

    @Override public void compensate(String requestId, String blobName) {
        try {
            BlobContainerClient container = container();
            if (!container.exists()) throw new IllegalStateException("container unavailable");
            for (String candidate : new String[] { blobName + ".json", blobName }) {
                var blob = container.getBlobClient(candidate);
                if (!blob.exists()) continue;
                var properties = blob.getProperties();
                if (!requestId.equals(properties.getMetadata() == null ? null : properties.getMetadata().get("generation_id")))
                    continue;
                blob.deleteIfExistsWithResponse(com.azure.storage.blob.models.DeleteSnapshotsOptionType.INCLUDE,
                        new BlobRequestConditions().setIfMatch(properties.getETag()), java.time.Duration.ofSeconds(5), null);
            }
        } catch (RuntimeException e) { throw new GenerationStorageException("Could not confirm generation compensation", e); }
    }

    private boolean isTimeout(Throwable t) {
        for (Throwable current = t; current != null; current = current.getCause()) {
            if (current instanceof java.net.SocketTimeoutException || current instanceof java.util.concurrent.TimeoutException
                    || current instanceof java.io.InterruptedIOException) return true;
            if (current instanceof InterruptedException) { Thread.currentThread().interrupt(); return true; }
        }
        return false;
    }
}
