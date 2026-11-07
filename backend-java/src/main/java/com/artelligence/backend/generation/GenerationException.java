package com.artelligence.backend.generation;

public class GenerationException extends RuntimeException {
    private final boolean timeout;
    public GenerationException(String safeMessage, boolean timeout, Throwable cause) { super(safeMessage, cause); this.timeout = timeout; }
    public boolean isTimeout() { return timeout; }
}
