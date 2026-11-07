package com.artelligence.backend.generation;

public class GenerationStorageException extends RuntimeException {
    private final boolean timeout;
    public GenerationStorageException(String message, Throwable cause) { this(message, false, cause); }
    public GenerationStorageException(String message, boolean timeout, Throwable cause) { super(message, cause); this.timeout = timeout; }
    public boolean isTimeout() { return timeout; }
}
