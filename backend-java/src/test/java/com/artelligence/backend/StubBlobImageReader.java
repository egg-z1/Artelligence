package com.artelligence.backend;

import java.util.List;
import java.util.Optional;

import com.artelligence.backend.blob.BlobImageReader;
import org.springframework.context.annotation.Primary;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

@Component
@Primary
@Profile("test")
class StubBlobImageReader implements BlobImageReader {
    @Override public List<BlobImage> listImages() { return List.of(); }
    @Override public Optional<BlobImage> getImage(String blobName) { return Optional.empty(); }
}
