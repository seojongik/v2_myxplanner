import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import 'package:intl/intl.dart';

class SpLsAvailabilityService {
  /// 특수 예약 레슨 가능한 시간 옵션 조회
  static Future<Map<String, dynamic>> findAvailableLessonTimeOptions({
    required String branchId,
    required String memberId,
    required DateTime selectedDate,
    required String selectedProId,
    required String selectedProName,
    required Map<String, dynamic> specialSettings,
  }) async {
    try {
      final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      print('🔍 레슨 시간 옵션 검색 시작');
      print('📍 지점 ID: $branchId');
      print('👤 회원 ID: $memberId');
      print('📅 선택 날짜: $selectedDateStr');
      print('👨‍🏫 선택 프로: $selectedProName ($selectedProId)');
      print('=' * 60);
      
      // 1. 세션 계획 파싱 (timeBlocks 반환)
      final timeBlocks = _parseSessionPlan(specialSettings);
      if (timeBlocks.isEmpty) {
        return {
          'success': false,
          'error': '세션 계획을 파싱할 수 없습니다.'
        };
      }
      
      final totalDuration = _calculateTotalSessionDuration(timeBlocks);
      print('📋 세션 계획 파싱 완료 - 총 소요시간: ${totalDuration}분');
      
      // 2. 모든 필요한 데이터 수집
      print('\n📦 필요한 데이터 수집 중...');
      final allData = await _fetchAllLessonData(branchId, memberId, selectedDateStr, selectedProId, timeBlocks);
      if (!allData['success']) {
        return allData;
      }
      
      // 3. 시간 옵션 처리
      print('\n🔄 시간 옵션 처리 중...');
      final timeOptionsResult = _processLessonTimeOptionsLocally(allData, timeBlocks);
      
      print('✅ 레슨 시간 옵션 검색 완료');
      print('  전체 검토 시간대: ${timeOptionsResult['available'].length + timeOptionsResult['unavailable'].length}개');
      print('  예약 가능: ${timeOptionsResult['available'].length}개');
      print('  예약 불가: ${timeOptionsResult['unavailable'].length}개');
      
      return {
        'success': true,
        'time_blocks': timeBlocks,
        'total_duration': totalDuration,
        'available_options': timeOptionsResult['available'],
        'unavailable_options': timeOptionsResult['unavailable'],
        'pro_info': allData['pro_info_formatted'],
        'work_schedule': allData['work_schedule_formatted'],
        'remaining_lessons': allData['remaining_lesson_result'],
        'summary': {
          'date': selectedDateStr,
          'pro_id': selectedProId,
          'pro_name': selectedProName,
          'total_duration': totalDuration,
          'total_available_options': timeOptionsResult['available'].length,
          'total_unavailable_options': timeOptionsResult['unavailable'].length,
        }
      };
      
    } catch (e) {
      print('❌ 레슨 시간 옵션 검색 실패: $e');
      return {
        'success': false,
        'error': '레슨 시간 옵션 검색 중 오류: $e'
      };
    }
  }

