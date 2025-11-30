#!/usr/bin/env python3
"""
모든 프로젝트를 동시에 실행하는 통합 스크립트

실행되는 프로젝트:
    - myxplanner: iOS 시뮬레이터
    - landing: 웹 크롬 (포트 3000)
    - crm: 웹 크롬 (포트 8080)
    - crm_lite_pro: Android 에뮬레이터

각 프로젝트는 별도의 터미널 창에서 실행됩니다.
"""

import os
import sys
import subprocess
import time
import json
import threading

# 프로젝트 경로 설정
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MYXPLANNER_DIR = os.path.join(BASE_DIR, 'myxplanner')
LANDING_DIR = os.path.join(BASE_DIR, 'landing')
CRM_DIR = os.path.join(BASE_DIR, 'crm')
CRM_LITE_PRO_DIR = os.path.join(BASE_DIR, 'crm_lite_pro')

# Android SDK 경로
ANDROID_SDK = os.path.expanduser('~/Library/Android/sdk')
EMULATOR_PATH = os.path.join(ANDROID_SDK, 'emulator', 'emulator')

# 창 위치 인덱스 (0부터 시작)
window_index = 0


def get_screen_resolution():
    """macOS에서 화면 해상도 동적 감지"""
    try:
        # AppleScript로 화면 해상도 가져오기
        script = '''
        tell application "System Events"
            tell primary desktop
                get {its width, its height}
            end tell
        end tell
        '''
        result = subprocess.run(
            ['osascript', '-e', script],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            # 결과 파싱: {2560, 2880}
            output = result.stdout.strip()
            import re
            match = re.search(r'\{(\d+),\s*(\d+)\}', output)
            if match:
                width = int(match.group(1))
                height = int(match.group(2))
                return width, height
    except Exception as e:
        print(f"⚠️  화면 해상도 감지 실패: {e}")
    
    # 기본값 (감지 실패 시)
    return 2560, 2880


# 화면 해상도 동적 감지
SCREEN_WIDTH, SCREEN_HEIGHT = get_screen_resolution()
GRID_COLS = 2  # 가로 2열
GRID_ROWS = 4  # 세로 4행
WINDOW_WIDTH = SCREEN_WIDTH // GRID_COLS
WINDOW_HEIGHT = SCREEN_HEIGHT // GRID_ROWS


def is_cursor_terminal():
    """Cursor 통합 터미널인지 확인"""
    # Cursor 관련 환경변수 확인
    term_program = os.environ.get('TERM_PROGRAM', '').lower()
    vs_code_pid = os.environ.get('VSCODE_PID')
    cursor_pid = os.environ.get('CURSOR_PID')
    
    # 부모 프로세스 확인 (더 확실한 방법)
    try:
        import psutil
        current_process = psutil.Process()
        parent = current_process.parent()
        if parent:
            parent_name = parent.name().lower()
            if 'cursor' in parent_name or 'code' in parent_name:
                return True
    except:
        pass
    
    # 환경변수 기반 확인
    # VSCODE_PID가 있으면 Cursor 또는 VS Code 환경
    if vs_code_pid:
        return True
    
    # TERM_PROGRAM 확인
    if 'cursor' in term_program or cursor_pid:
        return True
    
    # 기본적으로 Cursor 환경으로 간주 (별도 터미널 앱 열기 방지)
    # 사용자가 Cursor에서 실행 중이면 True 반환
    return True  # 항상 Cursor 터미널로 간주하여 별도 앱 열기 방지


def get_window_position(index):
    """창 인덱스에 따른 위치 계산 (2x4 그리드)"""
    col = index % GRID_COLS
    row = index // GRID_COLS
    x = col * WINDOW_WIDTH
    y = row * WINDOW_HEIGHT
    return x, y, WINDOW_WIDTH, WINDOW_HEIGHT


def set_window_position(app_name, x, y, width, height, delay=1.0):
    """macOS에서 창 위치와 크기 설정"""
    time.sleep(delay)  # 창이 열릴 때까지 대기
    script = f'''
    tell application "System Events"
        try
            tell process "{app_name}"
                set frontmost to true
                if (count of windows) > 0 then
                    set bounds of window 1 to {{{x}, {y}, {x + width}, {y + height}}}
                end if
            end tell
        end try
    end tell
    '''
    subprocess.run(['osascript', '-e', script], capture_output=True)


def set_browser_window_position(browser_name, x, y, width, height, delay=2.0):
    """브라우저 창 위치 설정"""
    time.sleep(delay)
    script = f'''
    tell application "System Events"
        try
            tell process "{browser_name}"
                set frontmost to true
                if (count of windows) > 0 then
                    set bounds of window 1 to {{{x}, {y}, {x + width}, {y + height}}}
                end if
            end tell
        end try
    end tell
    '''
    subprocess.run(['osascript', '-e', script], capture_output=True)


def set_simulator_window_position(x, y, width, height, delay=3.0):
    """iOS 시뮬레이터 창 위치 설정"""
    time.sleep(delay)
    script = f'''
    tell application "System Events"
        try
            tell process "Simulator"
                set frontmost to true
                if (count of windows) > 0 then
                    set bounds of window 1 to {{{x}, {y}, {x + width}, {y + height}}}
                end if
            end tell
        end try
    end tell
    '''
    subprocess.run(['osascript', '-e', script], capture_output=True)


def create_terminal_script(title, command, cwd):
    """각 프로젝트를 실행할 스크립트 파일 생성"""
    script_dir = os.path.join(BASE_DIR, '.test_scripts')
    os.makedirs(script_dir, exist_ok=True)
    
    script_file = os.path.join(script_dir, f'{title.lower().replace(" ", "_")}.sh')
    script_content = f'''#!/bin/bash
# {title} 실행 스크립트
cd "{cwd}"
{command}
'''
    with open(script_file, 'w') as f:
        f.write(script_content)
    os.chmod(script_file, 0o755)
    return script_file


def run_terminal_command(title, command, cwd=None, win_idx=None):
    """Cursor IDE에서 각 프로젝트를 별도 터미널로 실행"""
    global window_index
    cwd_path = cwd or BASE_DIR
    
    if win_idx is None:
        win_idx = window_index
        window_index += 1
    
    # Cursor IDE에서 실행 중이면 별도 터미널로 실행
    if is_cursor_terminal():
        # 각 프로젝트를 실행할 스크립트 파일 생성
        script_file = create_terminal_script(title, command, cwd_path)
        
        # VS Code/Cursor 명령어로 새 터미널 생성 시도
        # code 명령어가 있으면 사용, 없으면 직접 실행
        try:
            # VS Code/Cursor의 터미널 명령어 시도
            vs_code_cmd = subprocess.run(['which', 'code'], capture_output=True, text=True)
            cursor_cmd = subprocess.run(['which', 'cursor'], capture_output=True, text=True)
            
            if vs_code_cmd.returncode == 0 or cursor_cmd.returncode == 0:
                # VS Code/Cursor 명령어로 새 터미널에서 스크립트 실행
                cmd_tool = 'code' if vs_code_cmd.returncode == 0 else 'cursor'
                # 터미널 명령어 실행 (하지만 이 방법도 제한적)
                print(f"🚀 [{title}] 새 터미널에서 실행 중...")
        except:
            pass
        
        # 백그라운드로 실행
        process = subprocess.Popen(
            command,
            shell=True,
            cwd=cwd_path,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )
        
        # 로그를 실시간으로 출력하는 스레드 시작 (색상 구분)
        colors = {
            'MyXPlanner': '\033[94m',  # 파란색
            'Landing': '\033[92m',      # 초록색
            'CRM': '\033[93m',          # 노란색
            'CRM Lite Pro': '\033[95m', # 자홍색
        }
        reset = '\033[0m'
        color = colors.get(title, '')
        
        def log_output():
            for line in iter(process.stdout.readline, ''):
                if line:
                    print(f"{color}[{title}]{reset} {line.rstrip()}")
        
        thread = threading.Thread(target=log_output, daemon=True)
        thread.start()
        
        return process
    else:
        # macOS Terminal 앱에서 실행
        escaped_cwd = cwd_path.replace('"', '\\"')
        escaped_command = command.replace('"', '\\"')
        
        # 창 위치 계산
        x, y, width, height = get_window_position(win_idx)
        
        script = f'''
        tell application "Terminal"
            activate
            if (count of windows) = 0 then
                set newWindow to do script "cd \\"{escaped_cwd}\\" && {escaped_command}"
                set bounds of newWindow to {{{x}, {y}, {x + width}, {y + height}}}
            else
                tell window 1
                    set newTab to (do script "cd \\"{escaped_cwd}\\" && {escaped_command}")
                end tell
                set bounds of window 1 to {{{x}, {y}, {x + width}, {y + height}}}
            end if
        end tell
        '''
        subprocess.run(['osascript', '-e', script])
        
        # 창 제목 설정 및 위치 재조정 (약간의 지연 후)
        time.sleep(0.5)
        set_window_position('Terminal', title, x, y, width, height)
        
        return None


def check_flutter():
    """Flutter 설치 확인"""
    try:
        result = subprocess.run(['flutter', '--version'], 
                              capture_output=True, 
                              text=True)
        if result.returncode == 0:
            print("✅ Flutter가 설치되어 있습니다.")
            return True
    except FileNotFoundError:
        pass
    
    print("❌ Flutter가 설치되어 있지 않습니다.")
    return False


def check_node_npm():
    """Node.js와 npm 설치 확인"""
    try:
        subprocess.run(['node', '--version'], 
                      capture_output=True, 
                      check=True)
        subprocess.run(['npm', '--version'], 
                      capture_output=True, 
                      check=True)
        print("✅ Node.js와 npm이 설치되어 있습니다.")
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("❌ Node.js 또는 npm이 설치되어 있지 않습니다.")
        return False


def get_ios_device_id():
    """실행 중인 iOS 시뮬레이터의 디바이스 ID 반환"""
    result = subprocess.run(['flutter', 'devices'], 
                          capture_output=True, 
                          text=True, 
                          cwd=MYXPLANNER_DIR)
    for line in result.stdout.split('\n'):
        if 'simulator' in line.lower() and 'ios' in line.lower():
            parts = line.split('•')
            if len(parts) >= 2:
                device_id = parts[1].strip()
                return device_id
    return None


def start_ios_simulator():
    """iOS 시뮬레이터 시작"""
    # 이미 실행 중인지 확인
    result = subprocess.run(['flutter', 'devices'], 
                          capture_output=True, 
                          text=True, 
                          cwd=MYXPLANNER_DIR)
    if 'simulator' in result.stdout.lower():
        print("✅ iOS 시뮬레이터가 이미 실행 중입니다.")
        return True

    print("🍎 iOS 시뮬레이터 시작 중...")
    
    # 사용 가능한 시뮬레이터 찾기
    sim_result = subprocess.run(
        ['xcrun', 'simctl', 'list', 'devices', 'available', '-j'],
        capture_output=True, 
        text=True
    )

    try:
        devices = json.loads(sim_result.stdout)
        for runtime, device_list in devices.get('devices', {}).items():
            if 'iOS' in runtime:
                for device in device_list:
                    if 'iPhone' in device.get('name', '') and device.get('isAvailable', False):
                        udid = device['udid']
                        name = device['name']
                        print(f"   📱 {name} 부팅 중...")
                        subprocess.run(['xcrun', 'simctl', 'boot', udid], 
                                     capture_output=True)
                        subprocess.run(['open', '-a', 'Simulator'])
                        break
                break
    except:
        subprocess.run(['open', '-a', 'Simulator'])

    # 시뮬레이터가 준비될 때까지 대기
    print("⏳ 시뮬레이터 부팅 대기 중...")
    for i in range(30):
        time.sleep(2)
        result = subprocess.run(['flutter', 'devices'], 
                              capture_output=True, 
                              text=True, 
                              cwd=MYXPLANNER_DIR)
        if 'simulator' in result.stdout.lower():
            print("✅ iOS 시뮬레이터가 준비되었습니다.")
            return True
        if i % 5 == 0:
            print(f"   {i*2}초 경과...")

    print("❌ 시뮬레이터 시작 시간 초과")
    return False


def get_android_device_id():
    """실행 중인 Android 에뮬레이터의 디바이스 ID 반환"""
    result = subprocess.run(['flutter', 'devices'], 
                          capture_output=True, 
                          text=True, 
                          cwd=CRM_LITE_PRO_DIR)
    for line in result.stdout.split('\n'):
        if ('sdk' in line.lower() or 'emulator-' in line.lower()) and 'android' in line.lower():
            parts = line.split('•')
            if len(parts) >= 2:
                device_id = parts[1].strip()
                return device_id
    return None


def start_android_emulator():
    """Android 에뮬레이터 시작"""
    # 이미 실행 중인지 확인
    result = subprocess.run(['flutter', 'devices'], 
                          capture_output=True, 
                          text=True, 
                          cwd=CRM_LITE_PRO_DIR)
    if 'sdk' in result.stdout.lower() or 'emulator-' in result.stdout.lower():
        print("✅ Android 에뮬레이터가 이미 실행 중입니다.")
        return True

    if not os.path.exists(EMULATOR_PATH):
        print(f"❌ Android 에뮬레이터를 찾을 수 없습니다: {EMULATOR_PATH}")
        return False

    # AVD 목록 확인
    avdmanager_path = os.path.join(ANDROID_SDK, 'cmdline-tools/latest/bin/avdmanager')
    if not os.path.exists(avdmanager_path):
        # 다른 가능한 경로 시도
        alt_paths = [
            os.path.join(ANDROID_SDK, 'tools/bin/avdmanager'),
            os.path.join(ANDROID_SDK, 'bin/avdmanager'),
        ]
        for alt_path in alt_paths:
            if os.path.exists(alt_path):
                avdmanager_path = alt_path
                break
        else:
            print(f"❌ avdmanager를 찾을 수 없습니다.")
            print(f"   Android SDK가 제대로 설치되어 있는지 확인하세요.")
            return False
    
    avd_result = subprocess.run(
        [avdmanager_path, 'list', 'avd', '-c'],
        capture_output=True, 
        text=True
    )
    
    # 에러가 있으면 출력
    if avd_result.stderr:
        print(f"⚠️  avdmanager 실행 중 경고: {avd_result.stderr.strip()}")
    
    avd_list = [a.strip() for a in avd_result.stdout.strip().split('\n') if a.strip()]

    if not avd_list:
        print("❌ 사용 가능한 Android 에뮬레이터(AVD)가 없습니다.")
        print("\n💡 해결 방법:")
        print("   1. Android Studio를 열고")
        print("   2. Tools > Device Manager 메뉴로 이동")
        print("   3. 'Create Device' 버튼을 클릭하여 새 AVD 생성")
        print("   4. 또는 터미널에서 다음 명령 실행:")
        print("      ~/Library/Android/sdk/cmdline-tools/latest/bin/avdmanager create avd -n Pixel_6_API_34 -k 'system-images;android-34;google_apis;x86_64'")
        print("\n   AVD 생성 후 다시 시도하세요.")
        return False

    avd_name = avd_list[0]
    print(f"🤖 Android 에뮬레이터 '{avd_name}' 시작 중...")

    env = os.environ.copy()
    env['ANDROID_SDK_ROOT'] = ANDROID_SDK
    env['ANDROID_HOME'] = ANDROID_SDK

    subprocess.Popen(
        [EMULATOR_PATH, '-avd', avd_name, '-no-snapshot-load'],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        env=env
    )

    # 에뮬레이터가 부팅될 때까지 대기
    print("⏳ 에뮬레이터 부팅 대기 중...")
    for i in range(60):
        time.sleep(2)
        result = subprocess.run(['flutter', 'devices'], 
                              capture_output=True, 
                              text=True, 
                              cwd=CRM_LITE_PRO_DIR)
        if 'sdk' in result.stdout.lower() or 'emulator-' in result.stdout.lower():
            print("✅ Android 에뮬레이터가 준비되었습니다.")
            time.sleep(3)
            return True
        if i % 5 == 0:
            print(f"   {i*2}초 경과...")

    print("❌ 에뮬레이터 시작 시간 초과")
    return False


def run_myxplanner_ios():
    """MyXPlanner를 iOS 시뮬레이터에서 실행"""
    global window_index
    print("\n📱 MyXPlanner (iOS) 준비 중...")
    
    # iOS 시뮬레이터 시작
    if not start_ios_simulator():
        print("❌ iOS 시뮬레이터 시작 실패")
        return False
    
    # 디바이스 ID 가져오기
    device_id = get_ios_device_id()
    if not device_id:
        print("❌ iOS 시뮬레이터 디바이스 ID를 찾을 수 없습니다.")
        return False
    
    # Flutter 패키지 설치
    print("   📦 패키지 설치 중...")
    subprocess.run(['flutter', 'pub', 'get'], 
                  cwd=MYXPLANNER_DIR, 
                  capture_output=True)
    
    # 터미널에서 실행 (창 인덱스 0)
    term_idx = window_index
    window_index += 1
    command = f'flutter run -d {device_id}'
    process = run_terminal_command('MyXPlanner (iOS)', command, MYXPLANNER_DIR, term_idx)
    
    # 시뮬레이터 창 위치 설정 (창 인덱스 4)
    sim_idx = 4
    x, y, w, h = get_window_position(sim_idx)
    threading.Thread(target=set_simulator_window_position, args=(x, y, w, h), daemon=True).start()
    
    if is_cursor_terminal():
        if process:
            print("   ✅ MyXPlanner가 백그라운드에서 실행 중입니다.")
        else:
            print("   ✅ MyXPlanner 실행 준비 완료.")
    else:
        print("   ✅ MyXPlanner 터미널 탭이 열렸습니다.")
    return True


def run_landing_web():
    """Landing을 웹에서 실행"""
    global window_index
    print("\n🌐 Landing (Web) 준비 중...")
    
    # Node.js/npm 확인
    if not check_node_npm():
        return False
    
    # 의존성 확인
    node_modules = os.path.join(LANDING_DIR, 'node_modules')
    if not os.path.exists(node_modules):
        print("   📦 의존성 설치 중...")
        subprocess.run(['npm', 'install'], 
                     cwd=LANDING_DIR, 
                     capture_output=True)
    
    # 터미널에서 실행 (창 인덱스 1)
    term_idx = window_index
    window_index += 1
    command = 'npm run dev'
    process = run_terminal_command('Landing (Web)', command, LANDING_DIR, term_idx)
    
    # 브라우저 창 위치 설정 (창 인덱스 5) - Chrome
    browser_idx = 5
    x, y, w, h = get_window_position(browser_idx)
    threading.Thread(target=set_browser_window_position, args=('Google Chrome', x, y, w, h), daemon=True).start()
    
    if is_cursor_terminal():
        if process:
            print("   ✅ Landing이 백그라운드에서 실행 중입니다.")
        else:
            print("   ✅ Landing 실행 준비 완료.")
    else:
        print("   ✅ Landing 터미널 탭이 열렸습니다.")
    return True


def run_crm_web():
    """CRM을 웹에서 실행"""
    global window_index
    print("\n🌐 CRM (Web) 준비 중...")
    
    # Flutter 패키지 설치
    print("   📦 패키지 설치 중...")
    subprocess.run(['flutter', 'pub', 'get'], 
                  cwd=CRM_DIR, 
                  capture_output=True)
    
    # 터미널에서 실행 (창 인덱스 2)
    term_idx = window_index
    window_index += 1
    command = 'flutter run -d chrome --web-port=8080'
    process = run_terminal_command('CRM (Web)', command, CRM_DIR, term_idx)
    
    # 브라우저 창 위치 설정 (창 인덱스 6) - Chrome
    browser_idx = 6
    x, y, w, h = get_window_position(browser_idx)
    threading.Thread(target=set_browser_window_position, args=('Google Chrome', x, y, w, h), daemon=True).start()
    
    if is_cursor_terminal():
        if process:
            print("   ✅ CRM이 백그라운드에서 실행 중입니다.")
        else:
            print("   ✅ CRM 실행 준비 완료.")
    else:
        print("   ✅ CRM 터미널 탭이 열렸습니다.")
    return True


def run_crm_lite_pro_android():
    """CRM Lite Pro를 Android 에뮬레이터에서 실행"""
    global window_index
    print("\n🤖 CRM Lite Pro (Android) 준비 중...")
    
    # Android 에뮬레이터 시작
    if not start_android_emulator():
        print("❌ Android 에뮬레이터 시작 실패")
        return False
    
    # 디바이스 ID 가져오기
    device_id = get_android_device_id()
    if not device_id:
        print("❌ Android 에뮬레이터 디바이스 ID를 찾을 수 없습니다.")
        return False
    
    # Flutter 패키지 설치
    print("   📦 패키지 설치 중...")
    subprocess.run(['flutter', 'pub', 'get'], 
                  cwd=CRM_LITE_PRO_DIR, 
                  capture_output=True)
    
    # 터미널에서 실행 (창 인덱스 3)
    term_idx = window_index
    window_index += 1
    command = f'flutter run -d {device_id}'
    process = run_terminal_command('CRM Lite Pro (Android)', command, CRM_LITE_PRO_DIR, term_idx)
    
    # Android 에뮬레이터 창 위치 설정 (창 인덱스 7)
    emulator_idx = 7
    x, y, w, h = get_window_position(emulator_idx)
    # Android 에뮬레이터는 여러 프로세스 이름을 시도
    def set_emulator_pos():
        time.sleep(5.0)  # 에뮬레이터가 완전히 부팅될 때까지 대기
        for proc_name in ['emulator', 'qemu-system-x86_64', 'qemu-system-aarch64']:
            try:
                set_window_position(proc_name, x, y, w, h, 0.5)
            except:
                pass
    threading.Thread(target=set_emulator_pos, daemon=True).start()
    
    if is_cursor_terminal():
        if process:
            print("   ✅ CRM Lite Pro가 백그라운드에서 실행 중입니다.")
        else:
            print("   ✅ CRM Lite Pro 실행 준비 완료.")
    else:
        print("   ✅ CRM Lite Pro 터미널 탭이 열렸습니다.")
    return True


def main():
    print("=" * 60)
    print("🚀 모든 프로젝트 동시 실행")
    print("=" * 60)
    print(f"\n화면 해상도: {SCREEN_WIDTH}x{SCREEN_HEIGHT}")
    print(f"창 배치: {GRID_COLS}x{GRID_ROWS} 그리드 (각 창: {WINDOW_WIDTH}x{WINDOW_HEIGHT})")
    print("\n실행될 프로젝트:")
    print("  1. 📱 MyXPlanner - iOS 시뮬레이터")
    print("  2. 🌐 Landing - 웹 크롬 (포트 3000)")
    print("  3. 🌐 CRM - 웹 크롬 (포트 8080)")
    print("  4. 🤖 CRM Lite Pro - Android 에뮬레이터")
    print("\n창 배치 순서:")
    print("  [0] MyXPlanner 터미널    [1] Landing 터미널")
    print("  [2] CRM 터미널           [3] CRM Lite Pro 터미널")
    print("  [4] MyXPlanner 앱       [5] Landing 웹")
    print("  [6] CRM 웹              [7] CRM Lite Pro 앱")
    
    if is_cursor_terminal():
        print("\n💡 Cursor IDE에서 실행됩니다.")
        print("   각 프로젝트를 별도 터미널 패널로 분리하여 실행할 수 있습니다.")
        print("\n   방법 1: 자동 실행 (현재 터미널에 모든 로그 표시)")
        print("   방법 2: Cursor에서 Split Terminal 사용")
        print("      - 터미널 패널에서 '+' 버튼 옆의 Split 버튼 클릭")
        print("      - 또는 Cmd+\\ (백슬래시)로 터미널 분할")
        print("      - 각 터미널에서 아래 명령어를 실행하세요\n")
    else:
        print("\n각 프로젝트는 별도의 터미널 탭에서 실행되며, 창이 자동으로 배치됩니다.\n")
    
    # Flutter 설치 확인
    if not check_flutter():
        print("\n❌ Flutter가 필요합니다. 먼저 설치해주세요.")
        return 1
    
    # 프로젝트 디렉토리 확인
    projects = [
        ('MyXPlanner', MYXPLANNER_DIR),
        ('Landing', LANDING_DIR),
        ('CRM', CRM_DIR),
        ('CRM Lite Pro', CRM_LITE_PRO_DIR),
    ]
    
    for name, path in projects:
        if not os.path.exists(path):
            print(f"❌ {name} 프로젝트 디렉토리를 찾을 수 없습니다: {path}")
            return 1
    
    print("✅ 모든 프로젝트 디렉토리가 확인되었습니다.\n")
    
    # 실행 명령어 준비
    commands = []
    
    # MyXPlanner iOS 명령 준비
    device_id = get_ios_device_id()
    if device_id:
        commands.append(('MyXPlanner', f'flutter run -d {device_id}', MYXPLANNER_DIR))
    
    # Landing 웹 명령 준비
    commands.append(('Landing', 'npm run dev', LANDING_DIR))
    
    # CRM 웹 명령 준비
    commands.append(('CRM', 'flutter run -d chrome --web-port=8080', CRM_DIR))
    
    # CRM Lite Pro Android 명령 준비
    android_device_id = get_android_device_id()
    if android_device_id:
        commands.append(('CRM Lite Pro', f'flutter run -d {android_device_id}', CRM_LITE_PRO_DIR))
    
    if is_cursor_terminal():
        print("=" * 60)
        print("프로젝트 실행 방법")
        print("=" * 60)
        print("\n💡 Cursor IDE에서 Split Terminal을 사용하여 각 프로젝트를 별도 패널로 실행하세요:")
        print("\n   방법 1: Cursor에서 Split Terminal 사용 (권장)")
        print("   1. Cursor 하단의 터미널 패널 열기 (Ctrl+` 또는 View > Terminal)")
        print("   2. 터미널 패널에서 '+' 버튼 옆의 Split 버튼 클릭")
        print("   3. 또는 Cmd+\\ (백슬래시)로 터미널 분할")
        print("   4. 총 4개의 터미널 패널을 만드세요")
        print("   5. 각 터미널에서 아래 Python 스크립트를 실행하세요:\n")
        
        scripts = [
            ('MyXPlanner', 'run_myxplanner.py'),
            ('Landing', 'run_landing.py'),
            ('CRM', 'run_crm.py'),
            ('CRM Lite Pro', 'run_crm_lite_pro.py'),
        ]
        
        for i, (title, script) in enumerate(scripts, 1):
            script_path = os.path.join(BASE_DIR, script)
            print(f"   터미널 {i} ({title}):")
            print(f"      python {script_path}\n")
        
        print("   방법 2: 자동 실행 (현재 터미널에 모든 로그 표시)")
        print("   아래에서 자동으로 모든 프로젝트를 백그라운드로 실행합니다...\n")
        print("=" * 60 + "\n")
        
        # 자동 실행 옵션
        results = []
        for title, cmd, cwd in commands:
            result = run_terminal_command(title, cmd, cwd)
            results.append((title, result is not None))
            time.sleep(0.5)  # 약간의 지연
    else:
        print("=" * 60)
        print("프로젝트 병렬 실행 시작")
        print("=" * 60)
        print("모든 프로젝트를 동시에 시작합니다...\n")
        
        # 병렬 실행을 위한 스레드 리스트
        results = []
        results_lock = threading.Lock()
        
        def run_with_result(name, func):
            """함수를 실행하고 결과를 저장"""
            try:
                result = func()
                with results_lock:
                    results.append((name, result))
            except Exception as e:
                print(f"❌ [{name}] 실행 중 오류: {e}")
                with results_lock:
                    results.append((name, False))
        
        # 모든 프로젝트를 병렬로 시작
        threads = [
            threading.Thread(target=run_with_result, args=('MyXPlanner', run_myxplanner_ios), daemon=True),
            threading.Thread(target=run_with_result, args=('Landing', run_landing_web), daemon=True),
            threading.Thread(target=run_with_result, args=('CRM', run_crm_web), daemon=True),
            threading.Thread(target=run_with_result, args=('CRM Lite Pro', run_crm_lite_pro_android), daemon=True),
        ]
        
        # 모든 스레드 시작
        for thread in threads:
            thread.start()
        
        # 모든 스레드가 시작될 때까지 대기
        time.sleep(1)
        
        # 모든 스레드가 완료될 때까지 대기 (최대 30초)
        for thread in threads:
            thread.join(timeout=30)
        
        # 결과가 모두 수집될 때까지 대기
        max_wait = 60
        waited = 0
        while len(results) < 4 and waited < max_wait:
            time.sleep(0.5)
            waited += 0.5
    
    # 결과 요약
    print("\n" + "=" * 60)
    print("실행 결과 요약")
    print("=" * 60)
    
    success_count = 0
    for name, success in results:
        status = "✅ 성공" if success else "❌ 실패"
        print(f"  {status}: {name}")
        if success:
            success_count += 1
    
    print(f"\n총 {len(results)}개 중 {success_count}개 프로젝트가 실행되었습니다.")
    print("\n각 터미널 창에서 프로젝트가 실행 중입니다.")
    print("종료하려면 각 터미널 창에서 Ctrl+C를 누르세요.\n")
    
    return 0 if success_count == len(results) else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\n⚠️  사용자에 의해 중단되었습니다.")
        sys.exit(0)

