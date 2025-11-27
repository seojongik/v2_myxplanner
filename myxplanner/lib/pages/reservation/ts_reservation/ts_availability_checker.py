#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
타석 예약 가능성 검증 도구
Flutter 앱의 타석 예약 로직을 Python으로 구현하여 예약 가능 여부를 터미널에서 확인

필수 입력 항목:
- 지점 ID (branch_id): 예약할 지점의 고유 ID
- 회원 ID (member_id): 예약하는 회원의 고유 ID
- 타석 ID (ts_id): 예약할 타석의 고유 ID
- 예약 날짜 (selected_date): 예약 날짜 (YYYY-MM-DD 형식)
- 시작 시간 (start_time): 예약 시작 시간 (HH:MM 형식)
- 연습 시간 (duration_minutes): 연습 시간 (분 단위)

예약 가능성 검증 조건:
1. 기본 정보 검증
   - 필수 입력값 존재 확인: 모든 필수 입력값이 누락되지 않았는지 확인
   - 날짜 형식 검증: YYYY-MM-DD 형식의 유효한 날짜인지 확인
   - 시간 형식 검증: HH:MM 형식의 유효한 시간인지 확인
   - 과거 날짜 검증: 과거 날짜 예약 방지

2. 날짜 및 영업시간 검증
   - 영업 스케줄 조회: 해당 날짜의 영업시간 확인
   - 휴무일 확인: 해당 날짜가 휴무일인지 확인
   - 영업시간 내 예약 확인: 예약 시간이 영업시간 범위 내인지 확인
   - 당일 예약 시간 제한: 오늘 날짜는 현재 시간 이후로만 예약 가능

3. 타석 정보 및 상태 검증
   - 타석 존재 확인: 해당 타석이 존재하는지 확인
   - 타석 상태 확인: 타석 상태가 '예약가능' 상태인지 확인
   - 최소/최대 이용시간 확인: 연습시간이 타석별 최소/최대 시간 범위 내인지 확인
   - 타석 버퍼 시간 적용: 타석별 버퍼 시간 정보 확인

4. 회원 타입 제한 검증
   - 회원 정보 조회: 회원의 타입 정보 확인
   - 타석 이용 제한 확인: 해당 타석의 회원 타입 제한 규칙 확인
   - 제한 회원 타입 매칭: 회원 타입이 타석 제한 목록에 포함되지 않는지 확인

5. 시간 겹침 검증 (핵심 검증)
   - 기존 예약 조회: 해당 날짜 타석의 기존 예약 시간 조회
   - 시간 겹침 계산: 요청 시간과 기존 예약 시간의 겹침 여부 확인
   - 버퍼 시간 적용: 타석별 버퍼 시간을 고려한 시간 겹침 검사

6. 시간권 계약 검증
   - 회원 시간권 조회: 회원의 모든 시간권 계약 조회
   - 잔액 확인: 계약별 잔여 시간 확인
   - 유효기간 확인: 계약의 유효기간 확인
   - 사용 가능한 계약 필터링: 잔액 충분 및 유효기간 내 계약 선별

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
        'User-Agent': 'TsAvailabilityChecker/1.0'
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
# 타석 예약 가능성 검증 클래스
# =============================================================================

