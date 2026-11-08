package com.artelligence.backend;

import org.springframework.boot.tomcat.servlet.TomcatServletWebServerFactory;
import org.springframework.boot.web.server.WebServerFactoryCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration(proxyBeanMethods = false)
public class TomcatPathConfiguration {
    @Bean
    WebServerFactoryCustomizer<TomcatServletWebServerFactory> encodedSlashSupport() {
        return factory -> factory.addConnectorCustomizers(connector -> {
            connector.setEncodedSolidusHandling("decode");
        });
    }
}
