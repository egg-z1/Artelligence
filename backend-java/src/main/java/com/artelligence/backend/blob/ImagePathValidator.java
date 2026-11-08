package com.artelligence.backend.blob;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.ResolverStyle;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.springframework.stereotype.Component;

@Component
public class ImagePathValidator {
    private static final Pattern PATH = Pattern.compile(
            "^(\\d{8})/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12})\\.png$");
    private static final DateTimeFormatter DATE = DateTimeFormatter.ofPattern("uuuuMMdd").withResolverStyle(ResolverStyle.STRICT);

    public String validate(String path) {
        if (path == null || path.isBlank()) {
            throw new InvalidImagePathException();
        }
        // The HTTP connector decodes the path once before Spring MVC binds this variable.
        // Reject any remaining percent sign so a second-encoded path cannot be decoded here.
        if (path.startsWith("/") || path.indexOf('\\') >= 0 || path.indexOf('%') >= 0
                || path.chars().anyMatch(Character::isISOControl) || path.endsWith(".json")) {
            throw new InvalidImagePathException();
        }
        Matcher matcher = PATH.matcher(path);
        if (!matcher.matches()) throw new InvalidImagePathException();
        try {
            LocalDate.parse(matcher.group(1), DATE);
            UUID.fromString(matcher.group(2));
        } catch (java.time.DateTimeException | IllegalArgumentException e) {
            throw new InvalidImagePathException();
        }
        return path;
    }
}
