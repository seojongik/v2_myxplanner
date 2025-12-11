#!/usr/bin/env python3
"""MyXPlanner 실행 스크립트"""
import subprocess
import sys
import os
import time
import json

PROJECT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'myxplanner')

def find_android_devices():
    """실행 중인 Android 디바이스/에뮬레이터 목록 찾기"""
    result = subprocess.run(['flutter', 'devices'], capture_output=True, text=True, cwd=PROJECT_DIR)
    devices = []
    for line in result.stdout.split('\n'):
        if 'android' in line.lower() and '•' in line:
            parts = line.split('•')
            if len(parts) >= 2:
                device_id = parts[1].strip()
                device_name = parts[0].strip() if len(parts) > 0 else ''
                if device_id:
                    is_emulator = 'emulator' in line.lower() or 'sdk' in line.lower()
                    devices.append((device_id, device_name, is_emulator))
    return devices

def find_android_device():
    """실행 중인 Android 디바이스 찾기 (하위 호환성)"""
    devices = find_android_devices()
    
    # 실제 디바이스를 우선적으로 반환
    for device_id, device_name, is_emulator in devices:
        if not is_emulator:
            return device_id
    
    # 실제 디바이스가 없으면 에뮬레이터 반환
    for device_id, device_name, is_emulator in devices:
        return device_id
    
    return None

def select_android_device():
    """Android 디바이스 선택 (실제 디바이스와 에뮬레이터 중 선택)"""
    devices = find_android_devices()
    
    if not devices:
        return None
    
    if len(devices) == 1:
        device_id, device_name, is_emulator = devices[0]
        device_type = "에뮬레이터" if is_emulator else "실제 디바이스 ✅"
        print(f"\n🤖 Android 디바이스 발견: {device_name} ({device_type})")
        return device_id
    
    # 여러 디바이스가 있으면 선택
    print("\n" + "="*50)
    print("🤖 Android 디바이스 선택")
    print("="*50)
    
    physical_devices = [(d, n, e) for d, n, e in devices if not e]
    emulators = [(d, n, e) for d, n, e in devices if e]
    
    all_devices = physical_devices + emulators  # 실제 디바이스 먼저
    
    for i, (device_id, device_name, is_emulator) in enumerate(all_devices, 1):
        device_type = "에뮬레이터" if is_emulator else "실제 디바이스 ✅ (무선)" if ':' in device_id else "실제 디바이스 ✅ (USB)"
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

