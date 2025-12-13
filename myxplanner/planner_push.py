#!/usr/bin/env python3
"""
골프 플래너 앱 - GitHub에 업로드
myxplanner/ 폴더만 v2_myxplanner 리포지토리로 push
"""
import subprocess
import sys
from pathlib import Path

# 설정
REMOTE_NAME = 'planner-origin'
REMOTE_URL = 'https://github.com/seojongik/v2_myxplanner.git'
FOLDER_PREFIX = 'myxplanner'
BRANCH = 'main'

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

def ensure_remote(project_root):
    """remote가 없으면 추가"""
    remotes, _ = run_command(['git', 'remote'], cwd=project_root, check=False)
    if REMOTE_NAME not in remotes.split('\n'):
        print_step(f"Remote '{REMOTE_NAME}' 추가 중...")
        run_command(['git', 'remote', 'add', REMOTE_NAME, REMOTE_URL], cwd=project_root)
        print_success(f"Remote 추가 완료: {REMOTE_URL}")
    return True

def main():
    project_root = Path(__file__).parent.parent

    print(f"{Colors.BOLD}골프 플래너 앱 - v2_myxplanner 리포지토리로 Push{Colors.RESET}")
    print(f"대상 폴더: {FOLDER_PREFIX}/")
    print(f"대상 리포: {REMOTE_URL}")
    print()

    # 1. myxplanner/ 폴더의 변경사항 확인
    print_step("플래너 변경사항 확인")
    status_output, _ = run_command(
        ['git', 'status', '--porcelain', f'{FOLDER_PREFIX}/'],
        cwd=project_root, check=False
    )

    if not status_output:
        print_warning(f"{FOLDER_PREFIX}/ 폴더에 변경사항이 없습니다.")

        # 이미 커밋된 것이 있는지 확인
        recent_commits, _ = run_command(
            ['git', 'log', '--oneline', '-1', '--', f'{FOLDER_PREFIX}/'],
            cwd=project_root, check=False
        )
        
        if recent_commits:
            print_success(f"최근 커밋 발견: {recent_commits}")
            # 비대화형 모드: 자동으로 push
            if len(sys.argv) > 1 and sys.argv[1] == '--auto':
                ensure_remote(project_root)
                print_step(f"Subtree push 중 ({REMOTE_NAME}/{BRANCH}) - 강제 push")
                try:
                    # subtree split으로 분리 후 force push
                    split_output, _ = run_command(
                        ['git', 'subtree', 'split', '--prefix', FOLDER_PREFIX, '--rejoin'],
                        cwd=project_root, check=False
                    )
                    # 최신 커밋의 해시 찾기
                    latest_commit, _ = run_command(
                        ['git', 'rev-parse', 'HEAD'],
                        cwd=project_root
                    )
                    # force push
                    run_command(
                        ['git', 'push', REMOTE_NAME, f'{latest_commit}:{BRANCH}', '--force'],
                        cwd=project_root
                    )
                    print_success("Subtree push 완료! (강제 push)")
                except Exception as e:
                    print_error(f"Subtree push 실패: {e}")
                    # 대체 방법: 직접 subtree push 시도
                    try:
                        run_command(
                            ['git', 'subtree', 'push', '--prefix', FOLDER_PREFIX, REMOTE_NAME, BRANCH, '--force'],
                            cwd=project_root, check=False
                        )
                    except:
                        pass
                sys.exit(0)
            else:
                # 대화형 모드: 사용자에게 물어봄
                response = input(f"{Colors.YELLOW}기존 커밋을 subtree push 하시겠습니까? (y/N): {Colors.RESET}").lower()
                if response == 'y':
                    ensure_remote(project_root)
                    print_step(f"Subtree push 중 ({REMOTE_NAME}/{BRANCH}) - 강제 push")
                    try:
                        # subtree split으로 분리 후 force push
                        split_output, _ = run_command(
                            ['git', 'subtree', 'split', '--prefix', FOLDER_PREFIX, '--rejoin'],
                            cwd=project_root, check=False
                        )
                        # 최신 커밋의 해시 찾기
                        latest_commit, _ = run_command(
                            ['git', 'rev-parse', 'HEAD'],
                            cwd=project_root
                        )
                        # force push
                        run_command(
                            ['git', 'push', REMOTE_NAME, f'{latest_commit}:{BRANCH}', '--force'],
                            cwd=project_root
                        )
                        print_success("Subtree push 완료! (강제 push)")
                    except Exception as e:
                        print_error(f"Subtree push 실패: {e}")
                        # 대체 방법: 직접 subtree push 시도
                        try:
                            run_command(
                                ['git', 'subtree', 'push', '--prefix', FOLDER_PREFIX, REMOTE_NAME, BRANCH, '--force'],
                                cwd=project_root, check=False
                            )
                        except:
                            pass
        sys.exit(0)

    print_success("변경사항 발견:")
    print(status_output)
    print()

    # 2. 커밋 메시지
    commit_message = None
    auto_mode = False
    
    if len(sys.argv) > 1:
        if sys.argv[1] == '--auto':
            auto_mode = True
            commit_message = "자동 커밋"
        else:
            commit_message = sys.argv[1]
    else:
        print(f"{Colors.YELLOW}커밋 메시지를 입력하세요:{Colors.RESET}")
        commit_message = input("> ")

    if not commit_message:
        print_error("커밋 메시지가 비어있습니다.")
        sys.exit(1)

    # 3. myxplanner/ 폴더만 스테이징
    print_step("플래너 스테이징")
    run_command(['git', 'add', f'{FOLDER_PREFIX}/'], cwd=project_root)
    print_success(f"스테이징 완료 ({FOLDER_PREFIX}/ 폴더만)")
    print()

    # 4. 모노레포에 커밋
    print_step("모노레포 커밋 생성")
    run_command(
        ['git', 'commit', '-m', f"[Planner] {commit_message}"],
        cwd=project_root
    )
    print_success(f"커밋 완료: [Planner] {commit_message}")
    print()

    # 5. Remote 확인/추가
    ensure_remote(project_root)

    # 6. Subtree push
    if auto_mode:
        print_step(f"자동 모드: Subtree push 중 ({REMOTE_NAME}/{BRANCH})")
    else:
        response = input(f"{Colors.YELLOW}v2_myxplanner 리포지토리에 Push하시겠습니까? (y/N): {Colors.RESET}").lower()
        if response != 'y':
            print_warning("Push를 취소했습니다. 커밋은 모노레포에 저장되었습니다.")
            sys.exit(0)

    print_step(f"Subtree push 중 ({REMOTE_NAME}/{BRANCH}) - 강제 push (로컬 우선)")
    try:
        subtree_branch = f'subtree-{FOLDER_PREFIX}'
        
        # 기존 subtree 브랜치가 있으면 삭제
        run_command(
            ['git', 'branch', '-D', subtree_branch],
            cwd=project_root, check=False
        )
        
        # subtree split으로 분리 및 브랜치 생성
        run_command(
            ['git', 'subtree', 'split', '--prefix', FOLDER_PREFIX, '-b', subtree_branch],
            cwd=project_root
        )
        
        # force push
        run_command(
            ['git', 'push', REMOTE_NAME, f'{subtree_branch}:{BRANCH}', '--force'],
            cwd=project_root
        )
        
        # 임시 브랜치 삭제
        run_command(
            ['git', 'branch', '-D', subtree_branch],
            cwd=project_root, check=False
        )
        print_success("Push 완료! (로컬 우선 강제 push)")
    except Exception as e:
        print_error(f"Subtree push 실패: {e}")
        # 대체 방법: 일반 subtree push 시도
        try:
            run_command(
                ['git', 'subtree', 'push', '--prefix', FOLDER_PREFIX, REMOTE_NAME, BRANCH],
                cwd=project_root
            )
            print_success("Push 완료!")
        except:
            print_error("모든 push 방법 실패")
            raise
    
    print(f"{Colors.GREEN}✓ {REMOTE_URL} 에 {FOLDER_PREFIX}/ 폴더가 push 되었습니다. (로컬 우선){Colors.RESET}")

if __name__ == '__main__':
    main()
