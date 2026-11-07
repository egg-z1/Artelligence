package com.artelligence.backend.blob;

public class BlobStorageException extends RuntimeException {
    public BlobStorageException(String message, Throwable cause) { super(message, cause); }
    public BlobStorageException(String message) { super(message); }
}
