import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import 'package:intl/intl.dart';

class SpTsAvailabilityService {
  /// 특수 예약 타석 가능한 시간 옵션 조회
  static Future<Map<String, dynamic>> findAvailableTimeSlots({
    required String branchId,
    required String memberId,
    required String tsId,
    required DateTime selectedDate,
    required int durationMinutes,
    int timeSlotInterval = 30, // 30분 간격으로 체크
  }) async {
    try {
      print('🔍 타석 ${tsId}번 예약 가능 시간 조회 (${DateFormat('yyyy-MM-dd').format(selectedDate)})');
      
      final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      
      // 1. 기본 검증
      final basicCheck = await _quickValidateBasics(branchId, memberId, tsId, selectedDate, durationMinutes);
      if (!basicCheck['success']) return basicCheck;
      
      // 2. 영업시간 및 타석 정보 조회
      final scheduleInfo = await _getScheduleInfo(branchId, selectedDateStr);
      if (!scheduleInfo['success']) return scheduleInfo;
      
      final tsInfo = await _getTsInfo(branchId, tsId, durationMinutes);
      if (!tsInfo['success']) return tsInfo;
      
      // 3. 기존 예약 조회
      final existingReservations = await _getExistingReservations(branchId, tsId, selectedDateStr);
      
      // 4. 회원 시간권 확인
      final timePassCheck = await _checkMemberTimePass(memberId, durationMinutes);
      
      // 5. 가능한 시간 슬롯 계산
      final availableSlots = _calculateAvailableSlots(
        scheduleInfo['data'],
        tsInfo['data'],
        existingReservations,
        selectedDate,
        durationMinutes,
        timeSlotInterval,
      );
      
      print('✅ 검증 완료 - 가능한 시간: ${availableSlots.length}개');
      
      return {
        'success': true,
        'available_slots': availableSlots,
        'schedule_info': scheduleInfo['data'],
        'ts_info': tsInfo['data'],
        'existing_reservations': existingReservations,
        'time_pass_info': timePassCheck,
        'summary': {
          'date': selectedDateStr,
          'ts_id': tsId,
          'duration_minutes': durationMinutes,
          'total_available_slots': availableSlots.length,
          'business_hours': '${scheduleInfo['data']['business_start']} ~ ${scheduleInfo['data']['business_end']}',
          'existing_reservations_count': existingReservations.length,
        }
      };
      
    } catch (e) {
      return {
        'success': false,
        'error': '시간 조회 중 오류: $e'
      };
    }
  }

  /// 모든 타석의 가용한 시간 옵션 조회 (시간대별 가용 타석 정보 포함)
  static Future<Map<String, dynamic>> findAvailableTimeSlotsForAllTs({
    required String branchId,
    required String memberId,
    required DateTime selectedDate,
    required int durationMinutes,
    int timeSlotInterval = 5, // 5분 간격으로 체크
  }) async {
    try {
      final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      print('🔍 모든 타석 가용 시간 조회 (${selectedDateStr})');
      
      // 1. 기본 검증
      final basicCheck = await _quickValidateBasics(branchId, memberId, '1', selectedDate, durationMinutes);
      if (!basicCheck['success']) return basicCheck;
      
      // 2. 영업시간 정보 조회
      final scheduleInfo = await _getScheduleInfo(branchId, selectedDateStr);
      if (!scheduleInfo['success']) return scheduleInfo;
      
      // 3. 모든 타석 정보 조회
      final allTsInfo = await _getAllTsInfo(branchId, durationMinutes);
      if (!allTsInfo['success']) return allTsInfo;
      
      // 4. 모든 타석의 기존 예약 조회
      final allReservations = await _getAllExistingReservations(branchId, selectedDateStr);
      
      // 5. 회원 시간권 확인
      final timePassCheck = await _checkMemberTimePass(memberId, durationMinutes);
      
      // 6. 시간대별 가용 타석 계산
      final timeSlotAvailability = _calculateTimeSlotAvailabilityForAllTs(
        scheduleInfo['data'],
        allTsInfo['data'],
        allReservations,
        selectedDate,
        durationMinutes,
        timeSlotInterval,
      );
      
      print('✅ 검증 완료 - 가능한 시간대: ${timeSlotAvailability.length}개');
      
      return {
        'success': true,
        'time_slot_availability': timeSlotAvailability,
        'schedule_info': scheduleInfo['data'],
        'all_ts_info': allTsInfo['data'],
        'all_reservations': allReservations,
        'time_pass_info': timePassCheck,
        'summary': {
          'date': selectedDateStr,
          'duration_minutes': durationMinutes,
          'total_time_slots': timeSlotAvailability.length,
          'business_hours': '${scheduleInfo['data']['business_start']} ~ ${scheduleInfo['data']['business_end']}',
          'total_ts_count': allTsInfo['data'].length,
        }
      };
      
    } catch (e) {
      return {
        'success': false,
        'error': '시간 조회 중 오류: $e'
      };
    }
  }

