package com.artelligence.backend.generation.websocket;

import org.springframework.context.annotation.Configuration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.web.socket.server.HandshakeHandler;
import org.springframework.web.socket.server.support.DefaultHandshakeHandler;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;
import org.springframework.boot.web.servlet.ServletContextInitializer;
import jakarta.websocket.server.ServerContainer;
import java.util.Arrays;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.context.annotation.Bean;

@Configuration
@EnableWebSocket
public class GenerationWebSocketConfiguration implements WebSocketConfigurer {
    private final GenerationWebSocketHandler handler;
    private final Set<String> allowedOrigins;

    public GenerationWebSocketConfiguration(GenerationWebSocketHandler handler,
            @Value("${WEBSOCKET_ALLOWED_ORIGINS:https://www.artelligence.shop,https://artelligence.shop,https://www.artelligence.store,https://artelligence.store}") String allowedOrigins) {
        this.handler = handler;
        this.allowedOrigins = Arrays.stream(allowedOrigins.split(","))
                .map(String::trim).filter(value -> !value.isEmpty()).collect(Collectors.toUnmodifiableSet());
    }

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        HandshakeHandler handshakeHandler = new DefaultHandshakeHandler() {
            @Override
            protected boolean isValidOrigin(ServerHttpRequest request) {
                String origin = request.getHeaders().getOrigin();
                // Native Flutter clients may omit Origin. Browser clients must match the explicit allowlist.
                return origin == null || allowedOrigins.contains(origin);
            }
        };
        registry.addHandler(handler, "/ws/{client_id}")
                // The custom handshake handler applies the exact allowlist and permits native clients without Origin.
                .setAllowedOriginPatterns("*")
                .setHandshakeHandler(handshakeHandler);
    }

    @Bean
    ServletContextInitializer webSocketMessageLimits() {
        return servletContext -> {
            Object attribute = servletContext.getAttribute(ServerContainer.class.getName());
            if (attribute instanceof ServerContainer container) {
                container.setDefaultMaxTextMessageBufferSize(32 * 1024);
                container.setDefaultMaxBinaryMessageBufferSize(32 * 1024);
            }
        };
    }
}
