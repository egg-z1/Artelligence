package com.artelligence.backend.generation;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Map;

import com.azure.storage.blob.BlobClient;
import com.azure.storage.blob.BlobContainerClient;
import com.azure.storage.blob.models.BlobProperties;
import com.azure.storage.blob.models.BlobRequestConditions;
import com.azure.storage.blob.options.BlobParallelUploadOptions;
import com.azure.storage.blob.sas.BlobServiceSasSignatureValues;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class AzureGeneratedImageStoreTest {
    private final Clock clock = Clock.fixed(Instant.parse("2026-11-07T00:00:00Z"), ZoneOffset.UTC);
    private final BlobContainerClient container = mock(BlobContainerClient.class);
    private final AzureGeneratedImageStore store = new AzureGeneratedImageStore("", "generated-images", new ObjectMapper(), clock, container);

    @Test void refusesMissingConfiguredContainerWithoutCreatingIt() {
        when(container.exists()).thenReturn(false);
        assertThrows(GenerationStorageException.class, () -> store.save("rid", "20261107/rid.png", new byte[] {1}, "p", null, null));
        verify(container, never()).createIfNotExists();
        verify(container, never()).create();
        verify(container, never()).getBlobClient(anyString());
    }

    @Test void writesUniqueImageAndSidecarThenIssuesReadOnly24HourSas() {
        when(container.exists()).thenReturn(true);
        BlobClient image = mock(BlobClient.class), sidecar = mock(BlobClient.class);
        when(container.getBlobClient("20261107/rid.png")).thenReturn(image);
        when(container.getBlobClient("20261107/rid.png.json")).thenReturn(sidecar);
        when(image.uploadWithResponse(any(BlobParallelUploadOptions.class), any(Duration.class), isNull())).thenReturn(null);
        when(sidecar.uploadWithResponse(any(BlobParallelUploadOptions.class), any(Duration.class), isNull())).thenReturn(null);
        when(image.generateSas(any(BlobServiceSasSignatureValues.class))).thenReturn("mock-sas");
        when(image.getBlobUrl()).thenReturn("https://storage/blob");

        var result = store.save("rid", "20261107/rid.png", new byte[] {1, 2}, "prompt", "title", "excerpt");
        assertEquals("20261107/rid.png", result.imageId());
        assertEquals("https://storage/blob?mock-sas", result.imageUrl());

        var options = ArgumentCaptor.forClass(BlobParallelUploadOptions.class);
        verify(image).uploadWithResponse(options.capture(), any(Duration.class), isNull());
        assertEquals("rid", options.getValue().getMetadata().get("generation_id"));
        assertEquals("*", options.getValue().getRequestConditions().getIfNoneMatch());
        var sas = ArgumentCaptor.forClass(BlobServiceSasSignatureValues.class);
        verify(image).generateSas(sas.capture());
        assertEquals(OffsetDateTime.parse("2026-11-08T00:00:00Z"), sas.getValue().getExpiryTime());
        assertEquals("r", sas.getValue().getPermissions());
        verify(sidecar).uploadWithResponse(any(BlobParallelUploadOptions.class), any(Duration.class), isNull());
    }

    @Test void compensationDeletesOnlyBlobsOwnedByThisRequest() {
        when(container.exists()).thenReturn(true);
        BlobClient owned = mock(BlobClient.class), foreign = mock(BlobClient.class);
        when(container.getBlobClient("20261107/rid.png.json")).thenReturn(owned);
        when(container.getBlobClient("20261107/rid.png")).thenReturn(foreign);
        when(owned.exists()).thenReturn(true); when(foreign.exists()).thenReturn(true);
        var ownedProperties = mock(BlobProperties.class); when(ownedProperties.getMetadata()).thenReturn(Map.of("generation_id", "rid"));
        when(ownedProperties.getETag()).thenReturn("etag-owned"); when(owned.getProperties()).thenReturn(ownedProperties);
        var foreignProperties = mock(BlobProperties.class); when(foreignProperties.getMetadata()).thenReturn(Map.of("generation_id", "other"));
        when(foreign.getProperties()).thenReturn(foreignProperties);

        store.compensate("rid", "20261107/rid.png");
        var conditions = ArgumentCaptor.forClass(BlobRequestConditions.class);
        verify(owned).deleteIfExistsWithResponse(any(), conditions.capture(), any(Duration.class), isNull());
        assertEquals("etag-owned", conditions.getValue().getIfMatch());
        verify(foreign, never()).deleteIfExistsWithResponse(any(), any(), any(), any());
    }

    @Test void preservesUnknownSidecarUploadOutcomeAsStorageFailure() {
        when(container.exists()).thenReturn(true);
        BlobClient image = mock(BlobClient.class), sidecar = mock(BlobClient.class);
        when(container.getBlobClient("p.png")).thenReturn(image);
        when(container.getBlobClient("p.png.json")).thenReturn(sidecar);
        when(image.uploadWithResponse(any(BlobParallelUploadOptions.class), any(Duration.class), isNull())).thenReturn(null);
        when(sidecar.uploadWithResponse(any(BlobParallelUploadOptions.class), any(Duration.class), isNull())).thenThrow(new RuntimeException("transport"));
        var failure = assertThrows(GenerationStorageException.class, () -> store.save("rid", "p.png", new byte[] {1}, "p", null, null));
        assertFalse(failure.isTimeout());
    }

    @Test void partialImageWriteIsRemovedOnlyWithMatchingRequestMetadataAndEtag() {
        when(container.exists()).thenReturn(true);
        BlobClient image = mock(BlobClient.class), sidecar = mock(BlobClient.class);
        when(container.getBlobClient("p.png")).thenReturn(image);
        when(container.getBlobClient("p.png.json")).thenReturn(sidecar);
        when(image.uploadWithResponse(any(BlobParallelUploadOptions.class), any(Duration.class), isNull())).thenReturn(null);
        when(sidecar.uploadWithResponse(any(BlobParallelUploadOptions.class), any(Duration.class), isNull())).thenThrow(new RuntimeException("sidecar write failed"));
        when(sidecar.exists()).thenReturn(false);
        when(image.exists()).thenReturn(true);
        var props = mock(BlobProperties.class);
        when(props.getMetadata()).thenReturn(Map.of("generation_id", "rid"));
        when(props.getETag()).thenReturn("etag-rid");
        when(image.getProperties()).thenReturn(props);

        assertThrows(GenerationStorageException.class, () -> store.save("rid", "p.png", new byte[] {1}, "p", null, null));
        store.compensate("rid", "p.png");
        var conditions = ArgumentCaptor.forClass(BlobRequestConditions.class);
        verify(image).deleteIfExistsWithResponse(any(), conditions.capture(), any(Duration.class), isNull());
        assertEquals("etag-rid", conditions.getValue().getIfMatch());
        verify(sidecar, never()).deleteIfExistsWithResponse(any(), any(), any(), any());
    }

    @Test void preExistingOrForeignBlobAtGeneratedPathIsNotDeleted() {
        when(container.exists()).thenReturn(true);
        BlobClient image = mock(BlobClient.class), sidecar = mock(BlobClient.class);
        when(container.getBlobClient("p.png.json")).thenReturn(sidecar);
        when(container.getBlobClient("p.png")).thenReturn(image);
        when(sidecar.exists()).thenReturn(false); when(image.exists()).thenReturn(true);
        var foreignProperties = mock(BlobProperties.class);
        when(foreignProperties.getMetadata()).thenReturn(Map.of("generation_id", "another-request"));
        when(image.getProperties()).thenReturn(foreignProperties);

        store.compensate("rid", "p.png");
        verify(image, never()).deleteIfExistsWithResponse(any(), any(), any(), any());
    }

    @Test void unknownSidecarOutcomeDeletesBothOwnedBlobsConditionally() {
        when(container.exists()).thenReturn(true);
        BlobClient image = mock(BlobClient.class), sidecar = mock(BlobClient.class);
        when(container.getBlobClient("p.png")).thenReturn(image);
        when(container.getBlobClient("p.png.json")).thenReturn(sidecar);
        when(image.uploadWithResponse(any(BlobParallelUploadOptions.class), any(Duration.class), isNull())).thenReturn(null);
        when(sidecar.uploadWithResponse(any(BlobParallelUploadOptions.class), any(Duration.class), isNull()))
                .thenThrow(new RuntimeException(new java.net.SocketTimeoutException("mock timeout")));
        when(image.exists()).thenReturn(true); when(sidecar.exists()).thenReturn(true);
        var imageProps = mock(BlobProperties.class); when(imageProps.getMetadata()).thenReturn(Map.of("generation_id", "rid"));
        when(imageProps.getETag()).thenReturn("etag-image"); when(image.getProperties()).thenReturn(imageProps);
        var jsonProps = mock(BlobProperties.class); when(jsonProps.getMetadata()).thenReturn(Map.of("generation_id", "rid"));
        when(jsonProps.getETag()).thenReturn("etag-json"); when(sidecar.getProperties()).thenReturn(jsonProps);

        var failure = assertThrows(GenerationStorageException.class, () -> store.save("rid", "p.png", new byte[] {1}, "p", null, null));
        assertTrue(failure.isTimeout());
        store.compensate("rid", "p.png");
        var imageConditions = ArgumentCaptor.forClass(BlobRequestConditions.class);
        var jsonConditions = ArgumentCaptor.forClass(BlobRequestConditions.class);
        verify(image).deleteIfExistsWithResponse(any(), imageConditions.capture(), any(Duration.class), isNull());
        verify(sidecar).deleteIfExistsWithResponse(any(), jsonConditions.capture(), any(Duration.class), isNull());
        assertEquals("etag-image", imageConditions.getValue().getIfMatch());
        assertEquals("etag-json", jsonConditions.getValue().getIfMatch());
    }

    @Test void configuredStorageClientUsesSingleTryAndFifteenSecondRequestTimeout() {
        var options = AzureGeneratedImageStore.retryOptions();
        assertEquals(1, options.getMaxTries());
        assertEquals(Duration.ofSeconds(15), options.getTryTimeoutDuration());
    }
}
