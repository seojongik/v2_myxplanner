#!/usr/bin/env python3
"""
골프 플래너 앱 - GitHub에서 최신 코드 가져오기

사용법:
  python planner_pull.py
"""

import subprocess
import sys
from pathlib import Path

# 색상 코드
class Colors:
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    RESET = '\033[0m'
    BOLD = '\033[1m'

def print_step(message):
    print(f"{Colors.BLUE}{Colors.BOLD}▶ {message}{Colors.RESET}")

def print_success(message):
    print(f"{Colors.GREEN}✓ {message}{Colors.RESET}")

def print_warning(message):
    print(f"{Colors.YELLOW}⚠ {message}{Colors.RESET}")

def print_error(message):
    print(f"{Colors.RED}✗ {message}{Colors.RESET}")

def run_command(cmd, cwd=None, check=True):
    try:
        result = subprocess.run(
            cmd,
            cwd=cwd,
            check=check,
            capture_output=True,
            text=True
        )
        return result.stdout.strip(), result.returncode
    except subprocess.CalledProcessError as e:
        if check:
            print_error(f"명령 실행 실패: {' '.join(cmd)}")
            print_error(f"에러: {e.stderr}")
            raise
        return e.stderr.strip(), e.returncode

def main():
    project_path = Path(__file__).parent

    print(f"{Colors.BOLD}골프 플래너 앱 - GitHub에서 최신 코드 가져오기{Colors.RESET}")
    print(f"경로: {project_path}")
    print()

    # 1. 로컬 변경사항 확인
    print_step("로컬 변경사항 확인")
    status_output, _ = run_command(['git', 'status', '--porcelain'],
                                  cwd=project_path, check=False)

    if status_output:
        print_warning("로컬에 변경사항이 있습니다:")
        print(status_output)
        print()
        response = input(f"{Colors.YELLOW}변경사항을 무시하고 계속하시겠습니까? (y/N): {Colors.RESET}").lower()
        if response != 'y':
            print_warning("Pull을 취소했습니다. 먼저 변경사항을 커밋하거나 stash하세요.")
            sys.exit(0)
    else:
        print_success("로컬 변경사항 없음")

    # 현재 브랜치 확인
    current_branch, _ = run_command(['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
                                   cwd=project_path)
    print(f"현재 브랜치: {Colors.BOLD}{current_branch}{Colors.RESET}")
    print()

    # 2. Fetch
    print_step("원격 저장소 정보 가져오기")
    run_command(['git', 'fetch', 'origin'], cwd=project_path)
    print_success("Fetch 완료")
    print()

    # 3. Pull
    print_step(f"최신 코드 병합 (origin/{current_branch})")
    
    # 현재 커밋과 원격 커밋 비교
    local_commit, _ = run_command(['git', 'rev-parse', 'HEAD'], cwd=project_path)
    remote_commit, _ = run_command(['git', 'rev-parse', f'origin/{current_branch}'], 
                                  cwd=project_path)
    
    if local_commit == remote_commit:
        print_success("이미 최신 상태입니다")
    else:
        # Pull 실행
        pull_output, _ = run_command(['git', 'pull', 'origin', current_branch], 
                                    cwd=project_path)
        if pull_output:
            print(pull_output)
        print_success("Pull 완료")
    
    print()
    print_success("Pull 완료!")

if __name__ == '__main__':
    main()
