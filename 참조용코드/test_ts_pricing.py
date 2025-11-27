#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
타석 요금 계산 테스트 (ts_pricing.dart)
- 터미널에서 순차적으로 입력받아 테스트
- 실제 API 호출로 검증
"""

import json
import requests
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
import sys

# =============================================================================
# API 설정
# =============================================================================

class ApiConfig:
    BASE_URL = 'https://autofms.mycafe24.com/dynamic_api.php'
    HEADERS = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'PricingTestApp/1.0'
    }

class HolidayService:
    """공휴일 관련 서비스"""
    
    @staticmethod
    def is_holiday(date):
        """공휴일 여부 확인"""
        try:
            # 일요일은 기본적으로 공휴일로 처리
            if date.weekday() == 6:  # 일요일 (0=월요일, 6=일요일)
                print(f'일요일이므로 공휴일로 처리: {date.strftime("%Y-%m-%d")}')
                return True
            
            # 주요 공휴일 체크
            month = date.month
            day = date.day
            
            # 신정
            if month == 1 and day == 1:
                print(f'신정이므로 공휴일: {date.strftime("%Y-%m-%d")}')
                return True
            
            # 어린이날
            if month == 5 and day == 5:
                print(f'어린이날이므로 공휴일: {date.strftime("%Y-%m-%d")}')
                return True
            
            # 현충일
            if month == 6 and day == 6:
                print(f'현충일이므로 공휴일: {date.strftime("%Y-%m-%d")}')
                return True
            
            # 광복절
            if month == 8 and day == 15:
                print(f'광복절이므로 공휴일: {date.strftime("%Y-%m-%d")}')
                return True
            
            # 개천절
            if month == 10 and day == 3:
                print(f'개천절이므로 공휴일: {date.strftime("%Y-%m-%d")}')
                return True
            
            # 한글날
            if month == 10 and day == 9:
                print(f'한글날이므로 공휴일: {date.strftime("%Y-%m-%d")}')
                return True
            
            # 크리스마스
            if month == 12 and day == 25:
                print(f'크리스마스이므로 공휴일: {date.strftime("%Y-%m-%d")}')
                return True
            
            print(f'평일로 처리: {date.strftime("%Y-%m-%d")}')
            return False
            
        except Exception as e:
            print(f'공휴일 확인 오류: {e}')
            return False
    
    @staticmethod
    def get_korean_day_of_week(date):
        """요일 문자열 변환"""
        weekdays = ['월', '화', '수', '목', '금', '토', '일']
        return weekdays[date.weekday()]

class ApiClient:
    @staticmethod
    def call_api(operation: str, table: str, **kwargs) -> Dict[str, Any]:
        """API 호출"""
        request_data = {
            'operation': operation,
            'table': table,
            **kwargs
        }
        
        print(f"🌐 API 호출: {operation} {table}")
        
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
# 타석 요금 계산 서비스
# =============================================================================

class TsPricingService:
    """타석 요금 계산 서비스"""
    
    def __init__(self):
        self.api_client = ApiClient()
    
    def calculate_pricing(self, branch_id: str, selected_date: str, selected_time: str,
                         selected_duration: int, selected_ts: str) -> Optional[Dict[str, Any]]:
        """요금 계산"""
        print(f"\n💰 타석 요금 계산 시작")
        print(f"   지점: {branch_id}")
        print(f"   날짜: {selected_date}")
        print(f"   시간: {selected_time}")
        print(f"   연습시간: {selected_duration}분")
        print(f"   타석: {selected_ts}")
        print("-" * 50)
        
        try:
            # 1. 종료 시간 계산
            end_time = self.calculate_end_time(selected_time, selected_duration)
            print(f"📅 종료 시간: {end_time}")
            
            # 2. 타석 정보 조회
            ts_info = self.get_ts_info(branch_id, selected_ts)
            if not ts_info:
                print("❌ 타석 정보 조회 실패")
                return None
            
            print(f"🏌️ 타석 정보:")
            print(f"   - 기본 요금: {ts_info.get('base_price', 0)}원/시간")
            print(f"   - 할인 요금: {ts_info.get('discount_price', 0)}원/시간")
            print(f"   - 할증 요금: {ts_info.get('extracharge_price', 0)}원/시간")
            
            # 3. 요금 정책 조회
            pricing_policies = self.get_pricing_policies(branch_id, selected_date)
            if not pricing_policies:
                print("❌ 요금 정책 조회 실패")
                return None
            
            print(f"📋 요금 정책: {len(pricing_policies)}개")
            for policy in pricing_policies:
                print(f"   - {policy.get('policy_start_time', '')} ~ {policy.get('policy_end_time', '')}: {policy.get('policy_apply', '')}")
            
            # 4. 시간대별 분석
            time_analysis = self.analyze_pricing_by_time_range(
                selected_time, end_time, pricing_policies
            )
            
            print(f"⏰ 시간대별 분석:")
            for policy_type, minutes in time_analysis.items():
                print(f"   - {policy_type}: {minutes}분")
            
            # 5. 최종 요금 계산
            price_analysis = self.calculate_final_pricing(ts_info, time_analysis)
            
            print(f"💵 요금 분석:")
            for policy_type, price in price_analysis.items():
                print(f"   - {policy_type}: {price}원")
            
            # 6. 총 요금
            total_price = sum(price_analysis.values())
            
            result = {
                'time_analysis': time_analysis,
                'price_analysis': price_analysis,
                'total_price': total_price,
                'total_minutes': selected_duration,
                'end_time': end_time,
                'ts_info': ts_info
            }
            
            print(f"💎 총 요금: {total_price}원")
            return result
            
        except Exception as e:
            print(f"❌ 요금 계산 오류: {e}")
            return None
    
    def calculate_end_time(self, start_time: str, duration_minutes: int) -> str:
        """종료 시간 계산"""
        try:
            hour, minute = map(int, start_time.split(':'))
            total_minutes = hour * 60 + minute + duration_minutes
            end_hour = (total_minutes // 60) % 24
            end_minute = total_minutes % 60
            return f"{end_hour:02d}:{end_minute:02d}"
        except:
            return "00:00"
    
    def get_ts_info(self, branch_id: str, ts_id: str) -> Optional[Dict[str, Any]]:
        """타석 정보 조회"""
        print(f"📍 타석 정보 조회 중... (타석: {ts_id})")
        
        result = self.api_client.call_api(
            operation='get',
            table='v2_ts_info',
            fields=['base_price', 'discount_price', 'extracharge_price'],
            where=[
                {'field': 'branch_id', 'operator': '=', 'value': branch_id},
                {'field': 'ts_id', 'operator': '=', 'value': ts_id}
            ],
            limit=1
        )
        
        if result.get('success') and result.get('data'):
            print(f"✅ 타석 정보 조회 완료")
            return result['data'][0]
        else:
            print(f"❌ 타석 정보 조회 실패: {result.get('error')}")
            return None
    
    def get_pricing_policies(self, branch_id: str, selected_date: str) -> List[Dict[str, Any]]:
        """요금 정책 조회"""
        print(f"📋 요금 정책 조회 중... (지점: {branch_id})")
        
        # 날짜 파싱
        try:
            date_obj = datetime.strptime(selected_date, '%Y-%m-%d')
            
            # 공휴일 여부 확인
            is_holiday = HolidayService.is_holiday(date_obj)
            day_of_week = HolidayService.get_korean_day_of_week(date_obj)
            
            print(f"📅 날짜 분석: {selected_date}")
            print(f"📅 요일: {day_of_week}")
            print(f"📅 공휴일: {is_holiday}")
            
        except Exception as e:
            print(f"❌ 날짜 파싱 오류: {e}")
            return []
        
        result = self.api_client.call_api(
            operation='get',
            table='v2_ts_pricing_policy',
            fields=['policy_start_time', 'policy_end_time', 'policy_apply'],
            where=[
                {'field': 'branch_id', 'operator': '=', 'value': branch_id},
                {'field': 'day_of_week', 'operator': '=', 'value': day_of_week}
            ],
            order_by=[{'field': 'policy_start_time', 'direction': 'ASC'}]
        )
        
        if result and result.get('success'):
            policies = result.get('data', [])
            print(f"✅ 요금 정책 조회 완료: {len(policies)}개")
            print(f"📋 {day_of_week} 요일 정책: {len(policies)}개")
            
            for policy in policies:
                print(f"   - {policy['policy_start_time']} ~ {policy['policy_end_time']}: {policy['policy_apply']}")
            
            return policies
        else:
            print("❌ 요금 정책 조회 실패")
            return []
    
    def analyze_pricing_by_time_range(self, start_time: str, end_time: str,
                                     pricing_policies: List[Dict[str, Any]]) -> Dict[str, int]:
        """시간대별 요금 분석"""
        def time_to_minutes(time_str: str) -> int:
            # HH:MM:SS 또는 HH:MM 형식 모두 처리
            time_parts = time_str.split(':')
            hour = int(time_parts[0])
            minute = int(time_parts[1])
            return hour * 60 + minute
        
        start_minutes = time_to_minutes(start_time)
        end_minutes = time_to_minutes(end_time)
        
        # 다음날로 넘어가는 경우 처리
        if end_minutes <= start_minutes:
            end_minutes += 24 * 60
        
        print(f"🔍 시간 분석 디버깅:")
        print(f"   시작: {start_time} ({start_minutes}분)")
        print(f"   종료: {end_time} ({end_minutes}분)")
        print(f"   총 시간: {end_minutes - start_minutes}분")
        
        # 시간대별 분석을 위한 시간 슬롯 생성
        time_slots = []
        
        for policy in pricing_policies:
            policy_start = time_to_minutes(policy['policy_start_time'])
            policy_end = time_to_minutes(policy['policy_end_time'])
            
            # 다음날로 넘어가는 정책 처리
            if policy_end <= policy_start:
                policy_end += 24 * 60
            
            # 겹치는 시간 계산
            overlap_start = max(start_minutes, policy_start)
            overlap_end = min(end_minutes, policy_end)
            
            if overlap_start < overlap_end:
                overlap_minutes = overlap_end - overlap_start
                policy_type = policy['policy_apply']
                
                # 중복 방지를 위해 시간 슬롯 저장
                time_slots.append({
                    'start': overlap_start,
                    'end': overlap_end,
                    'minutes': overlap_minutes,
                    'policy_type': policy_type
                })
        
        # 시간 슬롯 정렬 (시작 시간 기준)
        time_slots.sort(key=lambda x: x['start'])
        
        # 중복 제거 및 정확한 시간 계산
        merged_slots = []
        for slot in time_slots:
            # 기존 슬롯과 겹치는지 확인
            merged = False
            for existing in merged_slots:
                if (slot['start'] >= existing['start'] and 
                    slot['start'] < existing['end']):
                    # 겹치는 경우 - 우선순위가 높은 정책 적용
                    # (여기서는 첫 번째 정책을 우선으로 함)
                    merged = True
                    break
            
            if not merged:
                merged_slots.append(slot)
        
        # 최종 시간 분석
        time_analysis = {}
        total_calculated = 0
        
        print(f"📋 병합된 시간 슬롯:")
        for slot in merged_slots:
            policy_type = slot['policy_type']
            minutes = slot['minutes']
            
            print(f"   {slot['start']}~{slot['end']} ({minutes}분): {policy_type}")
            
            time_analysis[policy_type] = time_analysis.get(policy_type, 0) + minutes
            total_calculated += minutes
        
        print(f"✅ 계산된 총 시간: {total_calculated}분")
        
        return time_analysis
    
    def calculate_final_pricing(self, ts_info: Dict[str, Any], time_analysis: Dict[str, int]) -> Dict[str, int]:
        """최종 요금 계산"""
        price_analysis = {}
        
        for policy_key, minutes in time_analysis.items():
            if minutes > 0:
                # 정책 타입에 따른 시간당 요금 결정
                if policy_key == 'base_price':
                    price_per_hour = ts_info.get('base_price', 0) or 0
                elif policy_key == 'discount_price':
                    price_per_hour = ts_info.get('discount_price', 0) or 0
                elif policy_key == 'extracharge_price':
                    price_per_hour = ts_info.get('extracharge_price', 0) or 0
                else:
                    price_per_hour = ts_info.get('base_price', 0) or 0
                
                # 분당 요금 계산 (시간당 요금 / 60)
                final_price = round((price_per_hour / 60) * minutes)
                price_analysis[policy_key] = final_price
        
        return price_analysis

# =============================================================================
# 메인 실행부
# =============================================================================

def get_user_input():
    """사용자 입력 받기"""
    print("💰 타석 요금 계산 테스트")
    print("=" * 50)
    
    branch_id = input("지점 ID를 입력하세요: ").strip()
    selected_date = input("예약 날짜를 입력하세요 (YYYY-MM-DD): ").strip()
    selected_time = input("예약 시간을 입력하세요 (HH:MM): ").strip()
    selected_ts = input("타석 ID를 입력하세요: ").strip()
    
    while True:
        try:
            selected_duration = int(input("연습시간을 입력하세요 (분): ").strip())
            break
        except ValueError:
            print("❌ 숫자를 입력해주세요.")
    
    return branch_id, selected_date, selected_time, selected_ts, selected_duration

def display_results(result: Optional[Dict[str, Any]]):
    """결과 출력"""
    print("\n" + "=" * 50)
    print("💰 타석 요금 계산 결과")
    print("=" * 50)
    
    if not result:
        print("❌ 요금 계산 결과가 없습니다.")
        return
    
    print(f"⏰ 연습시간: {result['total_minutes']}분")
    print(f"🕐 종료시간: {result['end_time']}")
    print()
    
    print("📊 시간대별 분석:")
    for policy_type, minutes in result['time_analysis'].items():
        print(f"   🔹 {policy_type}: {minutes}분")
    print()
    
    print("💵 요금 분석:")
    for policy_type, price in result['price_analysis'].items():
        print(f"   💎 {policy_type}: {price:,}원")
    print()
    
    print("=" * 50)
    print(f"💰 총 요금: {result['total_price']:,}원")
    print("=" * 50)

def main():
    """메인 실행 함수"""
    try:
        service = TsPricingService()
        
        # 사용자 입력 받기
        branch_id, selected_date, selected_time, selected_ts, selected_duration = get_user_input()
        
        # 타석 요금 계산
        result = service.calculate_pricing(
            branch_id, selected_date, selected_time, selected_duration, selected_ts
        )
        
        # 결과 출력
        display_results(result)
        
        # 재실행 여부 확인
        print("\n" + "=" * 50)
        retry = input("다시 테스트하시겠습니까? (y/n): ").strip().lower()
        if retry == 'y':
            print("\n")
            main()
        else:
            print("🎉 테스트 완료!")
            
    except KeyboardInterrupt:
        print("\n\n⚠️  사용자에 의해 중단되었습니다.")
    except Exception as e:
        print(f"\n❌ 오류 발생: {e}")

if __name__ == '__main__':
    main() 