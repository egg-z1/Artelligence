from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from typing import Optional, List
import asyncio
import uuid
import logging
from datetime import datetime

from services.image_generator import ImageGeneratorService
from services.storage_service import StorageService
from config import settings

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# FastAPI 앱 초기화
app = FastAPI(
    title="Artelligence API",
    description="AI 기반 소설 장면 이미지 생성 서비스",
    version="1.0.0"
)

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 서비스 초기화
image_service = ImageGeneratorService()
storage_service = StorageService()

# WebSocket 연결 관리
class ConnectionManager:
    def __init__(self):
        self.active_connections: dict[str, WebSocket] = {}

    async def connect(self, websocket: WebSocket, client_id: str):
        await websocket.accept()
        self.active_connections[client_id] = websocket
        logger.info(f"Client {client_id} connected")

    def disconnect(self, client_id: str):
        if client_id in self.active_connections:
            del self.active_connections[client_id]
            logger.info(f"Client {client_id} disconnected")

    async def send_message(self, client_id: str, message: dict):
        if client_id in self.active_connections:
            await self.active_connections[client_id].send_json(message)

manager = ConnectionManager()

# Pydantic 모델
class ImageGenerationRequest(BaseModel):
    prompt: str = Field(..., min_length=1, max_length=4000, description="이미지 생성 프롬프트")
    size: Optional[str] = Field("1024x1024", description="이미지 크기 (1024x1024, 1792x1024, 1024x1792)")
    quality: Optional[str] = Field("standard", description="이미지 품질 (standard, hd)")
    style: Optional[str] = Field("vivid", description="이미지 스타일 (vivid, natural)")

class ImageGenerationResponse(BaseModel):
    image_id: str
    image_url: str
    blob_url: str
    prompt: str
    created_at: str
    status: str

class ImageListResponse(BaseModel):
    images: List[dict]
    total: int

# 헬스체크 엔드포인트
@app.get("/health")
async def health_check():
    """서비스 상태 확인"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "artelligence-backend"
    }

@app.get("/")
async def root():
    """루트 엔드포인트"""
    return {
        "message": "Welcome to Artelligence API",
        "version": "1.0.0",
        "docs": "/docs"
    }

# 이미지 생성 엔드포인트
@app.post("/api/v1/generate", response_model=ImageGenerationResponse)
async def generate_image(request: ImageGenerationRequest):
    """
    프롬프트 기반 이미지 생성
    
    - **prompt**: 이미지 생성 프롬프트 (필수)
    - **size**: 이미지 크기 (선택, 기본값: 1024x1024)
    - **quality**: 이미지 품질 (선택, 기본값: standard)
    - **style**: 이미지 스타일 (선택, 기본값: vivid)
    """
    try:
        image_id = str(uuid.uuid4())
        logger.info(f"Starting image generation for ID: {image_id}")
        
        # DALL-E로 이미지 생성
        result = await image_service.generate_image(
            prompt=request.prompt,
            size=request.size,
            quality=request.quality,
            style=request.style
        )
        
        if not result or "url" not in result:
            raise HTTPException(status_code=500, detail="이미지 생성 실패")
        
        # Azure Blob Storage에 저장
        blob_url = await storage_service.upload_image_from_url(
            image_url=result["url"],
            image_id=image_id,
            metadata={
                "prompt": request.prompt,
                "size": request.size,
                "quality": request.quality,
                "style": request.style,
                "created_at": datetime.utcnow().isoformat()
            }
        )
        
        logger.info(f"Image generated successfully: {image_id}")
        
        return ImageGenerationResponse(
            image_id=image_id,
            image_url=result["url"],
            blob_url=blob_url,
            prompt=request.prompt,
            created_at=datetime.utcnow().isoformat(),
            status="completed"
        )
        
    except Exception as e:
        logger.error(f"Error generating image: {str(e)}")
        raise HTTPException(status_code=500, detail=f"이미지 생성 중 오류 발생: {str(e)}")

# WebSocket 엔드포인트
@app.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    """
    실시간 이미지 생성 진행 상황 전송
    """
    await manager.connect(websocket, client_id)
    try:
        while True:
            data = await websocket.receive_json()
            
            if data.get("action") == "generate":
                try:
                    # 생성 시작 알림
                    await manager.send_message(client_id, {
                        "status": "processing",
                        "message": "이미지 생성 중..."
                    })
                    
                    image_id = str(uuid.uuid4())
                    
                    # 이미지 생성
                    result = await image_service.generate_image(
                        prompt=data.get("prompt"),
                        size=data.get("size", "1024x1024"),
                        quality=data.get("quality", "standard"),
                        style=data.get("style", "vivid")
                    )
                    
                    # 저장 중 알림
                    await manager.send_message(client_id, {
                        "status": "saving",
                        "message": "이미지 저장 중..."
                    })
                    
                    # 스토리지에 저장
                    blob_url = await storage_service.upload_image_from_url(
                        image_url=result["url"],
                        image_id=image_id,
                        metadata={
                            "prompt": data.get("prompt"),
                            "created_at": datetime.utcnow().isoformat()
                        }
                    )
                    
                    # 완료 알림
                    await manager.send_message(client_id, {
                        "status": "completed",
                        "image_id": image_id,
                        "image_url": result["url"],
                        "blob_url": blob_url,
                        "message": "이미지 생성 완료!"
                    })
                    
                except Exception as e:
                    await manager.send_message(client_id, {
                        "status": "error",
                        "message": f"오류 발생: {str(e)}"
                    })
                    
    except WebSocketDisconnect:
        manager.disconnect(client_id)

# 이미지 목록 조회
@app.get("/api/v1/images", response_model=ImageListResponse)
async def list_images(limit: int = 20, offset: int = 0):
    """
    생성된 이미지 목록 조회
    
    - **limit**: 조회할 이미지 수 (기본값: 20)
    - **offset**: 시작 위치 (기본값: 0)
    """
    try:
        images = await storage_service.list_images(limit=limit, offset=offset)
        return ImageListResponse(
            images=images,
            total=len(images)
        )
    except Exception as e:
        logger.error(f"Error listing images: {str(e)}")
        raise HTTPException(status_code=500, detail=f"이미지 목록 조회 중 오류 발생: {str(e)}")

# 특정 이미지 조회
@app.get("/api/v1/images/{image_id}")
async def get_image(image_id: str):
    """
    특정 이미지 정보 조회
    """
    try:
        image_data = await storage_service.get_image_metadata(image_id)
        if not image_data:
            raise HTTPException(status_code=404, detail="이미지를 찾을 수 없습니다")
        return image_data
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting image: {str(e)}")
        raise HTTPException(status_code=500, detail=f"이미지 조회 중 오류 발생: {str(e)}")

# 이미지 삭제
@app.delete("/api/v1/images/{image_id}")
async def delete_image(image_id: str):
    """
    이미지 삭제
    """
    try:
        success = await storage_service.delete_image(image_id)
        if not success:
            raise HTTPException(status_code=404, detail="이미지를 찾을 수 없습니다")
        return {"message": "이미지가 성공적으로 삭제되었습니다", "image_id": image_id}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting image: {str(e)}")
        raise HTTPException(status_code=500, detail=f"이미지 삭제 중 오류 발생: {str(e)}")

# 메트릭스 엔드포인트 (Prometheus)
@app.get("/metrics")
async def metrics():
    """
    Prometheus 메트릭스
    """
    return {
        "active_websocket_connections": len(manager.active_connections),
        "timestamp": datetime.utcnow().isoformat()
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )