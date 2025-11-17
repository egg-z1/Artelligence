"""
Artelligence Backend API 테스트 스크립트
실행 방법: python test_api.py
"""

import requests
import json
import time
import websocket
from typing import Dict, Any

# 테스트할 서버 URL
BASE_URL = "http://localhost:8000"

class Colors:
    """터미널 색상"""
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    END = '\033[0m'

def print_test(test_name: str):
    """테스트 시작 출력"""
    print(f"\n{Colors.BLUE}🧪 테스트: {test_name}{Colors.END}")
    print("-" * 60)

def print_success(message: str):
    """성공 메시지 출력"""
    print(f"{Colors.GREEN}✅ {message}{Colors.END}")

def print_error(message: str):
    """에러 메시지 출력"""
    print(f"{Colors.RED}❌ {message}{Colors.END}")

def print_info(message: str):
    """정보 메시지 출력"""
    print(f"{Colors.YELLOW}ℹ️  {message}{Colors.END}")

def test_health_check():
    """헬스체크 테스트"""
    print_test("헬스체크")
    
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            print_success(f"서버 상태: {data.get('status')}")
            print_info(f"응답: {json.dumps(data, indent=2, ensure_ascii=False)}")
            return True
        else:
            print_error(f"상태 코드: {response.status_code}")
            return False
            
    except requests.exceptions.ConnectionError:
        print_error("서버에 연결할 수 없습니다. 서버가 실행 중인지 확인하세요.")
        print_info("실행 명령: uvicorn main:app --reload")
        return False
    except Exception as e:
        print_error(f"오류 발생: {str(e)}")
        return False

