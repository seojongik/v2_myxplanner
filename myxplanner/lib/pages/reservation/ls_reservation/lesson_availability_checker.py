#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
레슨 시간 선택 가능 여부 판별 프로그램
Flutter 앱의 ls_step4_select_duration.dart 로직을 Python으로 구현
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
        'User-Agent': 'LessonDurationChecker/1.0'
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
# 레슨 시간 검증 클래스
# =============================================================================

class LessonDurationChecker:
    def __init__(self):
        self.api_client = ApiClient()
        
    def check_lesson_availability(self, branch_id: str, member_id: str, selected_date: str, 
                                selected_instructor: str, selected_time: str, 
                                requested_duration: int) -> Dict[str, Any]:
        """
        레슨 예약 가능 여부 종합 판별 (잔여 레슨 체크 포함)
        
        Args:
            branch_id: 지점 ID
            member_id: 회원 ID
            selected_date: 선택된 날짜 (YYYY-MM-DD)
            selected_instructor: 선택된 프로 ID
            selected_time: 선택된 시작시간 (HH:MM)
            requested_duration: 요청된 레슨시간 (분)
            
        Returns:
            Dict: 종합 검증 결과
        """
        try:
            # 1. 잔여 레슨 체크 (우선순위: 0 - 가장 높음)
            remaining_lesson_result = self._check_remaining_lessons(branch_id, member_id, selected_instructor, requested_duration)
            if not remaining_lesson_result['success']:
                return remaining_lesson_result
            
            # 2. 기본 레슨 시간 검증 수행
            basic_validation_result = self.check_lesson_duration(
                selected_date, selected_instructor, selected_time, requested_duration
            )
            
            # 3. 잔여 레슨 정보를 기본 검증 결과에 추가
            if basic_validation_result['success']:
                basic_validation_result['validation_details']['remaining_lesson_info'] = remaining_lesson_result['lesson_info']
                basic_validation_result['validation_details']['available_contracts'] = remaining_lesson_result['available_contracts']
            
            return basic_validation_result
            
        except Exception as e:
            return {
                'success': False,
                'error': f'종합 검증 중 오류 발생: {str(e)}'
            }
    
    def _check_remaining_lessons(self, branch_id: str, member_id: str, 
                               selected_instructor: str, requested_duration: int) -> Dict[str, Any]:
        """잔여 레슨 체크"""
        try:
            # 회원의 레슨 카운팅 데이터 조회 - Flutter 앱과 동일한 방식
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
                    'error': '회원의 레슨 계약 정보를 조회할 수 없습니다.',
                    'details': {
                        'member_id': member_id,
                        'branch_id': branch_id,
                        'api_error': response.get('error', '알 수 없는 오류')
                    }
                }
            
            # 응답 데이터 파싱
            lesson_data = response.get('data', [])
            
            # 만료일 체크 (오늘 날짜 이후인 것만)
            from datetime import datetime
            today = datetime.now().strftime('%Y-%m-%d')
            
            valid_records = []
            for record in lesson_data:
                expiry_date = record.get('LS_expiry_date', '')
                if expiry_date and expiry_date >= today:
                    valid_records.append(record)
            
            if not valid_records:
                return {
                    'success': False,
                    'error': '유효한 레슨 계약이 없습니다.',
                    'details': {
                        'member_id': member_id,
                        'branch_id': branch_id,
                        'total_contracts_found': len(lesson_data),
                        'valid_contracts_found': 0
                    }
                }
            
            # 선택된 프로의 유효한 계약 필터링
            valid_contracts = []
            for contract in valid_records:
                contract_pro_id = str(contract.get('pro_id', ''))
                balance_min = int(contract.get('LS_balance_min_after', 0))
                
                if contract_pro_id == selected_instructor and balance_min > 0:
                    valid_contracts.append(contract)
            
            if not valid_contracts:
                # 선택된 프로의 유효한 계약이 없는 경우
                # 프로 정보 조회
                pro_info = self._get_pro_info(selected_instructor)
                pro_name = pro_info.get('pro_name', f'프로 {selected_instructor}') if pro_info else f'프로 {selected_instructor}'
                
                return {
                    'success': False,
                    'error': f'{pro_name}의 잔여 레슨시간이 부족합니다.',
                    'validation_details': {
                        'priority': 0,
                        'type': 'no_remaining_lessons',
                        'member_id': member_id,
                        'instructor_id': selected_instructor,
                        'instructor_name': pro_name,
                        'requested_duration': requested_duration,
                        'available_contracts': [],
                        'total_contracts_found': len(lesson_data),
                        'valid_contracts_found': len(valid_records)
                    }
                }
            
            # 요청된 레슨시간을 수용할 수 있는 계약 찾기
            suitable_contracts = []
            for contract in valid_contracts:
                balance_min = int(contract.get('LS_balance_min_after', 0))
                if balance_min >= requested_duration:
                    suitable_contracts.append(contract)
            
            if not suitable_contracts:
                # 잔여 시간이 부족한 경우
                max_available = max(int(contract.get('LS_balance_min_after', 0)) for contract in valid_contracts)
                pro_info = self._get_pro_info(selected_instructor)
                pro_name = pro_info.get('pro_name', f'프로 {selected_instructor}') if pro_info else f'프로 {selected_instructor}'
                
                return {
                    'success': False,
                    'error': f'{pro_name}의 잔여 레슨시간이 부족합니다. 요청: {requested_duration}분, 최대 사용 가능: {max_available}분',
                    'validation_details': {
                        'priority': 0,
                        'type': 'insufficient_remaining_lessons',
                        'member_id': member_id,
                        'instructor_id': selected_instructor,
                        'instructor_name': pro_name,
                        'requested_duration': requested_duration,
                        'max_available_duration': max_available,
                        'shortage': requested_duration - max_available,
                        'available_contracts': [
                            {
                                'contract_id': contract.get('LS_contract_id'),
                                'remaining_minutes': int(contract.get('LS_balance_min_after', 0)),
                                'expiry_date': contract.get('LS_expiry_date')
                            } for contract in valid_contracts
                        ],
                        'total_contracts_found': len(lesson_data),
                        'valid_contracts_found': len(valid_records)
                    }
                }
            
            # 성공: 사용 가능한 계약이 있음
            # 프로 정보 조회
            pro_info = self._get_pro_info(selected_instructor)
            pro_name = pro_info.get('pro_name', f'프로 {selected_instructor}') if pro_info else f'프로 {selected_instructor}'
            
            return {
                'success': True,
                'lesson_info': {
                    'member_id': member_id,
                    'instructor_id': selected_instructor,
                    'instructor_name': pro_name,
                    'requested_duration': requested_duration,
                    'suitable_contracts_count': len(suitable_contracts)
                },
                'available_contracts': [
                    {
                        'contract_id': contract.get('LS_contract_id'),
                        'counting_id': contract.get('LS_counting_id'),
                        'remaining_minutes': int(contract.get('LS_balance_min_after', 0)),
                        'expiry_date': contract.get('LS_expiry_date'),
                        'balance_after_lesson': int(contract.get('LS_balance_min_after', 0)) - requested_duration
                    } for contract in suitable_contracts
                ]
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': f'잔여 레슨 체크 중 오류 발생: {str(e)}'
            }
        
    def check_lesson_duration(self, selected_date: str, selected_instructor: str, 
                            selected_time: str, requested_duration: int) -> Dict[str, Any]:
        """
        레슨 시간 선택 가능 여부 판별
        
        Args:
            selected_date: 선택된 날짜 (YYYY-MM-DD)
            selected_instructor: 선택된 프로 ID
            selected_time: 선택된 시작시간 (HH:MM)
            requested_duration: 요청된 레슨시간 (분)
            
        Returns:
            Dict: 검증 결과
        """
        try:
            # 1. 필수 전제조건 체크
            if not all([selected_date, selected_instructor, selected_time]):
                return {
                    'success': False,
                    'error': '필수 정보가 누락되었습니다 (날짜, 프로 ID, 시작시간)',
                    'details': {
                        'date': selected_date,
                        'instructor': selected_instructor,
                        'time': selected_time
                    }
                }
            
            # 2. 프로 정보 조회
            pro_info = self._get_pro_info(selected_instructor)
            if not pro_info:
                return {
                    'success': False,
                    'error': f'프로 정보를 찾을 수 없습니다: {selected_instructor}'
                }
            
            # 3. 프로 스케줄 조회
            work_schedule = self._get_pro_schedule(selected_instructor, selected_date)
            work_start = work_schedule.get('work_start', '09:00:00')
            work_end = work_schedule.get('work_end', '18:00:00')
            
            # 4. 기존 예약 조회
            reservations = self._get_existing_reservations(selected_instructor, selected_date)
            
            # 5. 최대 레슨시간 계산
            max_duration_result = self._calculate_max_duration(
                selected_time, work_start, work_end, reservations, pro_info
            )
            
            # 6. 최종 검증
            validation_result = self._validate_requested_duration(
                requested_duration, max_duration_result, pro_info, selected_time, reservations
            )
            
            return validation_result
            
        except Exception as e:
            return {
                'success': False,
                'error': f'검증 중 오류 발생: {str(e)}'
            }
    
    def _get_pro_info(self, pro_id: str) -> Optional[Dict[str, Any]]:
        """프로 정보 조회"""
        try:
            # v2_staff_pro 테이블에서 프로 정보 조회
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
            # v2_weekly_schedule_pro 테이블에서 스케줄 조회
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
                # 기본 근무시간 반환
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
            # v2_LS_orders 테이블에서 예약 조회
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
    
    def _calculate_max_duration(self, selected_time: str, work_start: str, 
                              work_end: str, reservations: List[Dict], 
                              pro_info: Dict) -> Dict[str, Any]:
        """최대 레슨시간 계산"""
        # 시작시간을 분으로 변환
        start_time_minutes = self._time_to_minutes(f"{selected_time}:00")
        work_start_minutes = self._time_to_minutes(work_start)
        work_end_minutes = self._time_to_minutes(work_end)
        
        # 근무시간 전/후 체크
        if start_time_minutes < work_start_minutes:
            return {
                'time_until_work_end': 0,
                'time_until_next_reservation': 0,
                'max_allowed_time': 90,
                'calculated_max': 0,
                'max_possible': 0,
                'min_service_min': int(pro_info.get('min_service_min', 30)),
                'svc_time_unit': int(pro_info.get('svc_time_unit', 5)),
                'error': 'before_work_hours',
                'work_start': work_start,
                'work_end': work_end
            }
        
        if start_time_minutes >= work_end_minutes:
            return {
                'time_until_work_end': 0,
                'time_until_next_reservation': 0,
                'max_allowed_time': 90,
                'calculated_max': 0,
                'max_possible': 0,
                'min_service_min': int(pro_info.get('min_service_min', 30)),
                'svc_time_unit': int(pro_info.get('svc_time_unit', 5)),
                'error': 'after_work_hours',
                'work_start': work_start,
                'work_end': work_end
            }
        
        # 1. 근무시간 종료까지 남은 시간
        time_until_work_end = work_end_minutes - start_time_minutes
        
        # 2. 다음 예약까지 남은 시간 (시간 구간 겹침 고려)
        time_until_next_reservation = time_until_work_end
        
        for reservation in reservations:
            reservation_start_minutes = self._time_to_minutes(reservation['LS_start_time'])
            reservation_end_minutes = self._time_to_minutes(reservation['LS_end_time'])
            
            # 현재 선택된 시작시간이 기존 예약의 종료시간 이후인 경우
            if start_time_minutes >= reservation_end_minutes:
                continue  # 이 예약은 영향 없음
            
            # 현재 선택된 시작시간이 기존 예약의 시작시간 이전인 경우
            if start_time_minutes < reservation_start_minutes:
                # 다음 예약 시작까지의 시간이 제한 요소
                time_until_next_reservation = reservation_start_minutes - start_time_minutes
                break
            
            # 현재 선택된 시작시간이 기존 예약 시간 중간에 있는 경우
            if reservation_start_minutes <= start_time_minutes < reservation_end_minutes:
                # 이 시간에는 레슨 시작 불가
                time_until_next_reservation = 0
                break
        
        if time_until_next_reservation == time_until_work_end:
            return {
                'time_until_work_end': time_until_work_end,
                'time_until_next_reservation': time_until_next_reservation,
                'max_allowed_time': 90,
                'calculated_max': time_until_work_end,
                'max_possible': time_until_work_end,
                'min_service_min': int(pro_info.get('min_service_min', 30)),
                'svc_time_unit': int(pro_info.get('svc_time_unit', 5)),
            }
        
        # 최대 90분 제한
        max_allowed_time = 90
        
        # 최소값 선택
        calculated_max = min(time_until_work_end, time_until_next_reservation, max_allowed_time)
        
        # 레슨시간 단위로 조정
        min_service_min = int(pro_info.get('min_service_min', 30))
        svc_time_unit = int(pro_info.get('svc_time_unit', 5))
        
        max_possible = min_service_min
        while max_possible + svc_time_unit <= calculated_max:
            max_possible += svc_time_unit
        
        # 최소 레슨시간보다 작을 수 없음
        if max_possible < min_service_min:
            max_possible = min_service_min
        
        return {
            'time_until_work_end': time_until_work_end,
            'time_until_next_reservation': time_until_next_reservation,
            'max_allowed_time': max_allowed_time,
            'calculated_max': calculated_max,
            'max_possible': max_possible,
            'min_service_min': min_service_min,
            'svc_time_unit': svc_time_unit
        }
    
    def _validate_requested_duration(self, requested_duration: int, 
                                   max_duration_result: Dict, 
                                   pro_info: Dict, selected_time: str, reservations: List[Dict]) -> Dict[str, Any]:
        """요청된 레슨시간 종합 검증"""
        min_service_min = max_duration_result['min_service_min']
        max_possible = max_duration_result['max_possible']
        svc_time_unit = max_duration_result['svc_time_unit']
        
        # 모든 검증 결과를 저장할 리스트
        validation_issues = []
        
        # 0. 근무시간 외 체크 (우선순위: 0 - 최고 우선순위)
        if 'error' in max_duration_result:
            error_type = max_duration_result['error']
            work_start = max_duration_result['work_start']
            work_end = max_duration_result['work_end']
            
            if error_type == 'before_work_hours':
                primary_issue = {
                    'priority': 0,
                    'type': 'before_work_hours',
                    'message': f'선택된 시간({selected_time})이 근무시작 시간({work_start}) 이전입니다.',
                    'details': {
                        'selected_time': selected_time,
                        'work_start': work_start,
                        'work_end': work_end,
                        'requested_duration': requested_duration
                    }
                }
                
                return {
                    'success': False,
                    'error': primary_issue['message'],
                    'validation_details': {
                        'requested_duration': requested_duration,
                        'min_duration': min_service_min,
                        'max_duration': max_possible,
                        'time_unit': svc_time_unit,
                        'start_time': selected_time,
                        'end_time': self._minutes_to_time(self._time_to_minutes(f"{selected_time}:00") + requested_duration),
                        'primary_issue': primary_issue,
                        'all_issues': [primary_issue],
                        'issues_count': 1,
                        'calculation_details': max_duration_result
                    }
                }
                
            elif error_type == 'after_work_hours':
                primary_issue = {
                    'priority': 0,
                    'type': 'after_work_hours',
                    'message': f'선택된 시간({selected_time})이 근무종료 시간({work_end}) 이후입니다.',
                    'details': {
                        'selected_time': selected_time,
                        'work_start': work_start,
                        'work_end': work_end,
                        'requested_duration': requested_duration
                    }
                }
                
                return {
                    'success': False,
                    'error': primary_issue['message'],
                    'validation_details': {
                        'requested_duration': requested_duration,
                        'min_duration': min_service_min,
                        'max_duration': max_possible,
                        'time_unit': svc_time_unit,
                        'start_time': selected_time,
                        'end_time': self._minutes_to_time(self._time_to_minutes(f"{selected_time}:00") + requested_duration),
                        'primary_issue': primary_issue,
                        'all_issues': [primary_issue],
                        'issues_count': 1,
                        'calculation_details': max_duration_result
                    }
                }
        
        # 1. 최소 레슨시간 체크 (우선순위: 1)
        if requested_duration < min_service_min:
            validation_issues.append({
                'priority': 1,
                'type': 'min_duration_violation',
                'message': f'요청된 레슨시간({requested_duration}분)이 최소 레슨시간({min_service_min}분)보다 작습니다.',
                'details': {
                    'requested': requested_duration,
                    'minimum_required': min_service_min,
                    'difference': min_service_min - requested_duration
                }
            })
        
        # 2. 레슨시간 단위 체크 (우선순위: 2)
        if requested_duration >= min_service_min and (requested_duration - min_service_min) % svc_time_unit != 0:
            # 올바른 단위로 조정된 값들 계산
            valid_durations = []
            for duration in range(min_service_min, max_possible + 1, svc_time_unit):
                valid_durations.append(duration)
            
            # 가장 가까운 유효한 시간 찾기
            closest_valid = min(valid_durations, key=lambda x: abs(x - requested_duration)) if valid_durations else min_service_min
            
            validation_issues.append({
                'priority': 2,
                'type': 'time_unit_violation',
                'message': f'요청된 레슨시간({requested_duration}분)이 올바른 단위가 아닙니다. 최소 {min_service_min}분부터 {svc_time_unit}분 단위로 선택해야 합니다.',
                'details': {
                    'requested': requested_duration,
                    'time_unit': svc_time_unit,
                    'closest_valid': closest_valid,
                    'valid_durations': valid_durations[:10]  # 처음 10개만 표시
                }
            })
        
        # 3. 시간 구간 겹침 검증 (우선순위: 3)
        start_time_minutes = self._time_to_minutes(f"{selected_time}:00")
        end_time_minutes = start_time_minutes + requested_duration
        end_time_str = self._minutes_to_time(end_time_minutes)
        
        conflicting_reservations = []
        for reservation in reservations:
            reservation_start_minutes = self._time_to_minutes(reservation['LS_start_time'])
            reservation_end_minutes = self._time_to_minutes(reservation['LS_end_time'])
            
            # 시간 구간 겹침 검사
            if start_time_minutes < reservation_end_minutes and end_time_minutes > reservation_start_minutes:
                conflicting_reservations.append({
                    'start': reservation['LS_start_time'],
                    'end': reservation['LS_end_time'],
                    'start_minutes': reservation_start_minutes,
                    'end_minutes': reservation_end_minutes
                })
        
        if conflicting_reservations:
            validation_issues.append({
                'priority': 3,
                'type': 'time_conflict',
                'message': f'요청된 레슨시간({selected_time}~{end_time_str})이 기존 예약과 겹칩니다.',
                'details': {
                    'requested_start': selected_time,
                    'requested_end': end_time_str,
                    'conflicting_reservations': conflicting_reservations
                }
            })
        
        # 4. 최대 레슨시간 체크 (우선순위: 4)
        if requested_duration > max_possible:
            # 제한 요소 분석
            limiting_factors = []
            calc_details = max_duration_result
            
            if calc_details['calculated_max'] == calc_details['time_until_work_end']:
                limiting_factors.append(f"근무시간 종료({calc_details['time_until_work_end']}분)")
            if calc_details['calculated_max'] == calc_details['time_until_next_reservation']:
                limiting_factors.append(f"다음 예약({calc_details['time_until_next_reservation']}분)")
            if calc_details['calculated_max'] == calc_details['max_allowed_time']:
                limiting_factors.append(f"시스템 제한({calc_details['max_allowed_time']}분)")
            
            validation_issues.append({
                'priority': 4,
                'type': 'max_duration_exceeded',
                'message': f'요청된 레슨시간({requested_duration}분)이 최대 가능 시간({max_possible}분)을 초과합니다.',
                'details': {
                    'requested': requested_duration,
                    'maximum_possible': max_possible,
                    'excess_time': requested_duration - max_possible,
                    'limiting_factors': limiting_factors,
                    'calculation_breakdown': calc_details
                }
            })
        
        # 검증 결과 분석
        if validation_issues:
            # 우선순위가 가장 높은(숫자가 작은) 이슈를 주요 오류로 선택
            primary_issue = min(validation_issues, key=lambda x: x['priority'])
            
            return {
                'success': False,
                'error': primary_issue['message'],
                'validation_details': {
                    'requested_duration': requested_duration,
                    'min_duration': min_service_min,
                    'max_duration': max_possible,
                    'time_unit': svc_time_unit,
                    'start_time': selected_time,
                    'end_time': end_time_str,
                    'primary_issue': primary_issue,
                    'all_issues': validation_issues,
                    'issues_count': len(validation_issues),
                    'calculation_details': max_duration_result
                }
            }
        
        # 모든 검증 통과
        return {
            'success': True,
            'message': f'레슨시간 선택이 가능합니다: {selected_time} ~ {end_time_str} ({requested_duration}분)',
            'validation_details': {
                'requested_duration': requested_duration,
                'min_duration': min_service_min,
                'max_duration': max_possible,
                'time_unit': svc_time_unit,
                'start_time': selected_time,
                'end_time': end_time_str,
                'all_checks_passed': True,
                'calculation_details': max_duration_result
            }
        }

