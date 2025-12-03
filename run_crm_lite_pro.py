#!/usr/bin/env python3
"""CRM Lite Pro 실행 스크립트"""
import subprocess
import sys
import os
import time
import json

PROJECT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'crm_lite_pro')

def find_android_device():
    """실행 중인 Android 디바이스 찾기"""
    result = subprocess.run(['flutter', 'devices'], capture_output=True, text=True, cwd=PROJECT_DIR)
    for line in result.stdout.split('\n'):
        if 'android' in line.lower() and ('•' in line or 'emulator' in line.lower() or 'sdk' in line.lower()):
            # flutter devices 출력 형식: "device_name • device_id • android • ..."
            parts = line.split('•')
            if len(parts) >= 2:
                device_id = parts[1].strip()
                if device_id:
                    return device_id
    return None

def find_ios_devices():
    """실행 중인 iOS 디바이스/시뮬레이터 목록 찾기"""
    result = subprocess.run(['flutter', 'devices'], capture_output=True, text=True, cwd=PROJECT_DIR)
    devices = []
    for line in result.stdout.split('\n'):
        if ('ios' in line.lower() or 'iphone' in line.lower()) and '•' in line:
            parts = line.split('•')
            if len(parts) >= 2:
                device_id = parts[1].strip()
                device_name = parts[0].strip() if len(parts) > 0 else ''
                if device_id:
                    is_simulator = 'simulator' in line.lower()
                    devices.append((device_id, device_name, is_simulator))
    return devices

def select_ios_device():
    """iOS 디바이스 선택 (실제 디바이스와 시뮬레이터 중 선택)"""
    devices = find_ios_devices()
    
    if not devices:
        return None
    
    if len(devices) == 1:
        device_id, device_name, is_simulator = devices[0]
        device_type = "시뮬레이터" if is_simulator else "실제 디바이스 ✅"
        print(f"\n📱 iOS 디바이스 발견: {device_name} ({device_type})")
        return device_id
    
    # 여러 디바이스가 있으면 선택
    print("\n" + "="*50)
    print("📱 iOS 디바이스 선택")
    print("="*50)
    
    physical_devices = [(d, n, s) for d, n, s in devices if not s]
    simulators = [(d, n, s) for d, n, s in devices if s]
    
    all_devices = physical_devices + simulators  # 실제 디바이스 먼저
    
    for i, (device_id, device_name, is_simulator) in enumerate(all_devices, 1):
        device_type = "시뮬레이터" if is_simulator else "실제 디바이스 ✅ (푸시 알림 가능)"
        print(f"{i}. {device_name} - {device_type}")
    
    print("="*50)
    
    while True:
        try:
            choice = input(f"\n선택하세요 (1-{len(all_devices)}): ").strip()
            idx = int(choice) - 1
            if 0 <= idx < len(all_devices):
                selected = all_devices[idx]
                print(f"\n✅ 선택됨: {selected[1]}")
                return selected[0]
        except ValueError:
            pass
        print(f"❌ 1-{len(all_devices)} 사이의 숫자를 입력하세요.")

def find_ios_device():
    """실행 중인 iOS 디바이스/시뮬레이터 찾기 (하위 호환성)"""
    devices = find_ios_devices()
    
    # 실제 디바이스를 우선적으로 반환 (푸시 알림 테스트용)
    for device_id, device_name, is_simulator in devices:
        if not is_simulator:
            return device_id
    
    # 실제 디바이스가 없으면 시뮬레이터 반환
    for device_id, device_name, is_simulator in devices:
        return device_id
    
    return None

def find_available_android_emulator():
    """사용 가능한 Android 에뮬레이터 찾기"""
    result = subprocess.run(['flutter', 'emulators'], capture_output=True, text=True, cwd=PROJECT_DIR)
    for line in result.stdout.split('\n'):
        if 'android' in line.lower():
            parts = line.split('•')
            if len(parts) >= 1:
                emulator_id = parts[0].strip()
                if emulator_id and emulator_id != 'Id':
                    return emulator_id
    return None

