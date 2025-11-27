#!/usr/bin/env python3
"""
MyXPlanner Flutter 앱 테스트 실행 스크립트

사용법:
    python test_run_myxplanner.py [옵션]
    
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
PROJECT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'myxplanner')

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

def flutter_pub_get():
    """Flutter 패키지 다운로드"""
    print("📦 Flutter 패키지를 다운로드합니다...")
    return run_command(['flutter', 'pub', 'get'])

def flutter_run_web():
    """웹에서 실행"""
    print("🌐 웹 브라우저에서 MyXPlanner 앱을 실행합니다...")
    return run_command(['flutter', 'run', '-d', 'chrome', '--web-port=8081'])

def flutter_run_mobile():
    """모바일 디바이스에서 실행"""
    print("📱 연결된 디바이스에서 MyXPlanner 앱을 실행합니다...")
    return run_command(['flutter', 'run'])

def flutter_run_ios():
    """iOS 시뮬레이터에서 실행"""
    print("🍎 iOS 시뮬레이터에서 MyXPlanner 앱을 실행합니다...")
    return run_command(['flutter', 'run', '-d', 'ios'])

def flutter_run_android():
    """Android 에뮬레이터에서 실행"""
    print("🤖 Android 에뮬레이터에서 MyXPlanner 앱을 실행합니다...")
    return run_command(['flutter', 'run', '-d', 'android'])

def flutter_build():
    """빌드만 수행"""
    print("🔨 MyXPlanner 앱을 빌드합니다...")
    return run_command(['flutter', 'build', 'web'])

def list_devices():
    """사용 가능한 디바이스 목록 표시"""
    print("📱 사용 가능한 디바이스 목록:\n")
    run_command(['flutter', 'devices'])

def check_firebase():
    """Firebase 설정 확인"""
    firebase_options = os.path.join(PROJECT_DIR, 'lib', 'firebase_options.dart')
    
    print("\n🔥 Firebase 설정 확인:")
    if os.path.exists(firebase_options):
        print(f"  ✅ firebase_options.dart 파일이 존재합니다.")
    else:
        print(f"  ⚠️  firebase_options.dart 파일이 없습니다.")
        print(f"     Firebase CLI로 설정을 생성하세요:")
        print(f"     flutterfire configure")
    
    # Firebase 설정 파일 확인
    firebase_json = os.path.join(PROJECT_DIR, 'firebase.json')
    if os.path.exists(firebase_json):
        print(f"  ✅ firebase.json 파일이 존재합니다.")
    else:
        print(f"  ℹ️  firebase.json 파일이 없습니다. (선택사항)")

def main():
    parser = argparse.ArgumentParser(
        description='MyXPlanner Flutter 앱 테스트 실행 스크립트',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
예제:
    python test_run_myxplanner.py              # 웹에서 실행
    python test_run_myxplanner.py --mobile     # 모바일에서 실행
    python test_run_myxplanner.py --ios        # iOS에서 실행
    python test_run_myxplanner.py --clean      # 클린 후 웹 실행
    python test_run_myxplanner.py --check      # Firebase 설정 확인
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
    parser.add_argument('--devices', action='store_true',
                       help='사용 가능한 디바이스 목록 표시')
    parser.add_argument('--check', action='store_true',
                       help='Firebase 설정 확인')
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("📅 MyXPlanner Flutter 앱 테스트 실행")
    print("=" * 60)
    
    # Flutter 설치 확인
    if not check_flutter():
        return 1
    
    # 프로젝트 디렉토리 확인
    if not os.path.exists(PROJECT_DIR):
        print(f"❌ MyXPlanner 프로젝트 디렉토리를 찾을 수 없습니다: {PROJECT_DIR}")
        return 1
    
    # Firebase 설정 확인
    if args.check:
        check_firebase()
        return 0
    
    # 디바이스 목록만 표시
    if args.devices:
        list_devices()
        return 0
    
    # Clean 수행
    if args.clean:
        if flutter_clean() != 0:
            print("❌ Flutter clean 실패")
            return 1
    
    # 패키지 다운로드
    if flutter_pub_get() != 0:
        print("❌ Flutter pub get 실패")
        return 1
    
    # Firebase 설정 간단 확인
    check_firebase()
    
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