class TsAvailabilityChecker:
    def __init__(self):
        self.api_client = ApiClient()
        
    def check_ts_availability(self, branch_id: str, member_id: str, ts_id: str, 
                            selected_date: str, start_time: str, duration_minutes: int) -> Dict[str, Any]:
        """
        타석 예약 가능성 종합 검증
        
        Args:
            branch_id: 지점 ID
            member_id: 회원 ID
            ts_id: 타석 ID
            selected_date: 선택된 날짜 (YYYY-MM-DD)
            start_time: 시작시간 (HH:MM)
            duration_minutes: 연습시간 (분)
            
        Returns:
            Dict: 종합 검증 결과
        """
        try:
            print("="*60)
            print("🏌️  타석 예약 가능성 검증 시작")
            print("="*60)
            print(f"📍 지점 ID: {branch_id}")
            print(f"👤 회원 ID: {member_id}")
            print(f"🎯 타석 ID: {ts_id}")
            print(f"📅 예약 날짜: {selected_date}")
            print(f"⏰ 시작 시간: {start_time}")
            print(f"⏱️  연습 시간: {duration_minutes}분")
            print("="*60)
            
            # 1. 기본 정보 검증
            print("\n🔍 1단계: 기본 정보 검증")
            basic_validation = self._validate_basic_info(
                branch_id, member_id, ts_id, selected_date, start_time, duration_minutes
            )
            if not basic_validation['success']:
                return basic_validation
            print("✅ 기본 정보 검증 통과")
            
            # 2. 날짜 및 영업시간 검증
            print("\n🔍 2단계: 날짜 및 영업시간 검증")
            schedule_validation = self._validate_schedule(selected_date, start_time, duration_minutes, branch_id)
            if not schedule_validation['success']:
                return schedule_validation
            print("✅ 날짜 및 영업시간 검증 통과")
            
            # 3. 타석 정보 및 상태 검증
            print("\n🔍 3단계: 타석 정보 및 상태 검증")
            ts_validation = self._validate_ts_info(ts_id, duration_minutes, branch_id)
            if not ts_validation['success']:
                return ts_validation
            print("✅ 타석 정보 및 상태 검증 통과")
            
            # 4. 회원 타입 제한 검증
            print("\n🔍 4단계: 회원 타입 제한 검증")
            member_validation = self._validate_member_restrictions(member_id, ts_validation['ts_info'], branch_id)
            if not member_validation['success']:
                return member_validation
            print("✅ 회원 타입 제한 검증 통과")
            
            # 5. 시간 겹침 검증 (핵심 검증)
            print("\n🔍 5단계: 시간 겹침 검증 (핵심)")
            time_conflict_validation = self._validate_time_conflicts(
                ts_id, selected_date, start_time, duration_minutes, ts_validation['ts_info'], branch_id
            )
            time_conflict_success = time_conflict_validation['success']
            if time_conflict_success:
                print("✅ 시간 겹침 검증 통과")
            else:
                print("❌ 시간 겹침 발견 (계속 진행)")
            
            # 6. 회원의 시간권 계약 조회 및 검증 (시간 겹침과 무관하게 실행)
            print("\n🔍 6단계: 회원 시간권 계약 조회 및 검증")
            contract_validation = self._validate_member_time_pass_contracts(
                member_id, duration_minutes, selected_date, branch_id
            )
            # 시간권이 없어도 다른 결제 방법이 있을 수 있으므로 오류로 처리하지 않음
            print("✅ 회원 시간권 계약 조회 완료")
            
            # 시간 겹침이 있으면 최종 결과를 실패로 처리
            if not time_conflict_success:
                return {
                    'success': False,
                    'error': time_conflict_validation['error'],
                    'details': time_conflict_validation.get('details', {}),
                    'validation_details': {
                        'ts_id': ts_id,
                        'date': selected_date,
                        'start_time': start_time,
                        'end_time': self._calculate_end_time(start_time, duration_minutes),
                        'duration_minutes': duration_minutes,
                        'schedule_info': schedule_validation.get('schedule_info', {}),
                        'ts_info': ts_validation.get('ts_info', {}),
                        'member_info': member_validation.get('member_info', {}),
                        'availability_info': time_conflict_validation.get('availability_info', {}),
                        'time_pass_contracts': contract_validation.get('time_pass_contracts', {}) if contract_validation else {}
                    }
                }
            
            # 모든 검증 통과
            end_time = self._calculate_end_time(start_time, duration_minutes)
            
            return {
                'success': True,
                'message': f'🎉 타석 예약이 가능합니다!',
                'validation_details': {
                    'ts_id': ts_id,
                    'date': selected_date,
                    'start_time': start_time,
                    'end_time': end_time,
                    'duration_minutes': duration_minutes,
                    'all_checks_passed': True,
                    'schedule_info': schedule_validation.get('schedule_info', {}),
                    'ts_info': ts_validation.get('ts_info', {}),
                    'member_info': member_validation.get('member_info', {}),
                    'availability_info': time_conflict_validation.get('availability_info', {}),
                    'time_pass_contracts': contract_validation.get('time_pass_contracts', {}) if contract_validation else {}
                }
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': f'검증 중 오류 발생: {str(e)}'
            }
    
    def _validate_basic_info(self, branch_id: str, member_id: str, ts_id: str, 
                           selected_date: str, start_time: str, duration_minutes: int) -> Dict[str, Any]:
        """기본 정보 검증"""
        try:
            # 필수 정보 존재 여부 확인
            if not all([branch_id, member_id, ts_id, selected_date, start_time]):
                return {
                    'success': False,
                    'error': '필수 정보가 누락되었습니다 (지점ID, 회원ID, 타석ID, 날짜, 시간)',
                    'details': {
                        'branch_id': branch_id,
                        'member_id': member_id,
                        'ts_id': ts_id,
                        'date': selected_date,
                        'time': start_time
                    }
                }
            
            # 날짜 형식 검증
            try:
                selected_datetime = datetime.strptime(selected_date, '%Y-%m-%d')
            except ValueError:
                return {
                    'success': False,
                    'error': '날짜 형식이 올바르지 않습니다. (YYYY-MM-DD 형식 사용)'
                }
            
            # 시간 형식 검증
            try:
                datetime.strptime(start_time, '%H:%M')
            except ValueError:
                return {
                    'success': False,
                    'error': '시간 형식이 올바르지 않습니다. (HH:MM 형식 사용)'
                }
            
            # 연습시간 검증
            if not isinstance(duration_minutes, int) or duration_minutes <= 0:
                return {
                    'success': False,
                    'error': '연습시간은 양의 정수여야 합니다.'
                }
            
            # 과거 날짜 검증
            today = datetime.now().date()
            if selected_datetime.date() < today:
                return {
                    'success': False,
                    'error': '과거 날짜는 예약할 수 없습니다.'
                }
            
            return {'success': True}
            
        except Exception as e:
            return {
                'success': False,
                'error': f'기본 정보 검증 중 오류: {str(e)}'
            }
    
    def _validate_schedule(self, selected_date: str, start_time: str, duration_minutes: int, branch_id: str) -> Dict[str, Any]:
        """날짜 및 영업시간 검증"""
        try:
            # 선택된 날짜의 스케줄 정보 조회
            date_obj = datetime.strptime(selected_date, '%Y-%m-%d')
            
            response = self.api_client.call_api(
                operation='get',
                table='v2_schedule_adjusted_ts',
                where=[
                    {'field': 'ts_date', 'operator': '=', 'value': selected_date},
                    {'field': 'branch_id', 'operator': '=', 'value': branch_id}
                ]
            )
            
            if not response.get('success') or not response.get('data'):
                return {
                    'success': False,
                    'error': f'{selected_date}의 영업 스케줄 정보를 찾을 수 없습니다.'
                }
            
            schedule_info = response['data'][0]
            
            # 휴무일 확인
            if schedule_info.get('is_holiday') == 'close':
                return {
                    'success': False,
                    'error': f'{selected_date}은 휴무일입니다.',
                    'schedule_info': schedule_info
                }
            
            # 영업시간 확인
            business_start = schedule_info.get('business_start')
            business_end = schedule_info.get('business_end')
            
            if not business_start or not business_end:
                return {
                    'success': False,
                    'error': '영업시간 정보가 설정되지 않았습니다.',
                    'schedule_info': schedule_info
                }
            
            # 시간 범위 검증
            start_minutes = self._time_to_minutes(start_time)
            business_start_minutes = self._time_to_minutes(business_start)
            business_end_minutes = self._time_to_minutes(business_end)
            
            # 00:00인 경우 24:00(1440분)으로 처리
            if business_end_minutes == 0:
                business_end_minutes = 1440
            
            end_minutes = start_minutes + duration_minutes
            
            if start_minutes < business_start_minutes:
                return {
                    'success': False,
                    'error': f'시작시간({start_time})이 영업시작시간({business_start}) 이전입니다.',
                    'schedule_info': schedule_info
                }
            
            if end_minutes > business_end_minutes:
                end_time = self._calculate_end_time(start_time, duration_minutes)
                business_end_display = business_end if business_end != '00:00' else '24:00'
                return {
                    'success': False,
                    'error': f'종료시간({end_time})이 영업종료시간({business_end_display}) 이후입니다.',
                    'schedule_info': schedule_info
                }
            
            # 오늘 날짜인 경우 현재 시간 이후 검증
            today = datetime.now().date()
            if date_obj.date() == today:
                now = datetime.now()
                current_minutes = now.hour * 60 + now.minute
                
                # 현재 시간을 5분 단위로 올림 처리
                adjusted_minutes = ((current_minutes / 5) + 1) * 5
                if adjusted_minutes >= 1440:
                    adjusted_minutes = 1439  # 23:59로 제한
                
                if start_minutes < adjusted_minutes:
                    current_time_adjusted = f"{int(adjusted_minutes // 60):02d}:{int(adjusted_minutes % 60):02d}"
                    return {
                        'success': False,
                        'error': f'오늘 날짜는 현재 시간({current_time_adjusted}) 이후로만 예약 가능합니다.',
                        'schedule_info': schedule_info
                    }
            
            return {
                'success': True,
                'schedule_info': schedule_info
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': f'스케줄 검증 중 오류: {str(e)}'
            }
    
    def _validate_ts_info(self, ts_id: str, duration_minutes: int, branch_id: str = None) -> Dict[str, Any]:
        """타석 정보 및 상태 검증"""
        try:
            # 타석 정보 조회 (ts_buffer 포함)
            where_conditions = [
                {'field': 'ts_id', 'operator': '=', 'value': ts_id}
            ]
            if branch_id:
                where_conditions.append({'field': 'branch_id', 'operator': '=', 'value': branch_id})
            
            response = self.api_client.call_api(
                operation='get',
                table='v2_ts_info',
                fields=['ts_id', 'ts_status', 'ts_min_minimum', 'ts_min_maximum', 'ts_buffer', 'member_type_prohibited'],
                where=where_conditions
            )
            
            if not response.get('success') or not response.get('data'):
                return {
                    'success': False,
                    'error': f'타석 {ts_id}의 정보를 찾을 수 없습니다.'
                }
            
            ts_info = response['data'][0]
            
            print(f"   🎯 타석 상태: {ts_info.get('ts_status', 'N/A')}")
            print(f"   ⏱️  최소 이용시간: {ts_info.get('ts_min_minimum', 0)}분")
            print(f"   ⏱️  최대 이용시간: {ts_info.get('ts_min_maximum', 999)}분")
            print(f"   🔄 버퍼 시간: {ts_info.get('ts_buffer', 0)}분")
            print(f"   🚫 제한 회원 타입: {ts_info.get('member_type_prohibited', '없음')}")
            
            # 타석 상태 확인
            if ts_info.get('ts_status') == '예약중지':
                return {
                    'success': False,
                    'error': f'타석 {ts_id}는 현재 예약이 중지된 상태입니다.',
                    'ts_info': ts_info
                }
            
            # 최소/최대 시간 확인
            min_minimum = float(ts_info.get('ts_min_minimum', 0))
            min_maximum = float(ts_info.get('ts_min_maximum', 999))
            
            if duration_minutes < min_minimum:
                return {
                    'success': False,
                    'error': f'타석 {ts_id}의 최소 이용시간은 {int(min_minimum)}분입니다. (요청: {duration_minutes}분)',
                    'ts_info': ts_info
                }
            
            if duration_minutes > min_maximum:
                return {
                    'success': False,
                    'error': f'타석 {ts_id}의 최대 이용시간은 {int(min_maximum)}분입니다. (요청: {duration_minutes}분)',
                    'ts_info': ts_info
                }
            
            return {
                'success': True,
                'ts_info': ts_info
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': f'타석 정보 검증 중 오류: {str(e)}'
            }
    
    def _validate_member_restrictions(self, member_id: str, ts_info: Dict[str, Any], branch_id: str) -> Dict[str, Any]:
        """회원 타입 제한 검증"""
        try:
            # 회원 타입 조회
            response = self.api_client.call_api(
                operation='get',
                table='v3_members',
                fields=['member_id', 'member_type'],
                where=[
                    {'field': 'member_id', 'operator': '=', 'value': member_id},
                    {'field': 'branch_id', 'operator': '=', 'value': branch_id}
                ]
            )
            
            if not response.get('success') or not response.get('data'):
                return {
                    'success': False,
                    'error': f'회원 {member_id}의 정보를 찾을 수 없습니다.'
                }
            
            member_info = response['data'][0]
            member_type = member_info.get('member_type', '')
            
            print(f"   👤 회원 타입: {member_type}")
            
            # 타석의 회원 타입 제한 확인
            member_type_prohibited = ts_info.get('member_type_prohibited', '')
            print(f"   🚫 타석 제한 회원 타입: {member_type_prohibited}")
            
            if member_type_prohibited and member_type:
                prohibited_types = [t.strip() for t in member_type_prohibited.split(',')]
                print(f"   🔍 제한 타입 목록: {prohibited_types}")
                
                if member_type in prohibited_types:
                    return {
                        'success': False,
                        'error': f'타석 {ts_info["ts_id"]}는 {member_type} 회원 타입의 이용이 제한됩니다.',
                        'details': {
                            'member_type': member_type,
                            'prohibited_types': prohibited_types,
                            'restriction_reason': f'회원 타입 "{member_type}"이 타석 제한 목록 {prohibited_types}에 포함됨'
                        },
                        'member_info': member_info
                    }
                else:
                    print(f"   ✅ 회원 타입 {member_type}은 제한 목록에 없음")
            else:
                print(f"   ℹ️ 타석 이용 제한 없음")
            
            return {
                'success': True,
                'member_info': member_info
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': f'회원 제한 검증 중 오류: {str(e)}'
            }
    
    def _validate_time_conflicts(self, ts_id: str, selected_date: str, start_time: str, 
                               duration_minutes: int, ts_info: Dict[str, Any], branch_id: str) -> Dict[str, Any]:
        """시간 겹침 검증 (핵심 검증)"""
        try:
            # 해당 날짜의 타석 예약 조회
            response = self.api_client.call_api(
                operation='get',
                table='v2_priced_TS',
                fields=['ts_start', 'ts_end'],
                where=[
                    {'field': 'ts_id', 'operator': '=', 'value': ts_id},
                    {'field': 'ts_date', 'operator': '=', 'value': selected_date},
                    {'field': 'branch_id', 'operator': '=', 'value': branch_id}
                ],
                orderBy=[
                    {'field': 'ts_start', 'direction': 'ASC'}
                ]
            )
            
            existing_reservations = []
            if response.get('success') and response.get('data'):
                existing_reservations = response['data']
            
            # 요청된 예약 시간 계산
            start_minutes = self._time_to_minutes(start_time)
            end_minutes = start_minutes + duration_minutes
            
            # 타석 버퍼 시간 적용
            ts_buffer_value = ts_info.get('ts_buffer', 0)
            ts_buffer = int(ts_buffer_value) if ts_buffer_value is not None else 0
            
            print(f"   📋 기존 예약 {len(existing_reservations)}건 확인")
            print(f"   🔄 타석 버퍼 시간: {ts_buffer}분")
            print(f"   ⏰ 요청 시간: {start_time} ~ {self._calculate_end_time(start_time, duration_minutes)} ({duration_minutes}분)")
            
            # 기존 예약과 시간 겹침 확인
            conflicts = []
            for reservation in existing_reservations:
                res_start = reservation.get('ts_start', '00:00')
                res_end = reservation.get('ts_end', '00:00')
                
                # None 값 체크
                if res_start is None or res_end is None:
                    print(f"   ⚠️  예약 데이터에 None 값 발견: start={res_start}, end={res_end}")
                    continue
                    
                res_start_minutes = self._time_to_minutes(res_start)
                res_end_minutes = self._time_to_minutes(res_end)
                
                # 버퍼 시간 적용
                res_start_with_buffer = res_start_minutes - ts_buffer
                res_end_with_buffer = res_end_minutes + ts_buffer
                
                print(f"   📅 기존 예약: {res_start} ~ {res_end} (버퍼 적용시: {self._minutes_to_time(res_start_with_buffer)} ~ {self._minutes_to_time(res_end_with_buffer)})")
                
                # 시간 겹침 검사
                if start_minutes < res_end_with_buffer and end_minutes > res_start_with_buffer:
                    conflicts.append({
                        'original_start': res_start,
                        'original_end': res_end,
                        'buffer_start': self._minutes_to_time(res_start_with_buffer),
                        'buffer_end': self._minutes_to_time(res_end_with_buffer)
                    })
            
            if conflicts:
                conflict_details = []
                for conflict in conflicts:
                    conflict_details.append(
                        f"{conflict['original_start']}~{conflict['original_end']} "
                        f"(버퍼포함: {conflict['buffer_start']}~{conflict['buffer_end']})"
                    )
                
                return {
                    'success': False,
                    'error': f'기존 예약과 시간이 겹칩니다.',
                    'details': {
                        'conflicts': conflicts,
                        'conflict_summary': ', '.join(conflict_details),
                        'buffer_minutes': ts_buffer
                    }
                }
            
            print("   ✅ 시간 겹침 없음 확인")
            
            return {
                'success': True,
                'availability_info': {
                    'existing_reservations_count': len(existing_reservations),
                    'buffer_minutes': ts_buffer,
                    'no_conflicts': True
                }
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': f'시간 겹침 검증 중 오류: {str(e)}'
            }
    
    def _time_to_minutes(self, time_str: str) -> int:
        """시간 문자열을 분 단위로 변환"""
        parts = time_str.split(':')
        hour = int(parts[0])
        minute = int(parts[1])
        return hour * 60 + minute
    
    def _validate_member_time_pass_contracts(self, member_id: str, duration_minutes: int, 
                                           selected_date: str, branch_id: str) -> Dict[str, Any]:
        """회원의 시간권 계약들 조회 및 검증"""
        try:
            print(f"   👤 회원 ID: {member_id}")
            print(f"   ⏱️  필요 시간: {duration_minutes}분")
            print(f"   📅 예약 날짜: {selected_date}")
            
            # 회원의 모든 시간권 계약 조회
            response = self.api_client.call_api(
                operation='get',
                table='v2_bill_times',
                fields=['contract_history_id', 'bill_balance_min_after', 'contract_TS_min_expiry_date', 'bill_min_id', 'bill_date'],
                where=[
                    {'field': 'branch_id', 'operator': '=', 'value': branch_id},
                    {'field': 'member_id', 'operator': '=', 'value': member_id}
                ],
                orderBy=[
                    {'field': 'contract_history_id', 'direction': 'ASC'},
                    {'field': 'bill_min_id', 'direction': 'DESC'}
                ]
            )
            
            if not response.get('success') or not response.get('data'):
                print("   ℹ️ 시간권 계약을 찾을 수 없습니다.")
                return {
                    'success': True,
                    'time_pass_contracts': []
                }
            
            # 계약별로 최신 잔액 정보만 추출
            contracts_data = {}
            for record in response['data']:
                contract_id = record['contract_history_id']
                if contract_id not in contracts_data:
                    contracts_data[contract_id] = record
            
            print(f"   📋 총 {len(contracts_data)}개의 시간권 계약 발견")
            
            # 각 계약 검증
            valid_contracts = []
            insufficient_contracts = []
            expired_contracts = []
            
            for contract_id, contract_data in contracts_data.items():
                current_balance = int(contract_data['bill_balance_min_after'])
                expiry_date = contract_data.get('contract_TS_min_expiry_date')
                
                print(f"\n   🔍 계약 ID: {contract_id}")
                print(f"      💰 현재 잔액: {current_balance:,}분")
                
                # 유효기간 확인
                is_expired = False
                if expiry_date and expiry_date != 'null' and expiry_date.strip():
                    print(f"      📅 유효기간: {expiry_date}")
                    if selected_date > expiry_date:
                        print(f"      ❌ 유효기간 만료")
                        expired_contracts.append({
                            'contract_history_id': contract_id,
                            'current_balance': current_balance,
                            'expiry_date': expiry_date,
                            'status': 'expired'
                        })
                        is_expired = True
                else:
                    print(f"      📅 유효기간: 무제한")
                
                if not is_expired:
                    # 잔액 확인
                    if current_balance >= duration_minutes:
                        remaining_balance = current_balance - duration_minutes
                        print(f"      ✅ 잔액 충분 (차감 후: {remaining_balance}분)")
                        valid_contracts.append({
                            'contract_history_id': contract_id,
                            'current_balance': current_balance,
                            'required_minutes': duration_minutes,
                            'remaining_balance': remaining_balance,
                            'expiry_date': expiry_date,
                            'status': 'valid'
                        })
                    else:
                        print(f"      ❌ 잔액 부족 (부족: {duration_minutes - current_balance}분)")
                        insufficient_contracts.append({
                            'contract_history_id': contract_id,
                            'current_balance': current_balance,
                            'required_minutes': duration_minutes,
                            'shortage': duration_minutes - current_balance,
                            'expiry_date': expiry_date,
                            'status': 'insufficient'
                        })
            
            # 결과 요약
            print(f"\n   📊 검증 결과:")
            print(f"      ✅ 사용 가능한 계약: {len(valid_contracts)}개")
            print(f"      ❌ 잔액 부족 계약: {len(insufficient_contracts)}개")
            print(f"      ⏰ 만료된 계약: {len(expired_contracts)}개")
            
            return {
                'success': True,
                'time_pass_contracts': {
                    'valid_contracts': valid_contracts,
                    'insufficient_contracts': insufficient_contracts,
                    'expired_contracts': expired_contracts,
                    'total_contracts': len(contracts_data),
                    'usable_contracts': len(valid_contracts)
                }
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': f'회원 시간권 계약 조회 중 오류: {str(e)}'
            }
    
    def _minutes_to_time(self, minutes: int) -> str:
        """분을 시간 문자열로 변환"""
        if minutes < 0:
            minutes = 0
        if minutes >= 1440:
            minutes = minutes % 1440
        
        hour = minutes // 60
        minute = minutes % 60
        return f"{hour:02d}:{minute:02d}"
    
    def _calculate_end_time(self, start_time: str, duration_minutes: int) -> str:
        """종료 시간 계산"""
        start_minutes = self._time_to_minutes(start_time)
        end_minutes = start_minutes + duration_minutes
        return self._minutes_to_time(end_minutes)

