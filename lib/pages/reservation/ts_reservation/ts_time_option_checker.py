#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
타석 예약 시간 옵션 체커
사용자가 입력한 조건(지점, 회원, 날짜, 연습시간)에 따라 
가능한 시작시간과 타석을 추천해주는 도구

필수 입력 항목:
- 지점 ID (branch_id): 예약할 지점의 고유 ID
- 회원 ID (member_id): 예약하는 회원의 고유 ID
- 예약 날짜 (selected_date): 예약 날짜 (YYYY-MM-DD 형식)
- 연습 시간 (duration_minutes): 연습 시간 (분 단위)

API 설계 및 데이터 처리 방식:
1. 데이터 수집 단계 (API 호출 최소화)
   - 기본 검증: 날짜, 영업시간, 회원 정보를 한 번에 검증
   - 타석 정보: 사용 가능한 모든 타석 정보를 한 번에 조회y
   - 예약 데이터: 해당 날짜의 모든 예약을 한 번에 조회
   - 시간 슬롯: 5분 단위 시간대를 로컬에서 생성

2. 로컬 처리 단계 (프론트엔드 로직 구현)
   - 타석별 예약 데이터 전처리: 조회한 예약 데이터를 타석별로 분류
   - 시간 충돌 검사: 각 시간대별로 타석 예약 가능 여부를 로컬에서 계산
   - 버퍼 시간 적용: 타석별 버퍼 시간을 고려한 충돌 검사
   - 결과 생성: 시간대별 예약 가능한 타석 목록 반환

검증 조건:
- 타석 상태: '예약가능' 상태인 타석만 선별
- 시간 제한: 연습시간이 타석별 최소/최대 시간 범위 내인지 확인
- 회원 타입 제한: 특정 회원 타입에 대한 타석 사용 제한 확인
- 영업시간 범위: 예약 시간이 영업시간 내인지 확인
- 당일 예약 제한: 오늘 날짜는 현재 시간 이후로만 예약 가능

장점:
- API 호출 최소화: 기존 방식 대비 수백 배 적은 API 호출
- 빠른 처리: 모든 계산을 로컬에서 수행
- Flutter 앱과 동일한 로직: 실제 앱에서도 같은 방식으로 구현 가능

