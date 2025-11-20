import asyncio
import aiohttp
import logging
from typing import Optional, List, Dict
from datetime import datetime, timedelta
from azure.storage.blob.aio import BlobServiceClient, ContainerClient
from azure.storage.blob import BlobSasPermissions, generate_blob_sas
from azure.storage.blob import ContentSettings
from config import settings

logger = logging.getLogger(__name__)

class StorageService:
    """Azure Blob Storage 관리 서비스"""
    
    def __init__(self):
        """서비스 초기화"""
        self.connection_string = settings.AZURE_STORAGE_CONNECTION_STRING
        self.account_name = settings.AZURE_STORAGE_ACCOUNT_NAME
        self.account_key = settings.AZURE_STORAGE_ACCOUNT_KEY
        self.container_name = settings.AZURE_STORAGE_CONTAINER_NAME
        
        # BlobServiceClient 초기화
        self.blob_service_client = BlobServiceClient.from_connection_string(
            self.connection_string
        )
        
        logger.info("StorageService initialized")
    
    async def _ensure_container_exists(self):
        """컨테이너 존재 확인 및 생성"""
        try:
            container_client = self.blob_service_client.get_container_client(
                self.container_name
            )
            
            # 컨테이너 존재 확인
            exists = await container_client.exists()
            
            if not exists:
                await container_client.create_container()
                logger.info(f"Container '{self.container_name}' created")
            
        except Exception as e:
            logger.error(f"Error ensuring container exists: {str(e)}")
            raise
    
    async def upload_image_from_url(
        self,
        image_url: str,
        image_id: str,
        metadata: Optional[Dict] = None
    ) -> str:
        """
        URL에서 이미지 다운로드 후 Blob Storage에 업로드
        
        Args:
            image_url: 다운로드할 이미지 URL
            image_id: 이미지 고유 ID
            metadata: 이미지 메타데이터
            
        Returns:
            업로드된 Blob URL
        """
        try:
            await self._ensure_container_exists()
            
            # 이미지 다운로드
            async with aiohttp.ClientSession() as session:
                async with session.get(image_url, timeout=aiohttp.ClientTimeout(total=60)) as response:
                    if response.status != 200:
                        raise Exception(f"Failed to download image: {response.status}")
                    
                    image_data = await response.read()
            
            # Blob 이름 생성 (날짜별 폴더 구조)
            date_prefix = datetime.utcnow().strftime("%Y/%m/%d")
            blob_name = f"{date_prefix}/{image_id}.png"
            
            # Blob 클라이언트 생성
            blob_client = self.blob_service_client.get_blob_client(
                container=self.container_name,
                blob=blob_name
            )
            
            # 메타데이터 설정
            blob_metadata = metadata or {}
            blob_metadata.update({
                "image_id": image_id,
                "upload_timestamp": datetime.utcnow().isoformat()
            })
            
            # 업로드
            await asyncio.wait_for(
                blob_client.upload_blob(
                    image_data,
                    overwrite=True,
                    metadata=blob_metadata,
                    content_settings=ContentSettings(
                        content_type="image/png", 
                        cache_control="no-cache"
                    )
                ),
                timeout=settings.STORAGE_UPLOAD_TIMEOUT
            )
            
            # Blob URL 반환
            blob_url = blob_client.url
            logger.info(f"Image uploaded to: {blob_url}")
            
            return blob_url
            
        except asyncio.TimeoutError:
            logger.error("Image upload timeout")
            raise Exception("이미지 업로드 시간 초과")
        except Exception as e:
            logger.error(f"Error uploading image: {str(e)}")
            raise Exception(f"이미지 업로드 실패: {str(e)}")
    
    async def get_image_url_with_sas(
        self,
        image_id: str,
        expiry_hours: int = 24
    ) -> Optional[str]:
        """
        SAS 토큰이 포함된 이미지 URL 생성
        
        Args:
            image_id: 이미지 ID
            expiry_hours: SAS 토큰 만료 시간 (시간)
            
        Returns:
            SAS 토큰이 포함된 URL
        """
        try:
            # Blob 찾기
            blob_name = await self._find_blob_by_id(image_id)
            if not blob_name:
                return None
            
            # SAS 토큰 생성
            sas_token = generate_blob_sas(
                account_name=self.account_name,
                container_name=self.container_name,
                blob_name=blob_name,
                account_key=self.account_key,
                permission=BlobSasPermissions(read=True),
                expiry=datetime.utcnow() + timedelta(hours=expiry_hours)
            )
            
            # URL 생성
            blob_url = f"https://{self.account_name}.blob.core.windows.net/{self.container_name}/{blob_name}?{sas_token}"
            
            return blob_url
            
        except Exception as e:
            logger.error(f"Error generating SAS URL: {str(e)}")
            return None
    
    async def list_images(
        self,
        limit: int = 20,
        offset: int = 0
    ) -> List[Dict]:
        """
        저장된 이미지 목록 조회
        
        Args:
            limit: 조회할 이미지 수
            offset: 시작 위치
            
        Returns:
            이미지 정보 리스트
        """
        try:
            await self._ensure_container_exists()
            
            container_client = self.blob_service_client.get_container_client(
                self.container_name
            )
            
            images = []
            count = 0
            
            async for blob in container_client.list_blobs(include=['metadata']):
                # offset 적용
                if count < offset:
                    count += 1
                    continue
                
                # limit 적용
                if len(images) >= limit:
                    break
                
                blob_client = self.blob_service_client.get_blob_client(
                    container=self.container_name,
                    blob=blob.name
                )
                
                image_info = {
                    "image_id": blob.metadata.get("image_id", ""),
                    "blob_name": blob.name,
                    "url": blob_client.url,
                    "size": blob.size,
                    "created_at": blob.creation_time.isoformat() if blob.creation_time else None,
                    "metadata": blob.metadata
                }
                
                images.append(image_info)
                count += 1
            
            logger.info(f"Listed {len(images)} images")
            return images
            
        except Exception as e:
            logger.error(f"Error listing images: {str(e)}")
            raise Exception(f"이미지 목록 조회 실패: {str(e)}")
    
    async def get_image_metadata(self, image_id: str) -> Optional[Dict]:
        """
        특정 이미지의 메타데이터 조회
        
        Args:
            image_id: 이미지 ID
            
        Returns:
            이미지 메타데이터
        """
        try:
            blob_name = await self._find_blob_by_id(image_id)
            if not blob_name:
                return None
            
            blob_client = self.blob_service_client.get_blob_client(
                container=self.container_name,
                blob=blob_name
            )
            
            properties = await blob_client.get_blob_properties()
            
            return {
                "image_id": image_id,
                "blob_name": blob_name,
                "url": blob_client.url,
                "size": properties.size,
                "created_at": properties.creation_time.isoformat() if properties.creation_time else None,
                "metadata": properties.metadata
            }
            
        except Exception as e:
            logger.error(f"Error getting image metadata: {str(e)}")
            return None
    
    async def delete_image(self, image_id: str) -> bool:
        """
        이미지 삭제
        
        Args:
            image_id: 삭제할 이미지 ID
            
        Returns:
            삭제 성공 여부
        """
        try:
            blob_name = await self._find_blob_by_id(image_id)
            if not blob_name:
                return False
            
            blob_client = self.blob_service_client.get_blob_client(
                container=self.container_name,
                blob=blob_name
            )
            
            await blob_client.delete_blob()
            logger.info(f"Image deleted: {image_id}")
            
            return True
            
        except Exception as e:
            logger.error(f"Error deleting image: {str(e)}")
            return False
    
    async def _find_blob_by_id(self, image_id: str) -> Optional[str]:
        """
        이미지 ID로 Blob 이름 찾기
        
        Args:
            image_id: 이미지 ID
            
        Returns:
            Blob 이름
        """
        try:
            container_client = self.blob_service_client.get_container_client(
                self.container_name
            )
            
            async for blob in container_client.list_blobs(include=['metadata']):
                if blob.metadata and blob.metadata.get("image_id") == image_id:
                    return blob.name
            
            return None
            
        except Exception as e:
            logger.error(f"Error finding blob: {str(e)}")
            return None
    
    async def cleanup_old_images(self, days: int = 30) -> int:
        """
        오래된 이미지 삭제
        
        Args:
            days: 보관 기간 (일)
            
        Returns:
            삭제된 이미지 수
        """
        try:
            container_client = self.blob_service_client.get_container_client(
                self.container_name
            )
            
            cutoff_date = datetime.utcnow() - timedelta(days=days)
            deleted_count = 0
            
            async for blob in container_client.list_blobs():
                if blob.creation_time and blob.creation_time < cutoff_date:
                    blob_client = self.blob_service_client.get_blob_client(
                        container=self.container_name,
                        blob=blob.name
                    )
                    await blob_client.delete_blob()
                    deleted_count += 1
            
            logger.info(f"Cleaned up {deleted_count} old images")
            return deleted_count
            
        except Exception as e:
            logger.error(f"Error cleaning up old images: {str(e)}")
            return 0
    
    async def close(self):
        """리소스 정리"""
        await self.blob_service_client.close()