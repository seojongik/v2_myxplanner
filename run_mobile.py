#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MyGolfPlanner 모바일 실행 스크립트
Flutter 앱을 네트워크에서 접근 가능하도록 실행합니다.
"""

import subprocess
import socket
import sys
import os
import time

def get_local_ip():
    """로컬 IP 주소를 가져옵니다."""
    try:
        # 임시 소켓을 만들어 로컬 IP 확인
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            local_ip = s.getsockname()[0]
        return local_ip
    except Exception:
        return "192.168.1.xxx"

def check_flutter_installed():
    """Flutter가 설치되어 있는지 확인합니다."""
    try:
        result = subprocess.run(['flutter', '--version'], 
                              capture_output=True, text=True, timeout=10)
        return result.returncode == 0
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False

def main():
    print("🚀 MyGolfPlanner 모바일 실행 스크립트")
    print("=" * 30)
    
    # Flutter 설치 확인
    if not check_flutter_installed():
        print("❌ Flutter가 설치되어 있지 않거나 PATH에 없습니다.")
        print("   Flutter 설치 후 다시 시도해주세요.")
        sys.exit(1)
    
    # 현재 디렉토리 확인
    if not os.path.exists('pubspec.yaml'):
        print("❌ Flutter 프로젝트 디렉토리에서 실행해주세요.")
        print("   pubspec.yaml 파일이 있는 디렉토리에서 실행하세요.")
        sys.exit(1)
    
    # 로컬 IP 주소 가져오기
    local_ip = get_local_ip()
    port = 8080
    
    print(f"📱 모바일에서 접속할 주소:")
    print(f"   http://{local_ip}:{port}")
    print()
    print("📋 모바일 접속 방법:")
    print("1. 핸드폰이 같은 WiFi에 연결되어 있는지 확인")
    print("2. 핸드폰 브라우저에서 위 주소로 접속")
    print("3. 앱이 로딩될 때까지 잠시 기다리기")
    print()
    print("🔧 Flutter 앱 실행 중...")
    print("   (종료하려면 Ctrl+C 누르세요)")
    print("=" * 50)
    
    try:
        # Flutter 앱 실행 (verbose 모드로 더 많은 로그 출력)
        cmd = [
            'flutter', 'run', 
            '-d', 'web-server',
            '--web-hostname', '0.0.0.0',
            '--web-port', str(port),
            '--web-header', 'Cross-Origin-Embedder-Policy=unsafe-none',
            '--web-header', 'Cross-Origin-Opener-Policy=same-origin-allow-popups',
            '--verbose'  # 상세한 로그 출력
        ]
        
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE, 
                                 stderr=subprocess.STDOUT, 
                                 universal_newlines=True, 
                                 bufsize=1)
        
        # 실시간 출력
        for line in process.stdout:
            # ANSI 색상 코드 제거 (터미널에서 깔끔하게 출력)
            clean_line = line.rstrip()
            # 디버그 로그 강조 표시
            if any(keyword in clean_line for keyword in ['💳', '✅', '❌', '⚠️', '🔍', '📱', '🚀']):
                print(f"\033[1;33m{clean_line}\033[0m")  # 노란색으로 강조
            elif 'ERROR' in clean_line or '오류' in clean_line or '실패' in clean_line:
                print(f"\033[1;31m{clean_line}\033[0m")  # 빨간색으로 강조
            elif 'SUCCESS' in clean_line or '성공' in clean_line or '완료' in clean_line:
                print(f"\033[1;32m{clean_line}\033[0m")  # 초록색으로 강조
            else:
                print(clean_line)
            
            # 서버가 시작되면 안내 메시지 출력
            if "is being served at" in line:
                print()
                print("✅ 서버가 시작되었습니다!")
                print(f"📱 모바일에서 http://{local_ip}:{port} 로 접속하세요!")
                print()
        
    except KeyboardInterrupt:
        print("\n🛑 사용자에 의해 종료되었습니다.")
        if 'process' in locals():
            process.terminate()
    except Exception as e:
        print(f"❌ 오류 발생: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 