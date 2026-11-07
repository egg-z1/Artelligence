package com.artelligence.backend.generation;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.validation.beanvalidation.LocalValidatorFactoryBean;
import org.mockito.ArgumentCaptor;

class GenerationControllerTest {
    GenerationService service = mock(GenerationService.class);
    MockMvc mvc;
    @BeforeEach void setup() {
        var validator = new LocalValidatorFactoryBean(); validator.afterPropertiesSet();
        mvc = MockMvcBuilders.standaloneSetup(new GenerationController(service))
                .setControllerAdvice(new GenerationApiExceptionHandler()).setValidator(validator).build();
    }

    @Test void preservesSnakeCaseSuccessFields() throws Exception {
        when(service.generate(any())).thenReturn("{\"image_id\":\"20261107/a.png\",\"image_url\":\"url\",\"blob_url\":\"url\",\"work_title\":null,\"created_at\":\"2026-11-07T00:00:00Z\",\"status\":\"completed\"}".getBytes());
        mvc.perform(post("/api/v1/generate").contentType(MediaType.APPLICATION_JSON).content("""
                {"prompt":" a fox in a forest ","size":"1024x1024","quality":"standard","style":"vivid","work_title":" fox book ","excerpt":"scene"}
                """))
                .andExpect(status().isOk()).andExpect(jsonPath("$.image_id").exists())
                .andExpect(jsonPath("$.image_url").value("url")).andExpect(jsonPath("$.blob_url").value("url"))
                .andExpect(jsonPath("$.created_at").value("2026-11-07T00:00:00Z")).andExpect(jsonPath("$.status").value("completed"));
        var request = ArgumentCaptor.forClass(GenerateImageRequest.class);
        verify(service).generate(request.capture());
        assertEquals("a fox in a forest", request.getValue().getPrompt());
        assertEquals("fox book", request.getValue().getWorkTitle());
        assertEquals("scene", request.getValue().getExcerpt());
    }

    @Test void trimsBeforeLengthValidationAndRejectsUnsupportedValuesWith422() throws Exception {
        mvc.perform(post("/api/v1/generate").contentType(MediaType.APPLICATION_JSON).content("""
                {"prompt":"     short     "}
                """)).andExpect(status().isUnprocessableEntity()).andExpect(jsonPath("$.detail").exists());
        mvc.perform(post("/api/v1/generate").contentType(MediaType.APPLICATION_JSON).content("""
                {"prompt":"long enough prompt","size":"768x768"}
                """)).andExpect(status().isUnprocessableEntity());
        mvc.perform(post("/api/v1/generate").contentType(MediaType.APPLICATION_JSON).content("""
                {"prompt":"long enough prompt","quality":"ultra"}
                """)).andExpect(status().isUnprocessableEntity());
        mvc.perform(post("/api/v1/generate").contentType(MediaType.APPLICATION_JSON)
                .content("{\"prompt\":\"" + "x".repeat(4001) + "\"}"))
                .andExpect(status().isUnprocessableEntity());
    }

    @Test void acceptsPromptBoundsAfterTrimming() throws Exception {
        when(service.generate(any())).thenReturn("{}".getBytes());
        mvc.perform(post("/api/v1/generate").contentType(MediaType.APPLICATION_JSON)
                .content("{\"prompt\":\"" + "x".repeat(10) + "\"}"))
                .andExpect(status().isOk());
        mvc.perform(post("/api/v1/generate").contentType(MediaType.APPLICATION_JSON)
                .content("{\"prompt\":\"" + "x".repeat(4000) + "\"}"))
                .andExpect(status().isOk());
    }

    @Test void errorResponsesKeepFlutterDetailFieldAndSeparateStageTimeouts() throws Exception {
        var payload = "{\"prompt\":\"a sufficiently long prompt\"}";
        when(service.generate(any())).thenThrow(new GenerationException("생성 시간 초과", true, null));
        mvc.perform(post("/api/v1/generate").contentType(MediaType.APPLICATION_JSON).content(payload))
                .andExpect(status().isGatewayTimeout()).andExpect(jsonPath("$.detail").value("생성 시간 초과"));
        reset(service);
        when(service.generate(any())).thenThrow(new GenerationStorageException("storage timeout", true, null));
        mvc.perform(post("/api/v1/generate").contentType(MediaType.APPLICATION_JSON).content(payload))
                .andExpect(status().isGatewayTimeout()).andExpect(jsonPath("$.detail").exists());
        reset(service);
        when(service.generate(any())).thenThrow(new GenerationStorageException("storage down", false, null));
        mvc.perform(post("/api/v1/generate").contentType(MediaType.APPLICATION_JSON).content(payload))
                .andExpect(status().isServiceUnavailable()).andExpect(jsonPath("$.detail").exists());
        reset(service);
        when(service.generate(any())).thenThrow(new GenerationResponseException("serialization", null));
        mvc.perform(post("/api/v1/generate").contentType(MediaType.APPLICATION_JSON).content(payload))
                .andExpect(status().isInternalServerError()).andExpect(jsonPath("$.detail").exists());
    }
}
