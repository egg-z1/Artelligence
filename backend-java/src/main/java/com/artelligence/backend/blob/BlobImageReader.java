package com.artelligence.backend.blob;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

public interface BlobImageReader {
    List<BlobImage> listImages();
    Optional<BlobImage> getImage(String blobName);

    record BlobImage(String blobName, String url, OffsetDateTime createdAt, long size,
                     String contentType, String prompt, String workTitle, String excerpt) {}
}
