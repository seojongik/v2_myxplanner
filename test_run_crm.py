#!/usr/bin/env python3
"""
CRM Flutter 앱 테스트 실행 스크립트

사용법:
    python test_run_crm.py [옵션]
    
옵션:
    --web       : 웹 브라우저에서 실행 (기본값)
    --mobile    : 연결된 모바일 디바이스/에뮬레이터에서 실행
    --ios       : iOS 시뮬레이터에서 실행 (macOS only)
    --android   : Android 에뮬레이터에서 실행
    --build     : 빌드만 수행 (실행 안함)
    --clean     : flutter clean 후 실행
"""

import os
import sys
import subprocess
import argparse

# 프로젝트 경로 설정
PROJECT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'crm')

def run_command(cmd, cwd=None):
    """명령어 실행"""
    print(f"\n🚀 실행 중: {' '.join(cmd)}")
    print(f"📁 경로: {cwd or PROJECT_DIR}\n")
    result = subprocess.run(cmd, cwd=cwd or PROJECT_DIR)
    return result.returncode

def check_flutter():
    """Flutter 설치 확인"""
    try:
        result = subprocess.run(['flutter', '--version'], 
                              capture_output=True, 
                              text=True)
        if result.returncode == 0:
            print("✅ Flutter가 설치되어 있습니다.\n")
            return True
    except FileNotFoundError:
        pass
    
    print("❌ Flutter가 설치되어 있지 않습니다.")
    print("   https://flutter.dev/docs/get-started/install 에서 설치하세요.")
    return False

def flutter_clean():
    """Flutter 클린"""
    print("🧹 Flutter 프로젝트를 정리합니다...")
    return run_command(['flutter', 'clean'])

def flutter_deep_clean():
    """Flutter 강력 정리 (빌드 캐시 포함)"""
    print("🧹 Flutter 프로젝트를 강력하게 정리합니다...")
    print("   1. flutter clean 실행...")
    result = run_command(['flutter', 'clean'])
    if result != 0:
        return result
    
    print("   2. .dart_tool 디렉토리 삭제...")
    dart_tool_path = os.path.join(PROJECT_DIR, '.dart_tool')
    if os.path.exists(dart_tool_path):
        import shutil
        shutil.rmtree(dart_tool_path)
        print("      ✅ .dart_tool 삭제 완료")
    
    print("   3. build 디렉토리 삭제...")
    build_path = os.path.join(PROJECT_DIR, 'build')
    if os.path.exists(build_path):
        import shutil
        shutil.rmtree(build_path)
        print("      ✅ build 삭제 완료")
    
    print("   4. .flutter-plugins 파일들 삭제...")
    for file in ['.flutter-plugins', '.flutter-plugins-dependencies']:
        file_path = os.path.join(PROJECT_DIR, file)
        if os.path.exists(file_path):
            os.remove(file_path)
            print(f"      ✅ {file} 삭제 완료")
    
    return 0

def flutter_pub_get():
    """Flutter 패키지 다운로드"""
    print("📦 Flutter 패키지를 다운로드합니다...")
    return run_command(['flutter', 'pub', 'get'])

def flutter_run_web():
    """웹에서 실행"""
    print("🌐 웹 브라우저에서 CRM 앱을 실행합니다...")
    return run_command(['flutter', 'run', '-d', 'chrome', '--web-port=8080'])

def flutter_run_mobile():
    """모바일 디바이스에서 실행"""
    print("📱 연결된 디바이스에서 CRM 앱을 실행합니다...")
    return run_command(['flutter', 'run'])

def flutter_run_ios():
    """iOS 시뮬레이터에서 실행"""
    print("🍎 iOS 시뮬레이터에서 CRM 앱을 실행합니다...")
    return run_command(['flutter', 'run', '-d', 'ios'])

def flutter_run_android():
    """Android 에뮬레이터에서 실행"""
    print("🤖 Android 에뮬레이터에서 CRM 앱을 실행합니다...")
    return run_command(['flutter', 'run', '-d', 'android'])

def flutter_build():
    """빌드만 수행"""
    print("🔨 CRM 앱을 빌드합니다...")
    return run_command(['flutter', 'build', 'web'])

def list_devices():
    """사용 가능한 디바이스 목록 표시"""
    print("📱 사용 가능한 디바이스 목록:\n")
    run_command(['flutter', 'devices'])

def main():
    parser = argparse.ArgumentParser(
        description='CRM Flutter 앱 테스트 실행 스크립트',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
예제:
    python test_run_crm.py              # 웹에서 실행
    python test_run_crm.py --mobile     # 모바일에서 실행
    python test_run_crm.py --ios        # iOS에서 실행
    python test_run_crm.py --clean      # 클린 후 웹 실행
        """
    )
    
    parser.add_argument('--web', action='store_true', 
                       help='웹 브라우저에서 실행')
    parser.add_argument('--mobile', action='store_true',
                       help='연결된 모바일 디바이스에서 실행')
    parser.add_argument('--ios', action='store_true',
                       help='iOS 시뮬레이터에서 실행')
    parser.add_argument('--android', action='store_true',
                       help='Android 에뮬레이터에서 실행')
    parser.add_argument('--build', action='store_true',
                       help='빌드만 수행')
    parser.add_argument('--clean', action='store_true',
                       help='flutter clean 후 실행')
    parser.add_argument('--deep-clean', action='store_true',
                       help='강력한 정리 (캐시 포함) 후 실행')
    parser.add_argument('--devices', action='store_true',
                       help='사용 가능한 디바이스 목록 표시')
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("🏌️ CRM Flutter 앱 테스트 실행")
    print("=" * 60)
    
    # Flutter 설치 확인
    if not check_flutter():
        return 1
    
    # 프로젝트 디렉토리 확인
    if not os.path.exists(PROJECT_DIR):
        print(f"❌ CRM 프로젝트 디렉토리를 찾을 수 없습니다: {PROJECT_DIR}")
        return 1
    
    # 디바이스 목록만 표시
    if args.devices:
        list_devices()
        return 0
    
    # Clean 수행
    if args.deep_clean:
        if flutter_deep_clean() != 0:
            print("❌ Flutter deep clean 실패")
            return 1
    elif args.clean:
        if flutter_clean() != 0:
            print("❌ Flutter clean 실패")
            return 1
    
    # 패키지 다운로드
    if flutter_pub_get() != 0:
        print("❌ Flutter pub get 실패")
        return 1
    
    # 실행 모드 선택
    if args.build:
        return flutter_build()
    elif args.ios:
        return flutter_run_ios()
    elif args.android:
        return flutter_run_android()
    elif args.mobile:
        return flutter_run_mobile()
    else:  # 기본값: web
        return flutter_run_web()

if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\n⚠️  사용자에 의해 중단되었습니다.")
        sys.exit(0)

