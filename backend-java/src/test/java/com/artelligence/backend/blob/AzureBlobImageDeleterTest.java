package com.artelligence.backend.blob;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import java.time.Duration;

import com.azure.core.http.HttpResponse;
import com.azure.storage.blob.BlobContainerClient;
import com.azure.storage.blob.BlobClient;
import com.azure.storage.blob.models.BlobProperties;
import com.azure.storage.blob.models.BlobRequestConditions;
import com.azure.storage.blob.models.DeleteSnapshotsOptionType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.InOrder;

class AzureBlobImageDeleterTest {
    private static final String IMAGE = "20260102/550e8400-e29b-41d4-a716-446655440000.png";
    private BlobContainerClient container;
    private BlobClient image;
    private BlobClient sidecar;
    private AzureBlobImageDeleter deleter;

    @BeforeEach void setUp() {
        container = mock(BlobContainerClient.class);
        image = mock(BlobClient.class);
        sidecar = mock(BlobClient.class);
        doReturn(true).when(container).exists();
        when(container.getBlobClient(IMAGE)).thenReturn(image);
        when(container.getBlobClient(IMAGE + ".json")).thenReturn(sidecar);
        deleter = new AzureBlobImageDeleter("", "generated-images", container);
    }

    @Test void deletesImageThenSidecarUsingObservedEtags() {
        present(image, "image-etag");
        present(sidecar, "json-etag");
        deleter.deleteImage(IMAGE);
        InOrder order = inOrder(image, sidecar);
        order.verify(image).deleteWithResponse(eq(DeleteSnapshotsOptionType.INCLUDE), any(BlobRequestConditions.class),
                eq(Duration.ofSeconds(15)), isNull());
        order.verify(sidecar).deleteWithResponse(eq(DeleteSnapshotsOptionType.INCLUDE), any(BlobRequestConditions.class),
                eq(Duration.ofSeconds(15)), isNull());
        ArgumentCaptor<BlobRequestConditions> imageConditions = ArgumentCaptor.forClass(BlobRequestConditions.class);
        ArgumentCaptor<BlobRequestConditions> sidecarConditions = ArgumentCaptor.forClass(BlobRequestConditions.class);
        verify(image).deleteWithResponse(eq(DeleteSnapshotsOptionType.INCLUDE), imageConditions.capture(), any(), isNull());
        verify(sidecar).deleteWithResponse(eq(DeleteSnapshotsOptionType.INCLUDE), sidecarConditions.capture(), any(), isNull());
        assertEquals("image-etag", imageConditions.getValue().getIfMatch());
        assertEquals("json-etag", sidecarConditions.getValue().getIfMatch());
        verify(container, never()).getBlobClient(IMAGE + ".json.json");
    }

    @Test void deletesImageWhenSidecarIsAbsent() {
        present(image, "image-etag");
        when(sidecar.exists()).thenReturn(false);
        deleter.deleteImage(IMAGE);
        verify(image).deleteWithResponse(eq(DeleteSnapshotsOptionType.INCLUDE), any(BlobRequestConditions.class), any(), isNull());
        verify(sidecar, never()).deleteWithResponse(any(), any(), any(), any());
    }

    @Test void cleansOrphanSidecarWhenImageIsAbsent() {
        when(image.exists()).thenReturn(false);
        present(sidecar, "orphan-etag");
        deleter.deleteImage(IMAGE);
        verify(image, never()).deleteWithResponse(any(), any(), any(), any());
        verify(sidecar).deleteWithResponse(eq(DeleteSnapshotsOptionType.INCLUDE), argThat(c -> "orphan-etag".equals(c.getIfMatch())), any(), isNull());
    }

    @Test void rejectsWhenBothObjectsAreAbsent() {
        when(image.exists()).thenReturn(false);
        when(sidecar.exists()).thenReturn(false);
        assertThrows(ImageNotFoundException.class, () -> deleter.deleteImage(IMAGE));
        verify(image, never()).deleteWithResponse(any(), any(), any(), any());
        verify(sidecar, never()).deleteWithResponse(any(), any(), any(), any());
    }

    @Test void rechecksContainerBeforeReturningNotFound() {
        doReturn(true, false).when(container).exists();
        when(image.exists()).thenReturn(false);
        when(sidecar.exists()).thenReturn(false);
        assertThrows(BlobStorageException.class, () -> deleter.deleteImage(IMAGE));
    }

    @Test void containerMissingAndAccessErrorsAreStorageFailures() {
        doReturn(false).when(container).exists();
        assertThrows(BlobStorageException.class, () -> deleter.deleteImage(IMAGE));
        for (int status : new int[] {401, 403, 503}) {
            var error = azureError(status);
            doThrow(error).when(container).exists();
            assertThrows(BlobStorageException.class, () -> deleter.deleteImage(IMAGE), "Azure HTTP " + status);
        }
    }

    @Test void etagConflictIs409AndDoesNotDeleteSidecarOrStaleImage() {
        present(image, "old-etag");
        present(sidecar, "json-etag");
        doThrow(azureError(412))
                .when(image).deleteWithResponse(eq(DeleteSnapshotsOptionType.INCLUDE), any(BlobRequestConditions.class), any(), isNull());
        assertThrows(BlobDeletionConflictException.class, () -> deleter.deleteImage(IMAGE));
        verify(sidecar, never()).deleteWithResponse(any(), any(), any(), any());
    }

    @Test void containerDisappearingDuringDeleteIs503NotSuccess() {
        doReturn(true, false).when(container).exists();
        present(image, "image-etag");
        when(sidecar.exists()).thenReturn(false);
        doThrow(azureError(404)).when(image).deleteWithResponse(any(), any(), any(), any());
        assertThrows(BlobStorageException.class, () -> deleter.deleteImage(IMAGE));
    }

    @Test void partialDeleteFailureIsNotReportedAsSuccessAndRetryCleansRemainingSidecar() {
        when(image.exists()).thenReturn(true, false);
        props(image, "image-etag");
        when(sidecar.exists()).thenReturn(true, true);
        props(sidecar, "json-etag");
        when(image.deleteWithResponse(any(), any(), any(), any())).thenReturn(null);
        when(sidecar.deleteWithResponse(any(), any(), any(), any()))
                .thenThrow(new IllegalStateException("unknown remote outcome")).thenReturn(null);

        assertThrows(BlobStorageException.class, () -> deleter.deleteImage(IMAGE));
        // Retry targets only current image/sidecar names. The now absent image is skipped.
        deleter.deleteImage(IMAGE);
        verify(image, times(1)).deleteWithResponse(any(), any(), any(), any());
        verify(sidecar, times(2)).deleteWithResponse(any(), any(), any(), any());
    }

    private void present(BlobClient client, String etag) {
        when(client.exists()).thenReturn(true);
        props(client, etag);
        when(client.deleteWithResponse(any(), any(), any(), any())).thenReturn(null);
    }

    private void props(BlobClient client, String etag) {
        BlobProperties properties = mock(BlobProperties.class);
        when(properties.getETag()).thenReturn(etag);
        when(client.getProperties()).thenReturn(properties);
    }

    private com.azure.storage.blob.models.BlobStorageException azureError(int status) {
        HttpResponse response = mock(HttpResponse.class);
        when(response.getStatusCode()).thenReturn(status);
        return new com.azure.storage.blob.models.BlobStorageException("Azure operation failed", response, null);
    }
}
