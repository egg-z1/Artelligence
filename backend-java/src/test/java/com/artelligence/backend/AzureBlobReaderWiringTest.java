package com.artelligence.backend;

import static org.junit.jupiter.api.Assertions.assertInstanceOf;

import com.artelligence.backend.blob.AzureBlobImageReader;
import com.artelligence.backend.blob.BlobImageReader;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest(properties = {
    "azure.storage.connection-string=DefaultEndpointsProtocol=https;AccountName=testaccount;AccountKey=VGhpc0lzQVRlc3RLZXlGb3JUZXN0T25seQ==;EndpointSuffix=core.windows.net",
    "azure.storage.container=generated-images"
})
@ActiveProfiles("azure-adapter")
@Import(TestcontainersConfiguration.class)
class AzureBlobReaderWiringTest {
    @Autowired BlobImageReader reader;

    @Test void realAzureAdapterBeanIsConstructedWithoutCallingAzure() {
        assertInstanceOf(AzureBlobImageReader.class, reader);
    }
}
