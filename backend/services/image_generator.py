import asyncio
import logging
from typing import Optional, Dict
from openai import AsyncAzureOpenAI
from config import settings

logger = logging.getLogger(__name__)

class ImageGeneratorService:
    """Azure OpenAI DALL-E를 사용한 이미지 생성 서비스"""
    
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
        style: str = "vivid",
        n: int = 1
    ) -> Optional[Dict]:
        """
        프롬프트 기반 이미지 생성
        
        Args:
            prompt: 이미지 생성 프롬프트
            size: 이미지 크기 (1024x1024, 1792x1024, 1024x1792)
            quality: 이미지 품질 (standard, hd)
            style: 이미지 스타일 (vivid, natural)
            n: 생성할 이미지 수 (기본값: 1)
            
        Returns:
            생성된 이미지 정보 딕셔너리
        """
        try:
            logger.info(f"Generating image with prompt: {prompt[:100]}...")
            
            # 프롬프트 전처리
            processed_prompt = self._preprocess_prompt(prompt)
            
            # DALL-E 3 이미지 생성
            response = await asyncio.wait_for(
                self.client.images.generate(
                    model=self.deployment_name,
                    prompt=processed_prompt,
                    size=size,
                    quality=quality,
                    style=style,
                    n=n
                ),
                timeout=settings.IMAGE_GENERATION_TIMEOUT
            )
            
            if not response.data:
                logger.error("No image data in response")
                return None
            
            image_data = response.data[0]
            
            result = {
                "url": image_data.url,
                "revised_prompt": getattr(image_data, "revised_prompt", prompt),
                "size": size,
                "quality": quality,
                "style": style
            }
            
            logger.info(f"Image generated successfully: {image_data.url}")
            return result
            
        except asyncio.TimeoutError:
            logger.error("Image generation timeout")
            raise Exception("이미지 생성 시간 초과")
        except Exception as e:
            logger.error(f"Error generating image: {str(e)}")
            raise Exception(f"이미지 생성 실패: {str(e)}")
    
    def _preprocess_prompt(self, prompt: str) -> str:
        """
        프롬프트 전처리
        
        Args:
            prompt: 원본 프롬프트
            
        Returns:
            전처리된 프롬프트
        """
        # 길이 제한
        if len(prompt) > settings.MAX_PROMPT_LENGTH:
            prompt = prompt[:settings.MAX_PROMPT_LENGTH]
            logger.warning(f"Prompt truncated to {settings.MAX_PROMPT_LENGTH} characters")
        
        # 기본 전처리
        prompt = prompt.strip()
        
        # 소설 장면 시각화를 위한 프롬프트 향상
        if not any(keyword in prompt.lower() for keyword in ["painting", "illustration", "art style", "digital art"]):
            prompt = f"A detailed illustration of: {prompt}"
        
        return prompt
    
    async def generate_variations(
        self,
        prompt: str,
        variations: int = 3,
        size: str = "1024x1024"
    ) -> list:
        """
        동일 프롬프트로 여러 변형 이미지 생성
        
        Args:
            prompt: 이미지 생성 프롬프트
            variations: 생성할 변형 수
            size: 이미지 크기
            
        Returns:
            생성된 이미지 리스트
        """
        try:
            tasks = []
            for i in range(variations):
                # 각 변형마다 약간 다른 스타일 적용
                style = "vivid" if i % 2 == 0 else "natural"
                task = self.generate_image(prompt=prompt, size=size, style=style)
                tasks.append(task)
            
            results = await asyncio.gather(*tasks, return_exceptions=True)
            
            # 성공한 결과만 반환
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
        """
        프롬프트에 아트 스타일 추가
        
        Args:
            prompt: 원본 프롬프트
            art_style: 적용할 아트 스타일
            
        Returns:
            스타일이 적용된 프롬프트
        """
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
        enhanced_prompt = f"{style_prefix}: {prompt}"
        
        return enhanced_prompt