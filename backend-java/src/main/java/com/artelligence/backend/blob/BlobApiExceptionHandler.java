package com.artelligence.backend.blob;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class BlobApiExceptionHandler {
    @ExceptionHandler(BlobStorageException.class)
    ProblemDetail storageFailure(BlobStorageException exception) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.SERVICE_UNAVAILABLE, "이미지 저장소에 연결할 수 없습니다");
    }
}
