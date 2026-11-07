package com.artelligence.backend.blob;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import com.azure.storage.blob.BlobClient;
import com.azure.storage.blob.BlobContainerClient;
import com.azure.storage.blob.models.BlobProperties;
import com.azure.storage.blob.sas.BlobServiceSasSignatureValues;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.ByteArrayInputStream;
import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Optional;
import org.mockito.ArgumentCaptor;
import org.junit.jupiter.api.Test;

class AzureBlobImageReaderTest {
    private final ObjectMapper mapper = new ObjectMapper();

    @Test void missingContainerAndAuthorizationOrTransportErrorsAreStorageFailures() {
        var container = mock(BlobContainerClient.class);
        when(container.exists()).thenReturn(false);
        var reader = new AzureBlobImageReader(container, mapper);
        assertThrows(BlobStorageException.class, reader::listImages);
        when(container.exists()).thenThrow(new RuntimeException("unauthorized/network"));
        assertThrows(BlobStorageException.class, reader::listImages);
    }

    @Test void imageAbsenceIsDistinct404CandidateAndSidecarAbsenceLeavesMetadataEmpty() {
        var container = mock(BlobContainerClient.class);
        var image = mock(BlobClient.class);
        when(container.exists()).thenReturn(true);
        when(container.getBlobClient("missing.png")).thenReturn(image);
        when(image.exists()).thenReturn(false);
        var reader = new AzureBlobImageReader(container, mapper);
        assertEquals(Optional.empty(), reader.getImage("missing.png"));
        verify(container, never()).getBlobClient("missing.png.json");
    }

    @Test void missingAzureConfigurationFailsFast() {
        assertThrows(IllegalStateException.class, () -> new AzureBlobImageReader("", "images", mapper));
    }

    @Test void missingSidecarProducesEmptyMetadataAndReadOnlySasWith24HourExpiry() {
        var container = mock(BlobContainerClient.class);
        var blob = mock(BlobClient.class);
        var properties = mock(BlobProperties.class);
        when(container.exists()).thenReturn(true);
        when(container.getBlobClient("2026/01/a.png")).thenReturn(blob);
        when(container.getBlobClient("2026/01/a.png.json")).thenReturn(mock(BlobClient.class));
        when(blob.exists()).thenReturn(true);
        when(blob.getProperties()).thenReturn(properties);
        when(properties.getCreationTime()).thenReturn(OffsetDateTime.parse("2026-01-01T00:00:00Z"));
        when(properties.getBlobSize()).thenReturn(77L);
        when(properties.getContentType()).thenReturn("image/png");
        when(container.getBlobClient("2026/01/a.png.json").exists()).thenReturn(false);
        when(blob.getBlobUrl()).thenReturn("https://account/container/2026/01/a.png");
        when(blob.generateSas(any(BlobServiceSasSignatureValues.class))).thenReturn("sas-token");
        var clock = Clock.fixed(Instant.parse("2026-01-02T03:04:05Z"), ZoneOffset.UTC);
        var result = new AzureBlobImageReader(container, mapper, clock).getImage("2026/01/a.png").orElseThrow();
        assertNull(result.prompt()); assertNull(result.workTitle()); assertNull(result.excerpt());
        assertEquals("https://account/container/2026/01/a.png?sas-token", result.url());

        ArgumentCaptor<BlobServiceSasSignatureValues> captor = ArgumentCaptor.forClass(BlobServiceSasSignatureValues.class);
        verify(blob).generateSas(captor.capture());
        var values = captor.getValue();
        assertEquals(OffsetDateTime.parse("2026-01-03T03:04:05Z"), values.getExpiryTime());
        assertEquals("r", values.getPermissions());
    }

    @Test void malformedSidecarIsStorageFailureNotMissingMetadata() throws Exception {
        var container = mock(BlobContainerClient.class);
        var image = mock(BlobClient.class);
        var sidecar = mock(BlobClient.class);
        var properties = mock(BlobProperties.class);
        when(container.exists()).thenReturn(true);
        when(container.getBlobClient("bad.png")).thenReturn(image);
        when(container.getBlobClient("bad.png.json")).thenReturn(sidecar);
        when(image.exists()).thenReturn(true);
        when(image.getProperties()).thenReturn(properties);
        when(properties.getBlobSize()).thenReturn(10L);
        when(sidecar.exists()).thenReturn(true);
        var input = mock(com.azure.storage.blob.specialized.BlobInputStream.class);
        when(sidecar.openInputStream()).thenReturn(input);
        when(input.read(any(byte[].class), anyInt(), anyInt())).thenAnswer(invocation -> {
            byte[] bytes = "{broken".getBytes();
            System.arraycopy(bytes, 0, invocation.getArgument(0), invocation.getArgument(1), bytes.length);
            return bytes.length;
        }).thenReturn(-1);
        var reader = new AzureBlobImageReader(container, mapper, Clock.systemUTC());
        var error = assertThrows(BlobStorageException.class, () -> reader.getImage("bad.png"));
        assertTrue(error.getMessage().contains("sidecar"));
        verify(image, never()).generateSas(any(BlobServiceSasSignatureValues.class));
    }
}
