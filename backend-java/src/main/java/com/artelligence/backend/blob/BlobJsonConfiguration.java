package com.artelligence.backend.blob;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.json.JsonMapper;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration(proxyBeanMethods = false)
class BlobJsonConfiguration {
    @Bean
    ObjectMapper blobObjectMapper() {
        return JsonMapper.builder().findAndAddModules().build();
    }
}