# =============================================================================
# 메인 실행 부분
# =============================================================================

def main():
    """메인 함수"""
    try:
        print("🏌️  타석 예약 가능성 검증 도구")
        print("=" * 50)
        
        # 초기 설정
        checker = TsAvailabilityChecker()
        
        while True:
            try:
                print("\n📝 예약 정보를 입력해주세요:")
                print("-" * 30)
                
                # 사용자 입력
                branch_id = input("지점 ID: ").strip()
                if not branch_id:
                    print("❌ 지점 ID는 필수입니다.")
                    continue
                
                member_id = input("회원 ID: ").strip()
                if not member_id:
                    print("❌ 회원 ID는 필수입니다.")
                    continue
                
                ts_id = input("타석 ID: ").strip()
                if not ts_id:
                    print("❌ 타석 ID는 필수입니다.")
                    continue
                
                selected_date = input("예약 날짜 (YYYY-MM-DD): ").strip()
                if not selected_date:
                    print("❌ 예약 날짜는 필수입니다.")
                    continue
                
                start_time = input("시작 시간 (HH:MM): ").strip()
                if not start_time:
                    print("❌ 시작 시간은 필수입니다.")
                    continue
                
                duration_input = input("연습 시간 (분): ").strip()
                if not duration_input:
                    print("❌ 연습 시간은 필수입니다.")
                    continue
                
                try:
                    duration_minutes = int(duration_input)
                except ValueError:
                    print("❌ 연습 시간은 숫자여야 합니다.")
                    continue
                
                
                # 검증 실행
                result = checker.check_ts_availability(
                    branch_id=branch_id,
                    member_id=member_id,
                    ts_id=ts_id,
                    selected_date=selected_date,
                    start_time=start_time,
                    duration_minutes=duration_minutes
                )
                
                # 결과 출력
                print("\n" + "="*60)
                if result['success']:
                    print("🎉 검증 결과: 예약 가능!")
                    print("="*60)
                    
                    details = result['validation_details']
                    print(f"📅 예약 날짜: {details['date']}")
                    print(f"🎯 타석: {details['ts_id']}번")
                    print(f"⏰ 시간: {details['start_time']} ~ {details['end_time']}")
                    print(f"⏱️  이용시간: {details['duration_minutes']}분")
                    
                    # 추가 정보 출력
                    if 'schedule_info' in details:
                        schedule = details['schedule_info']
                        business_end_display = schedule.get('business_end', '00:00')
                        if business_end_display == '00:00':
                            business_end_display = '24:00'
                        print(f"🏢 영업시간: {schedule.get('business_start', '')} ~ {business_end_display}")
                    
                    if 'ts_info' in details:
                        ts_info = details['ts_info']
                        buffer_time = ts_info.get('ts_buffer', 0)
                        print(f"🔄 타석 버퍼: {buffer_time}분")
                    
                    if 'availability_info' in details:
                        avail_info = details['availability_info']
                        existing_count = avail_info.get('existing_reservations_count', 0)
                        print(f"📋 기존 예약: {existing_count}건")
                    
                    if 'time_pass_contracts' in details and details['time_pass_contracts']:
                        contracts = details['time_pass_contracts']
                        
                        print(f"📄 회원 시간권 계약 현황:")
                        print(f"   - 전체 계약 수: {contracts.get('total_contracts', 0)}개")
                        print(f"   - 사용 가능한 계약: {contracts.get('usable_contracts', 0)}개")
                        
                        # 사용 가능한 계약들 상세 정보
                        valid_contracts = contracts.get('valid_contracts', [])
                        if valid_contracts:
                            print(f"   \n✅ 사용 가능한 계약들:")
                            for i, contract in enumerate(valid_contracts, 1):
                                expiry_text = contract.get('expiry_date') or '무제한'
                                print(f"      {i}. 계약 ID: {contract.get('contract_history_id')}")
                                print(f"         현재 잔액: {contract.get('current_balance'):,}분")
                                print(f"         차감 후 잔액: {contract.get('remaining_balance'):,}분")
                                print(f"         유효기간: {expiry_text}")
                        
                        # 잔액 부족 계약들
                        insufficient_contracts = contracts.get('insufficient_contracts', [])
                        if insufficient_contracts:
                            print(f"   \n❌ 잔액 부족 계약들:")
                            for i, contract in enumerate(insufficient_contracts, 1):
                                expiry_text = contract.get('expiry_date') or '무제한'
                                print(f"      {i}. 계약 ID: {contract.get('contract_history_id')}")
                                print(f"         현재 잔액: {contract.get('current_balance'):,}분")
                                print(f"         부족 시간: {contract.get('shortage'):,}분")
                                print(f"         유효기간: {expiry_text}")
                        
                        # 만료된 계약들
                        expired_contracts = contracts.get('expired_contracts', [])
                        if expired_contracts:
                            print(f"   \n⏰ 만료된 계약들:")
                            for i, contract in enumerate(expired_contracts, 1):
                                print(f"      {i}. 계약 ID: {contract.get('contract_history_id')}")
                                print(f"         현재 잔액: {contract.get('current_balance'):,}분")
                                print(f"         만료일: {contract.get('expiry_date')}")
                    else:
                        print("📄 시간권 계약: 없음")
                    
                else:
                    print("❌ 검증 결과: 예약 불가!")
                    print("="*60)
                    print(f"🚫 사유: {result['error']}")
                    
                    # 상세 정보가 있는 경우 출력
                    if 'details' in result:
                        details = result['details']
                        if 'conflicts' in details:
                            print(f"⚠️  충돌 정보: {details['conflict_summary']}")
                        if 'prohibited_types' in details:
                            print(f"🚫 제한 회원 타입: {', '.join(details['prohibited_types'])}")
                        if 'member_type' in details:
                            print(f"👤 회원 타입: {details['member_type']}")
                        if 'restriction_reason' in details:
                            print(f"📝 제한 사유: {details['restriction_reason']}")
                    
                    # 예약 불가능한 경우에도 시간권 계약 정보 출력
                    if 'validation_details' in result:
                        details = result['validation_details']
                        if 'time_pass_contracts' in details and details['time_pass_contracts']:
                            contracts = details['time_pass_contracts']
                            
                            print(f"\n📄 회원 시간권 계약 현황:")
                            print(f"   - 전체 계약 수: {contracts.get('total_contracts', 0)}개")
                            print(f"   - 사용 가능한 계약: {contracts.get('usable_contracts', 0)}개")
                            
                            # 사용 가능한 계약들 상세 정보
                            valid_contracts = contracts.get('valid_contracts', [])
                            if valid_contracts:
                                print(f"   \n✅ 사용 가능한 계약들:")
                                for i, contract in enumerate(valid_contracts, 1):
                                    expiry_text = contract.get('expiry_date') or '무제한'
                                    print(f"      {i}. 계약 ID: {contract.get('contract_history_id')}")
                                    print(f"         현재 잔액: {contract.get('current_balance'):,}분")
                                    print(f"         차감 후 잔액: {contract.get('remaining_balance'):,}분")
                                    print(f"         유효기간: {expiry_text}")
                            
                            # 잔액 부족 계약들
                            insufficient_contracts = contracts.get('insufficient_contracts', [])
                            if insufficient_contracts:
                                print(f"   \n❌ 잔액 부족 계약들:")
                                for i, contract in enumerate(insufficient_contracts, 1):
                                    expiry_text = contract.get('expiry_date') or '무제한'
                                    print(f"      {i}. 계약 ID: {contract.get('contract_history_id')}")
                                    print(f"         현재 잔액: {contract.get('current_balance'):,}분")
                                    print(f"         부족 시간: {contract.get('shortage'):,}분")
                                    print(f"         유효기간: {expiry_text}")
                            
                            # 만료된 계약들
                            expired_contracts = contracts.get('expired_contracts', [])
                            if expired_contracts:
                                print(f"   \n⏰ 만료된 계약들:")
                                for i, contract in enumerate(expired_contracts, 1):
                                    print(f"      {i}. 계약 ID: {contract.get('contract_history_id')}")
                                    print(f"         현재 잔액: {contract.get('current_balance'):,}분")
                                    print(f"         만료일: {contract.get('expiry_date')}")
                        else:
                            print(f"\n📄 시간권 계약: 없음")
                
                print("="*60)
                
                # 계속 여부 확인
                continue_check = input("\n다른 예약을 확인하시겠습니까? (y/n): ").strip().lower()
                if continue_check not in ['y', 'yes', '예', 'ㅇ']:
                    break
                    
            except KeyboardInterrupt:
                print("\n\n프로그램을 종료합니다.")
                break
            except Exception as e:
                print(f"\n❌ 입력 처리 중 오류 발생: {e}")
                continue
        
    except Exception as e:
        print(f"❌ 프로그램 실행 중 오류 발생: {e}")

if __name__ == '__main__':
    main()