  /// 특정 시간 예약 가능성 빠른 체크
  static Future<Map<String, dynamic>> checkSpecificTime({
    required String branchId,
    required String memberId,
    required String tsId,
    required DateTime selectedDate,
    required String startTime,
    required int durationMinutes,
  }) async {
    try {
      final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      print('🔍 ${selectedDateStr} ${startTime} (${durationMinutes}분) 예약 가능성 체크');
      
      // 1. 기본 검증
      final basicCheck = await _quickValidateBasics(branchId, memberId, tsId, selectedDate, durationMinutes);
      if (!basicCheck['success']) return basicCheck;
      
      // 2. 영업시간 체크
      final scheduleInfo = await _getScheduleInfo(branchId, selectedDateStr);
      if (!scheduleInfo['success']) return scheduleInfo;
      
      final businessCheck = _checkBusinessHours(scheduleInfo['data'], startTime, durationMinutes, selectedDate);
      if (!businessCheck['success']) return businessCheck;
      
      // 3. 타석 정보 체크
      final tsInfo = await _getTsInfo(branchId, tsId, durationMinutes);
      if (!tsInfo['success']) return tsInfo;
      
      // 4. 시간 충돌 체크
      final conflictCheck = await _checkTimeConflicts(branchId, tsId, selectedDateStr, startTime, durationMinutes);
      if (!conflictCheck['success']) return conflictCheck;
      
      // 5. 회원 시간권 확인
      final timePassCheck = await _checkMemberTimePass(memberId, durationMinutes);
      
      print('✅ 예약 가능');
      
      return {
        'success': true,
        'message': '예약 가능',
        'details': {
          'ts_id': tsId,
          'date': selectedDateStr,
          'start_time': startTime,
          'end_time': _calculateEndTime(startTime, durationMinutes),
          'duration_minutes': durationMinutes,
        },
        'time_pass_info': timePassCheck,
      };
      
    } catch (e) {
      return {
        'success': false,
        'error': '검증 중 오류: $e'
      };
    }
  }

  // =============================================================================
  // 내부 헬퍼 함수들
  // =============================================================================

  /// 기본 검증 (빠른 체크)
  static Future<Map<String, dynamic>> _quickValidateBasics(
    String branchId, String memberId, String tsId, DateTime selectedDate, int durationMinutes
  ) async {
    if (branchId.isEmpty || memberId.isEmpty || tsId.isEmpty) {
      return {'success': false, 'error': '필수 정보 누락'};
    }
    
    if (durationMinutes <= 0) {
      return {'success': false, 'error': '연습시간은 양수여야 함'};
    }
    
    if (selectedDate.isBefore(DateTime.now().subtract(Duration(days: 1)))) {
      return {'success': false, 'error': '과거 날짜 예약 불가'};
    }
    
    return {'success': true};
  }

  /// 영업시간 정보 조회
  static Future<Map<String, dynamic>> _getScheduleInfo(String branchId, String date) async {
    try {
      print('🔍 [타석] 영업시간 정보 조회 시작 (날짜: $date)');
      final result = await ApiService.getTsScheduleByDate(date: date);
      print('   API 응답 타입: ${result.runtimeType}');

      // API 응답이 직접 데이터인 경우 (success 필드 없음)
      if (result != null && result is Map<String, dynamic>) {
        // is_holiday가 'close'인 경우 휴무일
        if (result['is_holiday'] == 'close') {
          print('   ❌ 실패: 휴무일 (is_holiday = close)');
          return {'success': false, 'error': '휴무일'};
        }

        final businessStart = result['business_start']?.toString() ?? '정보없음';
        final businessEnd = result['business_end']?.toString() ?? '정보없음';
        print('   ✅ 영업시간: $businessStart ~ $businessEnd');

        // 정상 데이터 반환
        return {'success': true, 'data': result};
      }

      // 기존 방식도 체크 (success 필드 있는 경우)
      if (result != null && result is Map && result['success'] == true && result['data'] != null) {
        final schedule = result['data'];
        if (schedule['is_holiday'] == 'close') {
          print('   ❌ 실패: 휴무일 (is_holiday = close)');
          return {'success': false, 'error': '휴무일'};
        }

        final businessStart = schedule['business_start']?.toString() ?? '정보없음';
        final businessEnd = schedule['business_end']?.toString() ?? '정보없음';
        print('   ✅ 영업시간: $businessStart ~ $businessEnd');

        return {'success': true, 'data': schedule};
      }

      print('   ❌ 실패: 영업시간 정보 없음');
      return {'success': false, 'error': '영업시간 정보 없음'};
    } catch (e) {
      print('   ❌ 실패: 영업시간 조회 오류 - $e');
      return {'success': false, 'error': '영업시간 조회 실패: $e'};
    }
  }

