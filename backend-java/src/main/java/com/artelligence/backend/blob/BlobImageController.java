package com.artelligence.backend.blob;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
public class BlobImageController {
    private final BlobImageService service;
    private final BlobImageReader reader;
    public BlobImageController(BlobImageService service, BlobImageReader reader) { this.service = service; this.reader = reader; }

    @GetMapping("/api/v1/images")
    public ImageListResponse images(@RequestParam(defaultValue="20") int limit,
            @RequestParam(defaultValue="0") int offset, @RequestParam(required=false, name="work_title") String workTitle) {
        if (limit < 1 || limit > 100 || offset < 0) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "limit은 1~100, offset은 0 이상이어야 합니다");
        var page = service.list(limit, offset, workTitle);
        return new ImageListResponse(page.images().stream().map(ImageDto::from).toList(), page.total());
    }

    @GetMapping("/api/v1/works")
    public WorksResponse works() { return new WorksResponse(service.works().stream().map(w -> new WorkDto(w.workTitle(), w.sceneCount(), w.thumbnailUrl(), w.latestCreatedAt())).toList()); }

    @GetMapping("/api/v1/images/{*imagePath}")
    public ImageDto image(@PathVariable String imagePath) {
        String path = imagePath.startsWith("/") ? imagePath.substring(1) : imagePath;
        BlobImageReader.BlobImage image = reader.getImage(path).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "이미지를 찾을 수 없습니다"));
        return ImageDto.from(image);
    }

    public record ImageDto(String image_id, String blob_name, String url, long size, java.time.OffsetDateTime created_at, String content_type, String prompt, String work_title, String excerpt) {
        static ImageDto from(BlobImageReader.BlobImage image) { return new ImageDto(image.blobName(), image.blobName(), image.url(), image.size(), image.createdAt(), image.contentType(), image.prompt(), image.workTitle(), image.excerpt()); }
    }
    public record ImageListResponse(List<ImageDto> images, int total) {}
    public record WorkDto(String work_title, int scene_count, String thumbnail_url, java.time.OffsetDateTime latest_created_at) {}
    public record WorksResponse(List<WorkDto> works) {}
}
