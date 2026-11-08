package com.artelligence.backend.blob;

public class BlobDeletionConflictException extends RuntimeException {
    public BlobDeletionConflictException(String message, Throwable cause) {
        super(message, cause);
    }
}
