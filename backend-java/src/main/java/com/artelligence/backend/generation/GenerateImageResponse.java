package com.artelligence.backend.generation;

import com.fasterxml.jackson.annotation.JsonProperty;

public record GenerateImageResponse(
        @JsonProperty("image_id") String imageId,
        @JsonProperty("image_url") String imageUrl,
        @JsonProperty("blob_url") String blobUrl,
        String prompt,
        @JsonProperty("work_title") String workTitle,
        String excerpt,
        @JsonProperty("created_at") String createdAt,
        String status) { }
