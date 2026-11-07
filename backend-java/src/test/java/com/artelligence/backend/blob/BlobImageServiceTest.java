package com.artelligence.backend.blob;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;

class BlobImageServiceTest {
    @Test void sortsFiltersCountsAndPagesAfterFiltering() {
        var reader = mock(BlobImageReader.class);
        var now = OffsetDateTime.parse("2026-01-03T12:00:00Z");
        when(reader.listImages()).thenReturn(List.of(
            image("old", "Book", now.minusDays(2)), image("new", "Book", now), image("other", "Else", now.minusDays(1))));
        var service = new BlobImageService(reader);
        var all = service.list(10, 0, null);
        assertEquals(List.of("new", "other", "old"), all.images().stream().map(BlobImageReader.BlobImage::blobName).toList());
        var filtered = service.list(1, 1, "Book");
        assertEquals(2, filtered.total());
        assertEquals("old", filtered.images().getFirst().blobName());
        assertTrue(service.list(10, 20, null).images().isEmpty());
    }

    @Test void groupsBlankTitlesAndUsesNewestThumbnail() {
        var reader = mock(BlobImageReader.class);
        var now = OffsetDateTime.parse("2026-01-03T12:00:00Z");
        when(reader.listImages()).thenReturn(List.of(image("old", "Book", now.minusDays(1)), image("new", "Book", now), image("legacy", "", now)));
        var works = new BlobImageService(reader).works();
        assertEquals(2, works.getFirst().sceneCount());
        assertEquals("new-url", works.getFirst().thumbnailUrl());
        assertEquals("미분류", works.get(1).workTitle());
    }

    private BlobImageReader.BlobImage image(String id, String title, OffsetDateTime created) {
        return new BlobImageReader.BlobImage(id, id + "-url", created, 1, "image/png", "p", title, null);
    }
}