def test_root_endpoint():
    """루트 엔드포인트 테스트"""
    print_test("루트 엔드포인트")
    
    try:
        response = requests.get(f"{BASE_URL}/", timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            print_success("루트 엔드포인트 접근 성공")
            print_info(f"응답: {json.dumps(data, indent=2, ensure_ascii=False)}")
            return True
        else:
            print_error(f"상태 코드: {response.status_code}")
            return False
            
    except Exception as e:
        print_error(f"오류 발생: {str(e)}")
        return False

def test_api_docs():
    """API 문서 접근 테스트"""
    print_test("API 문서")
    
    try:
        # Swagger UI
        response = requests.get(f"{BASE_URL}/docs", timeout=10)
        if response.status_code == 200:
            print_success("Swagger UI 접근 가능")
            print_info(f"URL: {BASE_URL}/docs")
        else:
            print_error(f"Swagger UI 접근 실패: {response.status_code}")
        
        # ReDoc
        response = requests.get(f"{BASE_URL}/redoc", timeout=10)
        if response.status_code == 200:
            print_success("ReDoc 접근 가능")
            print_info(f"URL: {BASE_URL}/redoc")
            return True
        else:
            print_error(f"ReDoc 접근 실패: {response.status_code}")
            return False
            
    except Exception as e:
        print_error(f"오류 발생: {str(e)}")
        return False

def test_image_generation():
    """이미지 생성 API 테스트"""
    print_test("이미지 생성")
    
    # 테스트 프롬프트
    payload = {
        "prompt": "고요한 호수 위에 떠 있는 작은 배, 석양의 황금빛이 물결에 반짝인다",
        "size": "1024x1024",
        "quality": "standard",
        "style": "vivid"
    }
    
    print_info("요청 데이터:")
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    
    try:
        print_info("이미지 생성 중... (최대 2분 소요)")
        response = requests.post(
            f"{BASE_URL}/api/v1/generate",
            json=payload,
            timeout=150
        )
        
        if response.status_code == 200:
            data = response.json()
            print_success("이미지 생성 성공!")
            print_info(f"Image ID: {data.get('image_id')}")
            print_info(f"Status: {data.get('status')}")
            print_info(f"Image URL: {data.get('image_url')[:80]}...")
            print_info(f"Blob URL: {data.get('blob_url')[:80]}...")
            
            return data
        else:
            print_error(f"상태 코드: {response.status_code}")
            print_error(f"응답: {response.text}")
            return None
            
    except requests.exceptions.Timeout:
        print_error("요청 타임아웃 (150초 초과)")
        print_info("Azure OpenAI 서비스 설정을 확인하세요.")
        return None
    except Exception as e:
        print_error(f"오류 발생: {str(e)}")
        return None

def test_list_images():
    """이미지 목록 조회 테스트"""
    print_test("이미지 목록 조회")
    
    try:
        response = requests.get(
            f"{BASE_URL}/api/v1/images",
            params={"limit": 5, "offset": 0},
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            print_success(f"이미지 {data.get('total')}개 조회 성공")
            
            for idx, img in enumerate(data.get('images', [])[:3], 1):
                print_info(f"\n이미지 {idx}:")
                print(f"  - ID: {img.get('image_id')}")
                print(f"  - 생성일: {img.get('created_at')}")
                print(f"  - 크기: {img.get('size')} bytes")
            
            return data
        else:
            print_error(f"상태 코드: {response.status_code}")
            return None
            
    except Exception as e:
        print_error(f"오류 발생: {str(e)}")
        return None

def test_get_image(image_id: str):
    """특정 이미지 조회 테스트"""
    print_test(f"이미지 조회 (ID: {image_id})")
    
    try:
        response = requests.get(
            f"{BASE_URL}/api/v1/images/{image_id}",
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            print_success("이미지 조회 성공")
            print_info(f"응답: {json.dumps(data, indent=2, ensure_ascii=False)[:200]}...")
            return data
        elif response.status_code == 404:
            print_error("이미지를 찾을 수 없습니다")
            return None
        else:
            print_error(f"상태 코드: {response.status_code}")
            return None
            
    except Exception as e:
        print_error(f"오류 발생: {str(e)}")
        return None

def test_websocket():
    """WebSocket 연결 테스트"""
    print_test("WebSocket 실시간 통신")
    
    ws_url = BASE_URL.replace("http://", "ws://").replace("https://", "wss://")
    ws_url = f"{ws_url}/ws/test-client-123"
    
    print_info(f"WebSocket URL: {ws_url}")
    
    try:
        def on_message(ws, message):
            data = json.loads(message)
            status = data.get('status')
            
            if status == 'processing':
                print_info("🔄 이미지 생성 중...")
            elif status == 'saving':
                print_info("💾 이미지 저장 중...")
            elif status == 'completed':
                print_success("✅ 이미지 생성 완료!")
                print_info(f"Image ID: {data.get('image_id')}")
                ws.close()
            elif status == 'error':
                print_error(f"오류: {data.get('message')}")
                ws.close()
        
        def on_error(ws, error):
            print_error(f"WebSocket 오류: {error}")
        
        def on_close(ws, close_status_code, close_msg):
            print_info("WebSocket 연결 종료")
        
        def on_open(ws):
            print_success("WebSocket 연결 성공")
            
            # 이미지 생성 요청
            request_data = {
                "action": "generate",
                "prompt": "환상적인 밤하늘에 떠 있는 보름달",
                "size": "1024x1024"
            }
            
            print_info("이미지 생성 요청 전송...")
            ws.send(json.dumps(request_data))
        
        ws = websocket.WebSocketApp(
            ws_url,
            on_message=on_message,
            on_error=on_error,
            on_close=on_close,
            on_open=on_open
        )
        
        # 타임아웃 설정 (2분)
        ws.run_forever(ping_interval=10, ping_timeout=5)
        return True
        
    except Exception as e:
        print_error(f"오류 발생: {str(e)}")
        print_info("websocket-client 패키지 설치: pip install websocket-client")
        return False

def test_metrics():
    """메트릭스 엔드포인트 테스트"""
    print_test("Prometheus 메트릭스")
    
    try:
        response = requests.get(f"{BASE_URL}/metrics", timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            print_success("메트릭스 조회 성공")
            print_info(f"활성 WebSocket 연결: {data.get('active_websocket_connections')}")
            print_info(f"타임스탬프: {data.get('timestamp')}")
            return True
        else:
            print_error(f"상태 코드: {response.status_code}")
            return False
            
    except Exception as e:
        print_error(f"오류 발생: {str(e)}")
        return False

def run_all_tests():
    """모든 테스트 실행"""
    print(f"\n{Colors.BLUE}{'='*60}")
    print("🚀 Artelligence Backend API 테스트 시작")
    print(f"{'='*60}{Colors.END}\n")
    
    results = []
    
    # 1. 기본 연결 테스트
    results.append(("헬스체크", test_health_check()))
    time.sleep(0.5)
    
    results.append(("루트 엔드포인트", test_root_endpoint()))
    time.sleep(0.5)
    
    results.append(("API 문서", test_api_docs()))
    time.sleep(0.5)
    
    results.append(("메트릭스", test_metrics()))
    time.sleep(0.5)
    
    # 2. 이미지 목록 조회 (기존 이미지 확인)
    list_result = test_list_images()
    results.append(("이미지 목록 조회", list_result is not None))
    time.sleep(0.5)
    
    # 3. 이미지 생성 테스트 (선택적)
    print_info("\n⚠️  이미지 생성 테스트는 Azure OpenAI 크레딧을 소비합니다.")
    user_input = input("이미지 생성 테스트를 실행하시겠습니까? (y/n): ")
    
    if user_input.lower() == 'y':
        generated_image = test_image_generation()
        results.append(("이미지 생성", generated_image is not None))
        
        # 생성된 이미지 조회
        if generated_image and generated_image.get('image_id'):
            time.sleep(1)
            get_result = test_get_image(generated_image['image_id'])
            results.append(("이미지 조회", get_result is not None))
    
    # 4. WebSocket 테스트 (선택적)
    print_info("\n⚠️  WebSocket 테스트도 Azure OpenAI 크레딧을 소비합니다.")
    user_input = input("WebSocket 테스트를 실행하시겠습니까? (y/n): ")
    
    if user_input.lower() == 'y':
        ws_result = test_websocket()
        results.append(("WebSocket", ws_result))
    
    # 결과 요약
    print(f"\n{Colors.BLUE}{'='*60}")
    print("📊 테스트 결과 요약")
    print(f"{'='*60}{Colors.END}\n")
    
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for test_name, result in results:
        status = f"{Colors.GREEN}✅ PASS{Colors.END}" if result else f"{Colors.RED}❌ FAIL{Colors.END}"
        print(f"{test_name:30} {status}")
    
    print(f"\n{Colors.BLUE}{'='*60}{Colors.END}")
    print(f"총 {total}개 테스트 중 {passed}개 성공")
    
    if passed == total:
        print(f"{Colors.GREEN}🎉 모든 테스트 통과!{Colors.END}")
    else:
        print(f"{Colors.YELLOW}⚠️  {total - passed}개 테스트 실패{Colors.END}")
    
    print(f"{Colors.BLUE}{'='*60}{Colors.END}\n")

if __name__ == "__main__":
    try:
        run_all_tests()
    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}테스트가 중단되었습니다.{Colors.END}")
    except Exception as e:
        print(f"\n{Colors.RED}예상치 못한 오류: {str(e)}{Colors.END}")