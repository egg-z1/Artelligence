package com.artelligence.backend.generation;

public interface GeneratedImageStore {
    StoredImage save(String requestId, String blobName, byte[] bytes, String prompt, String workTitle, String excerpt);
    void compensate(String requestId, String blobName);
}
