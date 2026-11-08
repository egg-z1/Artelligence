package com.artelligence.backend.generation;

import java.time.Duration;
import java.util.Base64;

import com.openai.azure.AzureUrlPathMode;
import com.openai.client.OpenAIClient;
import com.openai.client.okhttp.OpenAIOkHttpClient;
import com.openai.azure.credential.AzureApiKeyCredential;
import com.openai.models.images.ImageGenerateParams;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

@Component
@Profile("!local-qa")
public class AzureOpenAiImageGenerator implements ImageGenerator {
    private final String endpoint, apiKey, deployment;

    public AzureOpenAiImageGenerator(@Value("${azure.openai.endpoint:}") String endpoint,
            @Value("${azure.openai.api-key:}") String apiKey,
            @Value("${azure.openai.deployment-name:}") String deployment) {
        this.endpoint = endpoint; this.apiKey = apiKey; this.deployment = deployment;
    }

    @Override public GeneratedImage generate(String prompt, String size, String quality) {
        if (endpoint.isBlank() || apiKey.isBlank() || deployment.isBlank())
            throw new GenerationException("이미지 생성 설정이 완료되지 않았습니다", false, null);
        OpenAIClient client = OpenAIOkHttpClient.builder()
                .baseUrl(endpoint.replaceAll("/+$", "") + "/openai/v1")
                .credential(AzureApiKeyCredential.create(apiKey)).azureUrlPathMode(AzureUrlPathMode.UNIFIED)
                .timeout(Duration.ofSeconds(120)).maxRetries(0).build();
        try {
            var params = ImageGenerateParams.builder().model(deployment).prompt(prompt).n(1L)
                    .size(ImageGenerateParams.Size.of(size)).quality(ImageGenerateParams.Quality.of(quality)).build();
            var response = client.images().generate(params);
            var data = response.data().orElseThrow(() -> new IllegalStateException("No image data"));
            var encoded = data.getFirst().b64Json().orElseThrow(() -> new IllegalStateException("No image payload"));
            return new GeneratedImage(Base64.getDecoder().decode(encoded));
        } catch (GenerationException e) { throw e; }
        catch (RuntimeException e) {
            boolean timeout = hasTimeout(e);
            throw new GenerationException(timeout ? "이미지 생성 시간이 초과되었습니다" : "이미지 생성에 실패했습니다", timeout, e);
        } finally {
            client.close();
        }
    }

    private boolean hasTimeout(Throwable t) {
        for (Throwable current = t; current != null; current = current.getCause()) {
            if (current instanceof java.net.SocketTimeoutException || current instanceof java.util.concurrent.TimeoutException
                    || current instanceof java.io.InterruptedIOException) return true;
            if (current instanceof InterruptedException) { Thread.currentThread().interrupt(); return true; }
        }
        return false;
    }
}
