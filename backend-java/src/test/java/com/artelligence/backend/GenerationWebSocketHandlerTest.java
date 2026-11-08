package com.artelligence.backend;

import static org.mockito.Mockito.*;

import com.artelligence.backend.generation.GenerationService;
import com.artelligence.backend.generation.GenerateImageRequest;
import com.artelligence.backend.generation.websocket.GenerationWebSocketHandler;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.validation.Validation;
import java.io.IOException;
import java.net.URI;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

class GenerationWebSocketHandlerTest {
    @Test void processingSendFailureDoesNotStartGeneration() throws Exception {
        GenerationService generation = mock(GenerationService.class);
        var validatorFactory = Validation.buildDefaultValidatorFactory();
        var handler = new GenerationWebSocketHandler(generation, new ObjectMapper(), validatorFactory.getValidator());
        CountDownLatch generationCalled = new CountDownLatch(1);
        when(generation.generate(any(GenerateImageRequest.class), any())).thenAnswer(invocation -> {
            generationCalled.countDown();
            return "{}".getBytes(java.nio.charset.StandardCharsets.UTF_8);
        });
        WebSocketSession session = mock(WebSocketSession.class);
        when(session.getId()).thenReturn("session-1");
        when(session.getUri()).thenReturn(URI.create("ws://localhost/ws/client-1"));
        when(session.isOpen()).thenReturn(true);
        doThrow(new IOException("socket closed")).doNothing().when(session).sendMessage(any());

        try {
            handler.afterConnectionEstablished(session);
            TextMessage valid = new TextMessage("""
                    {"action":"generate","prompt":"a sufficiently long prompt","size":"1024x1024","quality":"standard"}
                    """);
            handler.handleTextMessage(session, valid);
            verify(generation, never()).generate(any(GenerateImageRequest.class), any());

            // A processing notification failure releases the per-connection and executor slots.
            handler.handleTextMessage(session, valid);
            org.junit.jupiter.api.Assertions.assertTrue(generationCalled.await(2, TimeUnit.SECONDS));
            verify(generation, times(1)).generate(any(GenerateImageRequest.class), any());
        } finally {
            validatorFactory.close();
        }
    }
}
