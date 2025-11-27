import 'package:flutter/material.dart';
import 'api_service.dart';

class AutoDiscountCouponService {
  
  // 자동 할인쿠폰 발행 처리 (메인 함수)
  static Future<List<Map<String, dynamic>>> processAutoCouponIssuance({
    required String branchId,
    required Map<String, dynamic> reservationData,
  }) async {
    try {
      print('=== 자동 할인쿠폰 발행 처리 시작 ===');
      print('브랜치 ID: $branchId');
      print('예약 데이터: $reservationData');
      
      // 1. 해당 브랜치의 유효한 쿠폰 설정 조회
      final couponSettings = await ApiService.getDiscountCouponSettings(
        branchId: branchId,
        settingStatus: '유효',
      );
      
      if (couponSettings.isEmpty) {
        print('유효한 할인쿠폰 설정이 없습니다.');
        return []; // 빈 목록 반환
      }
      
      print('조회된 쿠폰 설정 개수: ${couponSettings.length}');
      
      List<Map<String, dynamic>> issuedCoupons = [];
      
      // 2. 각 쿠폰 설정의 트리거 조건 확인
      for (final setting in couponSettings) {
        print('=== 쿠폰 설정 처리: ${setting['coupon_code']} ===');
        
        final triggerIdString = setting['trigger_id']?.toString();
        if (triggerIdString == null || triggerIdString.isEmpty) {
          print('트리거 ID가 없는 쿠폰 설정 건너뜀: ${setting['coupon_code']}');
          continue;
        }
        
        print('트리거 ID 문자열: "$triggerIdString"');
        
        // 트리거 ID 파싱 (쉼표로 구분된 여러 ID 지원)
        final triggerIds = triggerIdString.split(',').map((id) => id.trim()).where((id) => id.isNotEmpty).toList();
        print('파싱된 트리거 IDs: $triggerIds');
        
        if (triggerIds.isEmpty) {
          print('유효한 트리거 ID가 없는 쿠폰 설정 건너뜀: ${setting['coupon_code']}');
          continue;
        }
        
        // 3. 트리거 조건 조회
        final triggers = await ApiService.getDiscountCouponAutoTriggers(
          triggerIds: triggerIds,
          settingStatus: '유효',
        );
        
        print('조회된 트리거 조건 개수: ${triggers.length}');
        
        if (triggers.isEmpty) {
          print('유효한 트리거 조건이 없는 쿠폰 설정 건너뜀: ${setting['coupon_code']}');
          continue;
        }
        
        // 4. 모든 트리거 조건 확인 (OR 관계)
        bool shouldIssueCoupon = false;
        for (final trigger in triggers) {
          if (await _checkTriggerCondition(trigger, reservationData)) {
            shouldIssueCoupon = true;
            print('트리거 조건 충족: ${trigger['trigger_discription']} (ID: ${trigger['trigger_id']})');
            break; // 하나라도 충족하면 발행
          }
        }
        
        // 5. 조건 충족 시 쿠폰 발행
        if (shouldIssueCoupon) {
          final issued = await _issueCouponFromSetting(setting, reservationData);
          if (issued) {
            print('✅ 자동 쿠폰 발행 성공: ${setting['coupon_code']}');
            // 발행된 쿠폰 정보 추가
            issuedCoupons.add({
              'coupon_code': setting['coupon_code'],
              'coupon_description': setting['coupon_description'],
              'coupon_expiry_date': setting['coupon_expiry_days'] != null ? 
                DateTime.now().add(Duration(days: int.parse(setting['coupon_expiry_days'].toString()))).toString().split(' ')[0] : null,
              'discount_amt': setting['discount_amt'],
              'discount_ratio': setting['discount_ratio'],
              'discount_min': setting['discount_min'],
            });
          } else {
            print('❌ 자동 쿠폰 발행 실패: ${setting['coupon_code']}');
          }
        }
      }
      
      print('=== 자동 할인쿠폰 발행 처리 완료 ===');
      return issuedCoupons;
      
    } catch (e) {
      print('자동 할인쿠폰 발행 처리 오류: $e');
      return [];
    }
  }
  