  /// 타석 정보 조회
  static Future<Map<String, dynamic>> _getTsInfo(String branchId, String tsId, int durationMinutes) async {
    try {
      final result = await ApiService.getTsInfoById(tsId: tsId);
      print('타석 API 응답 타입: ${result.runtimeType}');
      print('타석 API 응답 내용: $result');
      
      // API 응답이 직접 데이터인 경우 (success 필드 없음)
      if (result != null && result is Map<String, dynamic>) {
        // 최소/최대 시간 체크는 실제 데이터가 있을 때만
        if (result['ts_min_minimum'] != null) {
          final minMinutes = int.tryParse(result['ts_min_minimum'].toString()) ?? 0;
          if (durationMinutes < minMinutes) {
            return {'success': false, 'error': '최소 이용시간 ${minMinutes}분 미만'};
          }
        }
        
        if (result['ts_min_maximum'] != null) {
          final maxMinutes = int.tryParse(result['ts_min_maximum'].toString()) ?? 999;
          if (durationMinutes > maxMinutes) {
            return {'success': false, 'error': '최대 이용시간 ${maxMinutes}분 초과'};
          }
        }
        
        return {'success': true, 'data': result};
      }
      
      // 기존 방식도 체크 (success 필드 있는 경우)
      if (result != null && result is Map && result['success'] == true && result['data'] != null) {
        final tsInfo = result['data'];
        
        // 최소/최대 시간 체크는 실제 데이터가 있을 때만
        if (tsInfo['ts_min_minimum'] != null) {
          final minMinutes = int.tryParse(tsInfo['ts_min_minimum'].toString()) ?? 0;
          if (durationMinutes < minMinutes) {
            return {'success': false, 'error': '최소 이용시간 ${minMinutes}분 미만'};
          }
        }
        
        if (tsInfo['ts_min_maximum'] != null) {
          final maxMinutes = int.tryParse(tsInfo['ts_min_maximum'].toString()) ?? 999;
          if (durationMinutes > maxMinutes) {
            return {'success': false, 'error': '최대 이용시간 ${maxMinutes}분 초과'};
          }
        }
        
        return {'success': true, 'data': tsInfo};
      }
      
      return {'success': false, 'error': '타석 정보 없음'};
    } catch (e) {
      return {'success': false, 'error': '타석 정보 조회 실패: $e'};
    }
  }

  /// 기존 예약 조회
  static Future<List<Map<String, dynamic>>> _getExistingReservations(String branchId, String tsId, String date) async {
    try {
      final dynamic result = await ApiService.getTsReservationsByDate(date: date);
      print('예약 API 응답 타입: ${result.runtimeType}');
      print('예약 API 응답 내용: $result');
      
      final List<Map<String, dynamic>> filteredReservations = [];
      
      // 1. result가 null인 경우
      if (result == null) {
        return filteredReservations;
      }
      
      // 2. result가 List인 경우 - 직접 리스트 응답
      if (result is List) {
        for (final dynamic item in result) {
          if (item != null && item is Map<String, dynamic> && item['ts_id']?.toString() == tsId) {
            filteredReservations.add(item);
          }
        }
        return filteredReservations;
      }
      
      // 3. result가 Map인 경우 - 여러 구조 처리
      if (result is Map<String, dynamic>) {
        // 3-1. success 필드가 있는 표준 응답
        if (result.containsKey('success') && result['success'] == true) {
          final dynamic data = result['data'];
          if (data != null && data is List) {
            for (final dynamic item in data) {
              if (item != null && item is Map<String, dynamic> && item['ts_id']?.toString() == tsId) {
                filteredReservations.add(item);
              }
            }
          } else if (data != null && data is Map<String, dynamic>) {
            // data가 Map인 경우 각 값을 체크
            data.forEach((dynamic key, dynamic value) {
              if (value != null && value is List) {
                for (final dynamic item in value) {
                  if (item != null && item is Map<String, dynamic> && item['ts_id']?.toString() == tsId) {
                    filteredReservations.add(item);
                  }
                }
              }
            });
          }
        } else {
          // 3-2. 날짜별 예약 Map 구조 (Map<String, List>)
          final dynamic dateValue = result[date];
          if (dateValue != null && dateValue is List) {
            for (final dynamic item in dateValue) {
              if (item != null && item is Map<String, dynamic> && item['ts_id']?.toString() == tsId) {
                filteredReservations.add(item);
              }
            }
          } else {
            // 모든 키의 값을 체크
            result.forEach((dynamic key, dynamic value) {
              if (value != null && value is List) {
                for (final dynamic item in value) {
                  if (item != null && item is Map<String, dynamic> && item['ts_id']?.toString() == tsId) {
                    filteredReservations.add(item);
                  }
                }
              }
            });
          }
        }
      }
      
      return filteredReservations;
    } catch (e) {
      print('기존 예약 조회 실패: $e');
      return [];
    }
  }

