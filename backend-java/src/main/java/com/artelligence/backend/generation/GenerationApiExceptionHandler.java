package com.artelligence.backend.generation;

import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.http.converter.HttpMessageNotReadableException;

@RestControllerAdvice
public class GenerationApiExceptionHandler {
    private static final Logger log = LoggerFactory.getLogger(GenerationApiExceptionHandler.class);
    @ExceptionHandler({MethodArgumentNotValidException.class, HttpMessageNotReadableException.class})
    ResponseEntity<Map<String, String>> invalidRequest(Exception e) {
        String detail = e instanceof MethodArgumentNotValidException invalid
                ? invalid.getBindingResult().getFieldErrors().stream().findFirst().map(error -> error.getField() + " 값이 유효하지 않습니다").orElse("요청 값이 유효하지 않습니다")
                : "요청 JSON 형식이 유효하지 않습니다";
        return ResponseEntity.unprocessableEntity().body(Map.of("detail", detail));
    }
    @ExceptionHandler(GenerationException.class)
    ResponseEntity<Map<String, String>> generation(GenerationException e) {
        HttpStatus status = e.isTimeout() ? HttpStatus.GATEWAY_TIMEOUT : HttpStatus.BAD_GATEWAY;
        return ResponseEntity.status(status).body(Map.of("detail", e.getMessage()));
    }
    @ExceptionHandler(GenerationStorageException.class)
    ResponseEntity<Map<String, String>> storage(GenerationStorageException e) {
        log.error("generation_storage_failure stage=storage");
        return ResponseEntity.status(e.isTimeout() ? HttpStatus.GATEWAY_TIMEOUT : HttpStatus.SERVICE_UNAVAILABLE)
                .body(Map.of("detail", e.isTimeout() ? "이미지 저장 시간이 초과되었습니다" : "이미지 저장소에 연결할 수 없습니다"));
    }
    @ExceptionHandler(GenerationResponseException.class)
    ResponseEntity<Map<String, String>> response(GenerationResponseException e) {
        log.error("generation_response_failure stage=response");
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of("detail", "이미지는 저장됐지만 응답을 만들지 못했습니다"));
    }
}