def find_ios_devices(debug=False):
    """실행 중인 iOS 디바이스/시뮬레이터 목록 찾기"""
    result = subprocess.run(['flutter', 'devices'], capture_output=True, text=True, cwd=PROJECT_DIR)
    devices = []
    full_output = result.stdout + result.stderr
    
    # 페어링되지 않은 디바이스 확인
    unpaired_device = None
    if 'unpaired' in full_output.lower() or 'pair' in full_output.lower():
        # 에러 메시지에서 디바이스 이름 추출
        for line in full_output.split('\n'):
            if 'iphone' in line.lower() or 'ipad' in line.lower():
                if 'unpaired' in line.lower() or 'pair' in line.lower():
                    # "Error: iPhone is not available..." 형식에서 추출
                    if 'iphone' in line.lower():
                        unpaired_device = 'iPhone'
                    elif 'ipad' in line.lower():
                        unpaired_device = 'iPad'
                    break
    
    for line in result.stdout.split('\n'):
        line_lower = line.lower()
        # iOS 관련 키워드 확인 (더 유연한 매칭)
        is_ios = ('ios' in line_lower or 'iphone' in line_lower or 'ipad' in line_lower or 
                  'apple' in line_lower or 'simulator' in line_lower)
        
        if is_ios and '•' in line:
            parts = line.split('•')
            if len(parts) >= 2:
                device_id = parts[1].strip()
                device_name = parts[0].strip() if len(parts) > 0 else ''
                if device_id and device_id.lower() != 'deviceid':  # 헤더 제외
                    is_simulator = 'simulator' in line_lower
                    devices.append((device_id, device_name, is_simulator))
    
    # 페어링되지 않은 디바이스가 있으면 사용자에게 알림
    if unpaired_device and not devices:
        # xcrun devicectl로 디바이스 확인
        devicectl_result = subprocess.run(
            ['xcrun', 'devicectl', 'list', 'devices'],
            capture_output=True,
            text=True
        )
        
        has_device = False
        device_name_from_devicectl = None
        if devicectl_result.returncode == 0:
            for line in devicectl_result.stdout.split('\n'):
                if 'iPhone' in line or 'iPad' in line:
                    has_device = True
                    parts = line.split()
                    if parts:
                        device_name_from_devicectl = parts[0]
                    break
        
        print(f"\n⚠️  {unpaired_device} 디바이스가 연결되어 있지만 Flutter에서 인식되지 않습니다.")
        if has_device:
            print(f"   디바이스 감지됨: {device_name_from_devicectl}")
            print("   Xcode에서 페어링을 완료해야 합니다.")
        
        print("\n   다음 단계를 따라주세요:")
        
        # Xcode의 Devices and Simulators 창 열기 시도
        print("   1. Xcode의 Devices and Simulators 창을 열어드립니다...")
        try:
            # Xcode가 설치되어 있으면 열기
            subprocess.run(['open', '-a', 'Xcode'], check=False)
            time.sleep(2)
            # Devices and Simulators 메뉴 열기 시도
            applescript = '''
            tell application "Xcode"
                activate
                delay 1
            end tell
            tell application "System Events"
                tell process "Xcode"
                    try
                        click menu item "Devices and Simulators" of menu "Window" of menu bar 1
                    end try
                end tell
            end tell
            '''
            result = subprocess.run(['osascript', '-e', applescript], check=False, capture_output=True)
            if result.returncode == 0:
                print("   ✅ Xcode의 Devices and Simulators 창을 열었습니다.")
            else:
                print("   ⚠️  자동으로 열 수 없습니다. 수동으로 열어주세요:")
                print("      Xcode > Window > Devices and Simulators (또는 Shift+Command+2)")
        except Exception as e:
            print("   ⚠️  Xcode를 자동으로 열 수 없습니다. 수동으로 열어주세요:")
            print("      Xcode > Window > Devices and Simulators (또는 Shift+Command+2)")
        
        print("   2. 연결된 디바이스를 선택하고 'Pair' 버튼 클릭")
        print("   3. 디바이스에서 '신뢰' 선택")
        print("   4. 페어링 완료 후 Enter 키를 눌러 다시 확인하세요")
        
        print("\n" + "="*60)
        print("💡 아이폰에 '이 컴퓨터를 신뢰하시겠습니까?' 메시지가 나타나지 않는 경우:")
        print("="*60)
        print("   1. 아이폰을 잠금 해제하고 홈 화면에 두세요")
        print("   2. 아이폰을 재부팅하세요 (전원 버튼 + 볼륨 다운)")
        print("   3. 케이블을 뽑았다가 다시 연결하세요")
        print("   4. Xcode를 완전히 종료하고 다시 열어보세요")
        print("   5. 아이폰 설정 > 일반 > VPN 및 기기 관리에서 신뢰 설정 확인")
        print("   6. macOS를 재부팅해보세요")
        print("="*60)
        
        # 페어링 후 재확인 옵션 제공 (최대 5번 시도)
        max_retries = 5
        for attempt in range(1, max_retries + 1):
            if attempt > 1:
                print(f"\n🔄 재시도 {attempt}/{max_retries}...")
            else:
                print("\n페어링을 완료하셨다면 Enter 키를 눌러주세요...")
                print("(아직 프롬프트가 나타나지 않았다면 위의 트러블슈팅을 시도해보세요)")
            
            input()
            print("\n🔄 디바이스 재확인 중...")
            
            # 재확인
            result = subprocess.run(['flutter', 'devices'], capture_output=True, text=True, cwd=PROJECT_DIR)
            devices = []
            for line in result.stdout.split('\n'):
                line_lower = line.lower()
                is_ios = ('ios' in line_lower or 'iphone' in line_lower or 'ipad' in line_lower or 
                          'apple' in line_lower or 'simulator' in line_lower)
                if is_ios and '•' in line:
                    parts = line.split('•')
                    if len(parts) >= 2:
                        device_id = parts[1].strip()
                        device_name = parts[0].strip() if len(parts) > 0 else ''
                        if device_id and device_id.lower() != 'deviceid':
                            is_simulator = 'simulator' in line_lower
                            devices.append((device_id, device_name, is_simulator))
            
            if devices:
                print(f"✅ 페어링 완료! {len(devices)}개의 iOS 디바이스를 찾았습니다.")
                # devices 업데이트 및 device_id 설정
                device_id, device_name, is_simulator = devices[0]
                is_physical_device = not is_simulator
                break
            else:
                if attempt < max_retries:
                    print("⚠️  아직 디바이스를 찾지 못했습니다.")
                    print("   위의 트러블슈팅을 시도한 후 다시 Enter를 눌러주세요.")
                else:
                    print("\n❌ 여러 번 시도했지만 디바이스를 찾지 못했습니다.")
                    print("   다음을 확인해주세요:")
                    print("   1. 아이폰이 잠금 해제되어 있고 홈 화면에 있는지 확인")
                    print("   2. 케이블 연결 상태 확인")
                    print("   3. 아이폰 설정 > 일반 > VPN 및 기기 관리에서 이 컴퓨터 신뢰 확인")
                    print("   4. Xcode에서 디바이스 상태 확인 (Window > Devices and Simulators)")
                    print("\n   또는 시뮬레이터를 사용하시겠습니까? (y/n): ", end='')
                    use_simulator = input().strip().lower()
                    if use_simulator == 'y':
                        # 시뮬레이터 시작
                        if start_ios_simulator():
                            device_id = find_ios_device()
                            if device_id:
                                devices = [(device_id, "iOS Simulator", True)]
                                print(f"✅ 시뮬레이터 시작 완료: {device_id}")
                                break
                    else:
                        print("\n프로그램을 종료합니다. 페어링을 완료한 후 다시 실행해주세요.")
                        sys.exit(1)
    
    # 디버깅: 디바이스를 찾지 못한 경우에만 출력
    if debug and not devices:
        debug_output = full_output.strip()
        if debug_output:
            print(f"\n🔍 Flutter devices 출력 (디버깅):\n{debug_output}\n")
    
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
    # Flutter emulators 명령어로 확인
    try:
        result = subprocess.run(
            ['flutter', 'emulators'],
            capture_output=True,
            text=True,
            cwd=PROJECT_DIR
        )
        for line in result.stdout.split('\n'):
            if 'ios' in line.lower() and 'simulator' in line.lower():
                parts = line.split('•')
                if len(parts) >= 2:
                    emulator_id = parts[0].strip()
                    emulator_name = parts[1].strip() if len(parts) > 1 else 'iOS Simulator'
                    if emulator_id and emulator_id.lower() != 'id':
                        return emulator_id, emulator_name
    except:
        pass
    
    # xcrun simctl로도 시도
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
    emulator_id, name = find_available_ios_simulator()
    
    if not emulator_id:
        print("❌ 사용 가능한 iOS 시뮬레이터를 찾을 수 없습니다.")
        print("   Xcode > Window > Devices and Simulators에서 시뮬레이터를 확인하세요.")
        return False
    
    print(f"🍎 iOS 시뮬레이터 시작 중... ({name})")
    
    # Flutter emulators를 사용하는 경우
    if emulator_id.startswith('apple_ios') or 'ios' in emulator_id.lower():
        # Flutter emulators로 시작
        subprocess.Popen(['flutter', 'emulators', '--launch', emulator_id], cwd=PROJECT_DIR)
    else:
        # xcrun simctl로 시작 (UDID인 경우)
        subprocess.run(['xcrun', 'simctl', 'boot', emulator_id], capture_output=True)
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
    print("📱 MyXPlanner 실행 - 플랫폼 선택")
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
    devices = find_android_devices()
    
    if not devices:
        print("\n⚠️  연결된 Android 디바이스가 없습니다.")
        print("   에뮬레이터를 시작합니다...")
        if not start_android_emulator():
            sys.exit(1)
        device_id = find_android_device()
    elif len(devices) == 1:
        device_id, device_name, is_emulator = devices[0]
        device_type = "에뮬레이터" if is_emulator else "실제 디바이스"
        print(f"\n🤖 {device_name} ({device_type})")
        if not is_emulator:
            connection_type = "무선" if ':' in device_id else "USB"
            print(f"✅ 실제 디바이스 - {connection_type} 연결")
    else:
        # 여러 디바이스가 있으면 선택
        device_id = select_android_device()
    
    if not device_id:
        print("❌ Android 디바이스를 찾을 수 없습니다.")
        sys.exit(1)
    
    print(f"\n🚀 MyXPlanner 실행 중... (Android 디바이스: {device_id})")
    subprocess.run(['flutter', 'run', '-d', device_id], cwd=PROJECT_DIR)

