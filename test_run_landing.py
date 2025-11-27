#!/usr/bin/env python3
"""
Landing 웹사이트 테스트 실행 스크립트 (React/Vite 지원)

사용법:
    python test_run_landing.py [옵션]

옵션:
    --dev       : 개발 모드로 실행 (Vite dev server, 기본값)
    --build     : 프로덕션 빌드 후 실행
    --port PORT : 사용할 포트 번호 (기본값: 3000)
    --host HOST : 사용할 호스트 (기본값: localhost)
    --open      : 자동으로 브라우저 열기
"""

import os
import sys
import subprocess
import argparse
import http.server
import socketserver
import webbrowser
import socket
import time
from pathlib import Path

# 프로젝트 경로 설정
PROJECT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'landing')

def is_port_available(port):
    """포트 사용 가능 여부 확인"""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        try:
            s.bind(('localhost', port))
            return True
        except socket.error:
            return False

def find_available_port(start_port=3000, max_attempts=10):
    """사용 가능한 포트 찾기"""
    for port in range(start_port, start_port + max_attempts):
        if is_port_available(port):
            return port
    return None

def check_node_npm():
    """Node.js와 npm 설치 확인"""
    try:
        node_version = subprocess.check_output(['node', '--version'], stderr=subprocess.STDOUT).decode().strip()
        npm_version = subprocess.check_output(['npm', '--version'], stderr=subprocess.STDOUT).decode().strip()
        print(f"✅ Node.js {node_version}")
        print(f"✅ npm {npm_version}")
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("❌ Node.js 또는 npm이 설치되어 있지 않습니다.")
        print("   https://nodejs.org 에서 Node.js를 설치해주세요.")
        return False

def check_dependencies():
    """node_modules 설치 확인"""
    node_modules_dir = os.path.join(PROJECT_DIR, 'node_modules')
    if not os.path.exists(node_modules_dir):
        print("\n📦 의존성 패키지를 설치합니다...")
        try:
            subprocess.run(['npm', 'install'], cwd=PROJECT_DIR, check=True)
            print("✅ 의존성 설치 완료!")
            return True
        except subprocess.CalledProcessError as e:
            print(f"❌ 의존성 설치 실패: {e}")
            return False
    return True

def run_dev_server(port, host, open_browser=False):
    """Vite 개발 서버 실행"""

    # 프로젝트 디렉토리 확인
    if not os.path.exists(PROJECT_DIR):
        print(f"❌ Landing 프로젝트 디렉토리를 찾을 수 없습니다: {PROJECT_DIR}")
        return 1

    # package.json 확인
    package_json = os.path.join(PROJECT_DIR, 'package.json')
    if not os.path.exists(package_json):
        print(f"❌ package.json 파일을 찾을 수 없습니다: {package_json}")
        return 1

    # Node.js/npm 확인
    if not check_node_npm():
        return 1

    # 의존성 확인 및 설치
    if not check_dependencies():
        return 1

    # 포트 사용 가능 여부 확인
    if not is_port_available(port):
        print(f"⚠️  포트 {port}가 이미 사용 중입니다.")
        new_port = find_available_port(port + 1)
        if new_port:
            print(f"✅ 사용 가능한 포트 {new_port}를 사용합니다.")
            port = new_port
        else:
            print("❌ 사용 가능한 포트를 찾을 수 없습니다.")
            return 1

    url = f"http://{host}:{port}"

    print("\n" + "=" * 60)
    print("🚀 Landing 웹사이트 개발 서버 시작 (Vite)")
    print("=" * 60)
    print(f"📁 디렉토리: {PROJECT_DIR}")
    print(f"🌍 URL: {url}")
    print(f"🔌 포트: {port}")
    print(f"💻 호스트: {host}")
    print("\n✅ 서버를 시작합니다...")
    print("⏹️  종료하려면 Ctrl+C를 누르세요.\n")
    print("=" * 60 + "\n")

    # 브라우저 자동 열기
    if open_browser:
        time.sleep(2)  # 서버 시작 대기
        print(f"🌐 브라우저를 엽니다: {url}")
        webbrowser.open(url)

    # Vite 개발 서버 실행
    try:
        env = os.environ.copy()
        env['PORT'] = str(port)
        subprocess.run(['npm', 'run', 'dev'], cwd=PROJECT_DIR, env=env)
        return 0
    except KeyboardInterrupt:
        print("\n\n⏹️  서버를 종료합니다...")
        return 0
    except subprocess.CalledProcessError as e:
        print(f"\n❌ 서버 실행 중 오류 발생: {e}")
        return 1

