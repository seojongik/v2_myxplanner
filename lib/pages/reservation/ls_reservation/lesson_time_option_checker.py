#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
레슨 시간 옵션 제안 프로그램
세션 구성을 정의하면 가능한 시작시간 옵션들을 제안

필수 입력 항목:
- 지점 ID (branch_id): 예약할 지점의 고유 ID
- 회원 ID (member_id): 예약하는 회원의 고유 ID
- 예약 날짜 (selected_date): 예약 날짜 (YYYY-MM-DD 형식)
- 선택된 프로 ID (selected_instructor): 레슨을 받을 프로의 고유 ID
- 세션 계획 (session_plan): 세션별 레슨시간과 휴식시간을 정의한 배열
  예: [{'lesson_duration': 25, 'break_time': 15}, {'lesson_duration': 30, 'break_time': 0}]

예약 가능성 판단 조건:
1. 프로 정보 검증 조건
   - 프로 존재 확인: 선택된 프로 ID가 유효한지 확인
   - 근무시간 조회: 프로의 해당 날짜 근무시간 확인
   - 레슨 규칙 확인: 최소 레슨시간(min_service_min), 시간 단위(svc_time_unit) 확인

2. 잔여 레슨 검증 조건
   - 계약 유효성: 회원의 유효한 레슨 계약 존재 확인
   - 잔여 시간: 계약의 잔여 레슨시간이 필요한 레슨시간 이상인지 확인
   - 만료일: 계약의 만료일이 현재 날짜 이후인지 확인
   - 프로 매칭: 선택된 프로와 일치하는 계약인지 확인

3. 시간 슬롯 검증 조건
   - 근무시간 범위: 전체 세션이 프로의 근무시간 내에 완료되는지 확인
   - 기존 예약 충돌: 기존 예약된 시간과 겹치지 않는지 확인
   - 5분 단위 시작시간: 시작시간이 5분 단위인지 확인

4. 세션 계획 검증 조건
   - 최소 레슨시간: 각 세션이 최소 레슨시간 이상인지 확인
   - 시간 단위: 각 세션 시간이 올바른 시간 단위의 배수인지 확인
   - 연속성: 세션 간 휴식시간을 고려한 연속적인 시간 배치 확인

