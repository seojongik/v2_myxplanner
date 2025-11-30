#!/usr/bin/env python3
"""
CRM Lite Pro Flutter 앱 테스트 실행 스크립트

사용법:
    python test_run_crm_lite_pro.py [옵션]

옵션:
    --web       : 웹 브라우저에서 실행 (기본값)
    --mobile    : 연결된 모바일 디바이스/에뮬레이터에서 실행
    --ios       : iOS 시뮬레이터에서 실행 (macOS only)
    --android   : Android 에뮬레이터에서 실행
    --build     : 빌드만 수행 (실행 안함)
    --clean     : flutter clean 후 실행
    --deep-clean: 강력한 정리 (캐시 포함) 후 실행
"""

import os
import sys
import subprocess
import argparse

# 프로젝트 경로 설정
PROJECT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'crm_lite_pro')

# Android SDK 경로
ANDROID_SDK = os.path.expanduser('~/Library/Android/sdk')
EMULATOR_PATH = os.path.join(ANDROID_SDK, 'emulator', 'emulator')
AVD_NAME = 'Pixel_6_API_34'


def run_command(cmd, cwd=None):
    """명령어 실행"""
    print(f"\n🚀 실행 중: {' '.join(cmd)}")
    print(f"📁 경로: {cwd or PROJECT_DIR}\n")
    result = subprocess.run(cmd, cwd=cwd or PROJECT_DIR)
    return result.returncode


def check_flutter():
    """Flutter 설치 확인"""
    try:
        result = subprocess.run(
            ['flutter', '--version'],
            capture_output=True,
            text=True,
        )
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
    print("🌐 웹 브라우저에서 CRM Lite Pro 앱을 실행합니다...")
    return run_command(['flutter', 'run', '-d', 'chrome', '--web-port=8082'])


def flutter_run_mobile():
    """모바일 디바이스에서 실행"""
    print("📱 연결된 디바이스에서 CRM Lite Pro 앱을 실행합니다...")
    return run_command(['flutter', 'run'])


def get_ios_device_id():
    """실행 중인 iOS 시뮬레이터의 디바이스 ID 반환"""
    result = subprocess.run(['flutter', 'devices'], capture_output=True, text=True, cwd=PROJECT_DIR)
    for line in result.stdout.split('\n'):
        if 'simulator' in line.lower() and 'ios' in line.lower():
            # 형식: iPhone 16 (mobile) • 134E3B34-... • ios • ...
            parts = line.split('•')
            if len(parts) >= 2:
                device_id = parts[1].strip()
                return device_id
    return None


def start_ios_simulator():
    """iOS 시뮬레이터 시작"""
    import time

    # 이미 실행 중인지 확인 (simulator라는 단어가 있으면 실행 중)
    result = subprocess.run(['flutter', 'devices'], capture_output=True, text=True, cwd=PROJECT_DIR)
    if 'simulator' in result.stdout.lower():
        print("✅ iOS 시뮬레이터가 이미 실행 중입니다.")
        return True

    print("🍎 iOS 시뮬레이터 시작 중...")

    # 사용 가능한 시뮬레이터 찾기
    sim_result = subprocess.run(
        ['xcrun', 'simctl', 'list', 'devices', 'available', '-j'],
        capture_output=True, text=True
    )

    try:
        import json
        devices = json.loads(sim_result.stdout)
        # iPhone 시뮬레이터 찾기
        for runtime, device_list in devices.get('devices', {}).items():
            if 'iOS' in runtime:
                for device in device_list:
                    if 'iPhone' in device.get('name', '') and device.get('isAvailable', False):
                        udid = device['udid']
                        name = device['name']
                        print(f"   📱 {name} 부팅 중...")
                        subprocess.run(['xcrun', 'simctl', 'boot', udid], capture_output=True)
                        subprocess.run(['open', '-a', 'Simulator'])
                        break
                break
    except:
        # JSON 파싱 실패 시 그냥 Simulator 앱 열기
        subprocess.run(['open', '-a', 'Simulator'])

    # 시뮬레이터가 준비될 때까지 대기
    print("⏳ 시뮬레이터 부팅 대기 중...")
    for i in range(30):  # 최대 60초 대기
        time.sleep(2)
        result = subprocess.run(['flutter', 'devices'], capture_output=True, text=True, cwd=PROJECT_DIR)
        if 'simulator' in result.stdout.lower():
            print("✅ iOS 시뮬레이터가 준비되었습니다.")
            return True
        if i % 5 == 0:
            print(f"   {i*2}초 경과...")

    print("❌ 시뮬레이터 시작 시간 초과")
    return False