def find_available_ios_simulator():
    """사용 가능한 iOS 시뮬레이터 찾기"""
    try:
        result = subprocess.run(
            ['xcrun', 'simctl', 'list', 'devices', 'available', '-j'],
            capture_output=True,
            text=True
        )
        devices = json.loads(result.stdout)
        for runtime, device_list in devices.get('devices', {}).items():
            if 'iOS' in runtime:
                for device in device_list:
                    if 'iPhone' in device.get('name', '') and device.get('isAvailable', False):
                        return device['udid'], device['name']
    except:
        pass
    return None, None

def start_android_emulator():
    """Android 에뮬레이터 시작"""
    emulator_id = find_available_android_emulator()
    
    if not emulator_id:
        print("❌ 사용 가능한 Android 에뮬레이터를 찾을 수 없습니다.")
        print("   'flutter emulators --create' 명령으로 에뮬레이터를 생성하세요.")
        return False
    
    print(f"🚀 Android 에뮬레이터 시작 중... ({emulator_id})")
    # 에뮬레이터를 백그라운드로 시작
    subprocess.Popen(['flutter', 'emulators', '--launch', emulator_id], cwd=PROJECT_DIR)
    
    # 에뮬레이터가 부팅될 때까지 대기 (최대 60초)
    print("⏳ 에뮬레이터 부팅 대기 중...")
    for i in range(60):
        time.sleep(1)
        device_id = find_android_device()
        if device_id:
            print(f"✅ 에뮬레이터 준비 완료! (디바이스: {device_id})")
            return True
        if i % 5 == 0:
            print(f"   대기 중... ({i}초)")
    
    print("❌ 에뮬레이터가 시작되지 않았습니다. 수동으로 에뮬레이터를 시작해주세요.")
    return False

def start_ios_simulator():
    """iOS 시뮬레이터 시작"""
    udid, name = find_available_ios_simulator()
    
    if not udid:
        print("❌ 사용 가능한 iOS 시뮬레이터를 찾을 수 없습니다.")
        print("   Xcode > Window > Devices and Simulators에서 시뮬레이터를 확인하세요.")
        return False
    
    print(f"🍎 iOS 시뮬레이터 시작 중... ({name})")
    # 시뮬레이터 부팅
    subprocess.run(['xcrun', 'simctl', 'boot', udid], capture_output=True)
    subprocess.run(['open', '-a', 'Simulator'])
    
    # 시뮬레이터가 부팅될 때까지 대기 (최대 60초)
    print("⏳ 시뮬레이터 부팅 대기 중...")
    for i in range(60):
        time.sleep(1)
        device_id = find_ios_device()
        if device_id:
            print(f"✅ 시뮬레이터 준비 완료! (디바이스: {device_id})")
            return True
        if i % 5 == 0:
            print(f"   대기 중... ({i}초)")
    
    print("❌ 시뮬레이터가 시작되지 않았습니다. 수동으로 시뮬레이터를 시작해주세요.")
    return False

def select_platform():
    """플랫폼 선택"""
    print("\n" + "="*50)
    print("📱 CRM Lite Pro 실행 - 플랫폼 선택")
    print("="*50)
    print("1. Android")
    print("2. iOS")
    print("3. 둘 다 동시 실행 (별도 터미널 창에서)")
    print("="*50)
    
    while True:
        choice = input("\n선택하세요 (1/2/3): ").strip()
        if choice in ['1', '2', '3']:
            return choice
        print("❌ 잘못된 선택입니다. 1, 2, 또는 3을 입력하세요.")

# 플랫폼 선택
platform_choice = select_platform()

if platform_choice == '1':
    # Android만 실행
    device_id = find_android_device()

    if not device_id:
        if not start_android_emulator():
            sys.exit(1)
        # 에뮬레이터 시작 후 디바이스 찾기 (최대 10초 추가 대기)
        for _ in range(10):
            device_id = find_android_device()
            if device_id:
                break
            time.sleep(1)

    if not device_id:
        print("❌ Android 디바이스를 찾을 수 없습니다.")
        sys.exit(1)

    print(f"\n🚀 CRM Lite Pro 실행 중... (Android 디바이스: {device_id})")
    subprocess.run(['flutter', 'run', '-d', device_id], cwd=PROJECT_DIR)

