package com.artelligence.backend;

import com.artelligence.backend.blob.BlobImageDeleter;
import org.springframework.context.annotation.Primary;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

@Component
@Primary
@Profile("test")
class StubBlobImageDeleter implements BlobImageDeleter {
    @Override public void deleteImage(String imagePath) {}
}
