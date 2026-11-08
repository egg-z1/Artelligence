package com.artelligence.backend.blob;

public class ImageNotFoundException extends RuntimeException {
    public ImageNotFoundException(String imagePath) {
        super("이미지를 찾을 수 없습니다: " + imagePath);
    }
}
