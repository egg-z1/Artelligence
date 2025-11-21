import os
import uuid
import logging
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
        이미지를 Azure Blob Storage에 업로드합니다.
        주의: 한글 프롬프트로 인한 400 에러 방지를 위해 metadata에는 prompt를 포함하지 않습니다.
        """
        try:
            # 1. 컨테이너 클라이언트 확보
            container_client = await self._ensure_container_exists()

            # 2. 파일 이름 생성 (날짜/UUID 구조)
            file_name = f"{datetime.now().strftime('%Y%m%d')}/{uuid.uuid4()}.{file_extension}"
            blob_client = container_client.get_blob_client(file_name)
            
            # 3. 데이터 타입 안전 변환 (bytes 확인)
            if not isinstance(image_data, bytes):
                logger.warning(f"Image data is type {type(image_data)}, converting to bytes.")
                if isinstance(image_data, str):
                    image_data = image_data.encode('utf-8')

            logger.info(f"Uploading blob: {file_name} (Size: {len(image_data)} bytes)")

            # 4. 업로드 실행
            # 중요: metadata 파라미터를 제거하여 한글 헤더 에러(400) 방지
            # 중요: ContentSettings 객체 사용
            await blob_client.upload_blob(
                data=image_data,
                overwrite=True,
                content_settings=ContentSettings(
                    content_type=f"image/{file_extension}",
                    cache_control="no-cache"
                )
            )
            
            # 5. 결과 반환
            return {
                "image_id": file_name,
                "image_url": blob_client.url
            }
            
        except Exception as e:
            logger.error(f"Failed to upload image: {str(e)}")
            raise Exception(f"이미지 업로드 실패: {str(e)}")

    async def get_image_metadata(self, image_id: str) -> dict:
        """이미지 메타데이터 조회"""
        try:
            container_client = self.blob_service_client.get_container_client(self.container_name)
            blob_client = container_client.get_blob_client(image_id)
            
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
            container_client = self.blob_service_client.get_container_client(self.container_name)
            blob_client = container_client.get_blob_client(image_id)
            
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