참고: 모든 API 호출에서 branch_id는 필수 파라미터로 사용됨
"""

import requests
import json
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple

# =============================================================================
# API 설정
# =============================================================================

class ApiConfig:
    BASE_URL = 'https://autofms.mycafe24.com/dynamic_api.php'
    HEADERS = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'LessonTimeOptionChecker/1.0'
    }

class ApiClient:
    @staticmethod
    def call_api(operation: str, table: str, **kwargs) -> Dict[str, Any]:
        """API 호출"""
        request_data = {
            'operation': operation,
            'table': table,
            **kwargs
        }
        
        try:
            response = requests.post(
                ApiConfig.BASE_URL,
                headers=ApiConfig.HEADERS,
                json=request_data,
                timeout=10
            )
            
            if response.status_code == 200:
                result = response.json()
                return result
            else:
                return {'success': False, 'error': f'HTTP {response.status_code}'}
                
        except Exception as e:
            return {'success': False, 'error': str(e)}

# =============================================================================
# 레슨 시간 옵션 체커 클래스
# =============================================================================

class LessonTimeOptionChecker:
    def __init__(self):
        self.api_client = ApiClient()
        
    def find_available_time_options(self, branch_id: str, member_id: str, selected_date: str, 
                                  selected_instructor: str, session_plan: List[Dict]) -> Dict[str, Any]:
        """
        세션 계획에 따른 가능한 시작시간 옵션 찾기
        
        Args:
            branch_id: 지점 ID
            member_id: 회원 ID
            selected_date: 선택된 날짜 (YYYY-MM-DD)
            selected_instructor: 선택된 프로 ID
            session_plan: 세션 계획 [{'lesson_duration': 25, 'break_time': 15}, ...]
            
        Returns:
            Dict: 가능한 시작시간 옵션들
        """
        try:
            print(f"\n🔍 레슨 시간 옵션 검색 시작")
            print(f"📍 지점 ID: {branch_id}")
            print(f"👤 회원 ID: {member_id}")
            print(f"📅 선택 날짜: {selected_date}")
            print(f"👨‍🏫 선택 프로: {selected_instructor}")
            print("="*60)
            
            # 1. 모든 필요한 데이터를 한 번에 수집
            print("\n📦 필요한 데이터 수집 중...")
            all_data = self._fetch_all_lesson_data(branch_id, member_id, selected_date, selected_instructor, session_plan)
            if not all_data['success']:
                return all_data
            
            # 2. 수집된 데이터를 사용해서 시간 옵션 처리
            print("\n🔄 시간 옵션 처리 중...")
            time_slots_result = self._process_lesson_time_options_locally(all_data, session_plan)
            
            total_duration = self._calculate_total_session_duration(session_plan)
            
            return {
                'success': True,
                'session_plan': session_plan,
                'total_duration': total_duration,
                'available_options': time_slots_result['available'],
                'unavailable_options': time_slots_result['unavailable'],
                'pro_info': all_data['pro_info_formatted'],
                'work_schedule': all_data['work_schedule_formatted'],
                'remaining_lessons': all_data['remaining_lesson_result']
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': f'시간 옵션 검색 중 오류 발생: {str(e)}'
            }
    
    def _calculate_total_session_duration(self, session_plan: List[Dict]) -> int:
        """전체 세션 소요 시간 계산"""
        total = 0
        for i, session in enumerate(session_plan):
            total += session['lesson_duration']
            if i < len(session_plan) - 1:  # 마지막 세션이 아닌 경우
                total += session['break_time']
        return total
    
    def _find_time_slots(self, work_start: str, work_end: str, reservations: List[Dict], 
                        total_duration: int, pro_info: Dict, session_plan: List[Dict]) -> Dict[str, Any]:
        """가능한 시간대 찾기"""
        work_start_minutes = self._time_to_minutes(work_start)
        work_end_minutes = self._time_to_minutes(work_end)
        min_service_min = int(pro_info.get('min_service_min', 30))
        svc_time_unit = int(pro_info.get('svc_time_unit', 5))
        
        # 예약된 시간들을 분 단위로 변환
        blocked_periods = []
        for reservation in reservations:
            start_min = self._time_to_minutes(reservation['LS_start_time'])
            end_min = self._time_to_minutes(reservation['LS_end_time'])
            blocked_periods.append((start_min, end_min))
        
        # 가능한 시간과 불가능한 시간 분류
        available_options = []
        unavailable_options = []
        
        # 5분 단위로 시작시간 후보 생성
        for start_candidate in range(work_start_minutes, work_end_minutes - total_duration + 1, 5):
            end_candidate = start_candidate + total_duration
            
            # 불가능한 이유 체크
            unavailable_reason = None
            
            # 근무시간 내에 완료되는지 확인
            if end_candidate > work_end_minutes:
                unavailable_reason = f"근무시간 종료 ({self._minutes_to_time(work_end_minutes)}) 이후까지 연장됨"
            
            # 기존 예약과 겹치는지 확인
            if not unavailable_reason:
                for blocked_start, blocked_end in blocked_periods:
                    if start_candidate < blocked_end and end_candidate > blocked_start:
                        unavailable_reason = f"기존 예약과 겹침 ({self._minutes_to_time(blocked_start)}~{self._minutes_to_time(blocked_end)})"
                        break
            
            # 각 세션이 유효한지 확인
            if not unavailable_reason:
                current_time = start_candidate
                session_details = []
                
                for i, session in enumerate(session_plan):
                    session_start = current_time
                    session_end = current_time + session['lesson_duration']
                    
                    # 세션 시간이 최소 단위를 만족하는지 확인
                    if session['lesson_duration'] < min_service_min:
                        unavailable_reason = f"세션 {i+1}이 최소 레슨시간({min_service_min}분) 미만"
                        break
                    
                    # 세션 시간이 올바른 단위인지 확인
                    if (session['lesson_duration'] - min_service_min) % svc_time_unit != 0:
                        unavailable_reason = f"세션 {i+1}이 올바른 시간 단위({svc_time_unit}분)가 아님"
                        break
                    
                    session_details.append({
                        'session_number': i + 1,
                        'start_time': self._minutes_to_time(session_start),
                        'end_time': self._minutes_to_time(session_end),
                        'lesson_duration': session['lesson_duration'],
                        'break_time': session['break_time'] if i < len(session_plan) - 1 else 0
                    })
                    
                    current_time = session_end + (session['break_time'] if i < len(session_plan) - 1 else 0)
                
                if not unavailable_reason:
                    # 시작시간이 적절한 단위인지 확인 (5분 단위)
                    if start_candidate % 5 == 0:
                        available_options.append({
                            'start_time': self._minutes_to_time(start_candidate),
                            'end_time': self._minutes_to_time(end_candidate),
                            'total_duration': total_duration,
                            'session_details': session_details
                        })
            
            # 불가능한 시간대 기록 (5분 단위만)
            if unavailable_reason and start_candidate % 5 == 0:
                unavailable_options.append({
                    'start_time': self._minutes_to_time(start_candidate),
                    'end_time': self._minutes_to_time(end_candidate),
                    'reason': unavailable_reason
                })
        
        return {
            'available': available_options,
            'unavailable': unavailable_options
        }
    
    def _calculate_option_score(self, start_time: int, work_start: int, work_end: int) -> float:
        """점수 계산 로직 제거됨"""
        return 0.0
    
    def _check_remaining_lessons(self, branch_id: str, member_id: str, 
                               selected_instructor: str, session_plan: List[Dict]) -> Dict[str, Any]:
        """잔여 레슨 체크"""
        try:
            # 전체 필요한 레슨 시간 계산
            total_lesson_time = sum(session['lesson_duration'] for session in session_plan)
            
            # 회원의 레슨 카운팅 데이터 조회
            response = self.api_client.call_api(
                operation='get',
                table='v3_LS_countings',
                fields=['pro_id', 'LS_balance_min_after', 'LS_expiry_date', 'LS_contract_id', 'LS_counting_id'],
                where=[
                    {'field': 'branch_id', 'operator': '=', 'value': branch_id},
                    {'field': 'member_id', 'operator': '=', 'value': member_id},
                    {'field': 'LS_balance_min_after', 'operator': '>', 'value': '0'},
                ]
            )
            
            if not response.get('success'):
                return {
                    'success': False,
                    'error': '회원의 레슨 계약 정보를 조회할 수 없습니다.'
                }
            
            lesson_data = response.get('data', [])
            
            # 만료일 체크
            today = datetime.now().strftime('%Y-%m-%d')
            valid_records = []
            for record in lesson_data:
                expiry_date = record.get('LS_expiry_date', '')
                if expiry_date and expiry_date >= today:
                    valid_records.append(record)
            
            if not valid_records:
                return {
                    'success': False,
                    'error': '유효한 레슨 계약이 없습니다.'
                }
            
            # 선택된 프로의 유효한 계약 필터링
            valid_contracts = []
            for contract in valid_records:
                contract_pro_id = str(contract.get('pro_id', ''))
                balance_min = int(contract.get('LS_balance_min_after', 0))
                
                if contract_pro_id == selected_instructor and balance_min > 0:
                    contract_info = {
                        'contract_id': contract.get('LS_contract_id', ''),
                        'counting_id': contract.get('LS_counting_id', ''),
                        'balance_min': balance_min,
                        'expiry_date': contract.get('LS_expiry_date', ''),
                        'sufficient': balance_min >= total_lesson_time
                    }
                    valid_contracts.append(contract_info)
            
            if not valid_contracts:
                pro_info = self._get_pro_info(selected_instructor)
                pro_name = pro_info.get('pro_name', f'프로 {selected_instructor}') if pro_info else f'프로 {selected_instructor}'
                
                return {
                    'success': False,
                    'error': f'{pro_name}의 잔여 레슨시간이 부족합니다.'
                }
            
            # 사용 가능한 계약이 있는지 확인
            sufficient_contracts = [c for c in valid_contracts if c['sufficient']]
            
            if not sufficient_contracts:
                pro_info = self._get_pro_info(selected_instructor)
                pro_name = pro_info.get('pro_name', f'프로 {selected_instructor}') if pro_info else f'프로 {selected_instructor}'
                
                return {
                    'success': False,
                    'error': f'{pro_name}의 잔여 레슨시간이 부족합니다. 필요: {total_lesson_time}분'
                }
            
            return {
                'success': True,
                'total_lesson_time': total_lesson_time,
                'valid_contracts': valid_contracts,
                'sufficient_contracts': sufficient_contracts
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': f'잔여 레슨 체크 중 오류 발생: {str(e)}'
            }
    
    def _get_pro_info(self, pro_id: str) -> Optional[Dict[str, Any]]:
        """프로 정보 조회"""
        try:
            response = self.api_client.call_api(
                operation='get',
                table='v2_staff_pro',
                where=[
                    {'field': 'pro_id', 'operator': '=', 'value': pro_id}
                ]
            )
            
            if response.get('success') and response.get('data'):
                return response['data'][0]
            else:
                return None
                
        except Exception as e:
            return None
    
    def _get_pro_schedule(self, pro_id: str, date: str) -> Dict[str, Any]:
        """프로 스케줄 조회"""
        try:
            response = self.api_client.call_api(
                operation='get',
                table='v2_weekly_schedule_pro',
                where=[
                    {'field': 'pro_id', 'operator': '=', 'value': pro_id},
                    {'field': 'schedule_date', 'operator': '=', 'value': date}
                ]
            )
            
            if response.get('success') and response.get('data'):
                return response['data'][0]
            else:
                return {
                    'work_start': '09:00:00',
                    'work_end': '18:00:00',
                    'is_day_off': None
                }
                
        except Exception as e:
            return {
                'work_start': '09:00:00',
                'work_end': '18:00:00',
                'is_day_off': None
            }
    
    def _get_existing_reservations(self, pro_id: str, date: str) -> List[Dict[str, Any]]:
        """기존 예약 조회"""
        try:
            response = self.api_client.call_api(
                operation='get',
                table='v2_LS_orders',
                where=[
                    {'field': 'pro_id', 'operator': '=', 'value': pro_id},
                    {'field': 'LS_date', 'operator': '=', 'value': date}
                ],
                orderBy=[
                    {'field': 'LS_start_time', 'direction': 'ASC'}
                ]
            )
            
            if response.get('success') and response.get('data'):
                return response['data']
            else:
                return []
                
        except Exception as e:
            return []
    
    def _time_to_minutes(self, time_str: str) -> int:
        """시간 문자열을 분 단위로 변환"""
        parts = time_str.split(':')
        hour = int(parts[0])
        minute = int(parts[1])
        return hour * 60 + minute
    
    def _minutes_to_time(self, minutes: int) -> str:
        """분을 시간 문자열로 변환"""
        hour = minutes // 60
        minute = minutes % 60
        return f"{hour:02d}:{minute:02d}"

# =============================================================================
# 메인 실행 부분
# =============================================================================

def main():
    """메인 함수"""
    try:
        # 초기 설정
        checker = LessonTimeOptionChecker()
        
        # 입력 받기
        branch_id = input("지점 ID를 입력하세요: ")
        member_id = input("회원 ID를 입력하세요: ")
        selected_date = input("날짜를 입력하세요 (YYYY-MM-DD): ")
        selected_instructor = input("프로 ID를 입력하세요: ")
        
        # 세션 계획 입력
        session_count = int(input("세션 수를 입력하세요: "))
        session_plan = []
        
        for i in range(session_count):
            lesson_duration = int(input(f"세션 {i+1} 레슨 시간을 입력하세요 (분): "))
            
            if i < session_count - 1:  # 마지막 세션이 아닌 경우에만 휴식시간 입력
                break_time = int(input(f"세션 {i+1} 후 휴식시간을 입력하세요 (분): "))
            else:
                break_time = 0
            
            session_plan.append({
                'lesson_duration': lesson_duration,
                'break_time': break_time
            })
        
        # 시간 옵션 검색
        result = checker.find_available_time_options(
            branch_id=branch_id,
            member_id=member_id,
            selected_date=selected_date,
            selected_instructor=selected_instructor,
            session_plan=session_plan
        )
        
        # 결과 출력
        print("\n" + "="*60)
        print("레슨 시간 옵션 검색 결과")
        print("="*60)
        
        if not result['success']:
            print(f"❌ 오류: {result['error']}")
            return
        
        # 세션 계획 요약
        print(f"\n📋 세션 계획:")
        total_lesson_time = sum(session['lesson_duration'] for session in session_plan)
        for i, session in enumerate(session_plan):
            print(f"  세션 {i+1}: {session['lesson_duration']}분", end="")
            if session['break_time'] > 0:
                print(f" + 휴식 {session['break_time']}분")
            else:
                print()
        print(f"  총 소요시간: {result['total_duration']}분 (레슨: {total_lesson_time}분)")
        
        # 프로 정보
        pro_info = result['pro_info']
        print(f"\n👨‍🏫 프로 정보:")
        print(f"  이름: {pro_info['name']}")
        print(f"  근무시간: {result['work_schedule']['start']} ~ {result['work_schedule']['end']}")
        print(f"  최소 레슨시간: {pro_info['min_service_min']}분")
        print(f"  레슨시간 단위: {pro_info['svc_time_unit']}분")
        print(f"  시작시간 선택 단위: 5분")
        
        # 잔여 레슨 정보
        remaining = result['remaining_lessons']
        print(f"\n💳 잔여 레슨 계약:")
        print(f"  필요한 레슨시간: {remaining['total_lesson_time']}분")
        print(f"  사용 가능한 계약:")
        
        for i, contract in enumerate(remaining['valid_contracts']):
            status = "✅ 사용가능" if contract['sufficient'] else "❌ 시간부족"
            print(f"    계약 {i+1}: {contract['balance_min']}분 (만료: {contract['expiry_date']}) {status}")
            print(f"      계약ID: {contract['contract_id']}, 카운팅ID: {contract['counting_id']}")
        
        sufficient_count = len(remaining['sufficient_contracts'])
        print(f"  → 사용 가능한 계약: {sufficient_count}개")
        
        # 가능한 시간 옵션들
        available_options = result['available_options']
        unavailable_options = result['unavailable_options']
        
        print(f"\n🕐 예약 시간 분석:")
        print(f"  전체 검토 시간대: {len(available_options) + len(unavailable_options)}개")
        print(f"  예약 가능: {len(available_options)}개")
        print(f"  예약 불가: {len(unavailable_options)}개")
        
        # 최초 예약 가능시간
        if available_options:
            first_option = available_options[0]
            print(f"\n✅ 최초 예약 가능시간: {first_option['start_time']} ~ {first_option['end_time']}")
            for session in first_option['session_details']:
                print(f"    세션 {session['session_number']}: {session['start_time']} ~ {session['end_time']} ({session['lesson_duration']}분)")
                if session['break_time'] > 0:
                    print(f"      휴식: {session['break_time']}분")
        
        # 예약 불가능한 시간대들
        if unavailable_options:
            print(f"\n❌ 예약 불가능한 시간대:")
            for i, option in enumerate(unavailable_options[:20]):  # 최대 20개만 표시
                print(f"  {option['start_time']} ~ {option['end_time']}: {option['reason']}")
                if i >= 19 and len(unavailable_options) > 20:
                    print(f"  ... 외 {len(unavailable_options) - 20}개 시간대")
                    break
        
        # 마지막 예약 가능시간
        if available_options and len(available_options) > 1:
            last_option = available_options[-1]
            print(f"\n✅ 마지막 예약 가능시간: {last_option['start_time']} ~ {last_option['end_time']}")
            for session in last_option['session_details']:
                print(f"    세션 {session['session_number']}: {session['start_time']} ~ {session['end_time']} ({session['lesson_duration']}분)")
                if session['break_time'] > 0:
                    print(f"      휴식: {session['break_time']}분")
        
        # 모든 가능한 시간대 요약
        if available_options:
            print(f"\n📋 모든 예약 가능시간:")
            for i, option in enumerate(available_options):
                print(f"  {i+1}. {option['start_time']} ~ {option['end_time']}")
        
    except Exception as e:
        print(f"오류 발생: {e}")

if __name__ == '__main__':
    main() 