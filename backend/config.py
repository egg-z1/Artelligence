from pydantic_settings import BaseSettings
from typing import List
import os
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

class Settings(BaseSettings):
    """애플리케이션 설정"""
    
    # 기본 설정
    APP_NAME: str = "Artelligence"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    
    # Azure OpenAI 설정
    AZURE_OPENAI_ENDPOINT: str = os.getenv("AZURE_OPENAI_ENDPOINT", "")
    AZURE_OPENAI_API_KEY: str = os.getenv("AZURE_OPENAI_API_KEY", "")
    AZURE_OPENAI_DEPLOYMENT_NAME: str = os.getenv("AZURE_OPENAI_DEPLOYMENT_NAME", "dall-e-3")
    AZURE_OPENAI_API_VERSION: str = "2024-02-01"
    
    # Azure Blob Storage 설정
    AZURE_STORAGE_ACCOUNT_NAME: str = os.getenv("AZURE_STORAGE_ACCOUNT_NAME", "")
    AZURE_STORAGE_ACCOUNT_KEY: str = os.getenv("AZURE_STORAGE_ACCOUNT_KEY", "")
    AZURE_STORAGE_CONNECTION_STRING: str = os.getenv("AZURE_STORAGE_CONNECTION_STRING", "")
    AZURE_STORAGE_CONTAINER_NAME: str = os.getenv("AZURE_STORAGE_CONTAINER_NAME", "generated-images")
    
    # Azure Key Vault 설정
    AZURE_KEY_VAULT_URL: str = os.getenv("AZURE_KEY_VAULT_URL", "")
    USE_KEY_VAULT: bool = os.getenv("USE_KEY_VAULT", "false").lower() == "true"
    
    # CORS 설정
    ALLOWED_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://localhost:8080",
        "https://*.azurecontainerapps.io",
        "https://www.artelligence.shop",
        "https://artelligence.shop",
    ]
    
    # 이미지 생성 설정
    DEFAULT_IMAGE_SIZE: str = "1024x1024"
    DEFAULT_IMAGE_QUALITY: str = "standard"
    DEFAULT_IMAGE_STYLE: str = "vivid"
    MAX_PROMPT_LENGTH: int = 4000
    
    # 타임아웃 설정
    IMAGE_GENERATION_TIMEOUT: int = 120  # 초
    STORAGE_UPLOAD_TIMEOUT: int = 60  # 초
    
    # 로깅 설정
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "INFO")
    
    class Config:
        env_file = ".env"
        case_sensitive = True

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        
        # Key Vault에서 시크릿 로드
        if self.USE_KEY_VAULT and self.AZURE_KEY_VAULT_URL:
            self._load_secrets_from_keyvault()
    
    def _load_secrets_from_keyvault(self):
        """Azure Key Vault에서 시크릿 로드"""
        try:
            credential = DefaultAzureCredential()
            client = SecretClient(vault_url=self.AZURE_KEY_VAULT_URL, credential=credential)
            
            # OpenAI API Key
            if not self.AZURE_OPENAI_API_KEY:
                secret = client.get_secret("azure-openai-api-key")
                self.AZURE_OPENAI_API_KEY = secret.value
            
            # OpenAI Endpoint
            if not self.AZURE_OPENAI_ENDPOINT:
                secret = client.get_secret("azure-openai-endpoint")
                self.AZURE_OPENAI_ENDPOINT = secret.value
            
            # Storage Account Key
            if not self.AZURE_STORAGE_ACCOUNT_KEY:
                secret = client.get_secret("azure-storage-account-key")
                self.AZURE_STORAGE_ACCOUNT_KEY = secret.value
            
            # Storage Connection String
            if not self.AZURE_STORAGE_CONNECTION_STRING:
                secret = client.get_secret("azure-storage-connection-string")
                self.AZURE_STORAGE_CONNECTION_STRING = secret.value
                
        except Exception as e:
            print(f"Warning: Could not load secrets from Key Vault: {str(e)}")
            print("Falling back to environment variables")

# 설정 인스턴스 생성
settings = Settings()