def run_build_server(port, host, open_browser=False):
    """프로덕션 빌드 후 서버 실행"""

    # 프로젝트 디렉토리 확인
    if not os.path.exists(PROJECT_DIR):
        print(f"❌ Landing 프로젝트 디렉토리를 찾을 수 없습니다: {PROJECT_DIR}")
        return 1

    # Node.js/npm 확인
    if not check_node_npm():
        return 1

    # 의존성 확인 및 설치
    if not check_dependencies():
        return 1

    # 빌드 실행
    print("\n🔨 프로덕션 빌드를 시작합니다...\n")
    try:
        subprocess.run(['npm', 'run', 'build'], cwd=PROJECT_DIR, check=True)
        print("\n✅ 빌드 완료!")
    except subprocess.CalledProcessError as e:
        print(f"\n❌ 빌드 실패: {e}")
        return 1

    # 빌드 결과물 디렉토리 확인
    build_dir = os.path.join(PROJECT_DIR, 'build')
    if not os.path.exists(build_dir):
        print(f"❌ 빌드 디렉토리를 찾을 수 없습니다: {build_dir}")
        return 1

    # 포트 사용 가능 여부 확인
    if not is_port_available(port):
        print(f"⚠️  포트 {port}가 이미 사용 중입니다.")
        new_port = find_available_port(port + 1)
        if new_port:
            print(f"✅ 사용 가능한 포트 {new_port}를 사용합니다.")
            port = new_port
        else:
            print("❌ 사용 가능한 포트를 찾을 수 없습니다.")
            return 1

    url = f"http://{host}:{port}"

    print("\n" + "=" * 60)
    print("🌐 Landing 웹사이트 프로덕션 서버 시작")
    print("=" * 60)
    print(f"📁 디렉토리: {build_dir}")
    print(f"🌍 URL: {url}")
    print(f"🔌 포트: {port}")
    print(f"💻 호스트: {host}")
    print("\n✅ 서버가 실행되었습니다!")
    print("⏹️  종료하려면 Ctrl+C를 누르세요.\n")
    print("=" * 60 + "\n")

    # 브라우저 자동 열기
    if open_browser:
        print(f"🌐 브라우저를 엽니다: {url}")
        webbrowser.open(url)

    # 서버 시작
    os.chdir(build_dir)

    Handler = http.server.SimpleHTTPRequestHandler
    Handler.extensions_map.update({
        '.html': 'text/html',
        '.css': 'text/css',
        '.js': 'application/javascript',
        '.json': 'application/json',
        '.png': 'image/png',
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.gif': 'image/gif',
        '.svg': 'image/svg+xml',
        '.ico': 'image/x-icon',
    })

    try:
        with socketserver.TCPServer((host, port), Handler) as httpd:
            httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n\n⏹️  서버를 종료합니다...")
        return 0
    except Exception as e:
        print(f"\n❌ 서버 실행 중 오류 발생: {e}")
        return 1

def check_files():
    """프로젝트 파일 구조 확인"""
    print("\n📂 Landing 프로젝트 파일 구조:\n")

    required_files = [
        'package.json',
        'vite.config.ts',
        'tsconfig.json',
        'tailwind.config.js',
        'index.html',
        'src/App.tsx',
        'src/main.tsx',
        'src/index.css',
    ]

    for file_path in required_files:
        full_path = os.path.join(PROJECT_DIR, file_path)
        if os.path.exists(full_path):
            print(f"  ✅ {file_path}")
        else:
            print(f"  ❌ {file_path} (없음)")

    # components 디렉토리 확인
    components_dir = os.path.join(PROJECT_DIR, 'src', 'components')
    if os.path.exists(components_dir):
        component_files = [f for f in os.listdir(components_dir) if f.endswith('.tsx')]
        print(f"\n  ✅ src/components/ ({len(component_files)}개 컴포넌트)")
        for comp in sorted(component_files)[:5]:  # 처음 5개만 표시
            print(f"     - {comp}")
        if len(component_files) > 5:
            print(f"     ... 외 {len(component_files) - 5}개")
    else:
        print(f"\n  ❌ src/components/ (없음)")

    # node_modules 확인
    node_modules_dir = os.path.join(PROJECT_DIR, 'node_modules')
    if os.path.exists(node_modules_dir):
        print(f"\n  ✅ node_modules/ (설치됨)")
    else:
        print(f"\n  ⚠️  node_modules/ (미설치 - npm install 필요)")

    print()

def main():
    parser = argparse.ArgumentParser(
        description='Landing 웹사이트 테스트 실행 스크립트 (React/Vite)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
예제:
    python test_run_landing.py                    # 개발 모드로 실행
    python test_run_landing.py --dev              # 개발 모드로 실행 (명시적)
    python test_run_landing.py --build            # 프로덕션 빌드 후 실행
    python test_run_landing.py --open             # 브라우저 자동 열기
    python test_run_landing.py --port 8080        # 포트 8080으로 실행
    python test_run_landing.py --check            # 파일 구조만 확인
        """
    )

    parser.add_argument('--dev', action='store_true', default=False,
                       help='개발 모드로 실행 (Vite dev server)')
    parser.add_argument('--build', action='store_true',
                       help='프로덕션 빌드 후 실행')
    parser.add_argument('--port', type=int, default=3000,
                       help='사용할 포트 번호 (기본값: 3000)')
    parser.add_argument('--host', default='localhost',
                       help='사용할 호스트 (기본값: localhost)')
    parser.add_argument('--open', action='store_true',
                       help='자동으로 브라우저 열기')
    parser.add_argument('--check', action='store_true',
                       help='파일 구조만 확인')

    args = parser.parse_args()

    # 파일 구조 확인
    if args.check:
        check_files()
        return 0

    # 빌드 모드가 명시적으로 지정되지 않으면 개발 모드를 기본값으로 사용
    if args.build:
        return run_build_server(args.port, args.host, args.open)
    else:
        # 개발 모드 (기본값)
        return run_dev_server(args.port, args.host, args.open)

if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\n⚠️  사용자에 의해 중단되었습니다.")
        sys.exit(0)