elif platform_choice == '2':
    # iOS만 실행
    devices = find_ios_devices()
    
    if not devices:
        print("\n⚠️  iOS 푸시 알림 테스트는 실제 디바이스에서 권장됩니다.")
        print("   실제 디바이스를 연결하거나 시뮬레이터를 시작합니다...")
        if not start_ios_simulator():
            sys.exit(1)
        device_id = find_ios_device()
    elif len(devices) == 1:
        device_id, device_name, is_simulator = devices[0]
        device_type = "시뮬레이터" if is_simulator else "실제 디바이스"
        print(f"\n📱 {device_name} ({device_type})")
        if is_simulator:
            print("⚠️  시뮬레이터에서는 백그라운드 푸시 알림이 작동하지 않습니다.")
        else:
            print("✅ 실제 디바이스 - 푸시 알림 테스트 가능!")
    else:
        # 여러 디바이스가 있으면 선택
        device_id = select_ios_device()
    
    if not device_id:
        print("❌ iOS 디바이스를 찾을 수 없습니다.")
        sys.exit(1)
    
    print(f"\n🚀 CRM Lite Pro 실행 중... (iOS 디바이스: {device_id})")
    result = subprocess.run(['flutter', 'run', '-d', device_id], cwd=PROJECT_DIR)
    
    # 에러 발생 시 처리 (에러 코드만 확인, 출력은 이미 표시됨)
    if result.returncode != 0:
        print("\n" + "="*50)
        print("❌ iOS 빌드 실패")
        print("="*50)
        print("\n💡 일반적인 해결 방법:")
        print("1. Xcode > Settings > Components에서 필요한 iOS 플랫폼 설치")
        print("2. 디바이스가 신뢰하는 컴퓨터로 등록되어 있는지 확인")
        print("3. Xcode에서 디바이스의 iOS 버전을 지원하는지 확인")
        print("4. iOS 시뮬레이터 사용 고려 (푸시 알림 제한적)")

else:
    # 둘 다 동시 실행
    print("\n" + "="*50)
    print("🚀 Android & iOS 동시 실행")
    print("="*50)
    
    # Android 디바이스 준비
    android_device_id = find_android_device()
    if not android_device_id:
        if not start_android_emulator():
            print("⚠️ Android 에뮬레이터 시작 실패")
            android_device_id = None
        else:
            android_device_id = find_android_device()
    
    # iOS 디바이스 준비
    ios_device_id = find_ios_device()
    if not ios_device_id:
        if not start_ios_simulator():
            print("⚠️ iOS 시뮬레이터 시작 실패")
            ios_device_id = None
        else:
            ios_device_id = find_ios_device()
    
    if not android_device_id and not ios_device_id:
        print("❌ 실행 가능한 디바이스가 없습니다.")
        sys.exit(1)
    
    # macOS에서 새 터미널 창 열기
    script_path = os.path.abspath(__file__)
    
    if android_device_id:
        print(f"\n🤖 Android 실행 중... (디바이스: {android_device_id})")
        # 새 터미널 창에서 Android 실행
        android_cmd = f"cd '{PROJECT_DIR}' && flutter run -d {android_device_id}"
        osascript_cmd = f"osascript -e 'tell application \"Terminal\" to do script \"{android_cmd}\"'"
        subprocess.Popen(osascript_cmd, shell=True)
        print("✅ Android가 새 터미널 창에서 실행됩니다.")
    
    if ios_device_id:
        print(f"\n🍎 iOS 실행 중... (디바이스: {ios_device_id})")
        # 새 터미널 창에서 iOS 실행
        ios_cmd = f"cd '{PROJECT_DIR}' && flutter run -d {ios_device_id}"
        osascript_cmd = f"osascript -e 'tell application \"Terminal\" to do script \"{ios_cmd}\"'"
        subprocess.Popen(osascript_cmd, shell=True)
        print("✅ iOS가 새 터미널 창에서 실행됩니다.")
    
    print("\n" + "="*50)
    print("✅ 두 플랫폼 모두 실행 중입니다!")
    print("💡 각각 별도의 터미널 창에서 실행됩니다.")
    print("="*50)

