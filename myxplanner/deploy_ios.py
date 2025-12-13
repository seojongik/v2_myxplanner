#!/usr/bin/env python3
"""
iOS App Store 배포 스크립트
Fastlane을 사용하여 자동으로 빌드하고 App Store Connect에 업로드합니다.
"""

import os
import sys
import subprocess
import argparse
from pathlib import Path

# 프로젝트 루트 경로 (myxplanner 디렉토리)
MYXPLANNER_ROOT = Path(__file__).parent
# 프로젝트 전체 루트 경로 (상위 디렉토리)
PROJECT_ROOT = MYXPLANNER_ROOT.parent
IOS_DIR = MYXPLANNER_ROOT / "ios"
FASTLANE_DIR = IOS_DIR / "fastlane"
NON_GIT_DIR = PROJECT_ROOT / "non-git"
ACCOUNT_INFO_FILE = NON_GIT_DIR / "ACCOUNT_INFO_MYGOLFPLANNER.md"

# 색상 출력
class Colors:
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    RESET = '\033[0m'
    BOLD = '\033[1m'

def print_success(msg):
    print(f"{Colors.GREEN}✅ {msg}{Colors.RESET}")

def print_warning(msg):
    print(f"{Colors.YELLOW}⚠️  {msg}{Colors.RESET}")

def print_error(msg):
    print(f"{Colors.RED}❌ {msg}{Colors.RESET}")

def print_info(msg):
    print(f"{Colors.BLUE}ℹ️  {msg}{Colors.RESET}")

def print_header(msg):
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.BLUE}{msg}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.RESET}\n")

def read_account_info():
    """ACCOUNT_INFO_MYGOLFPLANNER.md에서 계정 정보 읽기"""
    if not ACCOUNT_INFO_FILE.exists():
        return None
    
    info = {}
    with open(ACCOUNT_INFO_FILE, 'r', encoding='utf-8') as f:
        content = f.read()
        
        # API Key ID 찾기
        if '**API Key ID**' in content:
            for line in content.split('\n'):
                if '**API Key ID**' in line:
                    parts = line.split('|')
                    if len(parts) >= 3:
                        info['api_key_id'] = parts[2].strip().strip('`')
        
        # Issuer ID 찾기
        if '**Issuer ID**' in content:
            for line in content.split('\n'):
                if '**Issuer ID**' in line:
                    parts = line.split('|')
                    if len(parts) >= 3:
                        info['issuer_id'] = parts[2].strip().strip('`')
    
    return info

def find_api_key_file():
    """API 키 파일 찾기"""
    # 프로젝트 루트의 non-git 디렉토리에서 .p8 파일 찾기
    if NON_GIT_DIR.exists():
        for p8_file in NON_GIT_DIR.glob("*.p8"):
            # AuthKey_ 또는 ApiKey_로 시작하는 파일
            if p8_file.name.startswith(("AuthKey_", "ApiKey_")):
                return p8_file
    
    # fastlane 디렉토리에서 AuthKey.p8 찾기
    auth_key_file = FASTLANE_DIR / "AuthKey.p8"
    if auth_key_file.exists():
        return auth_key_file
    
    return None

def setup_api_key():
    """API 키 파일을 fastlane 디렉토리에 복사"""
    api_key_file = find_api_key_file()
    
    if not api_key_file:
        print_warning("API 키 파일을 찾을 수 없습니다.")
        return False
    
    target_file = FASTLANE_DIR / "AuthKey.p8"
    
    # 이미 같은 파일이면 스킵
    if target_file.exists() and target_file.samefile(api_key_file):
        print_info(f"API 키 파일 이미 설정됨: {api_key_file.name}")
        return True
    
    # 파일 복사
    import shutil
    shutil.copy2(api_key_file, target_file)
    print_success(f"API 키 파일 복사 완료: {api_key_file.name} → AuthKey.p8")
    return True

