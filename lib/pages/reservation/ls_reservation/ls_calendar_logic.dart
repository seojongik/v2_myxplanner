import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';

class LsCalendarLogic {
  // 레슨 카운팅 데이터 및 프로 정보
  Map<String, dynamic>? _lessonCountingData;
  Map<String, Map<String, dynamic>> _proInfoMap = {};
  Map<String, Map<String, Map<String, dynamic>>> _proScheduleMap = {};
  int _maxReservationAheadDays = 0;
  bool _isLoadingLessonData = false;

  // 레슨 카운팅 데이터 및 프로 정보 로드
  Future<void> loadLessonCountingData() async {
    if (_isLoadingLessonData) return;
    
    _isLoadingLessonData = true;

    try {
      final currentUser = ApiService.getCurrentUser();
      if (currentUser != null && currentUser['member_id'] != null) {
        final memberId = currentUser['member_id'].toString();
        final result = await ApiService.getMemberLsCountingData(memberId: memberId);
        
        if (result['success'] == true && result['debug_info'] != null) {
          final debugInfo = result['debug_info'] as Map<String, dynamic>;
          final proInfo = debugInfo['pro_info'] as Map<String, dynamic>?;
          final proSchedule = debugInfo['pro_schedule'] as Map<String, dynamic>?;
          final maxReservationAheadDays = debugInfo['max_reservation_ahead_days'] as int? ?? 0;
          
          if (proInfo != null) {
            _proInfoMap = proInfo.map((key, value) => 
              MapEntry(key, value as Map<String, dynamic>));
            _maxReservationAheadDays = maxReservationAheadDays;
          }
          
          if (proSchedule != null) {
            _proScheduleMap = proSchedule.map((proId, scheduleData) => 
              MapEntry(proId, (scheduleData as Map<String, dynamic>).map((date, data) => 
                MapEntry(date, data as Map<String, dynamic>))));
          }
          
          _lessonCountingData = result;
        }
      }
    } catch (e) {
      print('레슨 카운팅 데이터 로드 실패: $e');
    } finally {
      _isLoadingLessonData = false;
    }
  }

  // 레슨 예약용 날짜 비활성화 확인
  bool isDateDisabled(DateTime day, Map<String, Map<String, dynamic>> scheduleData) {
    // 1. 과거 날짜는 비활성화
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dayOnly = DateTime(day.year, day.month, day.day);
    
    if (dayOnly.isBefore(todayOnly)) {
      return true;
    }
    
    // 2. 영업시간 체크 (휴무일 비활성화)
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    final schedule = scheduleData[dateStr];
    if (schedule != null && schedule['is_holiday'] == 'close') {
      return true;
    }
    
    // 3. 프로별 개별 예약 가능 일수 및 스케줄 체크
    if (_proInfoMap.isNotEmpty) {
      bool hasAvailablePro = false;
      
      for (final proId in _proInfoMap.keys) {
        final proInfo = _proInfoMap[proId];
        if (proInfo != null) {
          // 3-1. 프로별 예약 가능 일수 체크
          final reservationAheadDays = int.tryParse(proInfo['reservation_ahead_days']?.toString() ?? '0') ?? 0;
          final maxAllowedDateForPro = todayOnly.add(Duration(days: reservationAheadDays));
          
          if (dayOnly.isAfter(maxAllowedDateForPro)) {
            continue;
          }
          
          // 3-2. 프로 스케줄 체크
          final proSchedule = _proScheduleMap[proId];
          if (proSchedule != null) {
            final daySchedule = proSchedule[dateStr];
            
            if (daySchedule == null) {
              hasAvailablePro = true;
              break;
            }
            
            final isDayOff = daySchedule['is_day_off']?.toString();
            if (isDayOff != '휴무') {
              hasAvailablePro = true;
              break;
            }
          } else {
            hasAvailablePro = true;
            break;
          }
        }
      }
      
      if (!hasAvailablePro) {
        return true;
      }
    }
    
    return false;
  }

  // 날짜 선택 시 레슨 정보 출력
  void onDateSelected(DateTime selectedDay, Map<String, Map<String, dynamic>> scheduleData) {
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDay);
    
    print('\n=== 선택된 날짜의 레슨 정보 ===');
    print('날짜: $dateKey');
    
    if (_lessonCountingData != null && _lessonCountingData!['success'] == true) {
      final validRecords = _lessonCountingData!['data'] as List<dynamic>;
      print('\n[유효한 레슨 계약]');
      for (final record in validRecords) {
        final proId = record['pro_id']?.toString();
        final proName = _proInfoMap[proId]?['pro_name']?.toString() ?? '프로 $proId';
        print('• $proName');
        print('  - LS_counting_id: ${record['LS_counting_id']}');
        print('  - LS_balance_min_after: ${record['LS_balance_min_after']}');
        print('  - LS_expiry_date: ${record['LS_expiry_date']}');
        print('  - contract_history_id: ${record['contract_history_id']}');
      }
    }
    
    print('\n[프로별 근무 시간 및 설정]');
    for (final proId in _proInfoMap.keys) {
      final proInfo = _proInfoMap[proId];
      final proSchedule = _proScheduleMap[proId];
      if (proInfo != null && proSchedule != null) {
        final daySchedule = proSchedule[dateKey];
        final proName = proInfo['pro_name']?.toString() ?? '프로 $proId';
        final reservationAheadDays = int.tryParse(proInfo['reservation_ahead_days']?.toString() ?? '0') ?? 0;
        
        final today = DateTime.now();
        final todayOnly = DateTime(today.year, today.month, today.day);
        final selectedDayOnly = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
        final maxAllowedDate = todayOnly.add(Duration(days: reservationAheadDays));
        final isDateExceedingLimit = selectedDayOnly.isAfter(maxAllowedDate);
        
        print('• $proName');
        print('  [스케줄]');
        if (isDateExceedingLimit) {
          print('    - 예약불가(예약 가능일수 초과)');
        } else if (daySchedule != null) {
          if (daySchedule['is_day_off'] == '휴무') {
            print('    - 근무상태: 휴무');
          } else {
            print('    - 근무시간: ${daySchedule['work_start']}~${daySchedule['work_end']}');
          }
        } else {
          print('    - 근무시간: 09:00:00~18:00:00 (기본)');
        }
        
        print('  [설정]');
        print('    - 최소 레슨시간: ${proInfo['min_service_min']}분');
        print('    - 레슨시간 단위: ${proInfo['svc_time_unit']}분');
        print('    - 최소 예약기간: ${proInfo['min_reservation_term']}분');
        print('    - 예약 가능일수: ${proInfo['reservation_ahead_days']}일');
        print('');
      }
    }
    print('================================\n');
  }

  // 레슨 관련 데이터 반환
  Map<String, dynamic> getLessonData() {
    return {
      'lessonCountingData': _lessonCountingData,
      'proInfoMap': _proInfoMap,
      'proScheduleMap': _proScheduleMap,
    };
  }

  // 로딩 상태 확인
  bool get isLoadingLessonData => _isLoadingLessonData;
} 