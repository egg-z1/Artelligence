import asyncio
import base64
import logging
from typing import Optional, Dict
from openai import AsyncAzureOpenAI
from config import settings

logger = logging.getLogger(__name__)

# DALL-E-3 스타일 크기 -> gpt-image-1(-mini) 지원 크기 매핑
SIZE_MAP = {
    "1024x1024": "1024x1024",
    "1792x1024": "1536x1024",
    "1024x1792": "1024x1536",
}

# DALL-E-3 quality 값 -> gpt-image-1(-mini) quality 값 매핑
QUALITY_MAP = {
    "standard": "medium",
    "hd": "high",
}


class ImageGeneratorService:
    """Azure OpenAI GPT-Image 계열 모델을 사용한 이미지 생성 서비스"""

    def __init__(self):
        """서비스 초기화"""
        self.client = AsyncAzureOpenAI(
            api_key=settings.AZURE_OPENAI_API_KEY,
            api_version=settings.AZURE_OPENAI_API_VERSION,
            azure_endpoint=settings.AZURE_OPENAI_ENDPOINT
        )
        self.deployment_name = settings.AZURE_OPENAI_DEPLOYMENT_NAME
        logger.info("ImageGeneratorService initialized")

    async def generate_image(
        self,
        prompt: str,
        size: str = "1024x1024",
        quality: str = "standard",
        style: Optional[str] = None,  # gpt-image 계열은 style 미지원, 호환성 위해 인자만 유지
        n: int = 1
    ) -> Optional[Dict]:
        """
        프롬프트 기반 이미지 생성 (gpt-image-1 / gpt-image-1-mini 대응)

        Args:
            prompt: 이미지 생성 프롬프트
            size: 이미지 크기 (내부적으로 gpt-image 지원 크기로 변환됨)
            quality: 이미지 품질 (standard/hd 입력 시 medium/high로 변환됨)
            style: 더 이상 사용되지 않음 (gpt-image 계열 미지원 파라미터)
            n: 생성할 이미지 수 (기본값: 1)

        Returns:
            생성된 이미지 정보 딕셔너리 (image_bytes 포함, url은 더 이상 제공되지 않음)
        """
        try:
            logger.info(f"Generating image with prompt: {prompt[:100]}...")

            processed_prompt = self._preprocess_prompt(prompt)
            mapped_size = SIZE_MAP.get(size, "1024x1024")
            mapped_quality = QUALITY_MAP.get(quality, quality if quality in ("low", "medium", "high", "auto") else "auto")

            if style:
                logger.debug(f"style 파라미터('{style}')는 gpt-image 계열에서 지원되지 않아 무시됩니다.")

            response = await asyncio.wait_for(
                self.client.images.generate(
                    model=self.deployment_name,
                    prompt=processed_prompt,
                    size=mapped_size,
                    quality=mapped_quality,
                    n=n
                ),
                timeout=settings.IMAGE_GENERATION_TIMEOUT
            )

            if not response.data:
                logger.error("No image data in response")
                return None

            image_data = response.data[0]

            if not getattr(image_data, "b64_json", None):
                logger.error("Response does not contain b64_json")
                return None

            image_bytes = base64.b64decode(image_data.b64_json)

            result = {
                "image_bytes": image_bytes,
                "revised_prompt": getattr(image_data, "revised_prompt", prompt),
                "size": mapped_size,
                "quality": mapped_quality,
            }

            logger.info(f"Image generated successfully ({len(image_bytes)} bytes)")
            return result

        except asyncio.TimeoutError:
            logger.error("Image generation timeout")
            raise Exception("이미지 생성 시간 초과")
        except Exception as e:
            logger.error(f"Error generating image: {str(e)}")
            raise Exception(f"이미지 생성 실패: {str(e)}")

    def _preprocess_prompt(self, prompt: str) -> str:
        if len(prompt) > settings.MAX_PROMPT_LENGTH:
            prompt = prompt[:settings.MAX_PROMPT_LENGTH]
            logger.warning(f"Prompt truncated to {settings.MAX_PROMPT_LENGTH} characters")

        prompt = prompt.strip()

        if not any(keyword in prompt.lower() for keyword in ["painting", "illustration", "art style", "digital art"]):
            prompt = f"A detailed illustration of: {prompt}"

        return prompt

    async def generate_variations(
        self,
        prompt: str,
        variations: int = 3,
        size: str = "1024x1024"
    ) -> list:
        try:
            tasks = [
                self.generate_image(prompt=prompt, size=size)
                for _ in range(variations)
            ]
            results = await asyncio.gather(*tasks, return_exceptions=True)
            valid_results = [r for r in results if not isinstance(r, Exception)]
            logger.info(f"Generated {len(valid_results)}/{variations} variations")
            return valid_results

        except Exception as e:
            logger.error(f"Error generating variations: {str(e)}")
            raise Exception(f"변형 이미지 생성 실패: {str(e)}")

    async def enhance_prompt_with_style(
        self,
        prompt: str,
        art_style: str = "realistic"
    ) -> str:
        style_templates = {
            "realistic": "Highly detailed, photorealistic",
            "anime": "Anime style, vibrant colors, detailed",
            "watercolor": "Watercolor painting style, soft colors",
            "oil_painting": "Oil painting style, classical art",
            "sketch": "Pencil sketch style, detailed linework",
            "fantasy": "Fantasy art style, magical, ethereal",
            "cyberpunk": "Cyberpunk style, neon lights, futuristic",
            "impressionist": "Impressionist painting style",
        }
        style_prefix = style_templates.get(art_style, "Detailed illustration")
        return f"{style_prefix}: {prompt}"