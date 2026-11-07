package com.artelligence.backend.generation;

import org.springframework.stereotype.Component;

@Component
public class PromptPreprocessor {
    public String process(String prompt) {
        String clean = prompt.strip();
        String lower = clean.toLowerCase(java.util.Locale.ROOT);
        if (lower.contains("painting") || lower.contains("illustration") || lower.contains("art style") || lower.contains("digital art")) return clean;
        return "A detailed illustration of: " + clean;
    }
}
