#!/usr/bin/env python3
"""
안드로이드 기기 로그 확인 스크립트
USB로 연결된 안드로이드 기기의 로그를 실시간으로 확인합니다.
"""

import subprocess
import sys
import os
import signal

def setup_environment():
    """환경 변수 설정"""
    java_home = "/Applications/Android Studio.app/Contents/jbr/Contents/Home"
    android_home = "/opt/homebrew/share/android-commandlinetools"
    
    env = os.environ.copy()
    env['JAVA_HOME'] = java_home
    env['ANDROID_HOME'] = android_home
    
    # PATH에 Android SDK 도구 추가
    paths_to_add = [
        f"{java_home}/bin",
        f"{android_home}/cmdline-tools/latest/bin",
        f"{android_home}/platform-tools",
    ]
    
    current_path = env.get('PATH', '')
    for path in paths_to_add:
        if os.path.exists(path) and path not in current_path:
            current_path = f"{path}:{current_path}"
    
    env['PATH'] = current_path
    return env

def check_devices(env):
    """연결된 기기 확인"""
    try:
        result = subprocess.run(
            ['adb', 'devices'],
            env=env,
            capture_output=True,
            text=True,
            timeout=10
        )
        
        lines = result.stdout.split('\n')[1:]
        devices = [line.split('\t')[0] for line in lines if line.strip() and '\tdevice' in line]
        
        if not devices:
            print("❌ 연결된 안드로이드 기기가 없습니다.")
            print("   USB 디버깅이 활성화되어 있고 기기가 연결되어 있는지 확인하세요.")
            return False
        
        print(f"✅ {len(devices)}개 기기 연결됨: {', '.join(devices)}")
        return True
    except FileNotFoundError:
        print("❌ ADB를 찾을 수 없습니다. Android SDK가 설치되어 있는지 확인하세요.")
        return False

def clear_logs(env):
    """로그 버퍼 클리어"""
    print("🧹 로그 버퍼 클리어 중...")
    subprocess.run(['adb', 'logcat', '-c'], env=env, capture_output=True)
    print("✅ 로그 버퍼 클리어 완료\n")

def show_logs(env, filter_tag=None):
    """로그 실시간 표시"""
    print("=" * 80)
    print("📱 안드로이드 로그 실시간 확인")
    print("=" * 80)
    print("\n💡 사용 방법:")
    print("   - Ctrl+C를 눌러 종료")
    print("   - MainActivity 관련 로그만 보려면: python3 check_logs.py MainActivity")
    print("   - 현대카드 관련 로그만 보려면: python3 check_logs.py hyundai")
    print("\n" + "=" * 80 + "\n")
    
    # 로그 필터 설정
    logcat_cmd = ['adb', 'logcat']
    
    if filter_tag:
        # 특정 태그 필터링
        if filter_tag.lower() == 'mainactivity':
            logcat_cmd.extend(['MainActivity:*', '*:S'])  # MainActivity만 표시
        elif filter_tag.lower() == 'hyundai':
            logcat_cmd.extend(['*:I'])  # Info 레벨 이상
            # grep으로 필터링 (Python에서 처리)
            process = subprocess.Popen(
                ['adb', 'logcat', '*:I'],
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1
            )
            
            print("🔍 현대카드 관련 로그 필터링 중...\n")
            try:
                for line in process.stdout:
                    line_lower = line.lower()
                    if any(keyword in line_lower for keyword in ['hyundai', 'hdcard', 'mainactivity']):
                        print(line, end='')
            except KeyboardInterrupt:
                process.terminate()
                print("\n\n✅ 로그 확인 종료")
            return
        else:
            logcat_cmd.extend([f'{filter_tag}:*', '*:S'])
    else:
        # MainActivity와 Flutter 관련 로그만 표시 (기본)
        logcat_cmd.extend(['MainActivity:*', 'flutter:*', '*:S'])
    
    try:
        process = subprocess.Popen(
            logcat_cmd,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1
        )
        
        # 실시간 출력
        for line in process.stdout:
            print(line, end='')
            
    except KeyboardInterrupt:
        process.terminate()
        print("\n\n✅ 로그 확인 종료")

def main():
    env = setup_environment()
    
    # 기기 확인
    if not check_devices(env):
        sys.exit(1)
    
    # 로그 버퍼 클리어
    clear_logs(env)
    
    # 필터 태그 확인
    filter_tag = sys.argv[1] if len(sys.argv) > 1 else None
    
    # 로그 표시
    show_logs(env, filter_tag)

if __name__ == '__main__':
    main()

