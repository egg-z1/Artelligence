package com.artelligence.backend.generation;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

class PromptPreprocessorTest {
    private final PromptPreprocessor subject = new PromptPreprocessor();
    @Test void keepsLegacyPreprocessingAndPassesExistingArtTerms() {
        assertEquals("A detailed illustration of: a fox", subject.process(" a fox "));
        assertEquals("an oil painting of a fox", subject.process("an oil painting of a fox"));
        assertEquals("digital art of a fox", subject.process("digital art of a fox"));
    }
}