  /// 회원 시간권 확인
  static Future<Map<String, dynamic>> _checkMemberTimePass(String memberId, int durationMinutes) async {
    int totalBalance = 0;
    int validContracts = 0;
    
    try {
      // 총 잔액 계산 - 안전한 방식
      try {
        final balanceResult = await ApiService.getMemberTimePassBalance(memberId: memberId);
        print('Balance API 응답 타입: ${balanceResult.runtimeType}');
        print('Balance API 응답 내용: $balanceResult');
        
        // 응답이 Map인 경우에만 처리
        if (balanceResult != null && balanceResult is Map) {
          final resultMap = balanceResult as Map<String, dynamic>;
          if (resultMap['success'] == true && resultMap['data'] != null) {
            final data = resultMap['data'];
            if (data is Map) {
              final dataMap = data as Map<String, dynamic>;
              totalBalance = int.tryParse(dataMap['balance']?.toString() ?? '0') ?? 0;
            }
          }
        }
      } catch (e) {
        print('시간권 잔액 조회 실패: $e');
      }
      
      // 유효한 계약 수 계산 - 안전한 방식
      try {
        final contractsResult = await ApiService.getMemberTimePassesByContract(memberId: memberId);
        print('Contracts API 응답 타입: ${contractsResult.runtimeType}');
        print('Contracts API 응답 내용: $contractsResult');
        
        // 응답이 Map인 경우에만 처리
        if (contractsResult != null && contractsResult is Map) {
          final resultMap = contractsResult as Map<String, dynamic>;
          if (resultMap['success'] == true && resultMap['data'] != null) {
            final contractsData = resultMap['data'];
            
            // List든 Map이든 안전하게 처리
            if (contractsData is List) {
              for (final contract in contractsData) {
                if (contract is Map) {
                  final contractMap = contract as Map<String, dynamic>;
                  final balance = int.tryParse(contractMap['balance']?.toString() ?? '0') ?? 0;
                  if (balance >= durationMinutes) {
                    validContracts++;
                  }
                }
              }
            } else if (contractsData is Map) {
              final contractsMap = contractsData as Map<String, dynamic>;
              contractsMap.forEach((key, contract) {
                if (contract is Map) {
                  final contractMap = contract as Map<String, dynamic>;
                  final balance = int.tryParse(contractMap['balance']?.toString() ?? '0') ?? 0;
                  if (balance >= durationMinutes) {
                    validContracts++;
                  }
                }
              });
            }
          }
        }
      } catch (e) {
        print('계약 정보 조회 실패: $e');
      }
      
      return {
        'total_balance': totalBalance,
        'valid_contracts': validContracts,
        'sufficient_balance': totalBalance >= durationMinutes,
      };
      
    } catch (e) {
      print('시간권 전체 조회 실패: $e');
      return {
        'total_balance': 0,
        'valid_contracts': 0,
        'sufficient_balance': false,
        'error': '시간권 조회 실패: $e'
      };
    }
  }

  /// 영업시간 체크
  static Map<String, dynamic> _checkBusinessHours(Map<String, dynamic> schedule, String startTime, int durationMinutes, DateTime selectedDate) {
    try {
      final businessStart = schedule['business_start']?.toString() ?? '09:00';
      final businessEnd = schedule['business_end']?.toString() ?? '22:00';
      
      final startMinutes = _timeToMinutes(startTime);
      final endMinutes = startMinutes + durationMinutes;
      final businessStartMinutes = _timeToMinutes(businessStart);
      final businessEndMinutes = _timeToMinutes(businessEnd);
      
      if (startMinutes < businessStartMinutes) {
        return {'success': false, 'error': '영업시간 전 (${businessStart} 이후 가능)'};
      }
      
      if (endMinutes > businessEndMinutes) {
        return {'success': false, 'error': '영업시간 후 (${businessEnd} 이전 종료 필요)'};
      }
      
      // 오늘 날짜인 경우 현재 시간 체크
      if (selectedDate.year == DateTime.now().year && 
          selectedDate.month == DateTime.now().month && 
          selectedDate.day == DateTime.now().day) {
        final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
        if (startMinutes <= nowMinutes) {
          return {'success': false, 'error': '현재 시간 이후 예약 가능'};
        }
      }
      
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': '영업시간 체크 실패: $e'};
    }
  }

