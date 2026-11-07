package com.artelligence.backend.generation;

public interface ImageGenerator {
    GeneratedImage generate(String prompt, String size, String quality);
}
