package com.artelligence.backend.blob;

import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Service;

@Service
public class BlobImageService {
    private final BlobImageReader reader;

    public BlobImageService(BlobImageReader reader) { this.reader = reader; }

    public ImagePage list(int limit, int offset, String workTitle) {
        List<BlobImageReader.BlobImage> filtered = reader.listImages().stream()
                .sorted(Comparator.comparing(BlobImageReader.BlobImage::createdAt,
                        Comparator.nullsLast(Comparator.reverseOrder())))
                .filter(i -> workTitle == null || (i.workTitle() == null ? "미분류" : i.workTitle()).equals(workTitle))
                .toList();
        int start = Math.min(offset, filtered.size());
        return new ImagePage(filtered.subList(start, Math.min(start + limit, filtered.size())), filtered.size());
    }

    public List<WorkSummary> works() {
        Map<String, WorkSummary> works = new LinkedHashMap<>();
        reader.listImages().stream().sorted(Comparator.comparing(BlobImageReader.BlobImage::createdAt,
                Comparator.nullsLast(Comparator.reverseOrder()))).forEach(image -> {
            String title = image.workTitle() == null || image.workTitle().isBlank() ? "미분류" : image.workTitle();
            WorkSummary old = works.get(title);
            works.put(title, old == null ? new WorkSummary(title, 1, image.url(), image.createdAt())
                    : new WorkSummary(title, old.sceneCount() + 1, old.thumbnailUrl(), old.latestCreatedAt()));
        });
        return List.copyOf(works.values());
    }

    public record ImagePage(List<BlobImageReader.BlobImage> images, int total) {}
    public record WorkSummary(String workTitle, int sceneCount, String thumbnailUrl, java.time.OffsetDateTime latestCreatedAt) {}
}