def run_fastlane(lane, api_key_id=None, issuer_id=None):
    """Fastlane 실행"""
    os.chdir(MYXPLANNER_ROOT / "ios")
    
    # 환경 변수 설정
    env = os.environ.copy()
    
    if api_key_id:
        env['APP_STORE_CONNECT_API_KEY_ID'] = api_key_id
        print_info(f"API Key ID: {api_key_id}")
    
    if issuer_id:
        env['APP_STORE_CONNECT_ISSUER_ID'] = issuer_id
        print_info(f"Issuer ID: {issuer_id}")
    
    # Fastlane 실행
    cmd = ['fastlane', lane]
    print_header(f"Fastlane 실행: {lane}")
    print_info(f"명령어: {' '.join(cmd)}")
    print()
    
    try:
        result = subprocess.run(cmd, env=env, check=False)
        return result.returncode == 0
    except KeyboardInterrupt:
        print_error("사용자에 의해 중단되었습니다.")
        return False
    except Exception as e:
        print_error(f"실행 중 오류 발생: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(
        description='iOS App Store 배포 스크립트',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
사용 예시:
  %(prog)s release          # App Store에 업로드 (제출은 수동)
  %(prog)s submit           # App Store에 업로드 + 자동 제출
  %(prog)s beta             # TestFlight에 배포
  %(prog)s build            # 빌드만 수행 (업로드 없음)
        """
    )
    
    parser.add_argument(
        'action',
        nargs='?',  # 선택적 인자로 변경
        choices=['release', 'beta', 'build', 'testflight', 'submit'],
        help='실행할 작업 (release: App Store 업로드만, submit: App Store 자동 제출, beta/testflight: TestFlight, build: 빌드만)'
    )
    
    parser.add_argument(
        '--api-key-id',
        help='App Store Connect API Key ID (기본값: non-git/ACCOUNT_INFO_MYGOLFPLANNER.md에서 읽기)'
    )
    
    parser.add_argument(
        '--issuer-id',
        help='App Store Connect Issuer ID (기본값: non-git/ACCOUNT_INFO_MYGOLFPLANNER.md에서 읽기)'
    )
    
    parser.add_argument(
        '--skip-setup',
        action='store_true',
        help='API 키 파일 설정 건너뛰기'
    )
    
    args = parser.parse_args()
    
    # action이 없으면 대화형으로 선택
    if not args.action:
        print_header("iOS App Store 배포 스크립트")
        print()
        print("어떤 작업을 수행하시겠습니까?")
        print()
        print("1. release   - App Store에 업로드 (제출은 수동)")
        print("2. submit    - App Store에 업로드 + 자동 제출")
        print("3. beta      - TestFlight에 배포")
        print("4. build     - 빌드만 수행 (업로드 없음)")
        print("5. help      - 도움말 보기")
        print()
        
        choice = input("선택 (1-5, 기본값: 1): ").strip() or "1"
        
        choice_map = {
            "1": "release",
            "2": "submit",
            "3": "beta",
            "4": "build",
            "5": "help"
        }
        
        if choice == "5" or choice not in choice_map:
            parser.print_help()
            print()
            print_info("💡 빠른 시작:")
            print_info("   python3 deploy_ios.py release   # 업로드만")
            print_info("   python3 deploy_ios.py submit    # 업로드 + 자동 제출")
            print_info("   python3 deploy_ios.py beta       # TestFlight")
            print_info("   python3 deploy_ios.py build     # 빌드만")
            sys.exit(0)
        
        args.action = choice_map[choice]
        print()
    
    print_header("iOS App Store 배포 스크립트")
    
    # 작업 매핑
    lane_map = {
        'release': 'release',  # 업로드만
        'submit': 'submit',    # 업로드 + 자동 제출
        'beta': 'beta',
        'testflight': 'upload_testflight',
        'build': 'build_only'
    }
    
    lane = lane_map[args.action]
    
    # API 키 설정
    if not args.skip_setup:
        if not setup_api_key():
            print_warning("API 키 파일을 찾을 수 없습니다. 수동으로 설정하세요.")
    
    # 계정 정보 읽기
    account_info = read_account_info()
    
    # API Key ID 설정
    api_key_id = args.api_key_id
    if not api_key_id and account_info:
        api_key_id = account_info.get('api_key_id')
    
    if not api_key_id:
        print_warning("API Key ID를 찾을 수 없습니다.")
        print_info("환경 변수 APP_STORE_CONNECT_API_KEY_ID를 설정하거나 --api-key-id 옵션을 사용하세요.")
    
    # Issuer ID 설정
    issuer_id = args.issuer_id
    if not issuer_id and account_info:
        issuer_id = account_info.get('issuer_id')
    
    if not issuer_id:
        print_warning("Issuer ID를 찾을 수 없습니다.")
        print_info("환경 변수 APP_STORE_CONNECT_ISSUER_ID를 설정하거나 --issuer-id 옵션을 사용하세요.")
    
    # Fastlane 실행
    success = run_fastlane(lane, api_key_id, issuer_id)
    
    if success:
        print_success("배포 완료!")
        if lane == 'release':
            print_info("App Store Connect에서 빌드 처리를 확인하세요:")
            print_info("https://appstoreconnect.apple.com")
            print_warning("빌드가 처리되면 수동으로 제출해야 합니다.")
        elif lane == 'submit':
            print_success("자동 제출 완료!")
            print_info("리뷰 상태를 App Store Connect에서 확인하세요:")
            print_info("https://appstoreconnect.apple.com")
    else:
        print_error("배포 실패")
        sys.exit(1)

if __name__ == '__main__':
    main()