# =============================================================================
# 메인 실행 부분
# =============================================================================

def main():
    """메인 함수"""
    try:
        # 초기 설정
        checker = LessonDurationChecker()
        
        # 입력 받기
        branch_id = input("지점 ID를 입력하세요: ")
        member_id = input("회원 ID를 입력하세요: ")
        selected_date = input("날짜를 입력하세요 (YYYY-MM-DD): ")
        
        # 세션 정보 입력
        session_count = int(input("세션 수를 입력하세요: "))
        selected_instructor = input("프로 ID를 입력하세요: ")
        
        # 첫 번째 세션 시작시간 입력
        initial_start_time = input("첫 번째 세션 시작시간을 입력하세요 (HH:MM): ")
        
        # 각 세션별 정보 입력
        sessions = []
        current_start_time = initial_start_time
        
        for i in range(session_count):
            lesson_duration = int(input(f"세션 {i+1} 레슨 시간을 입력하세요 (분): "))
            
            if i < session_count - 1:  # 마지막 세션이 아닌 경우에만 휴식시간 입력
                break_time = int(input(f"세션 {i+1} 후 휴식시간을 입력하세요 (분): "))
            else:
                break_time = 0
            
            sessions.append({
                'start_time': current_start_time,
                'lesson_duration': lesson_duration,
                'break_time': break_time
            })
            
            # 다음 세션 시작시간 계산
            if i < session_count - 1:
                current_start_minutes = time_to_minutes(current_start_time)
                next_start_minutes = current_start_minutes + lesson_duration + break_time
                current_start_time = minutes_to_time(next_start_minutes)
        
        # 세션 검증
        successful_sessions = []
        failed_sessions = []
        
        for i, session in enumerate(sessions):
            result = checker.check_lesson_availability(
                branch_id=branch_id,
                member_id=member_id,
                selected_date=selected_date,
                selected_instructor=selected_instructor,
                selected_time=session['start_time'],
                requested_duration=session['lesson_duration']
            )
            
            # 종료 시간 계산
            start_minutes = time_to_minutes(session['start_time'])
            end_minutes = start_minutes + session['lesson_duration']
            end_time = minutes_to_time(end_minutes)
            
            session_info = {
                'session_number': i + 1,
                'start_time': session['start_time'],
                'end_time': end_time,
                'lesson_duration': session['lesson_duration'],
                'break_time': session['break_time']
            }
            
            if result['success']:
                successful_sessions.append(session_info)
            else:
                failed_sessions.append({
                    **session_info,
                    'error': result['error']
                })
        
        # 결과 출력
        print("\n" + "="*60)
        print("레슨 예약 검증 결과")
        print("="*60)
        
        total_sessions = len(sessions)
        success_count = len(successful_sessions)
        success_rate = (success_count / total_sessions * 100) if total_sessions > 0 else 0
        
        print(f"총 세션 수: {total_sessions}")
        print(f"성공한 세션: {success_count}")
        print(f"실패한 세션: {len(failed_sessions)}")
        print(f"성공률: {success_rate:.1f}%")
        
        if successful_sessions:
            print("\n✅ 예약 가능한 세션:")
            for session in successful_sessions:
                print(f"  세션 {session['session_number']}: {session['start_time']} ~ {session['end_time']} ({session['lesson_duration']}분)")
        
        if failed_sessions:
            print("\n❌ 예약 불가능한 세션:")
            for session in failed_sessions:
                print(f"  세션 {session['session_number']}: {session['start_time']} ~ {session['end_time']} ({session['lesson_duration']}분)")
                print(f"    사유: {session['error']}")
        
        # JSON 형태로 결과 출력
        result_data = {
            "total_sessions": total_sessions,
            "successful_sessions": success_count,
            "failed_sessions": len(failed_sessions),
            "success_rate": success_rate,
            "sessions": {
                "successful": successful_sessions,
                "failed": failed_sessions
            }
        }
        
        print("\n" + "="*60)
        print("JSON 결과:")
        print(json.dumps(result_data, indent=2, ensure_ascii=False))
        
    except Exception as e:
        print(f"오류 발생: {e}")

def time_to_minutes(time_str: str) -> int:
    """시간 문자열을 분으로 변환"""
    hours, minutes = map(int, time_str.split(':'))
    return hours * 60 + minutes

def minutes_to_time(minutes: int) -> str:
    """분을 시간 문자열로 변환"""
    hours = minutes // 60
    mins = minutes % 60
    return f"{hours:02d}:{mins:02d}"

if __name__ == '__main__':
    main() 