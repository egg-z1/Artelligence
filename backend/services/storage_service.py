import os
import uuid
import logging
import aiohttp
from datetime import datetime
from azure.storage.blob.aio import BlobServiceClient
from azure.storage.blob import ContentSettings
from config import settings

# 로깅 설정
logger = logging.getLogger(__name__)

class StorageService:
    def __init__(self):
        # 환경 변수에서 설정 가져오기
        self.connect_str = settings.AZURE_STORAGE_CONNECTION_STRING
        self.container_name = settings.AZURE_STORAGE_CONTAINER_NAME

        if not self.connect_str:
            logger.error("AZURE_STORAGE_CONNECTION_STRING is not set")
            raise ValueError("Azure Storage Connection String이 설정되지 않았습니다.")

        try:
            # 비동기 클라이언트 초기화
            self.blob_service_client = BlobServiceClient.from_connection_string(self.connect_str)
            logger.info("StorageService initialized successfully")
        except Exception as e:
            logger.error(f"Storage Service initialization failed: {str(e)}")
            raise e

    async def _ensure_container_exists(self):
        """컨테이너가 존재하는지 확인하고 없으면 생성"""
        try:
            container_client = self.blob_service_client.get_container_client(self.container_name)
            if not await container_client.exists():
                await container_client.create_container()
                logger.info(f"Container '{self.container_name}' created")
            return container_client
        except Exception as e:
            logger.error(f"Container check/create failed: {str(e)}")
            raise e

    async def upload_image(self, image_data: bytes, prompt: str, file_extension: str = "png") -> dict:
        """
        이미지 바이트 데이터를 Azure Blob Storage에 업로드
        (한글 프롬프트 400 에러 방지를 위해 메타데이터 제외)
        """
        try:
            container_client = await self._ensure_container_exists()

            # 파일 이름 생성
            file_name = f"{datetime.now().strftime('%Y%m%d')}/{uuid.uuid4()}.{file_extension}"
            blob_client = container_client.get_blob_client(file_name)
            
            # 데이터 타입 안전 변환
            if not isinstance(image_data, bytes):
                if isinstance(image_data, str):
                    image_data = image_data.encode('utf-8')

            logger.info(f"Uploading blob: {file_name} (Size: {len(image_data)} bytes)")

            # 업로드 실행 (metadata 제거, ContentSettings 적용)
            await blob_client.upload_blob(
                data=image_data,
                overwrite=True,
                content_settings=ContentSettings(
                    content_type=f"image/{file_extension}",
                    cache_control="no-cache"
                )
            )
            
            return {
                "image_id": file_name,
                "image_url": blob_client.url
            }
            
        except Exception as e:
            logger.error(f"Failed to upload image: {str(e)}")
            raise Exception(f"이미지 업로드 실패: {str(e)}")

    async def upload_image_from_url(self, image_url: str, prompt: str) -> dict:
        """
        URL에서 이미지를 다운로드하여 업로드
        """
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(image_url) as response:
                    if response.status != 200:
                        raise Exception(f"이미지 다운로드 실패: {response.status}")
                    image_data = await response.read()
            
            # 위에서 만든 upload_image 함수 재사용
            return await self.upload_image(image_data, prompt)
            
        except Exception as e:
            logger.error(f"Failed to upload image from URL: {str(e)}")
            raise Exception(f"URL 업로드 실패: {str(e)}")

    async def list_images(self, limit: int = 20, offset: int = 0) -> dict:
        """
        이미지 목록 조회 (갤러리용)
        """
        try:
            container_client = self.blob_service_client.get_container_client(self.container_name)
            
            # 컨테이너가 없으면 빈 목록 반환
            if not await container_client.exists():
                return {"images": [], "total": 0}

            blobs = []
            # 모든 블록 리스팅 (include=['metadata']를 제거하여 속도 향상 및 에러 방지)
            async for blob in container_client.list_blobs():
                blobs.append(blob)
            
            # 최신순 정렬 (생성 시간 기준 내림차순)
            blobs.sort(key=lambda x: x.creation_time, reverse=True)
            
            total = len(blobs)
            
            # 페이지네이션 적용
            start = offset
            end = min(offset + limit, total)
            paginated_blobs = blobs[start:end]
            
            images = []
            for blob in paginated_blobs:
                # URL 생성
                blob_client = container_client.get_blob_client(blob.name)
                
                images.append({
                    "image_id": blob.name,
                    "url": blob_client.url,
                    "created_at": blob.creation_time.isoformat() if blob.creation_time else None,
                    "size": blob.size,
                    "blob_name": blob.name
                })
                
            return {
                "images": images,
                "total": total
            }
            
        except Exception as e:
            logger.error(f"Error listing images: {str(e)}")
            # 에러 시 빈 목록 반환 (앱 죽음 방지)
            return {"images": [], "total": 0}
    async def get_image_metadata(self, image_id: str) -> dict:
        """이미지 메타데이터 조회"""
        try:
            # 메타데이터 검색 없이, image_id(=파일 경로)로 바로 접근
            blob_client = self.blob_service_client.get_blob_client(
                container=self.container_name,
                blob=image_id
            )
            
            if not await blob_client.exists():
                return None

            props = await blob_client.get_blob_properties()
            
            return {
                "image_id": image_id,
                "url": blob_client.url,
                "size": props.size,
                "created_at": props.creation_time.isoformat() if props.creation_time else None,
                "content_type": props.content_settings.content_type
            }
        except Exception as e:
            logger.error(f"Error getting image metadata: {str(e)}")
            return None
        
    async def delete_image(self, image_id: str) -> bool:
        """이미지 삭제"""
        try:
            blob_client = self.blob_service_client.get_blob_client(
                container=self.container_name,
                blob=image_id
            )
            
            if await blob_client.exists():
                await blob_client.delete_blob()
                return True
            return False
        except Exception as e:
            logger.error(f"Error deleting image {image_id}: {str(e)}")
            return False

    async def close(self):
        """리소스 정리"""
        await self.blob_service_client.close()