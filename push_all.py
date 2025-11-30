#!/usr/bin/env python3
"""
전체 프로젝트 - v2_autogolf-project 리포지토리로 Push
모노레포 전체를 origin에 push (서브프로젝트 포함)
"""
import subprocess
import sys
from pathlib import Path

# 설정
REMOTE_URL = 'https://github.com/seojongik/v2_autogolf-project.git'

# 서브프로젝트 설정 (이름, 폴더, push 스크립트)
SUBPROJECTS = [
    {'name': 'CRM', 'folder': 'crm', 'script': 'crm/crm_push.py'},
    {'name': 'CRM Lite Pro', 'folder': 'crm_lite_pro', 'script': 'crm_lite_pro/crm_lite_pro_push.py', 'is_submodule': True},
    {'name': 'Landing', 'folder': 'landing', 'script': 'landing/landing_push.py'},
    {'name': 'Planner', 'folder': 'myxplanner', 'script': 'myxplanner/planner_push.py'},
]

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

def print_error(message):
    print(f"{Colors.RED}✗ {message}{Colors.RESET}")

def print_warning(message):
    print(f"{Colors.YELLOW}⚠ {message}{Colors.RESET}")

def run_command(cmd, cwd=None, check=True):
    try:
        result = subprocess.run(
            cmd, cwd=cwd, check=check,
            capture_output=True, text=True
        )
        return result.stdout.strip(), result.returncode
    except subprocess.CalledProcessError as e:
        if check:
            print_error(f"명령 실행 실패: {' '.join(cmd)}")
            print_error(f"에러: {e.stderr}")
            raise
        return e.stderr.strip(), e.returncode

def get_subproject_changes(root):
    """각 서브프로젝트의 변경사항 확인"""
    changed = []
    for proj in SUBPROJECTS:
        folder = proj['folder']
        is_submodule = proj.get('is_submodule', False)

        if is_submodule:
            # 서브모듈은 해당 폴더 내에서 git status 확인
            submodule_path = root / folder
            if submodule_path.exists():
                status, _ = run_command(['git', 'status', '--porcelain'], cwd=submodule_path, check=False)
                if status:
                    changed.append(proj)
        else:
            # subtree는 해당 폴더의 변경사항 확인
            status, _ = run_command(['git', 'status', '--porcelain', f'{folder}/'], cwd=root, check=False)
            if status:
                changed.append(proj)
    return changed

def run_subproject_push(root, proj, commit_message):
    """서브프로젝트 push 스크립트 실행 (자동 확인)"""
    script_path = root / proj['script']
    print_step(f"{proj['name']} push 실행 중...")

    try:
        # 스크립트를 커밋 메시지와 함께 실행, 'y'를 자동 입력
        result = subprocess.run(
            ['python3', str(script_path), commit_message],
            cwd=root,
            check=False,
            text=True,
            input='y\n'  # push 확인에 자동으로 'y' 응답
        )
        if result.returncode == 0:
            print_success(f"{proj['name']} push 완료")
        else:
            print_warning(f"{proj['name']} push 중 문제 발생 (계속 진행)")
    except Exception as e:
        print_error(f"{proj['name']} push 실패: {e}")

def main():
    root = Path(__file__).parent

    print(f"{Colors.BOLD}전체 프로젝트 - v2_autogolf-project 리포지토리로 Push{Colors.RESET}")
    print(f"대상 리포: {REMOTE_URL}")
    print()

    # 서브프로젝트 변경사항 확인
    print_step("서브프로젝트 변경사항 확인")
    changed_subprojects = get_subproject_changes(root)

    if changed_subprojects:
        print_success("변경된 서브프로젝트:")
        for proj in changed_subprojects:
            submodule_tag = " (서브모듈)" if proj.get('is_submodule') else ""
            print(f"  • {proj['name']}{submodule_tag}")
        print()

        response = input(f"{Colors.YELLOW}서브프로젝트들도 각각의 리포에 push하시겠습니까? (y/N): {Colors.RESET}").lower()
        push_subprojects = response == 'y'
    else:
        print_warning("변경된 서브프로젝트가 없습니다.")
        push_subprojects = False
    print()

    # 전체 변경사항 확인
    print_step("전체 변경사항 확인")
    status_output, _ = run_command(['git', 'status', '--porcelain'], cwd=root, check=False)

    if not status_output:
        print_warning("변경사항이 없습니다.")

        # Push 안된 커밋 확인
        current_branch, _ = run_command(
            ['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
            cwd=root
        )
        ahead_behind, _ = run_command(
            ['git', 'rev-list', '--left-right', '--count', f'origin/{current_branch}...HEAD'],
            cwd=root, check=False
        )

        if ahead_behind:
            parts = ahead_behind.split()
            if len(parts) == 2 and int(parts[1]) > 0:
                print_warning(f"Push되지 않은 커밋이 {parts[1]}개 있습니다.")
                response = input(f"{Colors.YELLOW}Push하시겠습니까? (y/N): {Colors.RESET}").lower()
                if response == 'y':
                    print_step(f"Push 중 (origin/{current_branch})")
                    run_command(['git', 'push', 'origin', current_branch], cwd=root)
                    print_success("Push 완료!")
                sys.exit(0)

        print("할 일이 없습니다.")
        sys.exit(0)

    # 변경된 프로젝트 표시
    print_success("변경사항 발견:")
    for line in status_output.split('\n'):
        if line.startswith(' M') or line.startswith('M '):
            folder = line.split('/')[0].split()[-1] if '/' in line else ''
            print(f"  {line}")
    print()

    # 커밋 메시지 입력
    commit_message = None
    if len(sys.argv) > 1:
        commit_message = sys.argv[1]
    else:
        print(f"{Colors.YELLOW}커밋 메시지를 입력하세요:{Colors.RESET}")
        commit_message = input("> ")

    if not commit_message:
        print_error("커밋 메시지가 비어있습니다.")
        sys.exit(1)

    # 서브프로젝트 push (사용자가 동의한 경우)
    if push_subprojects and changed_subprojects:
        print()
        print(f"{Colors.BOLD}=== 서브프로젝트 Push ==={Colors.RESET}")
        for proj in changed_subprojects:
            run_subproject_push(root, proj, commit_message)
        print()

    # 전체 add
    print_step("전체 스테이징")
    run_command(['git', 'add', '.'], cwd=root)
    print_success("스테이징 완료")
    print()

    # 커밋
    print_step("커밋 생성")
    run_command(['git', 'commit', '-m', commit_message], cwd=root)
    print_success(f"커밋 완료: {commit_message}")
    print()

    # Push
    current_branch, _ = run_command(
        ['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
        cwd=root
    )

    response = input(f"{Colors.YELLOW}v2_autogolf-project에 Push하시겠습니까? (y/N): {Colors.RESET}").lower()
    if response != 'y':
        print_warning("Push를 취소했습니다. 커밋은 로컬에 저장되었습니다.")
        sys.exit(0)

    print_step(f"Push 중 (origin/{current_branch})")
    run_command(['git', 'push', 'origin', current_branch], cwd=root)

    print()
    print_success("전체 Push 완료!")
    print(f"{Colors.GREEN}✓ {REMOTE_URL} 에 전체 프로젝트가 push 되었습니다.{Colors.RESET}")

if __name__ == '__main__':
    main()