  /// 시간 충돌 체크
  static Future<Map<String, dynamic>> _checkTimeConflicts(String branchId, String tsId, String date, String startTime, int durationMinutes) async {
    try {
      final existingReservations = await _getExistingReservations(branchId, tsId, date);
      
      final startMinutes = _timeToMinutes(startTime);
      final endMinutes = startMinutes + durationMinutes;
      
      for (final reservation in existingReservations) {
        final resStart = _timeToMinutes(reservation['ts_start']?.toString() ?? '00:00');
        final resEnd = _timeToMinutes(reservation['ts_end']?.toString() ?? '00:00');
        
        if (startMinutes < resEnd && endMinutes > resStart) {
          return {
            'success': false, 
            'error': '기존 예약과 충돌 (${reservation['ts_start']} ~ ${reservation['ts_end']})'
          };
        }
      }
      
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': '시간 충돌 체크 실패: $e'};
    }
  }

  /// 가능한 시간 슬롯 계산
  static List<Map<String, dynamic>> _calculateAvailableSlots(
    Map<String, dynamic> schedule,
    Map<String, dynamic> tsInfo,
    List<Map<String, dynamic>> existingReservations,
    DateTime selectedDate,
    int durationMinutes,
    int timeSlotInterval,
  ) {
    final availableSlots = <Map<String, dynamic>>[];
    
    try {
      final businessStart = schedule['business_start']?.toString() ?? '09:00';
      final businessEnd = schedule['business_end']?.toString() ?? '22:00';
      final tsBuffer = int.tryParse(tsInfo['ts_buffer']?.toString() ?? '0') ?? 0;
      
      final businessStartMinutes = _timeToMinutes(businessStart);
      int businessEndMinutes = _timeToMinutes(businessEnd);
      
      // 00:00인 경우 24:00(1440분)으로 처리 (Python 로직과 동일)
      if (businessEndMinutes == 0) {
        businessEndMinutes = 1440;
        print('영업 종료 시간 00:00 -> 24:00(1440분)으로 처리');
      }
      
      // 오늘 날짜인 경우 현재 시간 이후부터 시작
      int startFromMinutes = businessStartMinutes;
      if (selectedDate.year == DateTime.now().year && 
          selectedDate.month == DateTime.now().month && 
          selectedDate.day == DateTime.now().day) {
        final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
        // 5분 단위로 올림 처리 (Python 로직과 동일)
        final adjustedMinutes = ((nowMinutes / timeSlotInterval).ceil() * timeSlotInterval).toInt();
        startFromMinutes = adjustedMinutes > businessStartMinutes ? adjustedMinutes : businessStartMinutes;
        print('오늘 날짜: 현재 시간 ${_minutesToTime(nowMinutes)} -> ${_minutesToTime(startFromMinutes)}부터 시작');
      }
      
      // 시간 슬롯별로 체크
      for (int minutes = startFromMinutes; minutes + durationMinutes <= businessEndMinutes; minutes += timeSlotInterval) {
        final endMinutes = minutes + durationMinutes;
        
        // 기존 예약과 충돌 체크 (버퍼 시간 포함)
        bool hasConflict = false;
        for (final reservation in existingReservations) {
          final resStart = _timeToMinutes(reservation['ts_start']?.toString() ?? '00:00');
          final resEnd = _timeToMinutes(reservation['ts_end']?.toString() ?? '00:00');
          
          // 기존 예약 종료 시간에 버퍼 시간 추가
          final resEndWithBuffer = resEnd + tsBuffer;
          
          // 충돌 체크: 새 예약 시작이 기존 예약 종료+버퍼 이전이거나, 새 예약 종료가 기존 예약 시작 이후인 경우
          if (minutes < resEndWithBuffer && endMinutes > resStart) {
            hasConflict = true;
            break;
          }
        }
        
        if (!hasConflict) {
          availableSlots.add({
            'start_time': _minutesToTime(minutes),
            'end_time': _minutesToTime(endMinutes),
            'start_minutes': minutes,
            'end_minutes': endMinutes,
            'duration_minutes': durationMinutes,
            'ts_buffer_applied': tsBuffer,
          });
        }
      }
      
      print('📅 가능한 시간대 (버퍼 ${tsBuffer}분 적용): ${availableSlots.map((s) => '${s['start_time']}~${s['end_time']}').join(', ')}');
      
    } catch (e) {
      print('시간 슬롯 계산 실패: $e');
    }
    
    return availableSlots;
  }