  // 트리거 조건 확인
  static Future<bool> _checkTriggerCondition(
    Map<String, dynamic> trigger,
    Map<String, dynamic> reservationData,
  ) async {
    try {
      print('=== 트리거 조건 확인 시작 ===');
      print('트리거: ${trigger['trigger_discription']}');
      
      // Filter1 조건 확인
      bool filter1Result = true;
      if (trigger['filter1_table'] != null && trigger['filter1_field_name'] != null) {
        filter1Result = await _checkFilterCondition(
          tableName: trigger['filter1_table'],
          fieldName: trigger['filter1_field_name'],
          dataCondition: trigger['filter1_new_data_is_'],
          filterData: trigger['filter1_data'],
          reservationData: reservationData,
        );
        print('Filter1 결과: $filter1Result');
      }
      
      // Filter2 조건 확인 (있는 경우)
      bool filter2Result = true;
      if (trigger['filter2_table'] != null && trigger['filter2_field_name'] != null) {
        filter2Result = await _checkFilterCondition(
          tableName: trigger['filter2_table'],
          fieldName: trigger['filter2_field_name'],
          dataCondition: trigger['filter2_new_data_is_'],
          filterData: trigger['filter2_data'],
          reservationData: reservationData,
        );
        print('Filter2 결과: $filter2Result');
      }
      
      // Filter2가 있는 경우 AND 조건으로 처리, 없는 경우 Filter1만 사용
      bool finalResult;
      
      if (trigger['filter2_table'] != null && trigger['filter2_field_name'] != null) {
        finalResult = filter1Result && filter2Result;
        print('최종 트리거 조건 결과: $finalResult (관계: and)');
      } else {
        finalResult = filter1Result;
        print('최종 트리거 조건 결과: $finalResult (단일 조건)');
      }
      return finalResult;
      
    } catch (e) {
      print('트리거 조건 확인 오류: $e');
      return false;
    }
  }
  
  // 개별 필터 조건 확인
  static Future<bool> _checkFilterCondition({
    required String tableName,
    required String fieldName,
    required String dataCondition,
    required String filterData,
    required Map<String, dynamic> reservationData,
  }) async {
    try {
      print('--- 필터 조건 확인 시작 ---');
      print('테이블: $tableName, 필드: $fieldName');
      print('조건: $dataCondition, 기준값: $filterData');
      
      // 현재 예약 데이터에서 해당 필드 값 가져오기
      final currentValue = _getFieldValueFromReservationData(
        tableName: tableName,
        fieldName: fieldName,
        reservationData: reservationData,
      );
      
      if (currentValue == null) {
        print('필드 값을 찾을 수 없음: $tableName.$fieldName');
        return false;
      }
      
      print('현재 값: $currentValue (타입: ${currentValue.runtimeType})');
      print('조건 확인: $fieldName($currentValue) $dataCondition $filterData');
      
      bool result = false;
      
      // 조건에 따른 비교
      switch (dataCondition) {
        case '포함':
          result = _checkContains(currentValue, filterData);
          break;
        case '불포함':
          result = !_checkContains(currentValue, filterData);
          break;
        case '이상':
          result = _checkGreaterThanOrEqual(currentValue, filterData);
          break;
        case '이하':
          result = _checkLessThanOrEqual(currentValue, filterData);
          break;
        case '초과':
          result = _checkGreaterThan(currentValue, filterData);
          break;
        case '미만':
          result = _checkLessThan(currentValue, filterData);
          break;
        case '일치':
          result = _checkEquals(currentValue, filterData);
          break;
        default:
          print('지원하지 않는 조건: $dataCondition');
          result = false;
      }
      
      print('필터 조건 결과: $result');
      return result;
      
    } catch (e) {
      print('필터 조건 확인 오류: $e');
      return false;
    }
  }
  
  // 예약 데이터에서 필드 값 추출
  static dynamic _getFieldValueFromReservationData({
    required String tableName,
    required String fieldName,
    required Map<String, dynamic> reservationData,
  }) {
    // v2_priced_TS 테이블의 필드들을 예약 데이터에서 추출
    if (tableName == 'v2_priced_TS') {
      switch (fieldName) {
        case 'day_of_week':
          return reservationData['day_of_week'];
        case 'ts_start':
          return reservationData['ts_start'];
        case 'bill_min':
          return reservationData['bill_min'];
        case 'ts_min':
          return reservationData['ts_min'];
        case 'member_id':
          return reservationData['member_id'];
        case 'total_amt':
          return reservationData['total_amt'];
        case 'net_amt':
          return reservationData['net_amt'];
        default:
          return reservationData[fieldName];
      }
    }
    
    // 다른 테이블 지원 확장 가능
    return reservationData[fieldName];
  }
  