참고: 모든 API 호출에서 branch_id는 필수 파라미터로 사용됨
"""

import requests
import json
from datetime import datetime, timedelta
from typing import Dict, List, Any, Tuple
from ts_availability_checker import ApiClient, TsAvailabilityChecker

class TsTimeOptionChecker:
    def __init__(self):
        self.api_client = ApiClient()
        self.availability_checker = TsAvailabilityChecker()
        
    def get_available_time_options(self, branch_id: str, member_id: str, 
                                 selected_date: str, duration_minutes: int) -> Dict[str, Any]:
        """
        주어진 조건에서 가능한 시작시간 옵션들을 찾아서 반환
        
        Args:
            branch_id: 지점 ID
            member_id: 회원 ID  
            selected_date: 예약 날짜 (YYYY-MM-DD)
            duration_minutes: 연습 시간 (분)
            
        Returns:
            Dict: 시간별 가능한 타석 목록
        """
        try:
            print(f"\n🔍 예약 가능 시간 옵션 검색 시작")
            print(f"📍 지점 ID: {branch_id}")
            print(f"👤 회원 ID: {member_id}")
            print(f"📅 예약 날짜: {selected_date}")
            print(f"⏱️  연습 시간: {duration_minutes}분")
            print("="*60)
            
            # 1. 모든 필요한 데이터를 한 번에 수집
            print("\n📦 필요한 데이터 수집 중...")
            all_data = self._fetch_all_required_data(branch_id, member_id, selected_date, duration_minutes)
            if not all_data['success']:
                return all_data
            
            # 2. 수집된 데이터를 사용해서 프론트엔드 로직 구현
            print("\n🔄 시간 옵션 처리 중...")
            available_options = self._process_time_options_locally(all_data, duration_minutes, selected_date)
            
            print(f"\n📊 검색 결과: {len(available_options)}개 시간대에서 예약 가능")
            
            return {
                'success': True,
                'available_options': available_options,
                'total_time_slots': all_data['total_time_slots'],
                'available_time_slots': len(available_options),
                'schedule_info': all_data['schedule_info'],
                'available_ts_count': len(all_data['available_ts_list'])
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': f'시간 옵션 검색 중 오류: {str(e)}'
            }
    
    def _validate_basic_conditions(self, branch_id: str, member_id: str, 
                                  selected_date: str, duration_minutes: int) -> Dict[str, Any]:
        """기본 조건 검증 (날짜, 영업시간, 회원 정보)"""
        try:
            # 기본 정보 검증
            basic_validation = self.availability_checker._validate_basic_info(
                branch_id, member_id, "1", selected_date, "09:00", duration_minutes
            )
            if not basic_validation['success']:
                return basic_validation
            
            # 스케줄 검증  
            schedule_validation = self.availability_checker._validate_schedule(
                selected_date, "09:00", duration_minutes, branch_id
            )
            if not schedule_validation['success']:
                return schedule_validation
            
            return {
                'success': True,
                'schedule_info': schedule_validation['schedule_info']
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': f'기본 조건 검증 중 오류: {str(e)}'
            }
    
    def _get_available_ts_list(self, branch_id: str, member_id: str, duration_minutes: int) -> List[Dict[str, Any]]:
        """사용 가능한 타석 목록 조회"""
        try:
            # 모든 타석 정보 조회
            response = self.api_client.call_api(
                operation='get',
                table='v2_ts_info',
                fields=['ts_id', 'ts_status', 'ts_min_minimum', 'ts_min_maximum', 'ts_buffer', 'member_type_prohibited'],
                where=[
                    {'field': 'branch_id', 'operator': '=', 'value': branch_id}
                ],
                orderBy=[
                    {'field': 'ts_id', 'direction': 'ASC'}
                ]
            )
            
            if not response.get('success') or not response.get('data'):
                return []
            
            # 회원 타입 조회
            member_response = self.api_client.call_api(
                operation='get',
                table='v3_members',
                fields=['member_type'],
                where=[
                    {'field': 'member_id', 'operator': '=', 'value': member_id},
                    {'field': 'branch_id', 'operator': '=', 'value': branch_id}
                ]
            )
            
            member_type = ''
            if member_response.get('success') and member_response.get('data'):
                member_type = member_response['data'][0].get('member_type', '')
            
            available_ts_list = []
            
            for ts_info in response['data']:
                # 1. 타석 상태 확인
                if ts_info.get('ts_status') != '예약가능':
                    continue
                
                # 2. 최소/최대 시간 확인
                min_minimum = float(ts_info.get('ts_min_minimum', 0))
                min_maximum = float(ts_info.get('ts_min_maximum', 999))
                
                if duration_minutes < min_minimum or duration_minutes > min_maximum:
                    continue
                
                # 3. 회원 타입 제한 확인
                member_type_prohibited = ts_info.get('member_type_prohibited', '')
                if member_type_prohibited and member_type:
                    prohibited_types = [t.strip() for t in member_type_prohibited.split(',')]
                    if member_type in prohibited_types:
                        continue
                
                available_ts_list.append(ts_info)
            
            return available_ts_list
            
        except Exception as e:
            print(f"사용 가능한 타석 조회 중 오류: {e}")
            return []
    
    def _generate_time_slots(self, business_start: str, business_end: str, 
                           duration_minutes: int, selected_date: str) -> List[str]:
        """5분 단위 시간 슬롯 생성"""
        try:
            time_slots = []
            
            # 시작/종료 시간을 분으로 변환
            start_minutes = self._time_to_minutes(business_start)
            end_minutes = self._time_to_minutes(business_end)
            
            # 00:00인 경우 24:00(1440분)으로 처리
            if end_minutes == 0:
                end_minutes = 1440
            
            # 오늘 날짜인 경우 현재 시간 이후로 제한
            today = datetime.now().date()
            selected_date_obj = datetime.strptime(selected_date, '%Y-%m-%d').date()
            
            if selected_date_obj == today:
                now = datetime.now()
                current_minutes = now.hour * 60 + now.minute
                # 현재 시간을 5분 단위로 올림 처리
                adjusted_minutes = int(((current_minutes // 5) + 1) * 5)
                start_minutes = max(start_minutes, adjusted_minutes)
            
            # 5분 단위로 시간 슬롯 생성
            current_minutes = start_minutes
            while current_minutes + duration_minutes <= end_minutes:
                time_slot = self._minutes_to_time(current_minutes)
                time_slots.append(time_slot)
                current_minutes += 5  # 5분씩 증가
            
            return time_slots
            
        except Exception as e:
            print(f"시간 슬롯 생성 중 오류: {e}")
            return []
    
    def _fetch_all_required_data(self, branch_id: str, member_id: str, selected_date: str, duration_minutes: int) -> Dict[str, Any]:
        """모든 필요한 데이터를 한 번에 수집 (API 호출 최소화)"""
        try:
            print("   🔍 기본 조건 검증 중...")
            # 1. 기본 검증 (날짜, 영업시간)
            basic_check = self._validate_basic_conditions(branch_id, member_id, selected_date, duration_minutes)
            if not basic_check['success']:
                return basic_check
            
            print("   📋 타석 정보 조회 중...")
            # 2. 사용 가능한 타석 목록 조회
            available_ts_list = self._get_available_ts_list(branch_id, member_id, duration_minutes)
            if not available_ts_list:
                return {
                    'success': False,
                    'error': '사용 가능한 타석이 없습니다.'
                }
            
            print(f"   ✅ 사용 가능한 타석: {len(available_ts_list)}개")
            for ts in available_ts_list:
                buffer_time = ts.get('ts_buffer', 0)
                print(f"      - 타석 {ts['ts_id']}: {ts['ts_status']}, 버퍼: {buffer_time}분")
            
            print("   📅 해당 날짜 모든 예약 조회 중...")
            # 3. 해당 날짜의 모든 타석 예약을 한 번에 조회
            all_reservations = self._get_all_reservations_for_date(branch_id, selected_date)
            
            print(f"   ✅ 기존 예약: {len(all_reservations)}건")
            
            print("   🕐 시간 슬롯 생성 중...")
            # 4. 시간 슬롯 생성
            schedule_info = basic_check['schedule_info']
            business_start = schedule_info.get('business_start')
            business_end = schedule_info.get('business_end')
            time_slots = self._generate_time_slots(business_start, business_end, duration_minutes, selected_date)
            
            print(f"   ✅ 시간 슬롯: {len(time_slots)}개")
            
            return {
                'success': True,
                'schedule_info': schedule_info,
                'available_ts_list': available_ts_list,
                'all_reservations': all_reservations,
                'time_slots': time_slots,
                'total_time_slots': len(time_slots)
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': f'데이터 수집 중 오류: {str(e)}'
            }
    
    def _get_all_reservations_for_date(self, branch_id: str, selected_date: str) -> List[Dict[str, Any]]:
        """해당 날짜의 모든 타석 예약을 한 번에 조회"""
        try:
            response = self.api_client.call_api(
                operation='get',
                table='v2_priced_TS',
                fields=['ts_id', 'ts_start', 'ts_end'],
                where=[
                    {'field': 'ts_date', 'operator': '=', 'value': selected_date},
                    {'field': 'branch_id', 'operator': '=', 'value': branch_id}
                ],
                orderBy=[
                    {'field': 'ts_id', 'direction': 'ASC'},
                    {'field': 'ts_start', 'direction': 'ASC'}
                ]
            )
            
            if response.get('success') and response.get('data'):
                reservations = response['data']
                print(f"   🔍 조회된 예약 데이터:")
                for i, res in enumerate(reservations):
                    print(f"      {i+1}. 타석 {res.get('ts_id')}: {res.get('ts_start')} ~ {res.get('ts_end')}")
                    print(f"         원본 데이터: {res}")
                return reservations
            else:
                print(f"   ⚠️  예약 데이터 조회 실패 또는 데이터 없음")
                print(f"      API 응답: {response}")
                return []
                
        except Exception as e:
            print(f"예약 조회 중 오류: {e}")
            return []
    
    def _process_time_options_locally(self, all_data: Dict[str, Any], duration_minutes: int, selected_date: str) -> Dict[str, List[str]]:
        """수집된 데이터를 사용해서 프론트엔드 로직을 파이썬에서 구현"""
        try:
            available_options = {}
            time_slots = all_data['time_slots']
            available_ts_list = all_data['available_ts_list']
            all_reservations = all_data['all_reservations']
            
            # 타석별 예약 데이터를 미리 정리
            ts_reservations = {}
            for reservation in all_reservations:
                ts_id = str(reservation['ts_id'])  # 문자열로 통일
                if ts_id not in ts_reservations:
                    ts_reservations[ts_id] = []
                ts_reservations[ts_id].append({
                    'start': reservation['ts_start'],
                    'end': reservation['ts_end']
                })
            
            print(f"   📋 타석별 예약 분류 결과:")
            for ts_id, reservations in ts_reservations.items():
                print(f"      타석 {ts_id} (type: {type(ts_id)}): {len(reservations)}건 예약")
                for res in reservations:
                    print(f"         - {res['start']} ~ {res['end']}")
            
            # 사용 가능한 타석 중에서 예약이 없는 타석 확인
            available_ts_ids = [str(ts['ts_id']) for ts in available_ts_list]  # 문자열로 통일
            print(f"   🎯 사용 가능한 타석 ID: {available_ts_ids}")
            print(f"   🔍 타입 체크:")
            for ts in available_ts_list:
                ts_id_str = str(ts['ts_id'])
                print(f"      원본: {ts['ts_id']} (type: {type(ts['ts_id'])}) -> 문자열: {ts_id_str}")
                if ts_id_str not in ts_reservations:
                    print(f"      타석 {ts_id_str}: 예약 없음 (모든 시간대 가능할 예정)")
                else:
                    print(f"      타석 {ts_id_str}: {len(ts_reservations[ts_id_str])}건 예약 있음")
            
            print(f"   🔄 {len(time_slots)}개 시간대 × {len(available_ts_list)}개 타석 = {len(time_slots) * len(available_ts_list)}개 조합 검사 중...")
            
            # 각 시간 슬롯별로 가능한 타석 찾기 (로컬 처리)
            for time_slot in time_slots:
                available_ts_for_time = []
                
                for ts_info in available_ts_list:
                    ts_id = str(ts_info['ts_id'])  # 문자열로 통일
                    
                    # 해당 타석의 예약 목록
                    reservations = ts_reservations.get(ts_id, [])
                    
                    # 디버그: 특정 시간대에서 예약 개수 확인
                    if time_slot in ['09:00', '10:00', '11:00', '15:00', '18:00']:
                        print(f"      🎯 [타석 {ts_id}] {time_slot} 시간대 예약 확인: {len(reservations)}건")
                    
                    # 시간 겹침 검사 (로컬 처리)
                    is_available = self._check_time_conflict_locally(
                        time_slot, duration_minutes, reservations, ts_info
                    )
                    
                    if is_available:
                        available_ts_for_time.append(ts_id)
                
                if available_ts_for_time:
                    available_options[time_slot] = available_ts_for_time
            
            return available_options
            
        except Exception as e:
            print(f"로컬 처리 중 오류: {e}")
            return {}
    
    def _check_time_conflict_locally(self, start_time: str, duration_minutes: int, 
                                   reservations: List[Dict[str, str]], ts_info: Dict[str, Any]) -> bool:
        """시간 겹침 검사를 로컬에서 처리 (API 호출 없음)"""
        try:
            # 요청된 예약 시간 계산
            start_minutes = self._time_to_minutes(start_time)
            end_minutes = start_minutes + duration_minutes
            
            # 타석 버퍼 시간 적용
            ts_buffer_value = ts_info.get('ts_buffer')
            if ts_buffer_value is None or ts_buffer_value == 'None':
                ts_buffer = 0
            else:
                try:
                    ts_buffer = int(ts_buffer_value)
                except (ValueError, TypeError):
                    ts_buffer = 0
            
            # 첫 번째 시간대나 특정 조건에서만 상세 디버그 출력
            is_debug_time = start_time in ['09:00', '10:00', '11:00', '15:00', '18:00'] # 샘플 시간대만
            
            if is_debug_time:
                print(f"      🔍 [{start_time}] 시간 겹침 검사:")
                print(f"         요청 시간: {start_time} ~ {self._minutes_to_time(end_minutes)} ({duration_minutes}분)")
                print(f"         타석 버퍼: {ts_buffer}분")
                print(f"         검사할 예약: {len(reservations)}건")
            
            # 기존 예약과 시간 겹침 확인
            for i, reservation in enumerate(reservations):
                res_start = reservation.get('start', '00:00')
                res_end = reservation.get('end', '00:00')
                
                if res_start is None or res_end is None:
                    if is_debug_time:
                        print(f"         예약 {i+1}: None 값으로 스킵")
                    continue
                    
                res_start_minutes = self._time_to_minutes(res_start)
                res_end_minutes = self._time_to_minutes(res_end)
                
                # 버퍼 시간 적용
                res_start_with_buffer = res_start_minutes - ts_buffer
                res_end_with_buffer = res_end_minutes + ts_buffer
                
                if is_debug_time:
                    print(f"         예약 {i+1}: {res_start} ~ {res_end}")
                    print(f"                  버퍼 적용: {self._minutes_to_time(res_start_with_buffer)} ~ {self._minutes_to_time(res_end_with_buffer)}")
                
                # 시간 겹침 검사
                is_overlap = start_minutes < res_end_with_buffer and end_minutes > res_start_with_buffer
                
                if is_debug_time:
                    print(f"                  겹침 검사: {start_minutes} < {res_end_with_buffer} and {end_minutes} > {res_start_with_buffer} = {is_overlap}")
                
                if is_overlap:
                    if is_debug_time:
                        print(f"         ❌ 겹침 발견!")
                    return False  # 겹침 발견
            
            if is_debug_time:
                print(f"         ✅ 겹침 없음")
            
            return True  # 겹침 없음
            
        except Exception as e:
            print(f"         ❌ 시간 겹침 검사 중 오류: {e}")
            return False
    
    
    def _time_to_minutes(self, time_str: str) -> int:
        """시간 문자열을 분 단위로 변환"""
        try:
            # 다양한 시간 형식 지원
            if not time_str or time_str == 'None':
                return 0
            
            # ':' 기준으로 분리
            parts = time_str.split(':')
            hour = int(parts[0])
            minute = int(parts[1])
            
            # 시간 범위 검증
            if hour < 0 or hour > 23 or minute < 0 or minute > 59:
                print(f"⚠️  비정상적인 시간 형식: {time_str}")
                return 0
            
            return hour * 60 + minute
            
        except Exception as e:
            print(f"❌ 시간 변환 오류: '{time_str}' -> {e}")
            return 0
    
    def _minutes_to_time(self, minutes: int) -> str:
        """분을 시간 문자열로 변환"""
        if minutes < 0:
            minutes = 0
        if minutes >= 1440:
            minutes = minutes % 1440
        
        hour = minutes // 60
        minute = minutes % 60
        return f"{hour:02d}:{minute:02d}"

def main():
    """메인 실행 함수"""
    try:
        print("🏌️  타석 예약 시간 옵션 체커")
        print("=" * 50)
        
        checker = TsTimeOptionChecker()
        
        while True:
            try:
                print("\n📝 예약 조건을 입력해주세요:")
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
                
                selected_date = input("예약 날짜 (YYYY-MM-DD): ").strip()
                if not selected_date:
                    print("❌ 예약 날짜는 필수입니다.")
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
                
                # 시간 옵션 검색 실행
                result = checker.get_available_time_options(
                    branch_id=branch_id,
                    member_id=member_id,
                    selected_date=selected_date,
                    duration_minutes=duration_minutes
                )
                
                # 결과 출력
                print("\n" + "="*60)
                if result['success']:
                    print("🎉 검색 결과: 예약 가능한 시간대 발견!")
                    print("="*60)
                    
                    available_options = result['available_options']
                    if available_options:
                        print(f"📅 {selected_date} ({duration_minutes}분 연습)")
                        print(f"🎯 총 {result['available_time_slots']}개 시간대에서 예약 가능")
                        print(f"📋 검색된 전체 시간 슬롯: {result['total_time_slots']}개")
                        print(f"🏓 사용 가능한 타석 수: {result['available_ts_count']}개")
                        
                        # 영업시간 정보 출력
                        schedule_info = result['schedule_info']
                        business_end_display = schedule_info.get('business_end', '00:00')
                        if business_end_display == '00:00':
                            business_end_display = '24:00'
                        print(f"🏢 영업시간: {schedule_info.get('business_start', '')} ~ {business_end_display}")
                        
                        print(f"\n⏰ 예약 가능한 시간대:")
                        for time_slot in sorted(available_options.keys()):
                            available_ts = available_options[time_slot]
                            end_time = checker._minutes_to_time(
                                checker._time_to_minutes(time_slot) + duration_minutes
                            )
                            ts_list = ', '.join(sorted(map(str, available_ts), key=lambda x: int(x)))
                            print(f"   {time_slot} ~ {end_time} (가능타석: {ts_list})")
                    else:
                        print("📭 예약 가능한 시간대가 없습니다.")
                else:
                    print("❌ 검색 결과: 예약 불가능!")
                    print("="*60)
                    print(f"🚫 사유: {result['error']}")
                
                print("="*60)
                
                # 계속 여부 확인
                continue_check = input("\n다른 조건으로 검색하시겠습니까? (y/n): ").strip().lower()
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