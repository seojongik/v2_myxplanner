#!/usr/bin/env python3
"""
전화번호 인증 상태 초기화 스크립트

모든 회원의 member_phone_auth를 빈값으로 초기화합니다.
테스트 목적으로 사용됩니다.

사용법:
    python reset_phone_auth.py          # 전체 초기화
    python reset_phone_auth.py --dry-run  # 미리보기 (실제 변경 없음)
    python reset_phone_auth.py --phone 010-1234-5678  # 특정 번호만 초기화
"""

import os
import sys
import argparse
from datetime import datetime

# Supabase 설정
SUPABASE_URL = "https://yejialakeivdhwntmagf.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InllamlhbGFrZWl2ZGh3bnRtYWdmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM5MTE0MjcsImV4cCI6MjA3OTQ4NzQyN30.a1WA6V7pD2tss1pkh1OSJcuknt6FTyeabvm9UzNjcfs"

try:
    from supabase import create_client, Client
except ImportError:
    print("❌ supabase 패키지가 설치되어 있지 않습니다.")
    print("   설치: pip install supabase")
    sys.exit(1)


def get_supabase_client() -> Client:
    """Supabase 클라이언트 생성"""
    return create_client(SUPABASE_URL, SUPABASE_KEY)


def get_verified_members(supabase: Client):
    """인증 완료된 회원 목록 조회"""
    response = supabase.table('v3_members').select(
        'member_id, member_name, member_phone, member_phone_auth, member_phone_auth_timestamp'
    ).eq('member_phone_auth', 'success').execute()
    
    return response.data


def get_all_members_with_phone(supabase: Client):
    """전화번호가 있는 모든 회원 조회"""
    response = supabase.table('v3_members').select(
        'member_id, member_name, member_phone, member_phone_auth, member_phone_auth_timestamp'
    ).neq('member_phone', '').not_.is_('member_phone', 'null').execute()
    
    return response.data


def reset_phone_auth(supabase: Client, phone: str = None, dry_run: bool = False):
    """
    전화번호 인증 상태 초기화
    
    Args:
        supabase: Supabase 클라이언트
        phone: 특정 전화번호만 초기화 (None이면 전체)
        dry_run: True면 실제 변경 없이 미리보기만
    """
    print("=" * 60)
    print("📱 전화번호 인증 상태 초기화")
    print("=" * 60)
    print(f"⏰ 실행 시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"🔧 모드: {'미리보기 (Dry Run)' if dry_run else '실제 실행'}")
    print()
    
    if phone:
        # 특정 번호만 초기화
        print(f"🎯 대상: {phone}")
        response = supabase.table('v3_members').select(
            'member_id, member_name, member_phone, member_phone_auth'
        ).eq('member_phone', phone).execute()
        targets = response.data
    else:
        # 인증 완료된 회원만 초기화 대상
        targets = get_verified_members(supabase)
        print(f"🎯 대상: 인증 완료된 전체 회원")
    
    print(f"📊 초기화 대상: {len(targets)}명")
    print()
    
    if not targets:
        print("✅ 초기화할 대상이 없습니다.")
        return
    
    # 대상 목록 출력
    print("┌─────────────────────────────────────────────────────────┐")
    print("│ 번호 │ 이름     │ 전화번호        │ 현재상태          │")
    print("├─────────────────────────────────────────────────────────┤")
    for i, member in enumerate(targets, 1):
        name = (member.get('member_name') or '').ljust(8)[:8]
        phone_num = (member.get('member_phone') or '').ljust(15)[:15]
        status = member.get('member_phone_auth') or '(없음)'
        print(f"│ {i:4} │ {name} │ {phone_num} │ {status:17} │")
    print("└─────────────────────────────────────────────────────────┘")
    print()
    
    if dry_run:
        print("🔍 Dry Run 모드: 실제 변경이 적용되지 않았습니다.")
        print("   실제 초기화를 하려면 --dry-run 옵션 없이 실행하세요.")
        return
    
    # 확인 프롬프트
    confirm = input(f"⚠️  {len(targets)}명의 인증 상태를 초기화하시겠습니까? (y/N): ")
    if confirm.lower() != 'y':
        print("❌ 취소되었습니다.")
        return
    
    # 초기화 실행
    print()
    print("🔄 초기화 진행 중...")
    
    success_count = 0
    fail_count = 0
    
    for member in targets:
        member_phone = member.get('member_phone')
        try:
            supabase.table('v3_members').update({
                'member_phone_auth': '',
                'member_phone_auth_timestamp': None
            }).eq('member_phone', member_phone).execute()
            
            success_count += 1
            print(f"  ✅ {member.get('member_name')} ({member_phone})")
        except Exception as e:
            fail_count += 1
            print(f"  ❌ {member.get('member_name')} ({member_phone}): {e}")
    
    print()
    print("=" * 60)
    print(f"✅ 완료: {success_count}명 성공, {fail_count}명 실패")
    print("=" * 60)


def show_status(supabase: Client):
    """현재 인증 상태 통계 표시"""
    all_members = get_all_members_with_phone(supabase)
    verified = [m for m in all_members if m.get('member_phone_auth') == 'success']
    not_verified = [m for m in all_members if m.get('member_phone_auth') != 'success']
    
    print("=" * 60)
    print("📊 전화번호 인증 현황")
    print("=" * 60)
    print(f"전화번호 보유 회원: {len(all_members)}명")
    print(f"  ✅ 인증 완료: {len(verified)}명")
    print(f"  ❌ 미인증: {len(not_verified)}명")
    print()
    
    if verified:
        print("📱 인증 완료 회원 목록:")
        for m in verified:
            ts = m.get('member_phone_auth_timestamp') or ''
            print(f"  • {m.get('member_name')} ({m.get('member_phone')}) - {ts}")
    print()


def main():
    parser = argparse.ArgumentParser(
        description='전화번호 인증 상태 초기화 스크립트',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
예시:
  python reset_phone_auth.py              # 인증된 전체 회원 초기화
  python reset_phone_auth.py --dry-run    # 미리보기 (변경 없음)
  python reset_phone_auth.py --phone 010-1234-5678  # 특정 번호만
  python reset_phone_auth.py --status     # 현재 상태 확인
        """
    )
    parser.add_argument('--dry-run', action='store_true', 
                        help='실제 변경 없이 미리보기만')
    parser.add_argument('--phone', type=str, 
                        help='특정 전화번호만 초기화 (예: 010-1234-5678)')
    parser.add_argument('--status', action='store_true',
                        help='현재 인증 상태 통계만 표시')
    
    args = parser.parse_args()
    
    # Supabase 연결
    try:
        supabase = get_supabase_client()
        print("✅ Supabase 연결 성공")
        print()
    except Exception as e:
        print(f"❌ Supabase 연결 실패: {e}")
        sys.exit(1)
    
    if args.status:
        show_status(supabase)
    else:
        reset_phone_auth(supabase, phone=args.phone, dry_run=args.dry_run)


if __name__ == '__main__':
    main()