  // =============================================================================
  // 유틸리티 함수들
  // =============================================================================

  static int _timeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static String _minutesToTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static String _calculateEndTime(String startTime, int durationMinutes) {
    final startMinutes = _timeToMinutes(startTime);
    final endMinutes = startMinutes + durationMinutes;
    return _minutesToTime(endMinutes);
  }

  // =============================================================================
  // 모든 타석 관련 헬퍼 함수들
  // =============================================================================

  /// 모든 타석 정보 조회
  static Future<Map<String, dynamic>> _getAllTsInfo(String branchId, int durationMinutes) async {
    try {
      print('🔍 [타석] 타석 정보 조회 시작 (요청 시간: ${durationMinutes}분)');
      final result = await ApiService.getTsInfo();

      // 회원 타입 조회
      final currentUser = ApiService.getCurrentUser();
      final memberId = currentUser?['member_id']?.toString();
      String memberType = '';

      if (memberId != null) {
        try {
          memberType = await ApiService.getMemberType(memberId: memberId);
          print('   회원 타입: $memberType');
        } catch (e) {
          print('   ⚠️  회원 타입 조회 실패: $e');
          memberType = '';
        }
      }

      List<Map<String, dynamic>> validTsList = [];
      int totalTsCount = 0;
      int statusFailCount = 0;
      int timeFailCount = 0;
      int memberTypeFailCount = 0;

      // API 응답 처리
      if (result != null && result is List) {
        totalTsCount = result.length;
        print('   전체 타석 수: ${totalTsCount}개');

        // 각 타석 정보 검증
        for (final tsData in result) {
          if (tsData is Map<String, dynamic>) {
            final tsId = tsData['ts_id']?.toString();
            final tsStatus = tsData['ts_status']?.toString();
            final minMinutes = int.tryParse(tsData['ts_min_minimum']?.toString() ?? '0') ?? 0;
            final maxMinutes = int.tryParse(tsData['ts_min_maximum']?.toString() ?? '999') ?? 999;
            final memberTypeProhibited = tsData['member_type_prohibited']?.toString() ?? '';

            // 1. 타석 상태 체크
            if (tsStatus != '예약가능') {
              statusFailCount++;
              continue;
            }

            // 2. 시간 제한 체크
            if (durationMinutes < minMinutes || durationMinutes > maxMinutes) {
              timeFailCount++;
              continue;
            }

            // 3. 회원 타입 제한 체크
            if (memberTypeProhibited.isNotEmpty && memberType.isNotEmpty) {
              final prohibitedTypes = memberTypeProhibited.split(',').map((t) => t.trim()).toList();
              if (prohibitedTypes.contains(memberType)) {
                memberTypeFailCount++;
                continue;
              }
            }

            // 모든 조건을 통과한 타석만 추가
            if (tsId != null) {
              validTsList.add(tsData);
            }
          }
        }
      }

      print('');
      print('   📊 타석 필터링 결과:');
      print('      전체 타석: ${totalTsCount}개');
      print('      상태 불가(ts_status != 예약가능): ${statusFailCount}개');
      print('      시간 제한(${durationMinutes}분이 min/max 범위 밖): ${timeFailCount}개');
      print('      회원 타입 제한(member_type_prohibited에 포함): ${memberTypeFailCount}개');
      print('      최종 사용 가능: ${validTsList.length}개');

      if (validTsList.isEmpty) {
        print('   ❌ 사용 가능한 타석이 0개입니다!');
      }

      return {
        'success': true,
        'data': validTsList,
      };
    } catch (e) {
      print('   ❌ 실패: 타석 정보 조회 오류 - $e');
      return {
        'success': false,
        'error': '모든 타석 정보 조회 실패: $e'
      };
    }
  }

