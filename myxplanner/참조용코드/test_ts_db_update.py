#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
타석 예약 DB 업데이트 테스트

실제 UI에서 계약이 이미 선택된 상태에서 호출되는 로직을 테스트합니다.
- 입력: 선택된 계약 정보 + 사용량
- 처리: 현재 잔액 조회 → 차감 계산 → DB 업데이트
- 출력: 성공/실패 결과
"""

import requests
import json
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
import time

# =============================================================================
# 설정 변수들 (수정 필요시 여기서 변경)
# =============================================================================

# 1. 입력 변수들 (사용자가 입력하는 항목들)
# -----------------------------------------------------------------------------
# 필수 입력 항목들 (하드코딩 제거됨)
# - branch_id: 지점 ID
# - member_id: 회원 ID  
# - selected_date: 예약 날짜 (YYYY-MM-DD)
# - selected_time: 예약 시간 (HH:MM)
# - selected_duration: 연습 시간 (분)
# - selected_ts: 타석 번호
# - payment_type_input: 결제 방법 (1-4)
# - contract_history_id: 계약 히스토리 ID (계약 기반 결제시)
# - usage_amount: 사용 금액/시간 (계약 기반 결제시)
# - payment_amount: 결제 금액 (심플 결제시)

# 선택 입력 항목들 (기본값 제공)
# - ts_type: 타석 타입
# - member_phone: 회원 전화번호
# - term_discount: 기간 할인
# - member_discount: 회원 할인
# - junior_discount: 주니어 할인
# - routine_discount: 정기 할인
# - overtime_discount: 연장 할인
# - emergency_discount: 긴급 할인
# - revisit_discount: 재방문 할인
# - emergency_reason: 긴급 사유
# - morning: 오전 시간대 (0 또는 1)
# - normal: 일반 시간대 (0 또는 1)
# - peak: 피크 시간대 (0 또는 1)
# - night: 야간 시간대 (0 또는 1)

# 2. 계산 함수들 (비즈니스 로직) - 함수 정의는 하단에 위치
# -----------------------------------------------------------------------------
# total_discount - calculate_total_discount() 함수 사용
# end_time - calculate_end_time() 함수 사용
# ts_info - generate_ts_info() 함수 사용
# balance_after_usage - calculate_balance_after_usage() 함수 사용
# balance_sufficient - is_balance_sufficient() 함수 사용
# payment_method_name - get_payment_method_name() 함수 사용
# contract_type - get_contract_type() 함수 사용
# expiry_date_field_name - get_expiry_date_field_name() 함수 사용
# expiry_date_table_name - get_expiry_date_table_name() 함수 사용
# expiry_date_display - format_expiry_date_display() 함수 사용
# valid_expiry_date - is_valid_expiry_date() 함수 사용

# 3. 기본값 설정
# -----------------------------------------------------------------------------
# 예약 데이터 기본값
DEFAULT_TS_TYPE = '일반'
DEFAULT_MEMBER_PHONE = '010-0000-0000'
DEFAULT_TERM_DISCOUNT = 0
DEFAULT_MEMBER_DISCOUNT = 0
DEFAULT_JUNIOR_DISCOUNT = 0
DEFAULT_ROUTINE_DISCOUNT = 0
DEFAULT_OVERTIME_DISCOUNT = 0
DEFAULT_EMERGENCY_DISCOUNT = 0
DEFAULT_REVISIT_DISCOUNT = 0
DEFAULT_EMERGENCY_REASON = ''
DEFAULT_TOTAL_DISCOUNT = 0
DEFAULT_MORNING = 0
DEFAULT_NORMAL = 1
DEFAULT_PEAK = 0
DEFAULT_NIGHT = 0

# 빌링 데이터 기본값
DEFAULT_BILL_TYPE = '타석이용'
DEFAULT_BILL_DEDUCTION = 0
DEFAULT_BILL_STATUS = '결제완료'
DEFAULT_LOCKER_BILL_ID = None
DEFAULT_ROUTINE_ID = None
DEFAULT_BILL_DISCOUNT_MIN = 0

# =============================================================================

class ApiConfig:
    BASE_URL = 'https://autofms.mycafe24.com/dynamic_api.php'
    HEADERS = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
    TIMEOUT = 30
    LOG_TEXT_LIMIT = 500
    DUPLICATE_EXCLUDE_STATUS = '예약취소'

class ApiClient:
    @staticmethod
    def call_api(operation: str, table: str, **kwargs) -> Dict[str, Any]:
        """API 호출"""
        payload = {
            'operation': operation,
            'table': table,
            **kwargs
        }
        
        print(f"🔍 API 호출 요청:")
        print(f"   URL: {ApiConfig.BASE_URL}")
        print(f"   Payload: {json.dumps(payload, indent=2, ensure_ascii=False)}")
        
        try:
            response = requests.post(
                ApiConfig.BASE_URL,
                headers=ApiConfig.HEADERS,
                json=payload,
                timeout=ApiConfig.TIMEOUT
            )
            
            print(f"📡 API 응답:")
            print(f"   Status Code: {response.status_code}")
            print(f"   Response Headers: {dict(response.headers)}")
            print(f"   Response Text: {response.text[:ApiConfig.LOG_TEXT_LIMIT]}...")  # 설정된 길이만큼 출력
            
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"❌ API 호출 실패: {e}")
            print(f"   Response Status: {getattr(response, 'status_code', 'N/A')}")
            print(f"   Response Text: {getattr(response, 'text', 'N/A')}")
            return {'success': False, 'error': str(e)}

class TsDbUpdateService:
    """타석 예약 DB 업데이트 서비스"""
    
    @staticmethod
    def get_current_balance(contract_type: str, contract_history_id: str, branch_id: str, member_id: str) -> Dict[str, Any]:
        """현재 잔액 조회"""
        print(f"💰 현재 잔액 조회: {contract_type} 계약 {contract_history_id}")
        
        if contract_type == 'prepaid_credit':
            # 선불크레딧 잔액 조회
            response = ApiClient.call_api(
                operation='get',
                table='v2_bills',
                fields=['bill_balance_after', 'bill_date', 'bill_id'],
                where=[
                    ['branch_id', '=', branch_id],
                    ['member_id', '=', member_id],
                    ['contract_history_id', '=', contract_history_id]
                ],
                orderBy=[['bill_id', 'DESC']],
                limit=1
            )
            
            if response.get('success') and response.get('data'):
                balance = int(response['data'][0]['bill_balance_after'])
                print(f"✅ 선불크레딧 잔액: {balance:,}원")
                return {
                    'success': True,
                    'balance': balance,
                    'unit': '원',
                    'last_bill_id': response['data'][0]['bill_id']
                }
            else:
                print(f"❌ 선불크레딧 잔액 조회 실패")
                return {'success': False, 'error': '잔액 조회 실패'}
                
        elif contract_type == 'time_pass':
            # 시간권 잔액 조회
            response = ApiClient.call_api(
                operation='get',
                table='v2_bill_times',
                fields=['bill_balance_min_after', 'bill_min_id'],
                where=[
                    ['branch_id', '=', branch_id],
                    ['member_id', '=', member_id],
                    ['contract_history_id', '=', contract_history_id]
                ],
                orderBy=[['bill_min_id', 'DESC']],
                limit=1
            )
            
            if response.get('success') and response.get('data'):
                balance = int(response['data'][0]['bill_balance_min_after'])
                print(f"✅ 시간권 잔액: {balance:,}분")
                return {
                    'success': True,
                    'balance': balance,
                    'unit': '분',
                    'last_bill_min_id': response['data'][0]['bill_min_id']
                }
            else:
                print(f"❌ 시간권 잔액 조회 실패")
                return {'success': False, 'error': '잔액 조회 실패'}
        
        return {'success': False, 'error': '지원하지 않는 계약 타입'}
    
    @staticmethod
    def insert_reservation_data(reservation_data: Dict[str, Any]) -> Dict[str, Any]:
        """예약 데이터 삽입"""
        print(f"📝 예약 데이터 삽입 중...")
        
        response = ApiClient.call_api(
            operation='add',
            table='v2_priced_TS',
            data=reservation_data
        )
        
        if response.get('success'):
            print(f"✅ 예약 데이터 삽입 성공")
            return {'success': True, 'reservation_id': response.get('insert_id')}
        else:
            print(f"❌ 예약 데이터 삽입 실패: {response.get('error', '알 수 없는 오류')}")
            return {'success': False, 'error': response.get('error', '알 수 없는 오류')}
    
    @staticmethod
    def get_contract_expiry_date(contract_type: str, contract_history_id: str, branch_id: str, member_id: str) -> str:
        """계약 만료일 조회"""
        print(f"📅 계약 만료일 조회: {contract_type} 계약 {contract_history_id}")
        
        # 상단에 정의된 함수들을 사용
        table_name = get_expiry_date_table_name(contract_type)
        field_name = get_expiry_date_field_name(contract_type)
        
        if not table_name or not field_name:
            print(f"❌ 지원하지 않는 계약 타입: {contract_type}")
            return ''
        
        # 만료일 조회
        response = ApiClient.call_api(
            operation='get',
            table=table_name,
            fields=[field_name],
            where=[
                ['branch_id', '=', branch_id],
                ['member_id', '=', member_id],
                ['contract_history_id', '=', contract_history_id]
            ],
            orderBy=[['bill_id', 'DESC']] if contract_type == 'prepaid_credit' else [['bill_min_id', 'DESC']],
            limit=1
        )
        
        if response.get('success') and response.get('data'):
            expiry_date = response['data'][0].get(field_name)
            if is_valid_expiry_date(expiry_date):
                display_text = format_expiry_date_display(contract_type, expiry_date)
                print(f"✅ {display_text}")
                return expiry_date
            else:
                contract_name = get_payment_method_name('1' if contract_type == 'prepaid_credit' else '2')
                print(f"ℹ️ {contract_name} 만료일 없음")
                return ''
        else:
            contract_name = get_payment_method_name('1' if contract_type == 'prepaid_credit' else '2')
            print(f"❌ {contract_name} 만료일 조회 실패")
            return ''
    
    @staticmethod
    def update_contract_balance(contract_type: str, contract_history_id: str, branch_id: str, member_id: str, 
                              used_amount: int, before_balance: int, after_balance: int, 
                              reservation_id: str, usage_date: str, usage_time: str,
                              selected_ts: str, selected_duration: int) -> Dict[str, Any]:
        """계약 잔액 업데이트"""
        print(f"🔄 계약 잔액 업데이트: {contract_type} 계약 {contract_history_id}")
        print(f"   사용량: {used_amount}, 차감 전: {before_balance}, 차감 후: {after_balance}")
        
        # 계약 만료일 조회
        expiry_date = TsDbUpdateService.get_contract_expiry_date(
            contract_type, contract_history_id, branch_id, member_id
        )
        
        if contract_type == 'prepaid_credit':
            # 타석 정보 생성 (상단에 정의된 함수 사용)
            try:
                end_time = calculate_end_time(usage_time, selected_duration)
                ts_info = generate_ts_info(selected_ts, usage_time, end_time)
            except:
                ts_info = f"타석 예약 사용 (예약ID: {reservation_id})"
            
            # 선불크레딧 사용 내역 추가
            bill_data = {
                'member_id': member_id,
                'bill_date': usage_date,
                'bill_type': DEFAULT_BILL_TYPE,
                'bill_text': ts_info,
                'bill_totalamt': -used_amount,  # 마이너스로 저장 (차감)
                'bill_deduction': DEFAULT_BILL_DEDUCTION,  # 할인 금액
                'bill_netamt': -used_amount,  # 마이너스로 저장 (실제 차감 금액)
                'bill_timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'bill_balance_before': before_balance,
                'bill_balance_after': after_balance,
                'reservation_id': reservation_id,
                'bill_status': DEFAULT_BILL_STATUS,
                'contract_history_id': contract_history_id,
                'locker_bill_id': DEFAULT_LOCKER_BILL_ID,
                'routine_id': DEFAULT_ROUTINE_ID,
                'branch_id': branch_id,
                'contract_credit_expiry_date': expiry_date if expiry_date else None
            }
            
            response = ApiClient.call_api(
                operation='add',
                table='v2_bills',
                data=bill_data
            )
            
            if response.get('success'):
                print(f"✅ 선불크레딧 사용 내역 추가 성공")
                return {'success': True, 'bill_id': response.get('insert_id')}
            else:
                print(f"❌ 선불크레딧 사용 내역 추가 실패: {response.get('error', '알 수 없는 오류')}")
                return {'success': False, 'error': response.get('error', '알 수 없는 오류')}
                
        elif contract_type == 'time_pass':
            # 타석 정보 생성 (상단에 정의된 함수 사용)
            try:
                end_time = calculate_end_time(usage_time, selected_duration)
                ts_info = generate_ts_info(selected_ts, usage_time, end_time)
            except:
                ts_info = f"타석 예약 사용 (예약ID: {reservation_id})"
            
            # 시간권 사용 내역 추가
            bill_time_data = {
                'branch_id': branch_id,
                'member_id': member_id,
                'contract_history_id': contract_history_id,
                'bill_date': usage_date,
                'bill_type': DEFAULT_BILL_TYPE,
                'bill_text': ts_info,
                'bill_total_min': selected_duration,  # 총 시간
                'bill_discount_min': DEFAULT_BILL_DISCOUNT_MIN,  # 할인시간
                'bill_min': used_amount,  # 실제 과금시간 (차감시간)
                'bill_timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'bill_balance_min_before': before_balance,
                'bill_balance_min_after': after_balance,
                'bill_status': DEFAULT_BILL_STATUS,
                'reservation_id': reservation_id,
                'contract_TS_min_expiry_date': expiry_date if expiry_date else None
            }
            
            response = ApiClient.call_api(
                operation='add',
                table='v2_bill_times',
                data=bill_time_data
            )
            
            if response.get('success'):
                print(f"✅ 시간권 사용 내역 추가 성공")
                return {'success': True, 'bill_min_id': response.get('insert_id')}
            else:
                print(f"❌ 시간권 사용 내역 추가 실패: {response.get('error', '알 수 없는 오류')}")
                return {'success': False, 'error': response.get('error', '알 수 없는 오류')}
        
        return {'success': False, 'error': '지원하지 않는 계약 타입'}
    
    @staticmethod
    def process_reservation_with_selected_contract(
        branch_id: str,
        member_id: str,
        selected_date: str,
        selected_time: str,
        selected_duration: int,
        selected_ts: str,
        contract_type: str,
        contract_history_id: str,
        usage_amount: int,
        # 사용자 입력 파라미터들 추가
        ts_type: str = None,
        member_phone: str = None,
        term_discount: int = None,
        member_discount: int = None,
        junior_discount: int = None,
        routine_discount: int = None,
        overtime_discount: int = None,
        emergency_discount: int = None,
        revisit_discount: int = None,
        emergency_reason: str = None,
        total_discount: int = None,
        morning: int = None,
        normal: int = None,
        peak: int = None,
        night: int = None
    ) -> Dict[str, Any]:
        """선택된 계약으로 예약 처리"""
        print(f"\n🎯 선택된 계약으로 예약 처리 시작")
        print(f"   지점: {branch_id}, 회원: {member_id}")
        print(f"   날짜: {selected_date}, 시간: {selected_time}, 시간: {selected_duration}분")
        print(f"   타석: {selected_ts}")
        print(f"   계약: {contract_type} - {contract_history_id}")
        print(f"   사용량: {usage_amount}")
        
        # 1. 종료 시간 계산
        start_datetime = datetime.strptime(f"{selected_date} {selected_time}", "%Y-%m-%d %H:%M")
        end_datetime = start_datetime + timedelta(minutes=selected_duration)
        end_time = end_datetime.strftime("%H:%M")
        
        # 2. 중복 예약 체크
        is_duplicate = check_duplicate_reservation(
            branch_id, selected_ts, selected_date, selected_time, end_time
        )
        
        # 중복 예약이 있으면 처리 중단
        if is_duplicate:
            print("❌ 중복 예약으로 인해 예약이 불가능합니다.")
            return {'success': False, 'error': '중복 예약 - 해당 시간에 이미 예약이 존재합니다'}
        
        # 3. 예약 ID 생성 (중복이 없으므로 기본 형식 사용)
        reservation_id = generate_reservation_id(
            selected_date, selected_ts, selected_time, False
        )
        
        if not reservation_id:
            return {'success': False, 'error': '예약 ID 생성 실패'}
        
        print(f"생성된 예약 ID: {reservation_id}")
        
        # 4. 계약 타입 처리 (선불크레딧, 시간권만 지원)
        if contract_type in ['prepaid_credit', 'time_pass']:
            return TsDbUpdateService._process_contract_reservation(
                branch_id, member_id, selected_date, selected_time, selected_duration,
                selected_ts, contract_type, contract_history_id, usage_amount, reservation_id,
                # 사용자 입력값들 전달
                ts_type=ts_type,
                member_phone=member_phone,
                term_discount=term_discount,
                member_discount=member_discount,
                junior_discount=junior_discount,
                routine_discount=routine_discount,
                overtime_discount=overtime_discount,
                emergency_discount=emergency_discount,
                revisit_discount=revisit_discount,
                emergency_reason=emergency_reason,
                total_discount=total_discount,
                morning=morning,
                normal=normal,
                peak=peak,
                night=night
            )
        else:
            return {'success': False, 'error': '지원하지 않는 결제 방법입니다'}
    
    @staticmethod
    def _process_contract_reservation(
        branch_id: str, member_id: str, selected_date: str, selected_time: str,
        selected_duration: int, selected_ts: str, contract_type: str,
        contract_history_id: str, usage_amount: int, reservation_id: str,
        # 사용자 입력값들 전달
        ts_type: str = None,
        member_phone: str = None,
        term_discount: int = None,
        member_discount: int = None,
        junior_discount: int = None,
        routine_discount: int = None,
        overtime_discount: int = None,
        emergency_discount: int = None,
        revisit_discount: int = None,
        emergency_reason: str = None,
        total_discount: int = None,
        morning: int = None,
        normal: int = None,
        peak: int = None,
        night: int = None
    ) -> Dict[str, Any]:
        """계약 기반 예약 처리 (선불크레딧, 시간권)"""
        
        # 현재 잔액 조회
        balance_result = TsDbUpdateService.get_current_balance(
            contract_type, contract_history_id, branch_id, member_id
        )
        
        if not balance_result['success']:
            return {'success': False, 'error': '잔액 조회 실패'}
        
        current_balance = balance_result['balance']
        unit = balance_result['unit']
        
        # 잔액 확인
        if current_balance < usage_amount:
            print(f"❌ 잔액 부족: 현재 {current_balance:,}{unit}, 필요 {usage_amount:,}{unit}")
            return {'success': False, 'error': '잔액 부족'}
        
        # 차감 후 잔액 계산
        after_balance = current_balance - usage_amount
        
        # 예약 데이터 생성
        start_datetime = datetime.strptime(f"{selected_date} {selected_time}", "%Y-%m-%d %H:%M")
        end_datetime = start_datetime + timedelta(minutes=selected_duration)
        
        reservation_data = {
            'branch_id': branch_id,
            'member_id': member_id,
            'reservation_id': reservation_id,
            'ts_id': selected_ts,
            'ts_date': selected_date,
            'ts_start': selected_time + ':00',
            'ts_end': end_datetime.strftime("%H:%M:%S"),
            'ts_type': ts_type if ts_type else '일반',
            'ts_payment_method': contract_type,
            'ts_status': '결제완료',
            'member_name': f'회원{member_id}',
            'member_phone': member_phone if member_phone else '010-0000-0000',
            'total_amt': usage_amount if contract_type == 'prepaid_credit' else 0,
            'term_discount': term_discount if term_discount else 0,
            'member_discount': member_discount if member_discount else 0,
            'junior_discount': junior_discount if junior_discount else 0,
            'routine_discount': routine_discount if routine_discount else 0,
            'overtime_discount': overtime_discount if overtime_discount else 0,
            'emergency_discount': emergency_discount if emergency_discount else 0,
            'revisit_discount': revisit_discount if revisit_discount else 0,
            'emergency_reason': emergency_reason if emergency_reason else '',
            'total_discount': total_discount if total_discount else 0,
            'net_amt': usage_amount if contract_type == 'prepaid_credit' else 0,
            'morning': morning if morning else 0,
            'normal': normal if normal else 1,
            'peak': peak if peak else 0,
            'night': night if night else 0,
            'created_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }
        
        # 예약 데이터 삽입
        reservation_result = TsDbUpdateService.insert_reservation_data(reservation_data)
        
        if not reservation_result['success']:
            return {'success': False, 'error': '예약 데이터 삽입 실패'}
        
        # 계약 잔액 업데이트
        balance_update_result = TsDbUpdateService.update_contract_balance(
            contract_type, contract_history_id, branch_id, member_id,
            usage_amount, current_balance, after_balance,
            reservation_id, selected_date, selected_time,
            selected_ts, selected_duration
        )
        
        if not balance_update_result['success']:
            print(f"⚠️ 잔액 업데이트 실패하였지만 예약은 완료됨 (예약ID: {reservation_id})")
            return {
                'success': False, 
                'error': '잔액 업데이트 실패',
                'reservation_id': reservation_id
            }
        
        print(f"🎉 예약 처리 완료!")
        print(f"   예약ID: {reservation_id}")
        print(f"   차감 전 잔액: {current_balance:,}{unit}")
        print(f"   차감 후 잔액: {after_balance:,}{unit}")
        
        return {
            'success': True,
            'reservation_id': reservation_id,
            'before_balance': current_balance,
            'after_balance': after_balance,
            'used_amount': usage_amount,
            'unit': unit
        }

    @staticmethod
    def process_simple_payment_reservation(
        branch_id: str,
        member_id: str,
        selected_date: str,
        selected_time: str,
        selected_duration: int,
        selected_ts: str,
        payment_type: str,
        payment_amount: int,
        # 사용자 입력 파라미터들 추가
        ts_type: str = None,
        member_phone: str = None,
        term_discount: int = None,
        member_discount: int = None,
        junior_discount: int = None,
        routine_discount: int = None,
        overtime_discount: int = None,
        emergency_discount: int = None,
        revisit_discount: int = None,
        emergency_reason: str = None,
        total_discount: int = None,
        morning: int = None,
        normal: int = None,
        peak: int = None,
        night: int = None
    ) -> Dict[str, Any]:
        """카드결제/기업복지회원 예약 처리 (v2_priced_TS 테이블만 업데이트)"""
        print(f"\n🎯 심플 결제 예약 처리 시작")
        print(f"   지점: {branch_id}, 회원: {member_id}")
        print(f"   날짜: {selected_date}, 시간: {selected_time}, 시간: {selected_duration}분")
        print(f"   타석: {selected_ts}")
        print(f"   결제방법: {payment_type}")
        print(f"   결제금액: {payment_amount:,}원")
        
        # 1. 종료 시간 계산
        start_datetime = datetime.strptime(f"{selected_date} {selected_time}", "%Y-%m-%d %H:%M")
        end_datetime = start_datetime + timedelta(minutes=selected_duration)
        end_time = end_datetime.strftime("%H:%M")
        
        # 2. 중복 예약 체크
        is_duplicate = check_duplicate_reservation(
            branch_id, selected_ts, selected_date, selected_time, end_time
        )
        
        # 중복 예약이 있으면 처리 중단
        if is_duplicate:
            print("❌ 중복 예약으로 인해 예약이 불가능합니다.")
            return {'success': False, 'error': '중복 예약 - 해당 시간에 이미 예약이 존재합니다'}
        
        # 3. 예약 ID 생성 (중복이 없으므로 기본 형식 사용)
        reservation_id = generate_reservation_id(
            selected_date, selected_ts, selected_time, False
        )
        
        if not reservation_id:
            return {'success': False, 'error': '예약 ID 생성 실패'}
        
        print(f"생성된 예약 ID: {reservation_id}")
        
        # 4. 예약 데이터 생성 (사용자 입력값 또는 기본값 사용)
        reservation_data = {
            'branch_id': branch_id,
            'member_id': member_id,
            'reservation_id': reservation_id,
            'ts_id': selected_ts,
            'ts_date': selected_date,
            'ts_start': selected_time + ':00',
            'ts_end': end_datetime.strftime("%H:%M:%S"),
            'ts_type': ts_type if ts_type else DEFAULT_TS_TYPE,
            'ts_payment_method': payment_type,
            'ts_status': DEFAULT_BILL_STATUS,
            'member_name': f'회원{member_id}',
            'member_phone': member_phone if member_phone else DEFAULT_MEMBER_PHONE,
            'total_amt': payment_amount,
            'term_discount': term_discount if term_discount else DEFAULT_TERM_DISCOUNT,
            'member_discount': member_discount if member_discount else DEFAULT_MEMBER_DISCOUNT,
            'junior_discount': junior_discount if junior_discount else DEFAULT_JUNIOR_DISCOUNT,
            'routine_discount': routine_discount if routine_discount else DEFAULT_ROUTINE_DISCOUNT,
            'overtime_discount': overtime_discount if overtime_discount else DEFAULT_OVERTIME_DISCOUNT,
            'emergency_discount': emergency_discount if emergency_discount else DEFAULT_EMERGENCY_DISCOUNT,
            'revisit_discount': revisit_discount if revisit_discount else DEFAULT_REVISIT_DISCOUNT,
            'emergency_reason': emergency_reason if emergency_reason else DEFAULT_EMERGENCY_REASON,
            'total_discount': total_discount if total_discount else DEFAULT_TOTAL_DISCOUNT,
            'net_amt': payment_amount,
            'morning': morning if morning else DEFAULT_MORNING,
            'normal': normal if normal else DEFAULT_NORMAL,
            'peak': peak if peak else DEFAULT_PEAK,
            'night': night if night else DEFAULT_NIGHT,
            'created_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }
        
        # 5. 예약 데이터 삽입
        reservation_result = TsDbUpdateService.insert_reservation_data(reservation_data)
        
        if not reservation_result['success']:
            return {'success': False, 'error': '예약 데이터 삽입 실패'}
        
        print(f"🎉 예약 처리 완료!")
        print(f"   예약ID: {reservation_id}")
        print(f"   결제방법: {payment_type}")
        print(f"   결제금액: {payment_amount:,}원")
        
        return {
            'success': True,
            'reservation_id': reservation_id,
            'payment_type': payment_type,
            'payment_amount': payment_amount
        }

def check_duplicate_reservation(branch_id, ts_id, date, start_time, end_time):
    """중복 예약 체크"""
    try:
        print('\n=== 중복 예약 체크 ===')
        print(f'브랜치 ID: {branch_id}')
        print(f'타석 ID: {ts_id}')
        print(f'날짜: {date}')
        print(f'시작시간: {start_time}')
        print(f'종료시간: {end_time}')
        
        # 해당 날짜, 타석의 모든 예약 조회 (취소된 예약 제외)
        response = ApiClient.call_api(
            operation='get',
            table='v2_priced_TS',
            fields=['reservation_id', 'ts_start', 'ts_end', 'ts_status'],
            where=[
                {'field': 'branch_id', 'operator': '=', 'value': branch_id},
                {'field': 'ts_id', 'operator': '=', 'value': ts_id},
                {'field': 'ts_date', 'operator': '=', 'value': date},
                {'field': 'ts_status', 'operator': '<>', 'value': ApiConfig.DUPLICATE_EXCLUDE_STATUS}
            ]
        )
        
        if response.get('success') and response.get('data'):
            reservations = response['data']
            print(f'조회된 기존 예약 수: {len(reservations)}')
            
            # 시간 겹침 체크
            for reservation in reservations:
                existing_start = reservation.get('ts_start', '')
                existing_end = reservation.get('ts_end', '')
                reservation_id = reservation.get('reservation_id', '')
                
                if existing_start and existing_end:
                    # 시간 문자열에서 초 제거 (HH:mm 형태로 변환)
                    existing_start_time = existing_start[:5] if len(existing_start) > 5 else existing_start
                    existing_end_time = existing_end[:5] if len(existing_end) > 5 else existing_end
                    
                    print(f'기존 예약 {reservation_id}: {existing_start_time} ~ {existing_end_time}')
                    
                    # 시간 겹침 체크
                    if is_time_overlap(start_time, end_time, existing_start_time, existing_end_time):
                        print(f'❌ 시간 겹침 발견! 기존 예약: {existing_start_time} ~ {existing_end_time}')
                        return True  # 중복 발견
            
            print('✅ 시간 겹침 없음 - 중복 없음')
            return False  # 중복 없음
        else:
            print('기존 예약이 없음 - 중복 없음')
            return False
            
    except Exception as e:
        print(f'❌ 중복 예약 체크 오류: {e}')
        return False

def is_time_overlap(request_start, request_end, existing_start, existing_end):
    """시간 겹침 체크"""
    try:
        def time_to_minutes(time_str):
            parts = time_str.split(':')
            return int(parts[0]) * 60 + int(parts[1])
        
        req_start = time_to_minutes(request_start)
        req_end = time_to_minutes(request_end)
        exist_start = time_to_minutes(existing_start)
        exist_end = time_to_minutes(existing_end)
        
        # 겹침 체크: 시작시간이 기존 종료시간보다 작고, 종료시간이 기존 시작시간보다 크면 겹침
        return req_start < exist_end and req_end > exist_start
    except Exception as e:
        print(f'시간 겹침 체크 오류: {e}')
        return False

def generate_reservation_id(date, ts_id, start_time, is_duplicate=False):
    """예약 ID 생성"""
    try:
        # 날짜를 yymmdd 형식으로 변환
        date_obj = datetime.strptime(date, '%Y-%m-%d')
        date_part = date_obj.strftime('%y%m%d')
        
        # 시간을 hhmm 형식으로 변환
        time_part = start_time.replace(':', '')
        
        # 기본 reservation_id 생성
        base_reservation_id = f"{date_part}_{ts_id}_{time_part}"
        
        # 중복이 있으면 타임스탬프 추가
        if is_duplicate:
            timestamp = datetime.now().strftime('%H%M%S')
            reservation_id = f"{base_reservation_id}_{timestamp}"
            print(f'중복으로 인한 타임스탬프 추가: {reservation_id}')
        else:
            reservation_id = base_reservation_id
            
        return reservation_id
        
    except Exception as e:
        print(f'예약 ID 생성 오류: {e}')
        return None

def get_user_input_with_default(prompt: str, default_value: Any, input_type: type = str) -> Any:
    """사용자 입력을 받되, 기본값을 제공하는 함수"""
    user_input = input(f"{prompt} (기본값: {default_value}): ").strip()
    if not user_input:
        return default_value
    
    try:
        if input_type == int:
            return int(user_input)
        elif input_type == float:
            return float(user_input)
        else:
            return user_input
    except ValueError:
        print(f"❌ 잘못된 입력 형식입니다. 기본값 {default_value}를 사용합니다.")
        return default_value

def get_required_input(prompt: str, input_type: type = str) -> Any:
    """필수 입력을 받는 함수"""
    while True:
        user_input = input(f"{prompt} (필수): ").strip()
        if user_input:
            try:
                if input_type == int:
                    return int(user_input)
                elif input_type == float:
                    return float(user_input)
                else:
                    return user_input
            except ValueError:
                print(f"❌ 잘못된 입력 형식입니다. 다시 입력해주세요.")
        else:
            print("❌ 필수 입력 항목입니다. 값을 입력해주세요.")

def main():
    """메인 실행 함수"""
    print("🏌️ 타석 예약 DB 업데이트 테스트")
    print("=" * 50)
    
    # 테스트 데이터 입력
    try:
        print("\n📋 예약 정보를 입력하세요:")
        print("=" * 30)
        print("🔴 필수 입력 항목")
        
        # 필수 입력 항목들 (하드코딩 제거됨)
        branch_id = get_required_input("지점 ID")
        member_id = get_required_input("회원 ID")
        selected_date = get_required_input("예약 날짜 (YYYY-MM-DD)")
        selected_time = get_required_input("예약 시간 (HH:MM)")
        selected_duration = get_required_input("연습 시간 (분)", int)
        selected_ts = get_required_input("타석 번호")
        
        print("\n🟡 선택 입력 항목 (예약 데이터 설정)")
        print("(입력하지 않으면 기본값 사용)")
        
        # 선택 입력 항목들 (예약 데이터)
        ts_type = get_user_input_with_default("타석 타입", DEFAULT_TS_TYPE)
        member_phone = get_user_input_with_default("회원 전화번호", DEFAULT_MEMBER_PHONE)
        term_discount = get_user_input_with_default("기간 할인", DEFAULT_TERM_DISCOUNT, int)
        member_discount = get_user_input_with_default("회원 할인", DEFAULT_MEMBER_DISCOUNT, int)
        junior_discount = get_user_input_with_default("주니어 할인", DEFAULT_JUNIOR_DISCOUNT, int)
        routine_discount = get_user_input_with_default("정기 할인", DEFAULT_ROUTINE_DISCOUNT, int)
        overtime_discount = get_user_input_with_default("연장 할인", DEFAULT_OVERTIME_DISCOUNT, int)
        emergency_discount = get_user_input_with_default("긴급 할인", DEFAULT_EMERGENCY_DISCOUNT, int)
        revisit_discount = get_user_input_with_default("재방문 할인", DEFAULT_REVISIT_DISCOUNT, int)
        emergency_reason = get_user_input_with_default("긴급 사유", DEFAULT_EMERGENCY_REASON)
        
        # 시간대 설정
        print("\n시간대 설정 (0 또는 1로 입력):")
        morning = get_user_input_with_default("오전 시간대", DEFAULT_MORNING, int)
        normal = get_user_input_with_default("일반 시간대", DEFAULT_NORMAL, int)
        peak = get_user_input_with_default("피크 시간대", DEFAULT_PEAK, int)
        night = get_user_input_with_default("야간 시간대", DEFAULT_NIGHT, int)
        
        # 할인 총액 계산 (상단에 정의된 함수 사용)
        total_discount = calculate_total_discount(
            term_discount, member_discount, junior_discount, 
            routine_discount, overtime_discount, emergency_discount, revisit_discount
        )
        
        print("\n📋 결제 방법을 선택하세요:")
        print("1=선불크레딧, 2=시간권, 3=카드결제, 4=기업복지회원")
        payment_type_input = get_required_input("결제 방법 (1-4)")
        
        # 결제 방법 이름 가져오기 (상단에 정의된 함수 사용)
        payment_method_name = get_payment_method_name(payment_type_input)
        contract_type = get_contract_type(payment_type_input)
        
        # 결제 방법에 따른 처리
        if payment_type_input in ['1', '2']:
            # 계약 기반 결제 (선불크레딧, 시간권)
            contract_history_id = get_required_input("계약 히스토리 ID")
            
            if payment_type_input == '1':
                usage_amount = get_required_input("사용 금액 (원)", int)
            else:
                usage_amount = get_required_input("사용 시간 (분)", int)
            
            print(f"\n🎯 입력된 정보:")
            print(f"   지점: {branch_id}")
            print(f"   회원: {member_id}")
            print(f"   예약: {selected_date} {selected_time} ({selected_duration}분)")
            print(f"   타석: {selected_ts}")
            print(f"   계약: {payment_method_name} - {contract_history_id}")
            print(f"   사용량: {usage_amount:,}")
            print(f"   총 할인: {total_discount:,}")
            
            confirm = input("\n계속 진행하시겠습니까? (y/N): ").strip().lower()
            if confirm != 'y':
                print("테스트를 취소합니다.")
                return
            
            # 예약 처리 실행 (사용자 입력값들을 전달)
            result = TsDbUpdateService.process_reservation_with_selected_contract(
                branch_id=branch_id,
                member_id=member_id,
                selected_date=selected_date,
                selected_time=selected_time,
                selected_duration=selected_duration,
                selected_ts=selected_ts,
                contract_type=contract_type,
                contract_history_id=contract_history_id,
                usage_amount=usage_amount,
                # 사용자 입력값들 추가
                ts_type=ts_type,
                member_phone=member_phone,
                term_discount=term_discount,
                member_discount=member_discount,
                junior_discount=junior_discount,
                routine_discount=routine_discount,
                overtime_discount=overtime_discount,
                emergency_discount=emergency_discount,
                revisit_discount=revisit_discount,
                emergency_reason=emergency_reason,
                total_discount=total_discount,
                morning=morning,
                normal=normal,
                peak=peak,
                night=night
            )
            
            print(f"\n{'='*50}")
            if result['success']:
                print("🎉 예약 처리 성공!")
                print(f"   예약 ID: {result['reservation_id']}")
                if 'before_balance' in result:
                    print(f"   차감 전 잔액: {result['before_balance']:,}{result['unit']}")
                    print(f"   사용량: {result['used_amount']:,}{result['unit']}")
                    print(f"   차감 후 잔액: {result['after_balance']:,}{result['unit']}")
                else:
                    print(f"   결제수단: {payment_method_name}")
                    print(f"   결제금액: {usage_amount:,}")
            else:
                print("❌ 예약 처리 실패!")
                print(f"   오류: {result['error']}")
                if 'reservation_id' in result:
                    print(f"   예약 ID: {result['reservation_id']} (예약은 완료됨)")
        
        elif payment_type_input in ['3', '4']:
            # 심플 결제 (카드결제, 기업복지회원)
            payment_amount = get_required_input("결제 금액 (원)", int)
            
            print(f"\n🎯 입력된 정보:")
            print(f"   지점: {branch_id}")
            print(f"   회원: {member_id}")
            print(f"   예약: {selected_date} {selected_time} ({selected_duration}분)")
            print(f"   타석: {selected_ts}")
            print(f"   결제방법: {payment_method_name}")
            print(f"   결제금액: {payment_amount:,}원")
            print(f"   총 할인: {total_discount:,}")
            
            confirm = input("\n계속 진행하시겠습니까? (y/N): ").strip().lower()
            if confirm != 'y':
                print("테스트를 취소합니다.")
                return
            
            # 심플 결제 예약 처리 실행 (사용자 입력값들을 전달)
            result = TsDbUpdateService.process_simple_payment_reservation(
                branch_id=branch_id,
                member_id=member_id,
                selected_date=selected_date,
                selected_time=selected_time,
                selected_duration=selected_duration,
                selected_ts=selected_ts,
                payment_type=contract_type,
                payment_amount=payment_amount,
                # 사용자 입력값들 추가
                ts_type=ts_type,
                member_phone=member_phone,
                term_discount=term_discount,
                member_discount=member_discount,
                junior_discount=junior_discount,
                routine_discount=routine_discount,
                overtime_discount=overtime_discount,
                emergency_discount=emergency_discount,
                revisit_discount=revisit_discount,
                emergency_reason=emergency_reason,
                total_discount=total_discount,
                morning=morning,
                normal=normal,
                peak=peak,
                night=night
            )
            
            print(f"\n{'='*50}")
            if result['success']:
                print("🎉 예약 처리 성공!")
                print(f"   예약 ID: {result['reservation_id']}")
                print(f"   결제방법: {payment_method_name}")
                print(f"   결제금액: {result['payment_amount']:,}원")
            else:
                print("❌ 예약 처리 실패!")
                print(f"   오류: {result['error']}")
        
        else:
            print("❌ 잘못된 결제 방법입니다. 1-4 중에서 선택해주세요.")
            return
    
    except KeyboardInterrupt:
        print("\n\n테스트가 중단되었습니다.")
    except Exception as e:
        print(f"\n❌ 예상치 못한 오류가 발생했습니다: {e}")

# =============================================================================
# 계산 함수들 (비즈니스 로직 정의)
# =============================================================================

def calculate_total_discount(term_discount, member_discount, junior_discount, 
                           routine_discount, overtime_discount, emergency_discount, 
                           revisit_discount):
    """총 할인 금액 계산"""
    return term_discount + member_discount + junior_discount + routine_discount + overtime_discount + emergency_discount + revisit_discount

def calculate_end_time(start_time, duration_minutes):
    """시작 시간과 연습 시간을 기반으로 종료 시간 계산"""
    from datetime import datetime, timedelta
    start_datetime = datetime.strptime(start_time, "%H:%M")
    end_datetime = start_datetime + timedelta(minutes=duration_minutes)
    return end_datetime.strftime("%H:%M")

def generate_ts_info(ts_number, start_time, end_time):
    """타석 정보 문자열 생성 (예: "1번 타석(10:00 ~ 11:00)")"""
    return f"{ts_number}번 타석({start_time} ~ {end_time})"

def calculate_balance_after_usage(current_balance, usage_amount):
    """사용 후 잔액 계산"""
    return current_balance - usage_amount

def is_balance_sufficient(current_balance, required_amount):
    """잔액 충분 여부 확인"""
    return current_balance >= required_amount

def get_payment_method_name(payment_type_input):
    """결제 방법 번호를 이름으로 변환"""
    payment_methods = {
        '1': '선불크레딧',
        '2': '시간권',
        '3': '카드결제',
        '4': '기업복지회원'
    }
    return payment_methods.get(payment_type_input, '알 수 없음')

def get_contract_type(payment_type_input):
    """결제 방법 번호를 계약 타입으로 변환"""
    contract_types = {
        '1': 'prepaid_credit',
        '2': 'time_pass',
        '3': 'card_payment',
        '4': 'corporate_welfare'
    }
    return contract_types.get(payment_type_input)

def get_expiry_date_field_name(contract_type):
    """계약 타입에 따른 만료일 필드명 반환"""
    field_names = {
        'prepaid_credit': 'contract_credit_expiry_date',
        'time_pass': 'contract_TS_min_expiry_date'
    }
    return field_names.get(contract_type)

def get_expiry_date_table_name(contract_type):
    """계약 타입에 따른 만료일 조회 테이블명 반환"""
    table_names = {
        'prepaid_credit': 'v2_bills',
        'time_pass': 'v2_bill_times'
    }
    return table_names.get(contract_type)

def format_expiry_date_display(contract_type, expiry_date):
    """만료일 표시 형식 포맷팅"""
    if not expiry_date or expiry_date == 'null' or not expiry_date.strip():
        return ''
    
    contract_names = {
        'prepaid_credit': '선불크레딧',
        'time_pass': '시간권'
    }
    contract_name = contract_names.get(contract_type, '계약')
    return f"{contract_name} 만료일: {expiry_date}"

def is_valid_expiry_date(expiry_date):
    """만료일이 유효한지 확인"""
    return expiry_date and expiry_date != 'null' and expiry_date.strip()

if __name__ == "__main__":
    main() 