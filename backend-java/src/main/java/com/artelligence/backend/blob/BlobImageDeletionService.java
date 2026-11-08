package com.artelligence.backend.blob;

import org.springframework.stereotype.Service;

@Service
public class BlobImageDeletionService {
    private final ImagePathValidator validator;
    private final BlobImageDeleter deleter;

    public BlobImageDeletionService(ImagePathValidator validator, BlobImageDeleter deleter) {
        this.validator = validator;
        this.deleter = deleter;
    }

    public String delete(String imagePath) {
        String validatedPath = validator.validate(imagePath);
        deleter.deleteImage(validatedPath);
        return validatedPath;
    }
}