  /// 세션 계획 파싱 (순서 번호에 따라 break_min -> ls_min 순서)
  static List<Map<String, dynamic>> _parseSessionPlan(Map<String, dynamic> specialSettings) {
    final sessionPlan = <Map<String, dynamic>>[];
    
    // 모든 키를 수집하고 순서대로 정렬
    final Map<int, int> lsMinMap = {};
    final Map<int, int> lsBreakMinMap = {};
    
    specialSettings.forEach((key, value) {
      if (key.startsWith('ls_min(') && key.endsWith(')')) {
        final orderNum = int.tryParse(key.substring(7, key.length - 1)) ?? 0;
        final duration = int.tryParse(value?.toString() ?? '0') ?? 0;
        if (orderNum > 0 && duration > 0) {
          lsMinMap[orderNum] = duration;
        }
      } else if (key.startsWith('ls_break_min(') && key.endsWith(')')) {
        final orderNum = int.tryParse(key.substring(13, key.length - 1)) ?? 0;
        final duration = int.tryParse(value?.toString() ?? '0') ?? 0;
        if (orderNum > 0) {
          lsBreakMinMap[orderNum] = duration;
        }
      }
    });
    
    // 모든 순서 번호를 수집하고 정렬
    final allOrderNumbers = <int>{};
    allOrderNumbers.addAll(lsMinMap.keys);
    allOrderNumbers.addAll(lsBreakMinMap.keys);
    final sortedOrders = allOrderNumbers.toList()..sort();
    
    print('📋 세션 계획 파싱:');
    print('  ls_min 맵: $lsMinMap');
    print('  ls_break_min 맵: $lsBreakMinMap');
    print('  정렬된 순서: $sortedOrders');
    
    // 순서대로 세션 구성 (휴식시간과 레슨시간을 순서대로 배치)
    final timeBlocks = <Map<String, dynamic>>[];
    
    for (final orderNum in sortedOrders) {
      final breakTime = lsBreakMinMap[orderNum] ?? 0;
      final lessonDuration = lsMinMap[orderNum] ?? 0;
      
      // 휴식시간이 있으면 먼저 추가
      if (breakTime > 0) {
        timeBlocks.add({
          'type': 'break',
          'order_number': orderNum,
          'duration': breakTime,
        });
        print('  순서 ${orderNum}: 휴식 ${breakTime}분');
      }
      
      // 레슨시간이 있으면 추가
      if (lessonDuration > 0) {
        timeBlocks.add({
          'type': 'lesson',
          'order_number': orderNum,
          'duration': lessonDuration,
        });
        print('  순서 ${orderNum}: 레슨 ${lessonDuration}분');
      }
    }
    
    // 레슨 세션만 추출하여 세션 계획 구성
    int sessionNumber = 1;
    for (int i = 0; i < timeBlocks.length; i++) {
      final block = timeBlocks[i];
      if (block['type'] == 'lesson') {
        sessionPlan.add({
          'session_number': sessionNumber,
          'order_number': block['order_number'],
          'lesson_duration': block['duration'],
        });
        sessionNumber++;
      }
    }
    
    print('  시간 블록 순서:');
    for (int i = 0; i < timeBlocks.length; i++) {
      final block = timeBlocks[i];
      print('    ${i + 1}. ${block['type'] == 'break' ? '휴식' : '레슨'} ${block['duration']}분 (순서 ${block['order_number']})');
    }
    
    print('  최종 세션 계획:');
    for (final session in sessionPlan) {
      print('    세션 ${session['session_number']} (순서 ${session['order_number']}): 레슨 ${session['lesson_duration']}분');
    }
    
    return timeBlocks; // 전체 시간 블록을 반환
  }

  /// 전체 세션 소요 시간 계산 (모든 휴식시간 포함)
  static int _calculateTotalSessionDuration(List<Map<String, dynamic>> timeBlocks) {
    int total = 0;
    
    for (final block in timeBlocks) {
      total += block['duration'] as int;
    }
    
    return total;
  }

  /// 모든 레슨 데이터 수집
  static Future<Map<String, dynamic>> _fetchAllLessonData(
    String branchId, String memberId, String selectedDate, String selectedProId, List<Map<String, dynamic>> timeBlocks
  ) async {
    try {
      // 1. 프로 정보 조회
      final proInfoResult = await _getProInfo(selectedProId);
      if (!proInfoResult['success']) {
        return proInfoResult;
      }
      
      // 2. 프로 스케줄 조회
      final proScheduleResult = await _getProSchedule(selectedProId, selectedDate);
      if (!proScheduleResult['success']) {
        return proScheduleResult;
      }
      
      // 3. 기존 예약 조회
      final existingReservations = await _getExistingReservations(selectedProId, selectedDate);
      
      // 4. 잔여 레슨 체크 (레슨 세션만 추출)
      final lessonSessions = timeBlocks.where((block) => block['type'] == 'lesson').toList();
      final remainingLessonResult = await _checkRemainingLessons(branchId, memberId, selectedProId, lessonSessions);
      if (!remainingLessonResult['success']) {
        return remainingLessonResult;
      }
      
      return {
        'success': true,
        'pro_info': proInfoResult['data'],
        'pro_info_formatted': proInfoResult['formatted'],
        'work_schedule': proScheduleResult['data'],
        'work_schedule_formatted': proScheduleResult['formatted'],
        'existing_reservations': existingReservations,
        'remaining_lesson_result': remainingLessonResult,
      };
      
    } catch (e) {
      return {
        'success': false,
        'error': '레슨 데이터 수집 실패: $e'
      };
    }
  }

