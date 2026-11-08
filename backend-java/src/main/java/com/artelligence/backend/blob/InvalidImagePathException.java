package com.artelligence.backend.blob;

public class InvalidImagePathException extends RuntimeException {
    public InvalidImagePathException() {
        super("이미지 경로가 유효하지 않습니다");
    }
}
