package com.artelligence.backend.blob;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.Test;

class ImagePathValidatorTest {
    private final ImagePathValidator validator = new ImagePathValidator();

    @Test void allowsExistingGeneratedPathWithSlash() {
        assertEquals("20260102/550e8400-e29b-41d4-a716-446655440000.png",
                validator.validate("20260102/550e8400-e29b-41d4-a716-446655440000.png"));
    }

    @Test void rejectsSidecarsTraversalInvalidDatesAndExtensions() {
        for (String input : new String[] {"", "/20260102/550e8400-e29b-41d4-a716-446655440000.png",
                "20260102/../550e8400-e29b-41d4-a716-446655440000.png",
                "20260230/550e8400-e29b-41d4-a716-446655440000.png",
                "20260102/550e8400-e29b-41d4-a716-446655440000.png.json",
                "20260102/550e8400-e29b-41d4-a716-446655440000.jpg",
                "20260102%2F550e8400-e29b-41d4-a716-446655440000.png",
                "20260102%252F550e8400-e29b-41d4-a716-446655440000.png"}) {
            assertThrows(InvalidImagePathException.class, () -> validator.validate(input), input);
        }
    }
}
