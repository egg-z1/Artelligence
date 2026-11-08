package com.artelligence.backend.blob;

import java.time.Duration;

import com.azure.storage.blob.BlobContainerClient;
import com.azure.storage.blob.BlobServiceClientBuilder;
import com.azure.storage.blob.models.BlobRequestConditions;
import com.azure.storage.blob.models.DeleteSnapshotsOptionType;
import com.azure.storage.blob.specialized.BlobClientBase;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

@Component
@Profile("!test")
public class AzureBlobImageDeleter implements BlobImageDeleter {
    private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(15);
    private final String connectionString;
    private final String containerName;
    private final BlobContainerClient injectedContainer;

    @Autowired
    public AzureBlobImageDeleter(@Value("${azure.storage.connection-string:}") String connectionString,
            @Value("${azure.storage.container:generated-images}") String containerName) {
        this(connectionString, containerName, null);
    }

    AzureBlobImageDeleter(String connectionString, String containerName, BlobContainerClient injectedContainer) {
        this.connectionString = connectionString;
        this.containerName = containerName;
        this.injectedContainer = injectedContainer;
    }

    private BlobContainerClient container() {
        if (injectedContainer != null) return injectedContainer;
        if (connectionString.isBlank()) throw new BlobStorageException("Azure Blob storage is not configured");
        try {
            return new BlobServiceClientBuilder().connectionString(connectionString).buildClient()
                    .getBlobContainerClient(containerName);
        } catch (RuntimeException e) {
            throw new BlobStorageException("Azure Blob storage configuration is invalid", e);
        }
    }

    @Override
    public void deleteImage(String imagePath) {
        BlobContainerClient container = container();
        try {
            ensureContainerAvailable(container);

            String sidecarPath = imagePath + ".json";
            Snapshot image = snapshot(container.getBlobClient(imagePath));
            Snapshot sidecar = snapshot(container.getBlobClient(sidecarPath));
            if (image == null && sidecar == null) {
                // Recheck so a container removed after the initial probe is not mistaken for an absent image.
                ensureContainerAvailable(container);
                throw new ImageNotFoundException(imagePath);
            }

            // Preserve the existing image-then-sidecar order. A retry can finish either partial state.
            if (image != null) deleteIfUnchanged(container, image);
            if (sidecar != null) deleteIfUnchanged(container, sidecar);
        } catch (ImageNotFoundException | BlobDeletionConflictException | BlobStorageException e) {
            throw e;
        } catch (RuntimeException e) {
            throw new BlobStorageException("Azure Blob deletion failed or has an unknown outcome", e);
        }
    }

    private void ensureContainerAvailable(BlobContainerClient container) {
        try {
            if (!container.exists()) throw new BlobStorageException("Configured Azure Blob container does not exist");
        } catch (BlobStorageException e) {
            throw e;
        } catch (RuntimeException e) {
            throw new BlobStorageException("Configured Azure Blob container is unavailable", e);
        }
    }

    private Snapshot snapshot(BlobClientBase blob) {
        try {
            if (!blob.exists()) return null;
            return new Snapshot(blob, blob.getProperties().getETag().toString());
        } catch (com.azure.storage.blob.models.BlobStorageException e) {
            if (e.getStatusCode() == 404) return null;
            throw e;
        }
    }

    private void deleteIfUnchanged(BlobContainerClient container, Snapshot snapshot) {
        try {
            snapshot.client().deleteWithResponse(DeleteSnapshotsOptionType.INCLUDE,
                    new BlobRequestConditions().setIfMatch(snapshot.etag()), REQUEST_TIMEOUT, null);
        } catch (com.azure.storage.blob.models.BlobStorageException e) {
            if (e.getStatusCode() == 412) {
                throw new BlobDeletionConflictException("Blob changed after it was read", e);
            }
            // A concurrent delete is already the requested state. Confirm that a 404 is not a missing container.
            if (e.getStatusCode() == 404) {
                ensureContainerAvailable(container);
                return;
            }
            throw e;
        }
    }

    private record Snapshot(BlobClientBase client, String etag) {}
}