def flutter_run_ios():
    """iOS 시뮬레이터에서 실행"""
    if not start_ios_simulator():
        return 1

    device_id = get_ios_device_id()
    if device_id:
        print(f"🍎 iOS 시뮬레이터 ({device_id})에서 CRM Lite Pro 앱을 실행합니다...")
        return run_command(['flutter', 'run', '-d', device_id])
    else:
        print("❌ iOS 시뮬레이터 디바이스 ID를 찾을 수 없습니다.")
        return 1


def start_android_emulator():
    """Android 에뮬레이터 시작"""
    import time

    # 이미 실행 중인지 확인 (sdk 또는 emulator-로 시작하는 디바이스 확인)
    result = subprocess.run(['flutter', 'devices'], capture_output=True, text=True, cwd=PROJECT_DIR)
    if 'sdk' in result.stdout.lower() or 'emulator-' in result.stdout.lower():
        print("✅ Android 에뮬레이터가 이미 실행 중입니다.")
        return True

    if not os.path.exists(EMULATOR_PATH):
        print(f"❌ Android 에뮬레이터를 찾을 수 없습니다: {EMULATOR_PATH}")
        print("   Android Studio에서 AVD Manager로 에뮬레이터를 생성하세요.")
        return False

    # AVD 목록 확인
    avd_result = subprocess.run(
        [os.path.join(ANDROID_SDK, 'cmdline-tools/latest/bin/avdmanager'), 'list', 'avd', '-c'],
        capture_output=True, text=True
    )
    avd_list = [a.strip() for a in avd_result.stdout.strip().split('\n') if a.strip()]

    if not avd_list:
        print("❌ 사용 가능한 Android 에뮬레이터가 없습니다.")
        print("   Android Studio > Tools > AVD Manager에서 에뮬레이터를 생성하세요.")
        return False

    avd_name = avd_list[0]  # 첫 번째 AVD 사용
    print(f"🤖 Android 에뮬레이터 '{avd_name}' 시작 중...")

    # 환경변수 설정
    env = os.environ.copy()
    env['ANDROID_SDK_ROOT'] = ANDROID_SDK
    env['ANDROID_HOME'] = ANDROID_SDK

    # 백그라운드에서 에뮬레이터 실행
    subprocess.Popen(
        [EMULATOR_PATH, '-avd', avd_name, '-no-snapshot-load'],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        env=env
    )

    # 에뮬레이터가 부팅될 때까지 대기
    print("⏳ 에뮬레이터 부팅 대기 중...")
    for i in range(60):  # 최대 120초 대기
        time.sleep(2)
        result = subprocess.run(['flutter', 'devices'], capture_output=True, text=True, cwd=PROJECT_DIR)
        if 'sdk' in result.stdout.lower() or 'emulator-' in result.stdout.lower():
            print("✅ Android 에뮬레이터가 준비되었습니다.")
            time.sleep(3)  # 추가 안정화 대기
            return True
        if i % 5 == 0:
            print(f"   {i*2}초 경과...")

    print("❌ 에뮬레이터 시작 시간 초과")
    return False


