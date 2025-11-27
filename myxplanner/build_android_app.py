#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MyGolfPlanner 안드로이드 앱 빌드 스크립트
Flutter 앱을 안드로이드 APK/AAB로 빌드합니다.
"""

import subprocess
import sys
import os
import argparse
from pathlib import Path
from datetime import datetime

# 색상 코드
class Colors:
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    RESET = '\033[0m'
    BOLD = '\033[1m'
    CYAN = '\033[96m'

def print_step(message):
    print(f"{Colors.BLUE}{Colors.BOLD}▶ {message}{Colors.RESET}")

def print_success(message):
    print(f"{Colors.GREEN}✓ {message}{Colors.RESET}")

def print_warning(message):
    print(f"{Colors.YELLOW}⚠ {message}{Colors.RESET}")

def print_error(message):
    print(f"{Colors.RED}✗ {message}{Colors.RESET}")

def print_info(message):
    print(f"{Colors.CYAN}ℹ {message}{Colors.RESET}")

def check_flutter_installed():
    """Flutter가 설치되어 있는지 확인"""
    try:
        result = subprocess.run(
            ['flutter', '--version'],
            capture_output=True,
            text=True,
            timeout=10
        )
        if result.returncode == 0:
            # Flutter 버전 정보 출력
            version_lines = result.stdout.split('\n')[:3]
            for line in version_lines:
                if line.strip():
                    print_info(line.strip())
            return True
        return False
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False

def check_project_directory():
    """Flutter 프로젝트 디렉토리인지 확인하고 필요시 이동"""
    # 현재 디렉토리에 pubspec.yaml이 있는지 확인
    if os.path.exists('pubspec.yaml'):
        return True

    # 스크립트가 위치한 디렉토리 (myxplanner) 확인
    script_dir = Path(__file__).parent
    pubspec_path = script_dir / 'pubspec.yaml'

    if pubspec_path.exists():
        print_info(f"작업 디렉토리를 {script_dir}로 변경합니다...")
        os.chdir(script_dir)
        print_success(f"현재 디렉토리: {os.getcwd()}")
        return True

    print_error("Flutter 프로젝트 디렉토리를 찾을 수 없습니다.")
    print_info("pubspec.yaml 파일이 있는 디렉토리에서 실행하거나,")
    print_info("myxplanner 디렉토리에 pubspec.yaml이 있는지 확인하세요.")
    return False

def setup_android_environment():
    """안드로이드 빌드 환경 변수 설정"""
    java_home = "/Applications/Android Studio.app/Contents/jbr/Contents/Home"
    android_home = "/opt/homebrew/share/android-commandlinetools"
    
    env = os.environ.copy()
    
    # JAVA_HOME 설정
    if os.path.exists(java_home):
        env['JAVA_HOME'] = java_home
    else:
        # 다른 가능한 경로들 확인
        possible_java_paths = [
            "/Library/Java/JavaVirtualMachines/jdk-*/Contents/Home",
            "/usr/libexec/java_home",
        ]
        print_warning("기본 JAVA_HOME 경로를 찾을 수 없습니다.")
    
    # ANDROID_HOME 설정
    if os.path.exists(android_home):
        env['ANDROID_HOME'] = android_home
    else:
        # 다른 가능한 경로들 확인
        possible_android_paths = [
            os.path.expanduser("~/Library/Android/sdk"),
            "/usr/local/share/android-sdk",
        ]
        for path in possible_android_paths:
            if os.path.exists(path):
                env['ANDROID_HOME'] = path
                android_home = path
                break
    
    # PATH에 Android SDK 도구 추가
    if 'ANDROID_HOME' in env:
        paths_to_add = [
            f"{env.get('JAVA_HOME', '')}/bin",
            f"{android_home}/cmdline-tools/latest/bin",
            f"{android_home}/platform-tools",
            f"{android_home}/tools",
        ]
        
        current_path = env.get('PATH', '')
        for path in paths_to_add:
            if path and os.path.exists(path) and path not in current_path:
                current_path = f"{path}:{current_path}"
        
        env['PATH'] = current_path
    
    return env

def run_flutter_command(cmd, env=None, check=True):
    """Flutter 명령어 실행"""
    try:
        print_info(f"실행 중: flutter {' '.join(cmd)}")
        result = subprocess.run(
            ['flutter'] + cmd,
            env=env,
            check=check,
            text=True
        )
        return result.returncode == 0
    except subprocess.CalledProcessError as e:
        if check:
            print_error(f"명령 실행 실패: flutter {' '.join(cmd)}")
        return False
    except FileNotFoundError:
        print_error("Flutter를 찾을 수 없습니다. Flutter가 설치되어 있고 PATH에 추가되어 있는지 확인하세요.")
        return False

def clean_build():
    """빌드 캐시 정리"""
    print_step("빌드 캐시 정리 중...")
    success = run_flutter_command(['clean'], check=False)
    if success:
        print_success("빌드 캐시 정리 완료")
    else:
        print_warning("빌드 캐시 정리 중 일부 오류 발생 (계속 진행)")
    print()

def get_pub_dependencies():
    """의존성 패키지 가져오기"""
    print_step("의존성 패키지 가져오는 중...")
    success = run_flutter_command(['pub', 'get'])
    if success:
        print_success("의존성 패키지 가져오기 완료")
    else:
        print_error("의존성 패키지 가져오기 실패")
        return False
    print()
    return True

def generate_launcher_icons():
    """앱 아이콘 생성"""
    print_step("앱 아이콘 생성 중...")
    try:
        result = subprocess.run(
            ['flutter', 'pub', 'run', 'flutter_launcher_icons'],
            capture_output=True,
            text=True,
            timeout=60
        )
        if result.returncode == 0:
            print_success("앱 아이콘 생성 완료")
            return True
        else:
            # 경고는 있지만 성공한 경우도 있음
            if "Successfully generated" in result.stdout:
                print_success("앱 아이콘 생성 완료")
                return True
            else:
                print_warning("앱 아이콘 생성 중 일부 경고 발생 (계속 진행)")
                if result.stdout:
                    print_info(result.stdout)
                return True  # 경고만 있으면 계속 진행
    except subprocess.TimeoutExpired:
        print_error("앱 아이콘 생성 시간 초과")
        return False
    except FileNotFoundError:
        print_warning("flutter_launcher_icons를 찾을 수 없습니다. (계속 진행)")
        return True  # 없어도 빌드는 가능
    except Exception as e:
        print_warning(f"앱 아이콘 생성 중 오류 발생: {e} (계속 진행)")
        return True  # 오류가 있어도 빌드는 계속
    finally:
        print()

def run_adb_command(cmd, env=None, check=True, timeout=30):
    """ADB 명령어 실행"""
    try:
        result = subprocess.run(
            ['adb'] + cmd,
            env=env,
            check=check,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        # stdout과 stderr를 모두 반환
        output = result.stdout.strip()
        if result.stderr.strip():
            output = f"{output}\n{result.stderr.strip()}" if output else result.stderr.strip()
        return output, result.returncode == 0
    except subprocess.TimeoutExpired:
        print_error(f"명령어 실행 시간 초과 ({timeout}초): adb {' '.join(cmd)}")
        return "", False
    except FileNotFoundError:
        return "", False
    except subprocess.CalledProcessError as e:
        output = e.stdout.strip() if e.stdout else ""
        if e.stderr.strip():
            output = f"{output}\n{e.stderr.strip()}" if output else e.stderr.strip()
        return output, False

def check_android_devices(env):
    """연결된 안드로이드 기기 확인"""
    output, success = run_adb_command(['devices'], env=env, check=False)
    
    if not success:
        return []
    
    lines = output.split('\n')[1:]  # 첫 줄 "List of devices attached" 제외
    devices = []
    for line in lines:
        if line.strip() and '\tdevice' in line:
            device_id = line.split('\t')[0]
            devices.append(device_id)
    
    return devices

def uninstall_android_app(package_name, env):
    """안드로이드 앱 제거"""
    print_info(f"기존 앱 제거 시도 중: {package_name}")
    output, success = run_adb_command(['uninstall', package_name], env=env, check=False, timeout=60)

    if success or "Success" in output:
        print_success("기존 앱 제거 완료")
        return True
    else:
        # 앱이 설치되어 있지 않은 경우
        if "not installed" in output.lower() or "unknown package" in output.lower():
            print_info("제거할 기존 앱이 없습니다")
            return True
        else:
            print_warning(f"앱 제거 실패: {output}")
            return False

def install_android_apk(apk_path, env):
    """안드로이드 APK 설치"""
    print_step(f"APK 설치 중: {Path(apk_path).name}")

    # APK 크기 확인
    apk_size_mb = os.path.getsize(apk_path) / (1024 * 1024)
    # 크기에 따라 timeout 동적 설정 (최소 60초, 1MB당 2초 추가)
    install_timeout = max(60, int(apk_size_mb * 2))
    print_info(f"APK 크기: {apk_size_mb:.1f}MB, 예상 설치 시간: 최대 {install_timeout}초")

    # 첫 번째 설치 시도
    output, success = run_adb_command(['install', '-r', apk_path], env=env, check=False, timeout=install_timeout)

    # Success 문자열 확인 (대소문자 무시)
    if success or "success" in output.lower():
        print_success("APK 설치 완료!")
        return True

    # 서명 충돌로 실패한 경우
    if "INSTALL_FAILED_UPDATE_INCOMPATIBLE" in output or "signatures do not match" in output.lower():
        print_warning("서명이 다른 앱이 설치되어 있습니다. 기존 앱을 제거하고 재설치합니다...")

        # 패키지명 추출 시도
        package_name = "mygolfplanner.app"  # 기본 패키지명

        # 기존 앱 제거
        if uninstall_android_app(package_name, env):
            # 재설치 시도
            print_info("새 APK 설치 중...")
            output, success = run_adb_command(['install', apk_path], env=env, check=False, timeout=install_timeout)

            if success or "success" in output.lower():
                print_success("APK 설치 완료!")
                return True

    # 설치 실패
    print_error("APK 설치 실패")
    if output:
        print_error(f"상세 정보: {output}")

    # 수동 설치 안내
    print()
    print_warning("자동 설치에 실패했습니다. 다음 방법으로 수동 설치를 시도해보세요:")
    print_info(f"1. 기존 앱 제거: adb uninstall mygolfplanner.app")
    print_info(f"2. APK 설치: adb install {apk_path}")
    print_info(f"3. 또는 APK 파일을 기기로 전송 후 직접 설치")

    return False

def grant_android_permissions(env):
    """필요한 권한 부여 (선택사항)"""
    package_name = "mygolfplanner.app"
    permissions = []
    
    if not permissions:
        return True
    
    for permission in permissions:
        output, success = run_adb_command(
            ['shell', 'pm', 'grant', package_name, permission],
            env=env,
            check=False
        )
        if success:
            print_success(f"권한 부여 완료: {permission}")
        else:
            print_warning(f"권한 부여 실패 (무시 가능): {permission}")
    
    return True

def launch_android_app(env):
    """안드로이드 앱 실행"""
    print_step("앱 실행 중...")
    
    package_name = "mygolfplanner.app"
    activity_name = "com.example.reservation_system.MainActivity"
    
    output, success = run_adb_command(
        ['shell', 'am', 'start', '-n', f'{package_name}/{activity_name}'],
        env=env,
        check=False
    )
    
    if success:
        print_success("앱이 실행되었습니다!")
        return True
    else:
        # 실패 시 패키지명으로만 실행 시도
        output2, success2 = run_adb_command(
            ['shell', 'monkey', '-p', package_name, '-c', 'android.intent.category.LAUNCHER', '1'],
            env=env,
            check=False
        )
        if success2:
            print_success("앱이 실행되었습니다!")
            return True
        
        print_warning("앱 실행 실패 (수동으로 실행해주세요)")
        print_info(f"앱 패키지명: {package_name}")
        return False

def show_android_device_info(env):
    """안드로이드 기기 정보 표시"""
    print_step("기기 정보 확인 중...")
    
    info_commands = {
        "모델": ['shell', 'getprop', 'ro.product.model'],
        "Android 버전": ['shell', 'getprop', 'ro.build.version.release'],
        "API 레벨": ['shell', 'getprop', 'ro.build.version.sdk'],
    }
    
    for label, cmd in info_commands.items():
        output, _ = run_adb_command(cmd, env=env, check=False)
        if output:
            print_info(f"{label}: {output}")

def auto_install_and_run_apk(apk_file_path, auto_launch=True):
    """APK 빌드 후 자동으로 설치 및 실행"""
    print()
    print(f"{Colors.CYAN}{Colors.BOLD}📱 안드로이드 기기 자동 설치 및 실행{Colors.RESET}")
    print("=" * 60)
    print()
    
    env = setup_android_environment()
    
    # 연결된 기기 확인
    devices = check_android_devices(env)
    
    if not devices:
        print_warning("연결된 Android 기기나 에뮬레이터가 없습니다.")
        print_info("APK는 빌드되었지만 설치할 기기가 없습니다.")
        print()
        print("기기를 연결한 후 다음 명령어로 다시 빌드하면 자동으로 설치됩니다:")
        print(f"  python build_android_app.py --apk")
        print()
        return False
    
    print_success(f"{len(devices)}개의 기기가 연결되었습니다:")
    for i, device_id in enumerate(devices, 1):
        print(f"  {i}. {device_id}")
    print()
    
    # 여러 기기가 연결된 경우 첫 번째 기기 사용
    if len(devices) > 1:
        print_warning(f"여러 기기가 연결되어 있습니다. 첫 번째 기기({devices[0]})를 사용합니다.")
        print()
    
    # 기기 정보 표시
    show_android_device_info(env)
    print()
    
    # APK 설치
    if not install_android_apk(str(apk_file_path), env):
        return False
    print()
    
    # 권한 부여
    grant_android_permissions(env)
    print()
    
    # 앱 실행
    if auto_launch:
        if launch_android_app(env):
            print()
            print(f"{Colors.GREEN}{Colors.BOLD}✅ 설치 및 실행 완료!{Colors.RESET}")
            return True
        else:
            print_warning("앱 실행은 실패했지만 설치는 완료되었습니다.")
            return True
    else:
        print_info("앱이 설치되었습니다. 수동으로 실행해주세요.")
        return True

def build_android_apk(release=True, split_per_abi=False, auto_install=True):
    """안드로이드 APK 빌드"""
    print_step("안드로이드 APK 빌드 시작...")
    
    env = setup_android_environment()
    
    build_cmd = ['build', 'apk']
    if release:
        build_cmd.append('--release')
    if split_per_abi:
        build_cmd.append('--split-per-abi')
    
    success = run_flutter_command(build_cmd, env=env)
    
    if success:
        project_path = Path(__file__).parent
        apk_path = project_path / "build" / "app" / "outputs" / "flutter-apk"
        
        if release:
            apk_file = apk_path / "app-release.apk"
        else:
            apk_file = apk_path / "app-debug.apk"
        
        if apk_file.exists():
            size_mb = os.path.getsize(apk_file) / (1024 * 1024)
            print_success(f"APK 빌드 완료!")
            print_info(f"파일 위치: {apk_file}")
            print_info(f"파일 크기: {size_mb:.1f} MB")
            
            # 자동 설치 및 실행
            if auto_install:
                auto_install_and_run_apk(apk_file, auto_launch=True)
            
            return True
        else:
            print_error("APK 파일을 찾을 수 없습니다.")
            return False
    else:
        print_error("APK 빌드 실패")
        return False

def build_android_appbundle(release=True):
    """안드로이드 App Bundle (AAB) 빌드"""
    print_step("안드로이드 App Bundle (AAB) 빌드 시작...")
    
    env = setup_android_environment()
    
    build_cmd = ['build', 'appbundle']
    if release:
        build_cmd.append('--release')
    
    success = run_flutter_command(build_cmd, env=env)
    
    if success:
        project_path = Path(__file__).parent
        bundle_path = project_path / "build" / "app" / "outputs" / "bundle"
        
        if release:
            bundle_file = bundle_path / "release" / "app-release.aab"
        else:
            bundle_file = bundle_path / "debug" / "app-debug.aab"
        
        if bundle_file.exists():
            size_mb = os.path.getsize(bundle_file) / (1024 * 1024)
            print_success(f"App Bundle 빌드 완료!")
            print_info(f"파일 위치: {bundle_file}")
            print_info(f"파일 크기: {size_mb:.1f} MB")
            print_info("Google Play Store에 업로드할 준비가 되었습니다.")
            return True
        else:
            print_error("App Bundle 파일을 찾을 수 없습니다.")
            return False
    else:
        print_error("App Bundle 빌드 실패")
        return False

def main():
    parser = argparse.ArgumentParser(
        description='MyGolfPlanner 안드로이드 앱 빌드 스크립트',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
사용 예시:
  # 안드로이드 APK 빌드 (릴리즈, 자동 설치 및 실행)
  python build_android_app.py --apk
  
  # 안드로이드 APK 빌드 (자동 설치 건너뛰기)
  python build_android_app.py --apk --no-auto-install
  
  # 안드로이드 App Bundle 빌드 (릴리즈)
  python build_android_app.py --bundle
  
  # 디버그 빌드
  python build_android_app.py --apk --debug
  
  # 빌드 전 정리 없이 빌드
  python build_android_app.py --apk --no-clean
        """
    )
    
    parser.add_argument(
        '--apk',
        action='store_true',
        help='안드로이드 APK 빌드'
    )
    parser.add_argument(
        '--bundle',
        action='store_true',
        help='안드로이드 App Bundle (AAB) 빌드'
    )
    parser.add_argument(
        '--debug',
        action='store_true',
        help='디버그 빌드 (기본값: 릴리즈)'
    )
    parser.add_argument(
        '--no-clean',
        action='store_true',
        help='빌드 전 정리 건너뛰기'
    )
    parser.add_argument(
        '--split-per-abi',
        action='store_true',
        help='안드로이드 APK를 ABI별로 분할 빌드'
    )
    parser.add_argument(
        '--no-auto-install',
        action='store_true',
        help='APK 빌드 후 자동 설치 및 실행 건너뛰기'
    )
    
    args = parser.parse_args()
    
    print(f"{Colors.BOLD}{Colors.CYAN}MyGolfPlanner 안드로이드 앱 빌드 스크립트{Colors.RESET}")
    print("=" * 60)
    print()
    
    # Flutter 설치 확인
    if not check_flutter_installed():
        print_error("Flutter가 설치되어 있지 않거나 PATH에 없습니다.")
        print_info("Flutter 설치 후 다시 시도해주세요.")
        sys.exit(1)
    print()
    
    # 프로젝트 디렉토리 확인
    if not check_project_directory():
        sys.exit(1)
    print()
    
    # 빌드 타입 결정
    release = not args.debug
    
    # 빌드 타입이 지정되지 않은 경우 선택
    if not args.apk and not args.bundle:
        print_info("안드로이드 빌드 타입을 선택해주세요:")
        print("  1. APK (직접 설치용)")
        print("  2. App Bundle (Google Play 업로드용)")
        print()
        
        while True:
            try:
                choice = input(f"{Colors.YELLOW}선택 (1 또는 2, 기본값: 1): {Colors.RESET}").strip()
                if choice == '' or choice == '1':
                    args.apk = True
                    break
                elif choice == '2':
                    args.bundle = True
                    break
                else:
                    print_error("1 또는 2를 입력해주세요.")
            except KeyboardInterrupt:
                print(f"\n{Colors.YELLOW}사용자에 의해 취소되었습니다.{Colors.RESET}")
                sys.exit(0)
        print()
    
    # 빌드 전 정리
    if not args.no_clean:
        clean_build()
    
    # 의존성 가져오기
    if not get_pub_dependencies():
        sys.exit(1)
    
    # 앱 아이콘 생성
    generate_launcher_icons()
    
    # 빌드 실행
    success = False
    
    auto_install = not args.no_auto_install
    if args.apk:
        success = build_android_apk(release=release, split_per_abi=args.split_per_abi, auto_install=auto_install)
    elif args.bundle:
        success = build_android_appbundle(release=release)
    else:
        # 기본값: APK 빌드
        print_info("빌드 타입이 지정되지 않아 기본값으로 APK를 빌드합니다.")
        success = build_android_apk(release=release, split_per_abi=args.split_per_abi, auto_install=auto_install)
    
    print()
    if success:
        print(f"{Colors.GREEN}{Colors.BOLD}✅ 빌드 완료!{Colors.RESET}")
        print()
        if args.apk and args.no_auto_install:
            print("📱 APK 설치 방법:")
            print("   python build_android_app.py --apk")
            print("   (--no-auto-install 옵션 없이 실행하면 자동으로 설치됩니다)")
            print()
        elif args.bundle:
            print("📱 App Bundle 업로드 방법:")
            print("   Google Play Console > 앱 > 프로덕션 > 새 버전 만들기")
            print()
    else:
        print(f"{Colors.RED}{Colors.BOLD}❌ 빌드 실패{Colors.RESET}")
        sys.exit(1)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}사용자에 의해 취소되었습니다.{Colors.RESET}")
        sys.exit(0)
    except Exception as e:
        print_error(f"예상치 못한 오류 발생: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