  /// 모든 타석의 기존 예약 조회
  static Future<Map<String, List<Map<String, dynamic>>>> _getAllExistingReservations(String branchId, String date) async {
    try {
      print('🔍 [타석] 기존 예약 조회 시작 (날짜: $date)');
      final result = await ApiService.getTsReservationsByDate(date: date);

      Map<String, List<Map<String, dynamic>>> reservationsByTs = {};

      // API 응답 처리
      if (result != null) {
        if (result is Map<String, dynamic>) {
          // 타석별로 그룹화된 데이터 처리
          result.forEach((key, value) {
            if (value is List) {
              final tsId = key.toString();
              final reservations = <Map<String, dynamic>>[];

              for (final item in value) {
                if (item is Map<String, dynamic>) {
                  reservations.add(item);
                }
              }

              reservationsByTs[tsId] = reservations;
            }
          });
        } else if (result is List) {
          // 리스트 형태의 데이터 처리
          final resultList = result as List<dynamic>;
          for (final item in resultList) {
            if (item is Map<String, dynamic>) {
              final tsId = item['ts_id']?.toString();
              if (tsId != null) {
                reservationsByTs[tsId] ??= [];
                reservationsByTs[tsId]!.add(item);
              }
            }
          }
        }
      }

      final totalReservations = reservationsByTs.values.fold(0, (sum, list) => sum + list.length);
      print('   기존 예약 총 ${totalReservations}건');

      if (totalReservations > 0) {
        print('   📊 타석별 예약 현황:');
        reservationsByTs.forEach((tsId, reservations) {
          if (reservations.isNotEmpty) {
            print('      타석 ${tsId}: ${reservations.length}건');
            for (var res in reservations) {
              final start = res['ts_start']?.toString() ?? '??:??';
              final end = res['ts_end']?.toString() ?? '??:??';
              print('         - ${start} ~ ${end}');
            }
          }
        });
      }

      return reservationsByTs;
    } catch (e) {
      print('   ❌ 실패: 예약 조회 오류 - $e');
      return {};
    }
  }

