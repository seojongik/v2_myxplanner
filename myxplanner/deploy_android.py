#!/usr/bin/env python3
"""
Android Google Play Store 배포 스크립트
Flutter와 Fastlane을 사용하여 자동으로 빌드하고 Google Play Console에 업로드합니다.
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
ANDROID_DIR = MYXPLANNER_ROOT / "android"
FASTLANE_DIR = ANDROID_DIR / "fastlane"
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
        
        # 패키지명 찾기
        if '**앱 패키지명**' in content:
            for line in content.split('\n'):
                if '**앱 패키지명**' in line:
                    parts = line.split('|')
                    if len(parts) >= 3:
                        info['package_name'] = parts[2].strip().strip('`')
        
        # Keystore 정보 찾기
        if '**Keystore 파일**' in content:
            for line in content.split('\n'):
                if '**Keystore 파일**' in line:
                    parts = line.split('|')
                    if len(parts) >= 3:
                        keystore_path = parts[2].strip().strip('`')
                        # 상대 경로를 절대 경로로 변환
                        if not Path(keystore_path).is_absolute():
                            keystore_path = ANDROID_DIR / keystore_path
                        info['keystore_path'] = str(keystore_path)
        
        if '**Key Alias**' in content:
            for line in content.split('\n'):
                if '**Key Alias**' in line:
                    parts = line.split('|')
                    if len(parts) >= 3:
                        info['key_alias'] = parts[2].strip().strip('`')
        
        if '**Store Password**' in content:
            for line in content.split('\n'):
                if '**Store Password**' in line:
                    parts = line.split('|')
                    if len(parts) >= 3:
                        info['store_password'] = parts[2].strip().strip('`')
        
        if '**Key Password**' in content:
            for line in content.split('\n'):
                if '**Key Password**' in line:
                    parts = line.split('|')
                    if len(parts) >= 3:
                        info['key_password'] = parts[2].strip().strip('`')
    
    return info

def find_aab_file():
    """AAB 파일 찾기"""
    aab_path = MYXPLANNER_ROOT / "build" / "app" / "outputs" / "bundle" / "release" / "app-release.aab"
    if aab_path.exists():
        return aab_path
    
    # 다른 가능한 경로들 확인
    possible_paths = [
        MYXPLANNER_ROOT / "build" / "app" / "outputs" / "bundle" / "release" / "*.aab",
        MYXPLANNER_ROOT / "build" / "app" / "outputs" / "bundle" / "*.aab",
    ]
    
    for pattern in possible_paths:
        matches = list(MYXPLANNER_ROOT.glob(str(pattern.relative_to(MYXPLANNER_ROOT))))
        if matches:
            return matches[0]
    
    return None

def run_fastlane(lane, package_name=None, **kwargs):
    """Fastlane 실행"""
    os.chdir(ANDROID_DIR)
    
    # 환경 변수 설정
    env = os.environ.copy()
    
    if package_name:
        env['PACKAGE_NAME'] = package_name
    
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
        description='Android Google Play Store 배포 스크립트',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
사용 예시:
  %(prog)s release          # Google Play에 업로드 (제출은 수동)
  %(prog)s submit           # Google Play에 업로드 + 자동 제출
  %(prog)s internal         # 내부 테스트 트랙에 배포
  %(prog)s build            # 빌드만 수행 (업로드 없음)
        """
    )
    
    parser.add_argument(
        'action',
        nargs='?',  # 선택적 인자로 변경
        choices=['release', 'submit', 'internal', 'build'],
        help='실행할 작업 (release: 업로드만, submit: 업로드+자동제출, internal: 내부테스트, build: 빌드만)'
    )
    
    parser.add_argument(
        '--package-name',
        help='앱 패키지명 (기본값: non-git/ACCOUNT_INFO_MYGOLFPLANNER.md에서 읽기)'
    )
    
    parser.add_argument(
        '--skip-build',
        action='store_true',
        help='빌드 건너뛰기 (이미 빌드된 AAB 파일 사용)'
    )
    
    args = parser.parse_args()
    
    # action이 없으면 대화형으로 선택
    if not args.action:
        print_header("Android Google Play Store 배포 스크립트")
        print()
        print("어떤 작업을 수행하시겠습니까?")
        print()
        print("1. release   - Google Play에 업로드 (제출은 수동)")
        print("2. submit    - Google Play에 업로드 + 자동 제출")
        print("3. internal  - 내부 테스트 트랙에 배포")
        print("4. build     - 빌드만 수행 (업로드 없음)")
        print("5. help      - 도움말 보기")
        print()
        
        choice = input("선택 (1-5, 기본값: 1): ").strip() or "1"
        
        choice_map = {
            "1": "release",
            "2": "submit",
            "3": "internal",
            "4": "build",
            "5": "help"
        }
        
        if choice == "5" or choice not in choice_map:
            parser.print_help()
            print()
            print_info("💡 빠른 시작:")
            print_info("   python3 deploy_android.py release   # 업로드만")
            print_info("   python3 deploy_android.py submit    # 업로드 + 자동 제출")
            print_info("   python3 deploy_android.py internal  # 내부 테스트")
            print_info("   python3 deploy_android.py build     # 빌드만")
            sys.exit(0)
        
        args.action = choice_map[choice]
        print()
    
    print_header("Android Google Play Store 배포 스크립트")
    
    # 작업 매핑
    lane_map = {
        'release': 'release',      # 업로드만
        'submit': 'submit',        # 업로드 + 자동 제출
        'internal': 'internal',    # 내부 테스트 트랙
        'build': 'build_only'      # 빌드만
    }
    
    lane = lane_map[args.action]
    
    # 계정 정보 읽기
    account_info = read_account_info()
    
    # 패키지명 설정
    package_name = args.package_name
    if not package_name and account_info:
        package_name = account_info.get('package_name')
    
    if not package_name:
        print_warning("패키지명을 찾을 수 없습니다.")
        print_info("환경 변수 PACKAGE_NAME을 설정하거나 --package-name 옵션을 사용하세요.")
    
    # 빌드 확인 (--skip-build 옵션이 없으면 항상 새로 빌드)
    if args.skip_build:
        aab_file = find_aab_file()
        if not aab_file:
            print_error("기존 AAB 파일을 찾을 수 없습니다. --skip-build 옵션을 제거하고 빌드를 실행하세요.")
            sys.exit(1)
        print_info(f"기존 AAB 파일 사용: {aab_file}")
    elif lane != 'build_only':
        # 기존 AAB 파일이 있어도 새로 빌드
        existing_aab = find_aab_file()
        if existing_aab:
            print_info(f"기존 AAB 파일 발견: {existing_aab}")
            print_info("새로 빌드합니다...")
    
    # Fastlane 실행
    success = run_fastlane(lane, package_name=package_name)
    
    if success:
        print_success("배포 완료!")
        if lane in ['release', 'submit']:
            print_info("Google Play Console에서 빌드 처리를 확인하세요:")
            print_info("https://play.google.com/console")
    else:
        print_error("배포 실패")
        sys.exit(1)

if __name__ == '__main__':
    main()