def get_android_device_id():
    """실행 중인 Android 에뮬레이터의 디바이스 ID 반환"""
    result = subprocess.run(['flutter', 'devices'], capture_output=True, text=True, cwd=PROJECT_DIR)
    for line in result.stdout.split('\n'):
        if ('sdk' in line.lower() or 'emulator-' in line.lower()) and 'android' in line.lower():
            # 형식: sdk gphone64 arm64 (mobile) • emulator-5554 • android-arm64 • ...
            parts = line.split('•')
            if len(parts) >= 2:
                device_id = parts[1].strip()
                return device_id
    return None


def flutter_run_android():
    """Android 에뮬레이터에서 실행"""
    if not start_android_emulator():
        return 1

    device_id = get_android_device_id()
    if device_id:
        print(f"🤖 Android 에뮬레이터 ({device_id})에서 CRM Lite Pro 앱을 실행합니다...")
        return run_command(['flutter', 'run', '-d', device_id])
    else:
        print("❌ Android 에뮬레이터 디바이스 ID를 찾을 수 없습니다.")
        return 1


def flutter_build():
    """빌드만 수행"""
    print("🔨 CRM Lite Pro 앱을 빌드합니다...")
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
    firebase_json_alt = os.path.join(PROJECT_DIR, 'firebase', 'firebase.json')
    if os.path.exists(firebase_json):
        print(f"  ✅ firebase.json 파일이 존재합니다.")
    elif os.path.exists(firebase_json_alt):
        print(f"  ✅ firebase/firebase.json 파일이 존재합니다.")
    else:
        print(f"  ℹ️  firebase.json 파일이 없습니다. (선택사항)")


def interactive_select():
    """대화형 디바이스 선택"""
    print("\n📱 실행할 디바이스를 선택하세요:\n")
    print("  1. 🌐 웹 (Chrome)")
    print("  2. 🤖 Android")
    print("  3. 🍎 iOS")
    print("  4. 📱 자동 (연결된 디바이스)")
    print("  5. 🔨 빌드만")
    print("  6. 📋 디바이스 목록 보기")
    print("  0. ❌ 취소\n")

    try:
        choice = input("선택 (0-6): ").strip()
        return choice
    except EOFError:
        return '0'


def main():
    parser = argparse.ArgumentParser(
        description='CRM Lite Pro Flutter 앱 테스트 실행 스크립트',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
예제:
    python test_run_crm_lite_pro.py              # 대화형 선택
    python test_run_crm_lite_pro.py --web        # 웹에서 실행
    python test_run_crm_lite_pro.py --mobile     # 모바일에서 실행
    python test_run_crm_lite_pro.py --ios        # iOS에서 실행
    python test_run_crm_lite_pro.py --clean      # 클린 후 실행
    python test_run_crm_lite_pro.py --check      # Firebase 설정 확인
        """,
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
    parser.add_argument('--check', action='store_true',
                       help='Firebase 설정 확인')

    args = parser.parse_args()

    print("=" * 60)
    print("🏌️ CRM Lite Pro Flutter 앱 테스트 실행")
    print("=" * 60)

    # Flutter 설치 확인
    if not check_flutter():
        return 1

    # 프로젝트 디렉토리 확인
    if not os.path.exists(PROJECT_DIR):
        print(f"❌ CRM Lite Pro 프로젝트 디렉토리를 찾을 수 없습니다: {PROJECT_DIR}")
        return 1

    # Firebase 설정 확인
    if args.check:
        check_firebase()
        return 0

    # 디바이스 목록만 표시
    if args.devices:
        list_devices()
        return 0

    # 옵션이 없으면 대화형 선택
    has_option = args.web or args.mobile or args.ios or args.android or args.build

    if not has_option:
        choice = interactive_select()
        if choice == '0':
            print("\n취소되었습니다.")
            return 0
        elif choice == '1':
            args.web = True
        elif choice == '2':
            args.android = True
        elif choice == '3':
            args.ios = True
        elif choice == '4':
            args.mobile = True
        elif choice == '5':
            args.build = True
        elif choice == '6':
            list_devices()
            return 0
        else:
            print("\n❌ 잘못된 선택입니다.")
            return 1

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




