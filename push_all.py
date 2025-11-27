#!/usr/bin/env python3
"""
전체 프로젝트 한 번에 push
"""
import subprocess
from pathlib import Path

class Colors:
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    RESET = '\033[0m'
    BOLD = '\033[1m'

def main():
    root = Path(__file__).parent
    
    print(f"{Colors.BOLD}🚀 전체 프로젝트 Push{Colors.RESET}")
    print()
    
    # 변경사항 확인
    status = subprocess.run(
        ['git', 'status', '--porcelain'],
        cwd=root, capture_output=True, text=True
    )
    
    if not status.stdout.strip():
        print(f"{Colors.GREEN}✓ 변경사항 없음{Colors.RESET}")
        return
    
    print(f"{Colors.YELLOW}변경된 프로젝트:{Colors.RESET}")
    for line in status.stdout.strip().split('\n'):
        print(f"  {line}")
    print()
    
    commit_msg = input(f"{Colors.YELLOW}커밋 메시지: {Colors.RESET}")
    if not commit_msg:
        print(f"{Colors.RED}✗ 취소됨{Colors.RESET}")
        return
    
    # 전체 add
    subprocess.run(['git', 'add', '.'], cwd=root, check=True)
    
    # 커밋
    subprocess.run(['git', 'commit', '-m', commit_msg], cwd=root, check=True)
    
    # Push
    branch = subprocess.run(
        ['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
        cwd=root, capture_output=True, text=True, check=True
    ).stdout.strip()
    
    response = input(f"{Colors.YELLOW}Push하시겠습니까? (y/N): {Colors.RESET}").lower()
    if response != 'y':
        print(f"{Colors.RED}✗ Push 취소{Colors.RESET}")
        return
    
    subprocess.run(['git', 'push', 'origin', branch], cwd=root, check=True)
    
    print()
    print(f"{Colors.GREEN}✓ 전체 Push 완료!{Colors.RESET}")

if __name__ == '__main__':
    main()


