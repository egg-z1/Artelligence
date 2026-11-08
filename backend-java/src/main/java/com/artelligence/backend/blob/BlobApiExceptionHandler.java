package com.artelligence.backend.blob;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.http.ResponseEntity;
import java.util.Map;

@RestControllerAdvice
public class BlobApiExceptionHandler {
    @ExceptionHandler(BlobStorageException.class)
    ProblemDetail storageFailure(BlobStorageException exception) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.SERVICE_UNAVAILABLE, "이미지 저장소에 연결할 수 없습니다");
    }

    @ExceptionHandler(ImageNotFoundException.class)
    ResponseEntity<Map<String, String>> notFound(ImageNotFoundException exception) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("detail", exception.getMessage()));
    }

    @ExceptionHandler(BlobDeletionConflictException.class)
    ResponseEntity<Map<String, String>> conflict(BlobDeletionConflictException exception) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(Map.of("detail", "이미지가 변경되어 삭제하지 않았습니다"));
    }

    @ExceptionHandler(InvalidImagePathException.class)
    ResponseEntity<Map<String, String>> invalidPath(InvalidImagePathException exception) {
        return ResponseEntity.badRequest().body(Map.of("detail", exception.getMessage()));
    }
}