  // 조건 확인 헬퍼 메서드들
  static bool _checkContains(dynamic currentValue, String filterData) {
    final currentStr = currentValue.toString();
    final filterItems = filterData.split(',').map((item) => item.trim()).toList();
    return filterItems.any((item) => currentStr.contains(item));
  }
  
  static bool _checkGreaterThanOrEqual(dynamic currentValue, String filterData) {
    final current = _parseToNumber(currentValue);
    final filter = _parseToNumber(filterData);
    return current != null && filter != null && current >= filter;
  }
  
  static bool _checkLessThanOrEqual(dynamic currentValue, String filterData) {
    final current = _parseToNumber(currentValue);
    final filter = _parseToNumber(filterData);
    return current != null && filter != null && current <= filter;
  }
  
  static bool _checkGreaterThan(dynamic currentValue, String filterData) {
    final current = _parseToNumber(currentValue);
    final filter = _parseToNumber(filterData);
    return current != null && filter != null && current > filter;
  }
  
  static bool _checkLessThan(dynamic currentValue, String filterData) {
    final current = _parseToNumber(currentValue);
    final filter = _parseToNumber(filterData);
    return current != null && filter != null && current < filter;
  }
  
  static bool _checkEquals(dynamic currentValue, String filterData) {
    return currentValue.toString() == filterData;
  }
  
  // 시간 비교 처리 (HH:MM 형식)
  static bool _checkTimeCondition(String currentTime, String filterTime, String condition) {
    try {
      final currentParts = currentTime.split(':');
      final filterParts = filterTime.split(':');
      
      final currentMinutes = int.parse(currentParts[0]) * 60 + int.parse(currentParts[1]);
      final filterMinutes = int.parse(filterParts[0]) * 60 + int.parse(filterParts[1]);
      
      switch (condition) {
        case '이상':
          return currentMinutes >= filterMinutes;
        case '이하':
          return currentMinutes <= filterMinutes;
        case '초과':
          return currentMinutes > filterMinutes;
        case '미만':
          return currentMinutes < filterMinutes;
        case '일치':
          return currentMinutes == filterMinutes;
        default:
          return false;
      }
    } catch (e) {
      print('시간 비교 오류: $e');
      return false;
    }
  }
  
  // 숫자 파싱 헬퍼
  static double? _parseToNumber(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      // 시간 형식인 경우 분 단위로 변환
      if (value.contains(':')) {
        try {
          final parts = value.split(':');
          return (int.parse(parts[0]) * 60 + int.parse(parts[1])).toDouble();
        } catch (e) {
          return double.tryParse(value);
        }
      }
      return double.tryParse(value);
    }
    return null;
  }
  
  // 쿠폰 설정에서 실제 쿠폰 발행
  static Future<bool> _issueCouponFromSetting(
    Map<String, dynamic> setting,
    Map<String, dynamic> reservationData,
  ) async {
    try {
      final branchId = setting['branch_id']?.toString() ?? '';
      final memberId = reservationData['member_id']?.toString() ?? '';
      final memberName = reservationData['member_name']?.toString() ?? '';
      
      if (branchId.isEmpty || memberId.isEmpty) {
        print('브랜치 ID 또는 회원 ID가 없어 쿠폰 발행 불가');
        return false;
      }
      
      // 쿠폰 발행
      final issued = await ApiService.issueCoupon(
        branchId: branchId,
        memberId: memberId,
        memberName: memberName,
        couponCode: setting['coupon_code']?.toString() ?? '',
        couponType: setting['coupon_type']?.toString() ?? '',
        discountRatio: _parseToInt(setting['discount_ratio']),
        discountAmt: _parseToInt(setting['discount_amt']),
        discountMin: _parseToInt(setting['discount_min']),
        couponExpiryDays: _parseToInt(setting['coupon_expiry_days']),
        multipleCouponUse: setting['multiple_coupon_use']?.toString() ?? '불가능',
        couponDescription: setting['coupon_description']?.toString() ?? '',
        reservationIdIssued: reservationData['reservation_id']?.toString(),
      );
      
      return issued;
      
    } catch (e) {
      print('쿠폰 발행 오류: $e');
      return false;
    }
  }
  
  // 안전한 int 변환 헬퍼 메서드
  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}