package com.artelligence.backend.generation;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import com.fasterxml.jackson.annotation.JsonProperty;

public class GenerateImageRequest {
    @NotBlank @Size(min = 10, max = 4000)
    private String prompt;
    @NotNull @Pattern(regexp = "1024x1024|1792x1024|1024x1792")
    private String size = "1024x1024";
    @NotNull @Pattern(regexp = "standard|hd")
    private String quality = "standard";
    private String style = "vivid";
    @Size(max = 200) private String workTitle;
    @Size(max = 2000) private String excerpt;

    public String getPrompt() { return prompt; }
    public void setPrompt(String prompt) { this.prompt = prompt == null ? null : prompt.strip(); }
    public String getSize() { return size; }
    public void setSize(String size) { this.size = size; }
    public String getQuality() { return quality; }
    public void setQuality(String quality) { this.quality = quality; }
    public String getStyle() { return style; }
    public void setStyle(String style) { this.style = style; }
    @JsonProperty("work_title") public String getWorkTitle() { return workTitle; }
    @JsonProperty("work_title") public void setWorkTitle(String workTitle) { this.workTitle = workTitle == null ? null : workTitle.strip(); }
    public String getExcerpt() { return excerpt; }
    public void setExcerpt(String excerpt) { this.excerpt = excerpt == null ? null : excerpt.strip(); }
}