elif platform_choice == '2':
    # iOS만 실행
    devices = find_ios_devices(debug=False)
    device_id = None
    is_physical_device = True  # 기본값 (실제 디바이스로 가정)
    
    if not devices:
        print("\n⚠️  iOS 푸시 알림 테스트는 실제 디바이스에서 권장됩니다.")
        print("   실제 디바이스를 연결하거나 시뮬레이터를 시작합니다...")
        if not start_ios_simulator():
            print("\n⏳ 시뮬레이터 시작 실패. 잠시 대기 후 다시 확인합니다...")
            # 시뮬레이터 시작 실패 후에도 잠시 대기하고 다시 확인
            for _ in range(10):
                time.sleep(1)
                temp_devices = find_ios_devices()
                if temp_devices:
                    device_id, device_name, is_simulator = temp_devices[0]
                    is_physical_device = not is_simulator
                    devices = temp_devices
                    print(f"✅ iOS 디바이스 발견: {device_name} ({device_id})")
                    break
            if not device_id:
                # 디버깅 모드로 다시 확인
                print("\n🔍 디바이스 검색 중...")
                devices = find_ios_devices(debug=True)
                if devices:
                    device_id, device_name, is_simulator = devices[0]
                    is_physical_device = not is_simulator
                    print(f"✅ iOS 디바이스 발견: {device_name} ({device_id})")
                else:
                    print("\n❌ iOS 디바이스 또는 시뮬레이터를 찾을 수 없습니다.")
                    print("   다음을 확인해주세요:")
                    print("   1. 실제 iOS 디바이스가 연결되어 있고 신뢰되었는지 확인")
                    print("   2. Xcode > Window > Devices and Simulators에서 시뮬레이터 확인")
                    print("   3. 'flutter devices' 명령으로 사용 가능한 디바이스 확인")
                    sys.exit(1)
        else:
            # 시뮬레이터 시작 성공 후 디바이스 찾기 (최대 10초 추가 대기)
            for _ in range(10):
                temp_devices = find_ios_devices()
                if temp_devices:
                    device_id, device_name, is_simulator = temp_devices[0]
                    is_physical_device = not is_simulator
                    devices = temp_devices
                    break
                time.sleep(1)
    elif len(devices) == 1:
        device_id, device_name, is_simulator = devices[0]
        device_type = "시뮬레이터" if is_simulator else "실제 디바이스"
        print(f"\n📱 {device_name} ({device_type})")
        if is_simulator:
            print("⚠️  시뮬레이터에서는 백그라운드 푸시 알림이 작동하지 않습니다.")
        else:
            print("✅ 실제 디바이스 - 푸시 알림 테스트 가능!")
        is_physical_device = not is_simulator
    else:
        # 여러 디바이스가 있으면 선택
        device_id = select_ios_device()
        # 선택된 디바이스가 실제 디바이스인지 확인
        is_physical_device = True  # 기본값
        for d_id, d_name, d_is_simulator in devices:
            if d_id == device_id:
                is_physical_device = not d_is_simulator
                break
    
    if not device_id:
        print("\n❌ iOS 디바이스를 찾을 수 없습니다.")
        print("   다음을 확인해주세요:")
        print("   1. 실제 iOS 디바이스가 연결되어 있고 신뢰되었는지 확인")
        print("   2. Xcode > Window > Devices and Simulators에서 시뮬레이터 확인")
        print("   3. 'flutter devices' 명령으로 사용 가능한 디바이스 확인")
        sys.exit(1)
    
    print(f"\n🚀 MyXPlanner 실행 중... (iOS 디바이스: {device_id})")
    
    # 실제 디바이스인 경우 코드 서명 확인
    
    if is_physical_device:
        # 코드 서명 인증서 존재 여부만 빠르게 확인 (flutter run 대신)
        print("🔍 코드 서명 상태 확인 중...")
        cert_result = subprocess.run(
            ['security', 'find-identity', '-v', '-p', 'codesigning'],
            capture_output=True,
            text=True
        )
        
        # 인증서가 있는지 확인
        has_valid_cert = 'Apple Development' in cert_result.stdout or 'iPhone Developer' in cert_result.stdout or 'valid identities found' in cert_result.stdout
        cert_count = cert_result.stdout.count('valid identit')
        
        if has_valid_cert or '0 valid identities found' not in cert_result.stdout:
            print("\n✅ 코드 서명 확인 완료. 앱을 실행합니다...")
            code_signing_error = False
        else:
            code_signing_error = True
            print(f"\n⚠️ 유효한 코드 서명 인증서를 찾을 수 없습니다.")
        
        if code_signing_error:
            print("\n" + "="*60)
            print("⚠️  코드 서명 인증서가 필요합니다")
            print("="*60)
            print("실제 iOS 디바이스에서 실행하려면 개발 인증서가 필요합니다.")
            print("\n다음 단계를 따라주세요:")
            print("   1. Xcode 프로젝트를 열어드립니다...")
            
            # Xcode 프로젝트 열기
            ios_workspace = os.path.join(PROJECT_DIR, 'ios', 'Runner.xcworkspace')
            if os.path.exists(ios_workspace):
                subprocess.run(['open', ios_workspace], check=False)
                print("   ✅ Xcode 프로젝트를 열었습니다.")
            else:
                ios_project = os.path.join(PROJECT_DIR, 'ios', 'Runner.xcodeproj')
                if os.path.exists(ios_project):
                    subprocess.run(['open', ios_project], check=False)
                    print("   ✅ Xcode 프로젝트를 열었습니다.")
                else:
                    print("   ⚠️  Xcode 프로젝트를 찾을 수 없습니다.")
            
            print("\n   2. Xcode에서:")
            print("      - 왼쪽 네비게이터에서 'Runner' 프로젝트 선택")
            print("      - 'Runner' 타겟 선택")
            print("      - 'Signing & Capabilities' 탭 선택")
            print("      - 'Team' 드롭다운에서 Apple ID로 로그인")
            print("      - 'Automatically manage signing' 체크")
            print("      - Bundle Identifier가 고유한지 확인")
            print("\n   3. 코드 서명 설정 완료 후:")
            print("      - Xcode에서 한 번 빌드해보세요 (⌘+R)")
            print("      - 또는 이 스크립트에서 재확인하세요")
            
            print("\n" + "="*60)
            print("다음 중 선택하세요:")
            print("  1. 코드 서명 설정을 완료했으니 다시 확인하기")
            print("  2. Flutter clean 후 다시 시도하기")
            print("  3. 시뮬레이터 사용하기")
            print("="*60)
            choice = input("\n선택하세요 (1/2/3): ").strip()
            use_simulator = 'n'  # 초기화
            
            if choice == '1':
                # 재확인
                print("\n🔄 코드 서명 상태 재확인 중...")
                # Flutter clean 실행
                print("   Flutter clean 실행 중...")
                subprocess.run(['flutter', 'clean'], cwd=PROJECT_DIR, capture_output=True)
                print("   ✅ Flutter clean 완료")
                
                # 다시 확인 (빠른 방식)
                recheck_cert = subprocess.run(
                    ['security', 'find-identity', '-v', '-p', 'codesigning'],
                    capture_output=True,
                    text=True
                )
                
                recheck_has_cert = 'Apple Development' in recheck_cert.stdout or 'iPhone Developer' in recheck_cert.stdout
                recheck_error = '0 valid identities found' in recheck_cert.stdout and not recheck_has_cert
                
                if not recheck_error:
                    print("\n✅ 코드 서명 설정이 완료되었습니다!")
                    print("🚀 앱을 실행합니다...")
                    # 실제 실행
                    subprocess.run(['flutter', 'run', '-d', device_id], cwd=PROJECT_DIR)
                else:
                    print("\n⚠️  여전히 코드 서명 오류가 발생합니다.")
                    print("   다음을 확인해주세요:")
                    print("   1. Xcode에서 'Signing & Capabilities'에서 Team이 선택되었는지 확인")
                    print("   2. 'Automatically manage signing'이 체크되어 있는지 확인")
                    print("   3. Bundle Identifier가 고유한지 확인")
                    print("   4. Xcode에서 직접 빌드해보세요 (⌘+R)")
                    print("\n   또는 시뮬레이터를 사용하시겠습니까? (y/n): ", end='')
                    use_simulator = input().strip().lower()
                    if use_simulator == 'y':
                        choice = '3'  # 시뮬레이터 사용으로 전환
                    else:
                        print("\n코드 서명 설정을 완료한 후 다시 실행해주세요.")
                        sys.exit(1)
            
            elif choice == '2':
                # Flutter clean 후 재시도
                print("\n🧹 Flutter clean 실행 중...")
                subprocess.run(['flutter', 'clean'], cwd=PROJECT_DIR)
                print("✅ Flutter clean 완료")
                print("\n🔄 코드 서명 상태 재확인 중...")
                # 다시 확인
                recheck_result = subprocess.run(
                    ['flutter', 'run', '-d', device_id],
                    capture_output=True,
                    text=True,
                    cwd=PROJECT_DIR
                )
                
                recheck_output = (recheck_result.stdout + recheck_result.stderr).lower()
                recheck_error = (
                    'no valid code signing' in recheck_output or
                    'no development certificates' in recheck_output or
                    (recheck_result.returncode != 0 and 'code signing' in recheck_output and 'certificate' in recheck_output)
                )
                
                if not recheck_error:
                    print("\n✅ 코드 서명 설정이 완료되었습니다!")
                    print("🚀 앱을 실행합니다...")
                    subprocess.run(['flutter', 'run', '-d', device_id], cwd=PROJECT_DIR)
                else:
                    print("\n⚠️  여전히 코드 서명 오류가 발생합니다.")
                    print("   Xcode에서 직접 빌드해보세요 (⌘+R)")
                    print("   또는 시뮬레이터를 사용하시겠습니까? (y/n): ", end='')
                    use_simulator = input().strip().lower()
                    if use_simulator == 'y':
                        choice = '3'  # 시뮬레이터 사용으로 전환
                    else:
                        sys.exit(1)
            
            # 시뮬레이터 사용 선택
            if choice == '3' or use_simulator == 'y':
                print("\n🔄 시뮬레이터로 전환 중...")
                if start_ios_simulator():
                    device_id = find_ios_device()
                    if device_id:
                        print(f"✅ 시뮬레이터 시작 완료: {device_id}")
                        print(f"\n🚀 MyXPlanner 실행 중... (iOS 시뮬레이터: {device_id})")
                        subprocess.run(['flutter', 'run', '-d', device_id], cwd=PROJECT_DIR)
                    else:
                        print("❌ 시뮬레이터를 찾을 수 없습니다.")
                        sys.exit(1)
                else:
                    print("❌ 시뮬레이터를 시작할 수 없습니다.")
                    sys.exit(1)
            elif choice not in ['1', '2', '3']:
                print("\n❌ 잘못된 선택입니다.")
                sys.exit(1)
            # choice == '1' 또는 '2'에서 성공한 경우는 이미 실행됨
        else:
            # 코드 서명 문제 없으면 정상 실행
            print("\n✅ 코드 서명 확인 완료. 앱을 실행합니다...")
            # 실제 실행 (출력을 실시간으로 표시)
            subprocess.run(['flutter', 'run', '-d', device_id], cwd=PROJECT_DIR)
    else:
        # 시뮬레이터는 코드 서명 불필요
        subprocess.run(['flutter', 'run', '-d', device_id], cwd=PROJECT_DIR)

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
    ios_devices = find_ios_devices()
    if not ios_devices:
        if not start_ios_simulator():
            print("⚠️ iOS 시뮬레이터 시작 실패")
            ios_device_id = None
        else:
            ios_device_id = find_ios_device()
    elif len(ios_devices) == 1:
        ios_device_id, _, _ = ios_devices[0]
    else:
        # 여러 디바이스가 있으면 첫 번째 실제 디바이스 또는 첫 번째 시뮬레이터 사용
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