  /// 프로 정보 조회
  static Future<Map<String, dynamic>> _getProInfo(String proId) async {
    try {
      final result = await ApiService.getData(
        table: 'v2_staff_pro',
        where: [
          {'field': 'pro_id', 'operator': '=', 'value': proId}
        ],
      );
      
      if (result.isNotEmpty) {
        final proData = result.first;
        return {
          'success': true,
          'data': proData,
          'formatted': {
            'name': proData['pro_name'] ?? '프로 $proId',
            'min_service_min': int.tryParse(proData['min_service_min']?.toString() ?? '30') ?? 30,
            'svc_time_unit': int.tryParse(proData['svc_time_unit']?.toString() ?? '5') ?? 5,
            'min_reservation_min': int.tryParse(proData['min_reservation_min']?.toString() ?? '30') ?? 30,
            'reservation_ahead_days': int.tryParse(proData['reservation_ahead_days']?.toString() ?? '7') ?? 7,
          }
        };
      } else {
        return {
          'success': false,
          'error': '프로 정보를 찾을 수 없습니다.'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': '프로 정보 조회 실패: $e'
      };
    }
  }

  /// 프로 스케줄 조회
  static Future<Map<String, dynamic>> _getProSchedule(String proId, String date) async {
    try {
      final result = await ApiService.getData(
        table: 'v2_schedule_adjusted_pro',
        where: [
          {'field': 'pro_id', 'operator': '=', 'value': proId},
          {'field': 'scheduled_date', 'operator': '=', 'value': date},
        ],
      );
      
      Map<String, dynamic> scheduleData;
      if (result.isNotEmpty) {
        scheduleData = result.first;
      } else {
        // 기본 스케줄
        scheduleData = {
          'work_start': '09:00:00',
          'work_end': '18:00:00',
          'is_day_off': null,
        };
      }
      
      // 휴무일 체크
      if (scheduleData['is_day_off'] == '휴무') {
        return {
          'success': false,
          'error': '선택된 날짜는 프로 휴무일입니다.'
        };
      }
      
      return {
        'success': true,
        'data': scheduleData,
        'formatted': {
          'start': scheduleData['work_start']?.toString().substring(0, 5) ?? '09:00',
          'end': scheduleData['work_end']?.toString().substring(0, 5) ?? '18:00',
          'is_day_off': scheduleData['is_day_off'],
        }
      };
    } catch (e) {
      return {
        'success': false,
        'error': '프로 스케줄 조회 실패: $e'
      };
    }
  }

  /// 기존 예약 조회
  static Future<List<Map<String, dynamic>>> _getExistingReservations(String proId, String date) async {
    try {
      print('🔍 [레슨] 기존 예약 조회 시작 (프로 ID: $proId, 날짜: $date)');

      final result = await ApiService.getData(
        table: 'v2_LS_orders',
        where: [
          {'field': 'pro_id', 'operator': '=', 'value': proId},
          {'field': 'LS_date', 'operator': '=', 'value': date},
        ],
        orderBy: [
          {'field': 'LS_start_time', 'direction': 'ASC'}
        ],
      );

      print('   기존 예약 총 ${result.length}건');
      if (result.isNotEmpty) {
        print('   📊 예약 현황:');
        for (var res in result) {
          final start = res['LS_start_time']?.toString() ?? '??:??';
          final end = res['LS_end_time']?.toString() ?? '??:??';
          print('      - ${start} ~ ${end}');
        }
      }

      return result;
    } catch (e) {
      print('   ❌ 실패: 기존 예약 조회 오류 - $e');
      return [];
    }
  }

  /// 잔여 레슨 체크
  static Future<Map<String, dynamic>> _checkRemainingLessons(
    String branchId, String memberId, String selectedProId, List<Map<String, dynamic>> lessonSessions
  ) async {
    try {
      // 전체 필요한 레슨 시간 계산
      final totalLessonTime = lessonSessions.fold<int>(0, (sum, session) => sum + (session['duration'] as int));

      print('🔍 [레슨] 잔여 레슨 체크 시작');
      print('   필요한 총 레슨시간: ${totalLessonTime}분');
      print('   레슨 세션 수: ${lessonSessions.length}개');

      // 회원의 레슨 카운팅 데이터 조회
      final result = await ApiService.getData(
        table: 'v3_LS_countings',
        fields: ['pro_id', 'LS_balance_min_after', 'LS_expiry_date', 'LS_contract_id', 'LS_counting_id'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
          {'field': 'LS_balance_min_after', 'operator': '>', 'value': '0'},
        ],
      );

      print('   v3_LS_countings 조회 결과: ${result.length}건');

      if (result.isEmpty) {
        print('   ❌ 실패: 레슨 카운팅 데이터 없음 (LS_balance_min_after > 0 조건)');
        return {
          'success': false,
          'error': '회원의 레슨 계약 정보를 조회할 수 없습니다.'
        };
      }

      // 만료일 체크
      final today = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(today);
      final validRecords = result.where((record) {
        final expiryDate = record['LS_expiry_date']?.toString() ?? '';
        return expiryDate.isNotEmpty && expiryDate.compareTo(todayStr) >= 0;
      }).toList();

      print('   만료일 체크 (오늘: $todayStr):');
      print('      전체: ${result.length}건 → 유효: ${validRecords.length}건 (만료: ${result.length - validRecords.length}건)');

      if (validRecords.isEmpty) {
        print('   ❌ 실패: 모든 레슨권이 만료됨 (LS_expiry_date < $todayStr)');
        return {
          'success': false,
          'error': '유효한 레슨 계약이 없습니다.'
        };
      }

      // 선택된 프로의 유효한 계약 필터링
      final validContracts = <Map<String, dynamic>>[];
      int otherProCount = 0;

      for (final contract in validRecords) {
        final contractProId = contract['pro_id']?.toString() ?? '';
        final balanceMin = int.tryParse(contract['LS_balance_min_after']?.toString() ?? '0') ?? 0;

        if (contractProId == selectedProId && balanceMin > 0) {
          validContracts.add({
            'contract_id': contract['LS_contract_id']?.toString() ?? '',
            'counting_id': contract['LS_counting_id']?.toString() ?? '',
            'balance_min': balanceMin,
            'expiry_date': contract['LS_expiry_date']?.toString() ?? '',
            'sufficient': balanceMin >= totalLessonTime,
          });
        } else if (contractProId != selectedProId) {
          otherProCount++;
        }
      }

      print('   프로별 레슨권 분류:');
      print('      선택된 프로(ID: $selectedProId): ${validContracts.length}건');
      print('      다른 프로: ${otherProCount}건');

      if (validContracts.isEmpty) {
        print('   ❌ 실패: 선택된 프로의 레슨권 없음 (pro_id != $selectedProId)');
        return {
          'success': false,
          'error': '선택된 프로의 잔여 레슨시간이 부족합니다.'
        };
      }

      print('');
      print('   📊 선택된 프로의 레슨권 상세:');
      for (final contract in validContracts) {
        print('      계약 ID: ${contract['contract_id']}, 잔여: ${contract['balance_min']}분, 만료일: ${contract['expiry_date']}, 충분: ${contract['sufficient']}');
      }

      // 사용 가능한 계약이 있는지 확인
      final sufficientContracts = validContracts.where((c) => c['sufficient'] == true).toList();

      if (sufficientContracts.isEmpty) {
        final maxBalance = validContracts.map((c) => c['balance_min'] as int).reduce((a, b) => a > b ? a : b);
        print('   ❌ 실패: 모든 레슨권 잔액 부족 (필요: ${totalLessonTime}분, 최대 잔액: ${maxBalance}분)');
        return {
          'success': false,
          'error': '선택된 프로의 잔여 레슨시간이 부족합니다. 필요: ${totalLessonTime}분, 최대 잔액: ${maxBalance}분'
        };
      }

      print('   ✅ 사용 가능한 계약: ${sufficientContracts.length}개');

      return {
        'success': true,
        'total_lesson_time': totalLessonTime,
        'valid_contracts': validContracts,
        'sufficient_contracts': sufficientContracts,
      };

    } catch (e) {
      print('   ❌ 실패: 잔여 레슨 체크 오류 - $e');
      return {
        'success': false,
        'error': '잔여 레슨 체크 실패: $e'
      };
    }
  }

  /// 레슨 시간 옵션 로컬 처리
  static Map<String, dynamic> _processLessonTimeOptionsLocally(
    Map<String, dynamic> allData, List<Map<String, dynamic>> timeBlocks
  ) {
    final workSchedule = allData['work_schedule_formatted'];
    final proInfo = allData['pro_info_formatted'];
    final existingReservations = allData['existing_reservations'] as List<Map<String, dynamic>>;
    
    final workStart = workSchedule['start'] as String;
    final workEnd = workSchedule['end'] as String;
    final totalDuration = _calculateTotalSessionDuration(timeBlocks);
    
    return _findTimeSlots(workStart, workEnd, existingReservations, totalDuration, proInfo, timeBlocks);
  }

  /// 가능한 시간대 찾기
  static Map<String, dynamic> _findTimeSlots(
    String workStart, String workEnd, List<Map<String, dynamic>> reservations,
    int totalDuration, Map<String, dynamic> proInfo, List<Map<String, dynamic>> timeBlocks
  ) {
    final workStartMinutes = _timeToMinutes(workStart);
    final workEndMinutes = _timeToMinutes(workEnd);
    // 프로 정보 기반 제약 - 현재 미사용 (나중에 활성화 가능)
    // final minServiceMin = proInfo['min_service_min'] as int;
    // final svcTimeUnit = proInfo['svc_time_unit'] as int;
    
    // 예약된 시간들을 분 단위로 변환
    final blockedPeriods = <List<int>>[];
    for (final reservation in reservations) {
      final startMin = _timeToMinutes(reservation['LS_start_time']?.toString() ?? '00:00');
      final endMin = _timeToMinutes(reservation['LS_end_time']?.toString() ?? '00:00');
      blockedPeriods.add([startMin, endMin]);
    }
    
    // 가능한 시간과 불가능한 시간 분류
    final availableOptions = <Map<String, dynamic>>[];
    final unavailableOptions = <Map<String, dynamic>>[];
    
    print('🔍 시간 슬롯 검색:');
    print('  근무시간: ${workStart}~${workEnd} (${workStartMinutes}~${workEndMinutes}분)');
    print('  총 소요시간: ${totalDuration}분');
    print('  기존 예약: ${blockedPeriods.length}개');
    for (final blocked in blockedPeriods) {
      print('    ${_minutesToTime(blocked[0])}~${_minutesToTime(blocked[1])}');
    }
    
    // 5분 단위로 시작시간 후보 생성
    for (int startCandidate = workStartMinutes; startCandidate <= workEndMinutes - totalDuration; startCandidate += 5) {
      final endCandidate = startCandidate + totalDuration;
      
      // 불가능한 이유 체크
      String? unavailableReason;
      
      // 근무시간 내에 완료되는지 확인
      if (endCandidate > workEndMinutes) {
        unavailableReason = '근무시간 종료 (${_minutesToTime(workEndMinutes)}) 이후까지 연장됨';
      }
      
      // 각 시간 블록의 실제 시간대 계산 및 유효성 확인
      if (unavailableReason == null) {
        int currentTime = startCandidate;
        final blockDetails = <Map<String, dynamic>>[];
        final lessonDetails = <Map<String, dynamic>>[];
        int lessonNumber = 1;
        
        for (int i = 0; i < timeBlocks.length; i++) {
          final block = timeBlocks[i];
          final blockType = block['type'] as String;
          final blockDuration = block['duration'] as int;
          final orderNumber = block['order_number'] as int;
          
          final blockStart = currentTime;
          final blockEnd = currentTime + blockDuration;
          
          if (blockType == 'lesson') {
            // 레슨 시간 유효성 확인 - 프로 정보 기반 제약 주석 처리 (나중에 활성화 가능)
            // if (blockDuration < minServiceMin) {
            //   unavailableReason = '레슨 ${lessonNumber}이 최소 레슨시간(${minServiceMin}분) 미만';
            //   break;
            // }
            // 
            // if ((blockDuration - minServiceMin) % svcTimeUnit != 0) {
            //   unavailableReason = '레슨 ${lessonNumber}이 올바른 시간 단위(${svcTimeUnit}분)가 아님';
            //   break;
            // }
            
            // 레슨 시간이 기존 예약과 겹치는지 확인
            for (final blocked in blockedPeriods) {
              if (blockStart < blocked[1] && blockEnd > blocked[0]) {
                unavailableReason = '레슨 ${lessonNumber}이 기존 예약과 겹침 (${_minutesToTime(blocked[0])}~${_minutesToTime(blocked[1])})';
                break;
              }
            }
            
            if (unavailableReason != null) break;
            
            lessonDetails.add({
              'lesson_number': lessonNumber,
              'order_number': orderNumber,
              'start_time': _minutesToTime(blockStart),
              'end_time': _minutesToTime(blockEnd),
              'duration': blockDuration,
            });
            
            lessonNumber++;
          }
          
          blockDetails.add({
            'type': blockType,
            'order_number': orderNumber,
            'start_time': _minutesToTime(blockStart),
            'end_time': _minutesToTime(blockEnd),
            'duration': blockDuration,
          });
          
          currentTime = blockEnd;
        }
        
        if (unavailableReason == null) {
          availableOptions.add({
            'start_time': _minutesToTime(startCandidate),
            'end_time': _minutesToTime(endCandidate),
            'total_duration': totalDuration,
            'block_details': blockDetails,
            'lesson_details': lessonDetails,
          });
        }
      }
      
      // 불가능한 시간대 기록
      if (unavailableReason != null) {
        unavailableOptions.add({
          'start_time': _minutesToTime(startCandidate),
          'end_time': _minutesToTime(endCandidate),
          'reason': unavailableReason,
        });
      }
    }
    
    // 결과 출력
    print('');
    print('🔍 [레슨] 시간 슬롯 계산 결과:');
    print('   검토한 시간대 수: ${availableOptions.length + unavailableOptions.length}개');
    print('   가용 시간대 수: ${availableOptions.length}개');
    print('   불가 시간대 수: ${unavailableOptions.length}개');

    if (availableOptions.isEmpty) {
      print('');
      print('   ❌ 가용 시간대가 0개입니다!');
      print('   🔍 실제 판단 근거:');
      print('      - 프로 근무시간: ${workStart} ~ ${workEnd}');
      print('      - 필요한 총 시간: ${totalDuration}분');
      print('      - 기존 레슨 예약: ${reservations.length}건');
      print('');
      print('   📊 모든 시간대가 예약불가인 이유:');
      // 처음 10개 시간대의 불가 사유 표시
      final sampleCount = unavailableOptions.length < 10 ? unavailableOptions.length : 10;
      for (int i = 0; i < sampleCount; i++) {
        final option = unavailableOptions[i];
        print('      ${option['start_time']}~${option['end_time']}: ${option['reason']}');
      }
      if (unavailableOptions.length > 10) {
        print('      ... 외 ${unavailableOptions.length - 10}개 시간대 더');
      }
    } else {
      print('');
      print('   📅 가용 시간대 (처음 10개):');
      for (int i = 0; i < availableOptions.length && i < 10; i++) {
        final option = availableOptions[i];
        final blockDetails = option['block_details'] as List<Map<String, dynamic>>;

        print('      ${option['start_time']}~${option['end_time']}:');
        for (final block in blockDetails) {
          final blockType = block['type'] == 'break' ? '휴식' : '레슨';
          print('         ${blockType} ${block['start_time']}~${block['end_time']}(${block['duration']}분, 순서${block['order_number']})');
        }
      }
      if (availableOptions.length > 10) {
        print('      ... 외 ${availableOptions.length - 10}개 시간대 더');
      }
    }
    
    return {
      'available': availableOptions,
      'unavailable': unavailableOptions,
    };
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
} 