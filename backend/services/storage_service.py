import os
import json
import uuid
import logging
import aiohttp
from datetime import datetime, timedelta
from typing import Optional
from azure.storage.blob.aio import BlobServiceClient
from azure.storage.blob import ContentSettings, generate_blob_sas, BlobSasPermissions
from config import settings

logger = logging.getLogger(__name__)


class StorageService:
    def __init__(self):
        self.connect_str = settings.AZURE_STORAGE_CONNECTION_STRING
        self.container_name = settings.AZURE_STORAGE_CONTAINER_NAME

        if not self.connect_str:
            raise ValueError("Azure Storage Connection String이 설정되지 않았습니다.")

        parsed = dict(
            item.split("=", 1) for item in self.connect_str.split(";") if "=" in item
        )
        self.account_name = parsed.get("AccountName")
        self.account_key = parsed.get("AccountKey")

        self.blob_service_client = BlobServiceClient.from_connection_string(self.connect_str)

    def _generate_sas_url(self, blob_name: str, expiry_hours: int = 24) -> str:
        sas_token = generate_blob_sas(
            account_name=self.account_name,
            container_name=self.container_name,
            blob_name=blob_name,
            account_key=self.account_key,
            permission=BlobSasPermissions(read=True),
            expiry=datetime.utcnow() + timedelta(hours=expiry_hours),
        )
        return f"https://{self.account_name}.blob.core.windows.net/{self.container_name}/{blob_name}?{sas_token}"

    async def _ensure_container_exists(self):
        try:
            container_client = self.blob_service_client.get_container_client(self.container_name)
            if not await container_client.exists():
                await container_client.create_container()
                logger.info(f"Container '{self.container_name}' created")
            return container_client
        except Exception as e:
            logger.error(f"Container check/create failed: {str(e)}")
            raise e

    def _sidecar_name(self, file_name: str) -> str:
        """이미지 blob 이름에서 사이드카 JSON 파일 이름 생성"""
        return f"{file_name}.json"

    async def _save_sidecar(
        self,
        container_client,
        file_name: str,
        prompt: str,
        work_title: Optional[str],
        excerpt: Optional[str],
    ):
        """
        한글 등 non-ASCII 텍스트는 Blob metadata 헤더에 못 넣으므로,
        같은 이름의 .json 파일을 별도로 저장해 우회한다.
        """
        sidecar_data = {
            "prompt": prompt,
            "work_title": work_title,
            "excerpt": excerpt,
        }
        sidecar_client = container_client.get_blob_client(self._sidecar_name(file_name))
        await sidecar_client.upload_blob(
            data=json.dumps(sidecar_data, ensure_ascii=False).encode("utf-8"),
            overwrite=True,
            content_settings=ContentSettings(content_type="application/json"),
        )

    async def _load_sidecar(self, container_client, file_name: str) -> dict:
        """사이드카 JSON 로드. 없으면 빈 dict 반환 (기존 이미지와의 호환성)"""
        try:
            sidecar_client = container_client.get_blob_client(self._sidecar_name(file_name))
            if not await sidecar_client.exists():
                return {}
            data = await sidecar_client.download_blob()
            content = await data.readall()
            return json.loads(content)
        except Exception as e:
            logger.warning(f"Sidecar load failed for {file_name}: {str(e)}")
            return {}

    async def upload_image(
        self,
        image_data: bytes,
        prompt: str,
        work_title: Optional[str] = None,
        excerpt: Optional[str] = None,
        file_extension: str = "png",
    ) -> dict:
        """이미지 바이트 데이터를 업로드하고, 프롬프트/작품/발췌문을 사이드카 JSON으로 함께 저장"""
        try:
            container_client = await self._ensure_container_exists()

            file_name = f"{datetime.now().strftime('%Y%m%d')}/{uuid.uuid4()}.{file_extension}"
            blob_client = container_client.get_blob_client(file_name)

            if not isinstance(image_data, bytes):
                if isinstance(image_data, str):
                    image_data = image_data.encode("utf-8")

            logger.info(f"Uploading blob: {file_name} (Size: {len(image_data)} bytes)")

            await blob_client.upload_blob(
                data=image_data,
                overwrite=True,
                content_settings=ContentSettings(
                    content_type=f"image/{file_extension}",
                    cache_control="no-cache",
                ),
            )

            await self._save_sidecar(container_client, file_name, prompt, work_title, excerpt)

            return {
                "image_id": file_name,
                "image_url": self._generate_sas_url(file_name),
                "work_title": work_title,
                "excerpt": excerpt,
            }

        except Exception as e:
            logger.error(f"Failed to upload image: {str(e)}")
            raise Exception(f"이미지 업로드 실패: {str(e)}")

    async def upload_image_from_url(
        self,
        image_url: str,
        prompt: str,
        work_title: Optional[str] = None,
        excerpt: Optional[str] = None,
    ) -> dict:
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(image_url) as response:
                    if response.status != 200:
                        raise Exception(f"이미지 다운로드 실패: {response.status}")
                    image_data = await response.read()

            return await self.upload_image(image_data, prompt, work_title, excerpt)

        except Exception as e:
            logger.error(f"Failed to upload image from URL: {str(e)}")
            raise Exception(f"URL 업로드 실패: {str(e)}")

    async def list_images(self, limit: int = 20, offset: int = 0, work_title: Optional[str] = None) -> dict:
        """
        이미지 목록 조회 (갤러리용).
        work_title이 주어지면 해당 작품(문자열 그대로, "미분류" 포함)의 장면만 필터링.
        """
        try:
            container_client = self.blob_service_client.get_container_client(self.container_name)

            if not await container_client.exists():
                return {"images": [], "total": 0}

            blobs = []
            async for blob in container_client.list_blobs():
                if not blob.name.endswith(".json"):
                    blobs.append(blob)

            blobs.sort(key=lambda x: x.creation_time, reverse=True)

            images = []
            for blob in blobs:
                sidecar = await self._load_sidecar(container_client, blob.name)
                effective_title = sidecar.get("work_title") or "미분류"

                if work_title is not None and effective_title != work_title:
                    continue

                images.append({
                    "image_id": blob.name,
                    "url": self._generate_sas_url(blob.name),
                    "created_at": blob.creation_time.isoformat() if blob.creation_time else None,
                    "size": blob.size,
                    "blob_name": blob.name,
                    "prompt": sidecar.get("prompt"),
                    "work_title": sidecar.get("work_title"),
                    "excerpt": sidecar.get("excerpt"),
                })

            total = len(images)
            paginated = images[offset:offset + limit]

            return {"images": paginated, "total": total}

        except Exception as e:
            logger.error(f"Error listing images: {str(e)}")
            return {"images": [], "total": 0}

    async def list_works(self) -> dict:
        """
        작품 목록 조회. 같은 work_title을 가진 장면들을 묶어서
        작품별 장면 수와 대표 썸네일(최신 장면)을 함께 반환.
        """
        try:
            container_client = self.blob_service_client.get_container_client(self.container_name)

            if not await container_client.exists():
                return {"works": []}

            blobs = []
            async for blob in container_client.list_blobs():
                if not blob.name.endswith(".json"):
                    blobs.append(blob)

            blobs.sort(key=lambda x: x.creation_time, reverse=True)

            works: dict[str, dict] = {}
            for blob in blobs:
                sidecar = await self._load_sidecar(container_client, blob.name)
                title = sidecar.get("work_title") or "미분류"

                if title not in works:
                    works[title] = {
                        "work_title": title,
                        "scene_count": 0,
                        "thumbnail_url": self._generate_sas_url(blob.name),
                        "latest_created_at": blob.creation_time.isoformat() if blob.creation_time else None,
                    }
                works[title]["scene_count"] += 1

            return {"works": list(works.values())}

        except Exception as e:
            logger.error(f"Error listing works: {str(e)}")
            return {"works": []}

    async def get_image_metadata(self, image_id: str) -> dict:
        try:
            container_client = self.blob_service_client.get_container_client(self.container_name)
            blob_client = container_client.get_blob_client(image_id)

            if not await blob_client.exists():
                return None

            props = await blob_client.get_blob_properties()
            sidecar = await self._load_sidecar(container_client, image_id)

            return {
                "image_id": image_id,
                "url": self._generate_sas_url(image_id),
                "size": props.size,
                "created_at": props.creation_time.isoformat() if props.creation_time else None,
                "content_type": props.content_settings.content_type,
                "prompt": sidecar.get("prompt"),
                "work_title": sidecar.get("work_title"),
                "excerpt": sidecar.get("excerpt"),
            }
        except Exception as e:
            logger.error(f"Error getting image metadata: {str(e)}")
            return None

    async def delete_image(self, image_id: str) -> bool:
        try:
            container_client = self.blob_service_client.get_container_client(self.container_name)
            blob_client = container_client.get_blob_client(image_id)

            if await blob_client.exists():
                await blob_client.delete_blob()
                # 사이드카도 같이 삭제
                sidecar_client = container_client.get_blob_client(self._sidecar_name(image_id))
                if await sidecar_client.exists():
                    await sidecar_client.delete_blob()
                return True
            return False
        except Exception as e:
            logger.error(f"Error deleting image {image_id}: {str(e)}")
            return False

    async def close(self):
        await self.blob_service_client.close()