  /// 시간대별 가용 타석 계산
  static List<Map<String, dynamic>> _calculateTimeSlotAvailabilityForAllTs(
    Map<String, dynamic> schedule,
    List<Map<String, dynamic>> allTsInfo,
    Map<String, List<Map<String, dynamic>>> allReservations,
    DateTime selectedDate,
    int durationMinutes,
    int timeSlotInterval,
  ) {
    final timeSlotAvailability = <Map<String, dynamic>>[];
    final unavailableTimeSlots = <Map<String, dynamic>>[];
    
    try {
      final businessStart = schedule['business_start']?.toString() ?? '09:00';
      final businessEnd = schedule['business_end']?.toString() ?? '22:00';
      
      final businessStartMinutes = _timeToMinutes(businessStart);
      int businessEndMinutes = _timeToMinutes(businessEnd);
      
      // 00:00인 경우 24:00(1440분)으로 처리 (Python 로직과 동일)
      if (businessEndMinutes == 0) {
        businessEndMinutes = 1440;
        print('영업 종료 시간 00:00 -> 24:00(1440분)으로 처리');
      }
      
      // 오늘 날짜인 경우 현재 시간 이후부터 시작
      int startFromMinutes = businessStartMinutes;
      if (selectedDate.year == DateTime.now().year && 
          selectedDate.month == DateTime.now().month && 
          selectedDate.day == DateTime.now().day) {
        final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
        // 5분 단위로 올림 처리 (Python 로직과 동일)
        final adjustedMinutes = ((nowMinutes / timeSlotInterval).ceil() * timeSlotInterval).toInt();
        startFromMinutes = adjustedMinutes > businessStartMinutes ? adjustedMinutes : businessStartMinutes;
        print('오늘 날짜: 현재 시간 ${_minutesToTime(nowMinutes)} -> ${_minutesToTime(startFromMinutes)}부터 시작');
      }
      
      // 시간 슬롯별로 체크
      for (int minutes = startFromMinutes; minutes + durationMinutes <= businessEndMinutes; minutes += timeSlotInterval) {
        final endMinutes = minutes + durationMinutes;
        final startTime = _minutesToTime(minutes);
        final endTime = _minutesToTime(endMinutes);
        
        // 각 타석별로 가용성 체크
        final availableTs = <Map<String, dynamic>>[];
        final unavailableTs = <Map<String, dynamic>>[];
        
        for (final tsInfo in allTsInfo) {
          final tsId = tsInfo['ts_id']?.toString();
          if (tsId == null) continue;
          
          final tsReservations = allReservations[tsId] ?? [];
          final tsBuffer = int.tryParse(tsInfo['ts_buffer']?.toString() ?? '0') ?? 0;
          
          // 기존 예약과 충돌 체크 (버퍼 시간 포함)
          bool hasConflict = false;
          String conflictReason = '';
          
          for (final reservation in tsReservations) {
            final resStart = _timeToMinutes(reservation['ts_start']?.toString() ?? '00:00');
            final resEnd = _timeToMinutes(reservation['ts_end']?.toString() ?? '00:00');
            
            // 기존 예약 종료 시간에 버퍼 시간 추가
            final resEndWithBuffer = resEnd + tsBuffer;
            
            // 충돌 체크: 새 예약 시작이 기존 예약 종료+버퍼 이전이거나, 새 예약 종료가 기존 예약 시작 이후인 경우
            if (minutes < resEndWithBuffer && endMinutes > resStart) {
              hasConflict = true;
              conflictReason = '기존예약(${reservation['ts_start']}~${reservation['ts_end']})';
              if (tsBuffer > 0) {
                conflictReason += '+버퍼${tsBuffer}분';
              }
              break;
            }
          }
          
          if (!hasConflict) {
            availableTs.add({
              'ts_id': tsId,
              'ts_name': tsInfo['ts_name'] ?? '타석 $tsId',
              'ts_buffer': tsBuffer,
            });
          } else {
            unavailableTs.add({
              'ts_id': tsId,
              'ts_name': tsInfo['ts_name'] ?? '타석 $tsId',
              'ts_buffer': tsBuffer,
              'conflict_reason': conflictReason,
            });
          }
        }
        
        // 가용한 타석이 있는 시간대는 가용 목록에 추가
        if (availableTs.isNotEmpty) {
          timeSlotAvailability.add({
            'start_time': startTime,
            'end_time': endTime,
            'start_minutes': minutes,
            'end_minutes': endMinutes,
            'duration_minutes': durationMinutes,
            'available_ts': availableTs,
            'available_ts_count': availableTs.length,
          });
        }
        
        // 예약 불가 타석이 있는 시간대는 불가 목록에 추가
        if (unavailableTs.isNotEmpty) {
          unavailableTimeSlots.add({
            'start_time': startTime,
            'end_time': endTime,
            'start_minutes': minutes,
            'end_minutes': endMinutes,
            'duration_minutes': durationMinutes,
            'unavailable_ts': unavailableTs,
            'unavailable_ts_count': unavailableTs.length,
          });
        }
      }
      
      print('');
      print('🔍 [타석] 시간대별 가용 타석 계산 결과:');
      print('   검토한 시간대 수: ${(businessEndMinutes - startFromMinutes) ~/ timeSlotInterval}개');
      print('   가용 시간대 수: ${timeSlotAvailability.length}개');
      print('   불가 시간대 수: ${unavailableTimeSlots.length}개');

      if (timeSlotAvailability.isEmpty) {
        print('');
        print('   ❌ 가용 시간대가 0개입니다!');
        print('   🔍 실제 판단 근거:');
        print('      - 영업시간: ${businessStart} ~ ${businessEnd}');
        print('      - 요청 시간: ${durationMinutes}분');
        print('      - 사용 가능 타석: ${allTsInfo.length}개');
        print('      - 검토한 모든 시간대에서 가용 타석이 없었습니다.');
        print('');
        print('   📊 모든 시간대가 예약불가인 이유:');
        // 처음 10개 시간대의 불가 사유 표시
        final sampleCount = unavailableTimeSlots.length < 10 ? unavailableTimeSlots.length : 10;
        for (int i = 0; i < sampleCount; i++) {
          final slot = unavailableTimeSlots[i];
          final unavailableTsList = slot['unavailable_ts'] as List<dynamic>;
          print('      ${slot['start_time']}~${slot['end_time']}:');
          print('         전체 타석 ${allTsInfo.length}개 중 ${unavailableTsList.length}개 모두 불가');
          for (var ts in unavailableTsList) {
            print('         - 타석 ${ts['ts_id']}: ${ts['conflict_reason']}');
          }
        }
        if (unavailableTimeSlots.length > 10) {
          print('      ... 외 ${unavailableTimeSlots.length - 10}개 시간대 더');
        }
      } else {
        print('');
        print('   📅 가용 시간대 (처음 10개):');
        for (int i = 0; i < timeSlotAvailability.length && i < 10; i++) {
          final slot = timeSlotAvailability[i];
          final tsDetails = (slot['available_ts'] as List).map((ts) =>
            '@${ts['ts_id']}(버퍼${ts['ts_buffer']}분)').join(' ');
          print('      ${slot['start_time']}~${slot['end_time']}: $tsDetails');
        }
        if (timeSlotAvailability.length > 10) {
          print('      ... 외 ${timeSlotAvailability.length - 10}개 시간대 더');
        }
      }
      
    } catch (e) {
      print('시간대별 가용 타석 계산 실패: $e');
    }
    
    return timeSlotAvailability;
  }
} 