package com.artelligence.backend.blob;

import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

class BlobImageControllerTest {
    BlobImageReader reader = mock(BlobImageReader.class);
    BlobImageController controller = new BlobImageController(new BlobImageService(reader), reader);
    MockMvc mvc = MockMvcBuilders.standaloneSetup(controller).setControllerAdvice(new BlobApiExceptionHandler()).build();

    @Test void emptyCollectionAndSnakeCaseContract() throws Exception {
        when(reader.listImages()).thenReturn(List.of());
        mvc.perform(get("/api/v1/images")).andExpect(status().isOk()).andExpect(jsonPath("$.images").isArray()).andExpect(jsonPath("$.total").value(0));
        var image = new BlobImageReader.BlobImage("2026/01/a.png", "https://blob/sas", OffsetDateTime.parse("2026-01-01T00:00:00Z"), 99, "image/png", "prompt", "Novel", "excerpt");
        when(reader.listImages()).thenReturn(List.of(image));
        mvc.perform(get("/api/v1/images")).andExpect(status().isOk()).andExpect(jsonPath("$.images[0].image_id").value(image.blobName())).andExpect(jsonPath("$.images[0].blob_name").value(image.blobName())).andExpect(jsonPath("$.images[0].size").value(99)).andExpect(jsonPath("$.images[0].work_title").value("Novel")).andExpect(jsonPath("$.images[0].created_at").exists());
        mvc.perform(get("/api/v1/works")).andExpect(status().isOk()).andExpect(jsonPath("$.works[0].work_title").value("Novel")).andExpect(jsonPath("$.works[0].scene_count").value(1)).andExpect(jsonPath("$.works[0].thumbnail_url").exists()).andExpect(jsonPath("$.works[0].latest_created_at").exists());
    }

    @Test void routesSlashPathAndMapsMissingAndStorageFailure() throws Exception {
        var image = new BlobImageReader.BlobImage("2026/01/a.png", "url", OffsetDateTime.now(), 1, "image/png", null, null, null);
        when(reader.getImage("2026/01/a.png")).thenReturn(Optional.of(image));
        mvc.perform(get("/api/v1/images/2026/01/a.png")).andExpect(status().isOk()).andExpect(jsonPath("$.image_id").value("2026/01/a.png"));
        when(reader.getImage("missing.png")).thenReturn(Optional.empty());
        mvc.perform(get("/api/v1/images/missing.png")).andExpect(status().isNotFound());
        when(reader.listImages()).thenThrow(new BlobStorageException("down"));
        mvc.perform(get("/api/v1/images")).andExpect(status().is5xxServerError());
    }

    @Test void rejectsInvalidPagination() throws Exception {
        mvc.perform(get("/api/v1/images?limit=0")).andExpect(status().isBadRequest());
        mvc.perform(get("/api/v1/images?limit=101")).andExpect(status().isBadRequest());
        mvc.perform(get("/api/v1/images?offset=-1")).andExpect(status().isBadRequest());
        mvc.perform(get("/api/v1/images?offset=x")).andExpect(status().isBadRequest());
    }
}
