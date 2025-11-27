#!/usr/bin/env python3
"""
현대카드 앱 패키지명 확인 스크립트
안드로이드 기기에 설치된 현대카드 관련 앱의 패키지명을 확인합니다.
"""

import subprocess
import sys
import os

def find_adb_path():
    """ADB 경로 찾기"""
    # 환경 변수 확인
    android_home = os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT')
    if android_home:
        adb_path = os.path.join(android_home, 'platform-tools', 'adb')
        if os.path.exists(adb_path):
            return adb_path
    
    # 일반적인 macOS 경로 확인
    common_paths = [
        os.path.expanduser('~/Library/Android/sdk/platform-tools/adb'),
        '/usr/local/bin/adb',
        '/opt/homebrew/bin/adb',
    ]
    
    for path in common_paths:
        if os.path.exists(path):
            return path
    
    # PATH에서 adb 찾기
    try:
        result = subprocess.run(['which', 'adb'], capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout.strip()
    except:
        pass
    
    return None

def run_adb_command(command, check=True):
    """ADB 명령어 실행"""
    adb_path = find_adb_path()
    if not adb_path:
        print("❌ ADB를 찾을 수 없습니다.")
        print("\n다음 방법을 시도해보세요:")
        print("1. Android Studio를 설치하거나 Android SDK를 설치하세요")
        print("2. 환경 변수 설정:")
        print("   export ANDROID_HOME=$HOME/Library/Android/sdk")
        print("   export PATH=$PATH:$ANDROID_HOME/platform-tools")
        print("3. 또는 Homebrew로 설치:")
        print("   brew install android-platform-tools")
        sys.exit(1)
    
    try:
        result = subprocess.run(
            [adb_path] + command,
            capture_output=True,
            text=True,
            check=check
        )
        return result.stdout.strip(), True
    except subprocess.CalledProcessError as e:
        return e.stderr.strip(), False
    except FileNotFoundError:
        print(f"❌ ADB 실행 실패: {adb_path}")
        sys.exit(1)

def check_devices():
    """연결된 기기 확인"""
    print("📱 연결된 안드로이드 기기 확인 중...")
    output, success = run_adb_command(['devices'])
    
    if not success:
        print(f"❌ 기기 확인 실패: {output}")
        return False
    
    lines = output.split('\n')[1:]  # 첫 줄은 "List of devices attached" 제외
    devices = [line.split('\t')[0] for line in lines if line.strip() and '\tdevice' in line]
    
    if not devices:
        print("❌ 연결된 안드로이드 기기가 없습니다.")
        print("   USB 디버깅이 활성화되어 있고 기기가 연결되어 있는지 확인하세요.")
        return False
    
    print(f"✅ {len(devices)}개 기기 연결됨: {', '.join(devices)}")
    return True

def find_hyundai_packages():
    """현대카드 관련 패키지 찾기"""
    print("\n🔍 현대카드 관련 앱 패키지 검색 중...")
    
    # 모든 패키지 목록 가져오기
    output, success = run_adb_command(['shell', 'pm', 'list', 'packages'])
    
    if not success:
        print(f"❌ 패키지 목록 가져오기 실패: {output}")
        return []
    
    packages = output.split('\n')
    
    # 현대카드 관련 패키지 필터링
    hyundai_packages = []
    keywords = ['hyundai', 'hdcard']
    
    for package_line in packages:
        if 'package:' in package_line:
            package_name = package_line.replace('package:', '').strip()
            for keyword in keywords:
                if keyword.lower() in package_name.lower():
                    hyundai_packages.append(package_name)
                    break
    
    return hyundai_packages

def get_package_info(package_name):
    """패키지 상세 정보 가져오기"""
    # 패키지 정보 가져오기
    output, success = run_adb_command(['shell', 'dumpsys', 'package', package_name])
    
    if not success:
        return None
    
    info = {}
    
    # 앱 이름 추출
    for line in output.split('\n'):
        if 'versionName=' in line:
            info['version'] = line.split('versionName=')[1].split()[0] if 'versionName=' in line else 'Unknown'
        if 'applicationLabel=' in line:
            info['label'] = line.split('applicationLabel=')[1].strip() if 'applicationLabel=' in line else 'Unknown'
    
    # 앱 이름 (라벨) 가져오기
    label_output, _ = run_adb_command(['shell', 'pm', 'dump', package_name], check=False)
    for line in label_output.split('\n'):
        if 'ApplicationLabel' in line:
            info['label'] = line.split('ApplicationLabel:')[1].strip() if 'ApplicationLabel:' in line else package_name
            break
    
    return info

def get_intent_filters(package_name):
    """패키지의 Intent Filter (URL 스킴) 확인"""
    output, success = run_adb_command(['shell', 'dumpsys', 'package', package_name], check=False)
    
    if not success:
        return []
    
    schemes = []
    in_intent_filter = False
    
    for line in output.split('\n'):
        if 'android.intent.action.VIEW' in line:
            in_intent_filter = True
        elif in_intent_filter and 'scheme=' in line:
            scheme = line.split('scheme=')[1].split()[0].strip()
            if scheme:
                schemes.append(scheme)
        elif in_intent_filter and line.strip().startswith('Filter'):
            in_intent_filter = False
    
    return list(set(schemes))  # 중복 제거

def main():
    print("=" * 60)
    print("현대카드 앱 패키지명 확인 도구")
    print("=" * 60)
    
    # 기기 확인
    if not check_devices():
        sys.exit(1)
    
    # 현대카드 관련 패키지 찾기
    hyundai_packages = find_hyundai_packages()
    
    if not hyundai_packages:
        print("\n❌ 현대카드 관련 앱을 찾을 수 없습니다.")
        print("\n전체 패키지 목록에서 'hyundai' 또는 'hdcard' 검색 결과가 없습니다.")
        print("\n다음 명령어로 직접 확인할 수 있습니다:")
        print("  adb shell pm list packages | grep -i hyundai")
        print("  adb shell pm list packages | grep -i hdcard")
        sys.exit(1)
    
    print(f"\n✅ {len(hyundai_packages)}개 현대카드 관련 패키지 발견:")
    print("-" * 60)
    
    for i, package_name in enumerate(hyundai_packages, 1):
        print(f"\n[{i}] 패키지명: {package_name}")
        
        # 패키지 정보 가져오기
        info = get_package_info(package_name)
        if info:
            if 'label' in info:
                print(f"    앱 이름: {info['label']}")
            if 'version' in info:
                print(f"    버전: {info['version']}")
        
        # Intent Filter (URL 스킴) 확인
        schemes = get_intent_filters(package_name)
        if schemes:
            print(f"    지원 URL 스킴: {', '.join(schemes)}")
        else:
            print(f"    지원 URL 스킴: (확인 불가)")
    
    print("\n" + "=" * 60)
    print("📋 요약:")
    print(f"   발견된 패키지: {len(hyundai_packages)}개")
    print("\n💡 이 정보를 MainActivity.kt의 패키지 목록에 추가하세요.")
    print("=" * 60)

if __name__ == '__main__':
    main()

