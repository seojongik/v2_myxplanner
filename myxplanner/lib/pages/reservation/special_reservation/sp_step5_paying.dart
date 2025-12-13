import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../services/tile_design_service.dart';
import 'sp_db_update.dart';

class SpStep5Paying extends StatefulWidget {
  final Function(Map<String, dynamic>) onPaymentCompleted;
  final Function(Map<String, dynamic>)? onContractSelected; // 회원권 선택 콜백 추가
  final DateTime? selectedDate;
  final int? selectedProId;
  final String? selectedProName;
  final String? selectedTime;
  final String? selectedTsId;
  final Map<String, dynamic> specialSettings;
  final List<Map<String, dynamic>>? cachedTimePassContracts;
  final List<Map<String, dynamic>>? cachedLessonContracts;
  final bool isMembershipDataLoaded;
  final String? specialType;
  final Map<String, dynamic>? selectedMember;

  const SpStep5Paying({
    Key? key,
    required this.onPaymentCompleted,
    this.onContractSelected,
    this.selectedDate,
    this.selectedProId,
    this.selectedProName,
    this.selectedTime,
    this.selectedTsId,
    required this.specialSettings,
    this.cachedTimePassContracts,
    this.cachedLessonContracts,
    this.isMembershipDataLoaded = false,
    this.specialType,
    this.selectedMember,
  }) : super(key: key);

  @override
  State<SpStep5Paying> createState() => _SpStep5PayingState();
}

class _SpStep5PayingState extends State<SpStep5Paying> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _timePassContracts = [];
  List<Map<String, dynamic>> _lessonContracts = [];
  List<Map<String, dynamic>> _availableContracts = [];
  Map<String, dynamic>? _selectedContract;

  // 선택된 회원권 정보 getter
  Map<String, dynamic>? get selectedContract => _selectedContract;

  @override
  void initState() {
    super.initState();
    _debugPrintStepInfo();
    _loadPaymentData();
  }

  void _debugPrintStepInfo() {
    print('');
    print('═══════════════════════════════════════════════════════════');
    print('STEP5 (결제) 진입 - 선택된 예약 정보');
    print('═══════════════════════════════════════════════════════════');
    print('선택된 날짜: ${widget.selectedDate?.toString().split(' ')[0] ?? 'null'}');
    print('선택된 프로: ${widget.selectedProName ?? 'null'} (ID: ${widget.selectedProId ?? 'null'})');
    print('선택된 시간: ${widget.selectedTime ?? 'null'}');
    print('선택된 타석: ${widget.selectedTsId ?? 'null'}번 타석');
    print('');
    print('특수 예약 설정:');
    widget.specialSettings.forEach((key, value) {
      print('  $key = $value');
    });
    print('═══════════════════════════════════════════════════════════');
    print('');
  }

  // ts_min 합계 계산
  int _getTotalTsMin() {
    int totalTsMin = 0;
    widget.specialSettings.forEach((key, value) {
      if (key == 'ts_min' || key.startsWith('ts_min(')) {
        int minValue = 0;
        if (value != null && value.toString().isNotEmpty) {
          minValue = int.tryParse(value.toString()) ?? 0;
        }
        totalTsMin += minValue;
      }
    });
    return totalTsMin;
  }

  // ls_min 합계 계산
  int _getTotalLsMin() {
    int totalLsMin = 0;
    widget.specialSettings.forEach((key, value) {
      if (key.startsWith('ls_min(')) {
        int minValue = 0;
        if (value != null && value.toString().isNotEmpty) {
          minValue = int.tryParse(value.toString()) ?? 0;
        }
        totalLsMin += minValue;
      }
    });
    return totalLsMin;
  }

  // 계약 제약조건 체크 (회원권 제시 여부 결정)
  bool _checkContractConstraints(Map<String, dynamic> contract, Map<String, dynamic>? contractDetail, Map<String, int> dailyUsage) {
    // 계약 상세 정보가 없으면 통과
    if (contractDetail == null) {
      return true;
    }

    // 계약 상세 정보 병합
    final mergedContract = Map<String, dynamic>.from(contract);
    mergedContract.addAll(contractDetail);

    // 필요한 정보가 없으면 통과
    if (widget.selectedDate == null || widget.selectedTime == null || widget.selectedTsId == null) {
      return true;
    }

    final selectedDate = widget.selectedDate!;
    final selectedTime = widget.selectedTime!;
    final selectedTs = widget.selectedTsId.toString();

    // 1. 시간대 체크 (available_start_time, available_end_time)
    final availableStartTime = mergedContract['available_start_time']?.toString();
    final availableEndTime = mergedContract['available_end_time']?.toString();

    if (availableStartTime != null && availableStartTime.isNotEmpty && availableStartTime != 'null' &&
        availableEndTime != null && availableEndTime.isNotEmpty && availableEndTime != 'null') {
      
      if (availableStartTime != '전체' && availableEndTime != '전체') {
        try {
          // 선택한 시간을 분 단위로 변환
          final selectedTimeParts = selectedTime.split(':');
          final selectedHour = int.parse(selectedTimeParts[0]);
          final selectedMinute = selectedTimeParts.length > 1 ? int.parse(selectedTimeParts[1]) : 0;
          final selectedTimeInMinutes = selectedHour * 60 + selectedMinute;
          
          // 예약 시간 계산 (specialSettings에서 ts_min 합계 사용)
          final totalTsMin = _getTotalTsMin();
          final selectedEndTimeInMinutes = selectedTimeInMinutes + totalTsMin;

          // 이용 가능 시간을 분 단위로 변환
          final availableStartParts = availableStartTime.split(':');
          final availableStartHour = int.parse(availableStartParts[0]);
          final availableStartMinute = availableStartParts.length > 1 ? int.parse(availableStartParts[1]) : 0;
          final availableStartInMinutes = availableStartHour * 60 + availableStartMinute;

          final availableEndParts = availableEndTime.split(':');
          final availableEndHour = int.parse(availableEndParts[0]);
          final availableEndMinute = availableEndParts.length > 1 ? int.parse(availableEndParts[1]) : 0;
          final availableEndInMinutes = availableEndHour * 60 + availableEndMinute;

          // 예약 시간이 이용 가능 시간 범위를 벗어나는지 체크
          if (selectedTimeInMinutes < availableStartInMinutes ||
              selectedEndTimeInMinutes > availableEndInMinutes) {
            print('시간권 계약 ${contract['contract_history_id']}: 시간대 불일치');
            print('  이용 가능: $availableStartTime ~ $availableEndTime');
            print('  선택 시간: $selectedTime ~ 종료 ${totalTsMin}분 후');
            return false;
          }
        } catch (e) {
          print('시간권 계약 ${contract['contract_history_id']}: 시간 파싱 오류 - $e');
        }
      }
    }

    // 2. 예약 시간 제약 체크 (max_min_reservation_ahead)
    final maxMinReservationAhead = mergedContract['max_min_reservation_ahead'];
    if (maxMinReservationAhead != null && maxMinReservationAhead != 'null' && maxMinReservationAhead != '') {
      try {
        final minReservationMinutes = int.tryParse(maxMinReservationAhead.toString());
        if (minReservationMinutes != null && minReservationMinutes > 0) {
          final selectedTimeParts = selectedTime.split(':');
          final selectedHour = int.parse(selectedTimeParts[0]);
          final selectedMinute = selectedTimeParts.length > 1 ? int.parse(selectedTimeParts[1]) : 0;
          
          final reservationDateTime = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            selectedHour,
            selectedMinute,
          );
          
          final now = DateTime.now();
          final timeDifferenceMinutes = reservationDateTime.difference(now).inMinutes;
          
          // 예약 시간이 최소 예약 시간보다 가까우면 사용 불가
          if (timeDifferenceMinutes < minReservationMinutes) {
            print('시간권 계약 ${contract['contract_history_id']}: 예약 시간 제약 불일치 (${timeDifferenceMinutes}분 < ${minReservationMinutes}분)');
            return false;
          }
        }
      } catch (e) {
        print('시간권 계약 ${contract['contract_history_id']}: 예약 시간 제약 파싱 오류 - $e');
      }
    }

    // 3. 타석 체크 (available_ts_id)
    final availableTsId = mergedContract['available_ts_id']?.toString();
    if (availableTsId != null && availableTsId.isNotEmpty && availableTsId != 'null') {
      if (availableTsId != '없음' && availableTsId != '전체') {
        bool isTsAvailable = false;

        if (availableTsId.contains('-')) {
          // 범위 형식 (1-5)
          final rangeParts = availableTsId.split('-');
          if (rangeParts.length == 2) {
            try {
              final startTs = int.parse(rangeParts[0].trim());
              final endTs = int.parse(rangeParts[1].trim());
              final selectedTsNum = int.parse(selectedTs);

              if (selectedTsNum >= startTs && selectedTsNum <= endTs) {
                isTsAvailable = true;
              }
            } catch (e) {
              print('시간권 계약 ${contract['contract_history_id']}: 타석 범위 파싱 오류 - $e');
            }
          }
        } else if (availableTsId.contains(',')) {
          // 개별 목록 (1,2,3)
          final tsList = availableTsId.split(',').map((t) => t.trim()).toList();
          if (tsList.contains(selectedTs)) {
            isTsAvailable = true;
          }
        } else {
          // 단일 타석
          if (availableTsId.trim() == selectedTs) {
            isTsAvailable = true;
          }
        }

        if (!isTsAvailable) {
          print('시간권 계약 ${contract['contract_history_id']}: 타석 불일치 (설정: $availableTsId, 선택: $selectedTs)');
          return false;
        }
      }
    }

    // 4. max_use_per_day 체크 (일일 최대 사용 시간)
    final maxUsePerDay = mergedContract['max_use_per_day'];
    if (maxUsePerDay != null && maxUsePerDay != 'null' && maxUsePerDay != '') {
      try {
        final maxDailyMinutes = int.tryParse(maxUsePerDay.toString());
        if (maxDailyMinutes != null && maxDailyMinutes > 0) {
          final contractHistoryId = contract['contract_history_id']?.toString();
          final usedToday = contractHistoryId != null ? (dailyUsage[contractHistoryId] ?? 0) : 0;
          final totalTsMin = _getTotalTsMin();
          
          // 오늘 사용한 분수 + 예약하려는 분수가 최대 일일 사용 시간을 초과하면 제외
          if (usedToday + totalTsMin > maxDailyMinutes) {
            print('시간권 계약 ${contract['contract_history_id']}: max_use_per_day 초과 - 오늘 ${usedToday}분/${maxDailyMinutes}분 이미 사용, 예약 ${totalTsMin}분 추가 시 초과');
            return false;
          }
        }
      } catch (e) {
        print('시간권 계약 ${contract['contract_history_id']}: max_use_per_day 파싱 오류 - $e');
      }
    }

    return true;
  }

  /// 회원권 선택 시 DB 업데이트 트리거
  Future<void> _triggerDatabaseUpdate(Map<String, dynamic> contract) async {
    if (widget.selectedDate == null || 
        widget.selectedProId == null || 
        widget.selectedProName == null ||
        widget.selectedTime == null ||
        widget.selectedTsId == null) {
      print('❌ 필수 예약 정보가 누락되었습니다.');
      return;
    }

    try {
      print('');
      print('🚀 DB 업데이트 서비스 호출 시작');
      
      final success = await SpDbUpdateService.updateDatabaseForReservation(
        selectedDate: widget.selectedDate!,
        selectedProId: widget.selectedProId!,
        selectedProName: widget.selectedProName!,
        selectedTime: widget.selectedTime!,
        selectedTsId: widget.selectedTsId!,
        specialSettings: widget.specialSettings,
        selectedContract: contract,
        specialType: widget.specialType,
        selectedMember: widget.selectedMember,
      );

      if (success) {
        print('✅ 모든 DB 업데이트 성공');
        
        // Step 6으로 전달할 계산된 데이터 생성
        final step6Data = await _generateStep6Data(contract);
        
        // 결제 완료 콜백 호출 (계산된 데이터 전달)
        widget.onPaymentCompleted(step6Data);
      } else {
        print('❌ 일부 DB 업데이트 실패');
        // 실패 시 사용자에게 알림 (추후 추가 가능)
      }
      
    } catch (e) {
      print('❌ DB 업데이트 서비스 호출 오류: $e');
    }
  }

  // 선택된 회원권 상세 정보 출력
  Future<void> _printSelectedContractDetails(Map<String, dynamic> contract) async {
    final currentUser = widget.selectedMember ?? ApiService.getCurrentUser();
    
    print('');
    print('═══════════════════════════════════════════════════════════');
    print('선택된 회원권 상세 정보');
    print('═══════════════════════════════════════════════════════════');
    
    // 기본 설정 정보 출력
    final branchId = ApiService.getCurrentBranchId();
    print('📋 기본 설정 정보:');
    print('member_id: ${currentUser?['member_id'] ?? 'null'}');
    print('branch_id: ${branchId ?? 'null'} (ApiService.getCurrentBranchId())');
    print('pro_id: ${widget.selectedProId ?? 'null'}');
    print('pro_name: ${widget.selectedProName ?? 'null'}');
    print('');
    
    // 그룹레슨 최대인원 설정값 출력
    print('📋 그룹레슨 설정:');
    print('최대인원: ${widget.specialSettings['max_player_no'] ?? 'null'}명');
    print('최소인원: ${widget.specialSettings['min_player_no'] ?? 'null'}명');
    print('');
    
    // 회원권 정보 출력
    print('📋 회원권 정보:');
    print('회원권명: ${contract['contract_name'] ?? 'null'}');
    print('회원권 타입: ${contract['type'] ?? 'null'}');
    print('contract_history_id: ${contract['contract_history_id'] ?? 'null'}');
    print('contract_id: ${contract['contract_id'] ?? 'null'}');
    
    if (contract['type'] == 'combined') {
      print('시간권 잔액: ${contract['time_balance'] ?? 'null'}분');
      // 최신 레슨권 잔액 조회
      final currentLessonBalance = await _getCurrentLessonBalance(contract);
      print('레슨권 잔액: ${currentLessonBalance}분');
    } else if (contract['type'] == 'time_only') {
      print('시간권 잔액: ${contract['time_balance'] ?? 'null'}분');
    } else if (contract['type'] == 'lesson_only') {
      // 최신 레슨권 잔액 조회
      final currentLessonBalance = await _getCurrentLessonBalance(contract);
      print('레슨권 잔액: ${currentLessonBalance}분');
    }
    
    print('');
    _printDetailedTimeInfo();
    print('');
    await _printMembershipDeductionDetails(contract);
    print('═══════════════════════════════════════════════════════════');
    print('');
  }

  // 최신 레슨권 잔액 조회
  Future<int> _getCurrentLessonBalance(Map<String, dynamic> contract) async {
    try {
      final contractHistoryId = contract['contract_history_id']?.toString() ?? '';
      
      if (contractHistoryId.isEmpty) {
        print('레슨권 잔액 조회 실패: contract_history_id가 없음');
        return contract['lesson_balance'] as int? ?? 0;
      }
      
      final latestBalanceResult = await ApiService.getData(
        table: 'v3_LS_countings',
        fields: ['LS_balance_min_after'],
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
        ],
        orderBy: [
          {'field': 'LS_counting_id', 'direction': 'DESC'}
        ],
        limit: 1,
      );
      
      if (latestBalanceResult.isNotEmpty && latestBalanceResult.first['LS_balance_min_after'] != null) {
        return int.tryParse(latestBalanceResult.first['LS_balance_min_after'].toString()) ?? (contract['lesson_balance'] as int? ?? 0);
      } else {
        return contract['lesson_balance'] as int? ?? 0;
      }
    } catch (e) {
      print('최신 레슨권 잔액 조회 실패: $e');
      return contract['lesson_balance'] as int? ?? 0;
    }
  }

  // 시간 정보를 세션별로 상세하게 표시
  void _printDetailedTimeInfo() {
    if (widget.selectedTime == null) {
      print('선택된 시간: null');
      return;
    }

    final startTime = widget.selectedTime!;
    print('시간 정보 상세:');
    print('선택된 시간: $startTime');
    
    // 특수 예약 설정에서 시간 정보 추출
    final tsMin = int.tryParse(widget.specialSettings['ts_min']?.toString() ?? '0') ?? 0;

    // ls_min과 ls_break_min을 순서 번호 기준으로 수집
    final Map<int, int> lsMinMap = {};
    final Map<int, int> lsBreakMinMap = {};

    widget.specialSettings.forEach((key, value) {
      if (key.startsWith('ls_min(') && key.endsWith(')')) {
        final orderNum = int.tryParse(key.substring(7, key.length - 1)) ?? 0;
        final duration = int.tryParse(value?.toString() ?? '0') ?? 0;
        if (orderNum > 0 && duration > 0) {
          lsMinMap[orderNum] = duration;
        }
      } else if (key.startsWith('ls_break_min(') && key.endsWith(')')) {
        final orderNum = int.tryParse(key.substring(13, key.length - 1)) ?? 0;
        final duration = int.tryParse(value?.toString() ?? '0') ?? 0;
        if (orderNum > 0 && duration > 0) {
          lsBreakMinMap[orderNum] = duration;
        }
      }
    });

    // 모든 순서 번호를 수집하고 정렬
    final allOrderNumbers = <int>{};
    allOrderNumbers.addAll(lsMinMap.keys);
    allOrderNumbers.addAll(lsBreakMinMap.keys);
    final sortedOrders = allOrderNumbers.toList()..sort();

    // 순서대로 시간 블록 구성 (휴식과 레슨을 순서대로 배치)
    final timeBlocks = <Map<String, dynamic>>[];
    int lessonNumber = 1;

    for (final orderNum in sortedOrders) {
      final breakTime = lsBreakMinMap[orderNum] ?? 0;
      final lessonDuration = lsMinMap[orderNum] ?? 0;

      // 휴식시간이 있으면 먼저 추가
      if (breakTime > 0) {
        timeBlocks.add({
          'type': 'break',
          'order': orderNum,
          'duration': breakTime,
        });
      }

      // 레슨시간이 있으면 추가
      if (lessonDuration > 0) {
        timeBlocks.add({
          'type': 'lesson',
          'order': orderNum,
          'lesson_number': lessonNumber,
          'duration': lessonDuration,
        });
        lessonNumber++;
      }
    }

    // 시간 계산 및 출력
    DateTime currentTime = DateTime.parse('2025-01-01 $startTime:00');

    // 프로그램 시간 (전체 타석 시간)
    if (tsMin > 0) {
      final endTime = currentTime.add(Duration(minutes: tsMin));
      print('프로그램 시간: ${_formatTime(currentTime)} ~ ${_formatTime(endTime)} (${tsMin}분)');
    }

    // 시간 블록별 시간 출력
    for (final block in timeBlocks) {
      final duration = block['duration'] as int;
      final endTime = currentTime.add(Duration(minutes: duration));

      if (block['type'] == 'lesson') {
        final lessonNum = block['lesson_number'];
        print('레슨 세션($lessonNum): ${_formatTime(currentTime)} ~ ${_formatTime(endTime)} (${duration}분)');
      } else {
        print('휴식 시간: ${_formatTime(currentTime)} ~ ${_formatTime(endTime)} (${duration}분)');
      }

      currentTime = endTime;
    }
  }

  // 회원권 차감 내역을 세션별로 디버깅 출력
  Future<void> _printMembershipDeductionDetails(Map<String, dynamic> contract) async {
    print('회원권 차감 내역 계산:');
    print('회원권: ${contract['contract_name']}');
    print('계약 타입: ${contract['type']}');
    print('');

    // 타석 시간 차감 계산
    final tsMin = int.tryParse(widget.specialSettings['ts_min']?.toString() ?? '0') ?? 0;
    if (tsMin > 0 && contract['time_balance'] != null) {
      final beforeBalance = contract['time_balance'] as int;
      final deduction = tsMin;
      final afterBalance = beforeBalance - deduction;
      
      // reservation_id 생성
      final reservationId = _generateReservationId();
      
      // 시간대 분류 및 요금 계산 (비동기 처리)
      final timeSlotAnalysis = await _classifyProgramTimeSlot();
      
      print('📋 시간권 차감 내역:');
      print('  reservation_id: $reservationId');
      print('  시간대 분류:');
      print('    discount_min: ${timeSlotAnalysis['discount_min']}분');
      print('    normal_min: ${timeSlotAnalysis['normal_min']}분');
      print('    extracharge_min: ${timeSlotAnalysis['extracharge_min']}분');
      print('  총 금액: ${timeSlotAnalysis['total_amt']}원');
      print('  변경 전 잔액: ${beforeBalance}분');
      print('  금회 차감: ${deduction}분');
      print('  변경 후 잔액: ${afterBalance}분');
      print('');
    }

    // 레슨 시간 차감 계산 (세션별)
    final lessonSessions = <Map<String, int>>[];
    widget.specialSettings.forEach((key, value) {
      if (key.startsWith('ls_min(')) {
        final sessionMatch = RegExp(r'ls_min\((\d+)\)').firstMatch(key);
        if (sessionMatch != null) {
          final sessionNum = int.tryParse(sessionMatch.group(1) ?? '0') ?? 0;
          final minutes = int.tryParse(value?.toString() ?? '0') ?? 0;
          if (minutes > 0) {
            lessonSessions.add({
              'session': sessionNum,
              'minutes': minutes,
            });
          }
        }
      }
    });

    // 세션 번호 순으로 정렬
    lessonSessions.sort((a, b) => (a['session'] ?? 0).compareTo(b['session'] ?? 0));

    if (lessonSessions.isNotEmpty && contract['lesson_balance'] != null) {
      print('📋 레슨권 차감 내역 (세션별):');
      
      // 최신 잔액 조회
      int currentBalance;
      try {
        final currentUser = widget.selectedMember ?? ApiService.getCurrentUser();
        final memberId = currentUser?['member_id']?.toString() ?? '';
        final lsContractId = contract['contract_id']?.toString() ?? '';
        
        final latestBalanceResult = await ApiService.getData(
          table: 'v3_LS_countings',
          fields: ['LS_balance_min_after'],
          where: [
            {'field': 'member_id', 'operator': '=', 'value': memberId},
            {'field': 'LS_contract_id', 'operator': '=', 'value': lsContractId},
          ],
          orderBy: [
            {'field': 'LS_counting_id', 'direction': 'DESC'}
          ],
          limit: 1,
        );
        
        if (latestBalanceResult.isNotEmpty && latestBalanceResult.first['LS_balance_min_after'] != null) {
          currentBalance = int.tryParse(latestBalanceResult.first['LS_balance_min_after'].toString()) ?? (contract['lesson_balance'] as int);
        } else {
          currentBalance = contract['lesson_balance'] as int;
        }
      } catch (e) {
        currentBalance = contract['lesson_balance'] as int;
      }
      
      int totalDeduction = 0;
      
      print('  변경 전 잔액: ${currentBalance}분');
      print('');
      
      // 각 세션의 시작 시간 계산
      DateTime? baseTime;
      if (widget.selectedTime != null) {
        baseTime = DateTime.parse('2025-01-01 ${widget.selectedTime}:00');
      }
      
      DateTime? currentSessionTime = baseTime;
      
      for (int i = 0; i < lessonSessions.length; i++) {
        final session = lessonSessions[i];
        final sessionNum = session['session'] ?? 0;
        final minutes = session['minutes'] ?? 0;
        
        final sessionAfterBalance = currentBalance - minutes;
        totalDeduction += minutes;
        
        // 해당 세션의 시작 시간으로 LS_id 생성
        final lsId = _generateLsId(sessionNum, currentSessionTime);
        
        print('  레슨 세션($sessionNum) 차감:');
        print('    LS_id: $lsId');
        print('    세션 전 잔액: ${currentBalance}분');
        print('    세션 차감: ${minutes}분');
        print('    세션 후 잔액: ${sessionAfterBalance}분');
        print('');
        
        currentBalance = sessionAfterBalance;
        
        // 다음 세션 시작 시간 계산 (현재 세션 시간 + 브레이크 시간)
        if (currentSessionTime != null && i < lessonSessions.length - 1) {
          currentSessionTime = currentSessionTime.add(Duration(minutes: minutes));
          
          final breakKey = 'ls_break_min($sessionNum)';
          final breakMin = int.tryParse(widget.specialSettings[breakKey]?.toString() ?? '0') ?? 0;
          if (breakMin > 0) {
            currentSessionTime = currentSessionTime.add(Duration(minutes: breakMin));
          }
        }
      }
      
      print('  총 차감 시간: ${totalDeduction}분');
      print('  최종 잔액: ${currentBalance}분');
      print('');
    }
  }

  // LS_id 생성 함수 (세션별 시작시간 기반)
  String _generateLsId(int sessionNum, DateTime? sessionStartTime) {
    if (widget.selectedDate == null || widget.selectedProId == null || sessionStartTime == null) {
      return 'null';
    }
    
    // 날짜를 yymmdd 형식으로 변환
    final dateStr = widget.selectedDate!.toString().substring(2, 10).replaceAll('-', '');
    
    // 세션 시작 시간을 hhmm 형식으로 변환
    final timeStr = '${sessionStartTime.hour.toString().padLeft(2, '0')}${sessionStartTime.minute.toString().padLeft(2, '0')}';
    
    // 프로 ID
    final proId = widget.selectedProId!;
    
    // 최대인원
    final maxPlayerNo = widget.specialSettings['max_player_no'] ?? 1;
    
    return '${dateStr}_${proId}_${timeStr}_1/${maxPlayerNo}';
  }

  // reservation_id 생성 함수 (그룹레슨 대응)
  String _generateReservationId() {
    if (widget.selectedDate == null || widget.selectedTsId == null || widget.selectedTime == null) {
      return 'null';
    }
    
    // 날짜를 yymmdd 형식으로 변환
    final dateStr = widget.selectedDate!.toString().substring(2, 10).replaceAll('-', '');
    
    // 시간을 hhmm 형식으로 변환
    final timeStr = widget.selectedTime!.replaceAll(':', '');
    
    // 타석 번호
    final tsId = widget.selectedTsId!;
    
    // 최대인원 (그룹레슨 대응)
    final maxPlayerNo = widget.specialSettings['max_player_no'] ?? 1;
    
    return '${dateStr}_${tsId}_${timeStr}_1/${maxPlayerNo}';
  }

  // 프로그램 시간대 분류 및 요금 계산 함수
  Future<Map<String, dynamic>> _classifyProgramTimeSlot() async {
    if (widget.selectedDate == null || widget.selectedTime == null || widget.selectedTsId == null) {
      return {
        'discount_min': 0,
        'normal_min': 0,
        'extracharge_min': 0,
        'total_amt': 0,
        'price_analysis': {},
      };
    }
    
    try {
      // 타석 시간 가져오기
      final tsMin = int.tryParse(widget.specialSettings['ts_min']?.toString() ?? '0') ?? 0;
      if (tsMin <= 0) {
        return {
          'discount_min': 0,
          'normal_min': 0,
          'extracharge_min': 0,
          'total_amt': 0,
          'price_analysis': {},
        };
      }
      
      // 종료 시간 계산
      final startTime = widget.selectedTime!;
      final endTime = _calculateEndTime(startTime, tsMin);
      
      // 요금 정책 조회
      final pricingPolicies = await ApiService.getTsPricingPolicy(date: widget.selectedDate!);
      if (pricingPolicies.isEmpty) {
        return {
          'discount_min': 0,
          'normal_min': tsMin,
          'extracharge_min': 0,
          'total_amt': 0,
          'price_analysis': {},
        };
      }
      
      // 시간대별 분석
      final timeAnalysis = ApiService.analyzePricingByTimeRange(
        startTime: startTime,
        endTime: endTime,
        pricingPolicies: pricingPolicies,
      );
      
      // 타석 정보 조회 (단가 정보)
      final tsInfo = await ApiService.getTsInfoById(tsId: widget.selectedTsId!.toString());
      if (tsInfo == null) {
        print('타석 정보 조회 실패: ${widget.selectedTsId}');
        return {
          'discount_min': timeAnalysis['discount_price'] ?? 0,
          'normal_min': timeAnalysis['base_price'] ?? 0,
          'extracharge_min': timeAnalysis['extracharge_price'] ?? 0,
          'total_amt': 0,
          'price_analysis': {},
        };
      }
      
      // 요금 계산 (ts_pricing_service.dart 로직 활용)
      final priceAnalysis = _calculatePricing(tsInfo, timeAnalysis);
      final totalAmt = priceAnalysis.values.fold(0, (sum, price) => sum + price);
      
      // 각 시간대별 분 단위 및 요금 정보 반환
      final result = <String, dynamic>{
        'discount_min': timeAnalysis['discount_price'] ?? 0,
        'normal_min': timeAnalysis['base_price'] ?? 0,
        'extracharge_min': timeAnalysis['extracharge_price'] ?? 0,
        'total_amt': totalAmt,
        'price_analysis': priceAnalysis,
      };
      
      return result;
    } catch (e) {
      print('시간대 분류 및 요금 계산 오류: $e');
      return {
        'discount_min': 0,
        'normal_min': 0,
        'extracharge_min': 0,
        'total_amt': 0,
        'price_analysis': {},
      };
    }
  }

  // 요금 계산 함수 (ts_pricing_service.dart 로직 활용)
  Map<String, int> _calculatePricing(
    Map<String, dynamic> tsInfo,
    Map<String, int> timeAnalysis,
  ) {
    try {
      // 타석 단가 정보 (60분 기준)
      final basePricePerHour = int.tryParse(tsInfo['base_price']?.toString() ?? '0') ?? 0;
      final discountPricePerHour = int.tryParse(tsInfo['discount_price']?.toString() ?? '0') ?? 0;
      final extrachargePricePerHour = int.tryParse(tsInfo['extracharge_price']?.toString() ?? '0') ?? 0;
      
      print('타석 단가 (60분 기준):');
      print('- 일반: $basePricePerHour원');
      print('- 할인: $discountPricePerHour원');
      print('- 할증: $extrachargePricePerHour원');
      
      Map<String, int> priceAnalysis = {};
      
      // 각 시간대별로 요금 계산
      timeAnalysis.forEach((policyKey, minutes) {
        if (minutes > 0) {
          int pricePerHour = 0;
          
          switch (policyKey) {
            case 'base_price':
              pricePerHour = basePricePerHour;
              break;
            case 'discount_price':
              pricePerHour = discountPricePerHour;
              break;
            case 'extracharge_price':
              pricePerHour = extrachargePricePerHour;
              break;
            default:
              pricePerHour = 0;
          }
          
          // 분 단위로 요금 계산: (시간당 단가 / 60분) * 이용 분
          final finalPrice = ((pricePerHour / 60) * minutes).round();
          
          priceAnalysis[policyKey] = finalPrice;
          
          print('$policyKey: ${minutes}분 × (${pricePerHour}원/60분) = ${finalPrice}원');
        }
      });
      
      return priceAnalysis;
      
    } catch (e) {
      print('요금 계산 오류: $e');
      return {};
    }
  }

  // 종료 시간 계산 함수
  String _calculateEndTime(String startTime, int durationMinutes) {
    try {
      final parts = startTime.split(':');
      final startHour = int.parse(parts[0]);
      final startMinute = int.parse(parts[1]);
      
      final totalMinutes = startHour * 60 + startMinute + durationMinutes;
      final endHour = (totalMinutes ~/ 60) % 24;
      final endMinute = totalMinutes % 60;
      
      return '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
    } catch (e) {
      print('종료 시간 계산 오류: $e');
      return '00:00';
    }
  }

  // 시간 포맷팅 (HH:MM)
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // 시간권과 레슨권의 교집합 찾기
  Future<void> _findAvailableContracts() async {
    final availableContracts = <Map<String, dynamic>>[];
    final addedContracts = <String>{}; // 중복 방지를 위한 Set
    final totalTsMin = _getTotalTsMin();
    final totalLsMin = _getTotalLsMin();
    
    // 계약 상세 정보 조회 (제약조건 체크를 위해)
    Map<String, Map<String, dynamic>> contractDetails = {};
    final allContractHistoryIds = <String>[];
    
    for (final timePass in _timePassContracts) {
      final historyId = timePass['contract_history_id']?.toString();
      if (historyId != null && historyId.isNotEmpty) {
        allContractHistoryIds.add(historyId);
      }
    }
    
    if (allContractHistoryIds.isNotEmpty) {
      try {
        contractDetails = await ApiService.getContractDetails(
          contractHistoryIds: allContractHistoryIds,
        );
        print('📋 계약 상세 정보 조회 완료: ${contractDetails.length}개');
      } catch (e) {
        print('❌ 계약 상세 정보 조회 실패: $e');
      }
    }
    
    // 당일 사용량 조회 (max_use_per_day 제한 적용용)
    Map<String, int> dailyUsage = {};
    if (widget.selectedDate != null) {
      try {
        final currentUser = widget.selectedMember ?? ApiService.getCurrentUser();
        final memberId = currentUser?['member_id']?.toString();
        if (memberId != null) {
          final billDateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate!);
          dailyUsage = await ApiService.getDailyUsageByContract(
            memberId: memberId,
            billDate: billDateStr,
          );
          print('\n=== 당일 사용량 조회 결과 ===');
          dailyUsage.forEach((contractHistoryId, usedMinutes) {
            print('계약 $contractHistoryId: ${usedMinutes}분 이미 사용');
          });
        }
      } catch (e) {
        print('❌ 당일 사용량 조회 실패: $e');
      }
    }
    
    print('');
    print('🔍 회원권 교집합 분석 시작');
    print('필요한 타석 시간: ${totalTsMin}분');
    print('필요한 레슨 시간: ${totalLsMin}분');
    print('');
    
    // 디버깅: 시간권 데이터 구조 확인
    print('📋 시간권 데이터 구조 확인:');
    for (int i = 0; i < _timePassContracts.length && i < 2; i++) {
      final timePass = _timePassContracts[i];
      print('시간권 $i: ${timePass.keys.toList()}');
      print('  contract_name: ${timePass['contract_name']}');
      print('  contract_history_id: ${timePass['contract_history_id']}');
      print('  prohibited_ts_id: ${timePass['prohibited_ts_id']}');
      print('  prohibited_TS_id: ${timePass['prohibited_TS_id']}');
    }
    
    // 디버깅: 레슨 데이터 구조 확인  
    print('📋 레슨 데이터 구조 확인:');
    for (int i = 0; i < _lessonContracts.length && i < 5; i++) {
      final lesson = _lessonContracts[i];
      print('레슨 $i: ${lesson.keys.toList()}');
      print('  contract_name: ${lesson['contract_name']}');
      print('  contract_history_id: ${lesson['contract_history_id']}');
      print('  pro_id: ${lesson['pro_id']} (선택된 프로: ${widget.selectedProId})');
    }
    print('');

    // 시간권만 필요한 경우
    if (totalTsMin > 0 && totalLsMin == 0) {
      for (final timePass in _timePassContracts) {
        final balance = int.tryParse(timePass['balance']?.toString() ?? '0') ?? 0;
        if (balance >= totalTsMin) {
          final historyId = timePass['contract_history_id']?.toString();
          final contractDetail = historyId != null ? contractDetails[historyId] : null;
          
          // 제약조건 체크
          if (!_checkContractConstraints(timePass, contractDetail, dailyUsage)) {
            continue; // 제약조건 불일치 시 제외
          }
          
          // prohibited_ts_id 체크
          final prohibitedTsIdFromTimePass = timePass['prohibited_ts_id']?.toString() ?? timePass['prohibited_TS_id']?.toString() ?? '';
          final prohibitedTsIdFromDetail = contractDetail?['prohibited_ts_id']?.toString() ?? contractDetail?['prohibited_TS_id']?.toString() ?? '';
          final prohibitedTsId = prohibitedTsIdFromTimePass.isNotEmpty && prohibitedTsIdFromTimePass != 'null' 
              ? prohibitedTsIdFromTimePass 
              : (prohibitedTsIdFromDetail.isNotEmpty && prohibitedTsIdFromDetail != 'null' ? prohibitedTsIdFromDetail : '');
          
          if (prohibitedTsId.isNotEmpty && prohibitedTsId != 'null' && widget.selectedTsId != null) {
            final prohibitedTsList = prohibitedTsId.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
            if (prohibitedTsList.contains(widget.selectedTsId.toString())) {
              print('시간권 계약 ${timePass['contract_history_id']}: 선택 불가능한 타석 (제한된 타석: $prohibitedTsId, 선택: ${widget.selectedTsId})');
              continue; // 선택 불가능한 타석이면 제외
            }
          }
          
          final contractName = timePass['contract_name'] ?? '시간권 계약';
          
          availableContracts.add({
            'type': 'time_only',
            'contract_name': contractName,
            'contract_id': timePass['contract_id'],
            'contract_history_id': timePass['contract_history_id'],
            'time_balance': balance,
            'time_count': (balance / totalTsMin).floor(),
            'time_expiry': timePass['expiry_date'],
            'lesson_balance': null,
            'lesson_count': null,
            'lesson_expiry': null,
          });
        }
      }
    }
    
    // 레슨권만 필요한 경우
    else if (totalTsMin == 0 && totalLsMin > 0) {
      final selectedProLessons = _lessonContracts.where((lesson) {
        return lesson['pro_id'] == widget.selectedProId;
      }).toList();
      
      for (final lesson in selectedProLessons) {
        final balance = int.tryParse(lesson['LS_balance_min_after']?.toString() ?? '0') ?? 0;
        if (balance >= totalLsMin) {
          availableContracts.add({
            'type': 'lesson_only',
            'contract_name': lesson['contract_name'] ?? '레슨권',
            'contract_id': lesson['LS_contract_id'],
            'lesson_contract_id': lesson['LS_contract_id'],
            'contract_history_id': lesson['contract_history_id'],
            'time_balance': null,
            'time_count': null,
            'time_expiry': null,
            'lesson_balance': balance,
            'lesson_count': (balance / totalLsMin).floor(),
            'lesson_expiry': lesson['LS_expiry_date'],
          });
        }
      }
    }
    
    // 시간권과 레슨권 모두 필요한 경우
    else if (totalTsMin > 0 && totalLsMin > 0) {
      final selectedProLessons = _lessonContracts.where((lesson) {
        return lesson['pro_id'] == widget.selectedProId;
      }).toList();
      
      final validTimePassContracts = <Map<String, dynamic>>[];
      for (final timePass in _timePassContracts) {
        final timeBalance = int.tryParse(timePass['balance']?.toString() ?? '0') ?? 0;
        if (timeBalance >= totalTsMin) {
          final historyId = timePass['contract_history_id']?.toString();
          final contractDetail = historyId != null ? contractDetails[historyId] : null;
          
          // 제약조건 체크
          if (!_checkContractConstraints(timePass, contractDetail, dailyUsage)) {
            continue; // 제약조건 불일치 시 제외
          }
          
          // prohibited_ts_id 체크
          final prohibitedTsIdFromTimePass = timePass['prohibited_ts_id']?.toString() ?? timePass['prohibited_TS_id']?.toString() ?? '';
          final prohibitedTsIdFromDetail = contractDetail?['prohibited_ts_id']?.toString() ?? contractDetail?['prohibited_TS_id']?.toString() ?? '';
          final prohibitedTsId = prohibitedTsIdFromTimePass.isNotEmpty && prohibitedTsIdFromTimePass != 'null' 
              ? prohibitedTsIdFromTimePass 
              : (prohibitedTsIdFromDetail.isNotEmpty && prohibitedTsIdFromDetail != 'null' ? prohibitedTsIdFromDetail : '');
          
          if (prohibitedTsId.isNotEmpty && prohibitedTsId != 'null' && widget.selectedTsId != null) {
            final prohibitedTsList = prohibitedTsId.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
            if (prohibitedTsList.contains(widget.selectedTsId.toString())) {
              print('시간권 계약 ${timePass['contract_history_id']}: 선택 불가능한 타석 (제한된 타석: $prohibitedTsId, 선택: ${widget.selectedTsId})');
              continue; // 선택 불가능한 타석이면 제외
            }
          }
          
          validTimePassContracts.add(timePass);
        }
      }
      
      if (validTimePassContracts.isNotEmpty) {
        final validLessonContracts = <Map<String, dynamic>>[];
        for (final lesson in selectedProLessons) {
          final lessonBalance = int.tryParse(lesson['LS_balance_min_after']?.toString() ?? '0') ?? 0;
          if (lessonBalance >= totalLsMin) {
            validLessonContracts.add(lesson);
          }
        }
        
        if (validLessonContracts.isNotEmpty) {
          for (final timePass in validTimePassContracts) {
            for (final lesson in validLessonContracts) {
              final timeHistoryId = timePass['contract_history_id']?.toString();
              final lessonHistoryId = lesson['contract_history_id']?.toString();
              
              // 같은 contract_history_id끼리만 조합 가능
              if (timeHistoryId != lessonHistoryId) {
                print('  ❌ 제외: 시간권(${timeHistoryId}) != 레슨권(${lessonHistoryId})');
                continue; // 다른 계약끼리는 조합 불가
              }
              
              final timeBalance = int.tryParse(timePass['balance']?.toString() ?? '0') ?? 0;
              final lessonBalance = int.tryParse(lesson['LS_balance_min_after']?.toString() ?? '0') ?? 0;
              
              print('  🔍 검토: contract_history_id=${timeHistoryId}, 시간권잔액=${timeBalance}분, 레슨권잔액=${lessonBalance}분');
              
              final timeCount = (timeBalance / totalTsMin).floor();
              final lessonCount = (lessonBalance / totalLsMin).floor();
              final timeExpiry = timePass['expiry_date'];
              final lessonExpiry = lesson['LS_expiry_date'];
              
              // 같은 contract_history_id이므로 항상 combined_set
              final contractName = timePass['contract_name'] ?? lesson['contract_name'] ?? 
                            timePass['actual_contract_id'] ?? lesson['actual_contract_id'] ?? '프로그램 세트 계약';
              final contractType = 'combined';
              
              // 중복 조합 확인 (같은 contract_history_id이므로 단순화)
              final contractKey = timeHistoryId.toString();
              
              if (!addedContracts.contains(contractKey)) {
                addedContracts.add(contractKey);
                print('  ✅ 추가: ${contractName} (${contractKey}) [시간권:${timeHistoryId}, 레슨권:${lessonHistoryId}]');
                availableContracts.add({
                  'type': contractType,
                  'contract_name': contractName,
                  'contract_id': timePass['contract_id'],
                  'contract_history_id': timePass['contract_history_id'],
                  'time_balance': timeBalance,
                  'time_count': timeCount,
                  'time_expiry': timeExpiry,
                  'lesson_balance': lessonBalance,
                  'lesson_count': lessonCount,
                  'lesson_expiry': lessonExpiry,
                  'lesson_contract_id': lesson['LS_contract_id'],
                  'lesson_contract_history_id': lesson['contract_history_id'],
                });
              } else {
                print('  ❌ 중복 제외: ${contractName} (${contractKey}) [시간권:${timeHistoryId}, 레슨권:${lessonHistoryId}]');
              }
            }
          }
        }
      }
    }

    setState(() {
      _availableContracts = availableContracts;
    });

    print('📋 사용 가능한 회원권 수: ${availableContracts.length}개');
    for (final contract in availableContracts) {
      final timeHistoryId = contract['contract_history_id'];
      final lessonHistoryId = contract['lesson_contract_history_id'];
      print('  - ${contract['contract_name']} (${contract['type']}) [시간권:${timeHistoryId}, 레슨권:${lessonHistoryId}]');
    }
    print('');
  }

  Future<void> _loadPaymentData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      if (widget.isMembershipDataLoaded && 
          widget.cachedTimePassContracts != null && 
          widget.cachedLessonContracts != null) {
        _loadCachedData();
      } else {
        await _loadTimePassContracts();
        await _loadLessonContracts();
      }

      await _findAvailableContracts();

    } catch (e) {
      print('❌ 결제 데이터 로드 실패: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadCachedData() {
    print('');
    print('🚀 캐시된 회원권 데이터 사용');
    print('═══════════════════════════════════════════════════════════');
    
    final validTimePassContracts = widget.cachedTimePassContracts ?? [];
    final validLessonContracts = widget.cachedLessonContracts ?? [];

    setState(() {
      _timePassContracts = validTimePassContracts;
      _lessonContracts = validLessonContracts;
    });

    final selectedDateStr = widget.selectedDate?.toString().split(' ')[0];
    print('📋 예약 날짜 기준 유효성 검증 결과:');
    print('선택된 예약 날짜: $selectedDateStr');
    print('유효한 시간권 계약: ${validTimePassContracts.length}개');
    print('유효한 레슨 계약: ${validLessonContracts.length}개');
    print('═══════════════════════════════════════════════════════════');
    print('');
  }

  Future<void> _loadTimePassContracts() async {
    try {
      final currentUser = widget.selectedMember ?? ApiService.getCurrentUser();
      final memberId = currentUser?['member_id'];

      if (memberId == null) {
        print('❌ 회원 ID를 찾을 수 없습니다.');
        return;
      }

      final contracts = await ApiService.getMemberTimePassesByContract(memberId: memberId.toString());
      
      setState(() {
        _timePassContracts = contracts;
      });

    } catch (e) {
      print('❌ 시간권 계약 조회 실패: $e');
      setState(() {
        _timePassContracts = [];
      });
    }
  }

  Future<void> _loadLessonContracts() async {
    try {
      final currentUser = widget.selectedMember ?? ApiService.getCurrentUser();
      final memberId = currentUser?['member_id'];

      if (memberId == null || widget.selectedDate == null || widget.selectedProId == null) {
        print('❌ 필요한 정보가 부족합니다.');
        return;
      }

      final contractsResponse = await ApiService.getMemberLsCountingData(
        memberId: memberId.toString(),
      );
      
      final contracts = contractsResponse['data'] as List<Map<String, dynamic>>? ?? [];

      setState(() {
        _lessonContracts = contracts;
      });

    } catch (e) {
      print('❌ 레슨 계약 조회 실패: $e');
      setState(() {
        _lessonContracts = [];
      });
    }
  }

  // 유효기간 포맷팅
  String _formatExpiryDate(String? expiryDate) {
    if (expiryDate == null || expiryDate.isEmpty) {
      return '무제한';
    }
    
    try {
      final date = DateTime.parse(expiryDate);
      return DateFormat('yyyy.MM.dd').format(date);
    } catch (e) {
      return expiryDate;
    }
  }

  // 계약 타입 텍스트 반환
  String _getContractTypeText(String type, Map<String, dynamic> contract) {
    final historyId = contract['contract_history_id']?.toString() ?? '';
    
    switch (type) {
      case 'combined':
        return historyId.isNotEmpty ? 'ID:$historyId' : '프로그램';
      case 'combined_set':
        return historyId.isNotEmpty ? 'ID:$historyId' : '세트';
      case 'combined_separate':
        return historyId.isNotEmpty ? 'ID:$historyId' : '조합';
      case 'time_only':
        return historyId.isNotEmpty ? 'ID:$historyId' : '타석전용';
      case 'lesson_only':
        return historyId.isNotEmpty ? 'ID:$historyId' : '레슨전용';
      default:
        return historyId.isNotEmpty ? 'ID:$historyId' : '일반';
    }
  }

  // 컴팩트한 회원권 정보 위젯 
  Widget _buildCompactMembershipInfo(Map<String, dynamic> contract) {
    // 타석과 레슨 중 작은 횟수 및 빠른 만료일 찾기
    int? minCount;
    String? earliestExpiry;
    
    final timeCount = contract['time_count'] as int?;
    final lessonCount = contract['lesson_count'] as int?;
    final timeExpiry = contract['time_expiry'] as String?;
    final lessonExpiry = contract['lesson_expiry'] as String?;
    
    // 작은 횟수 찾기
    if (timeCount != null && lessonCount != null) {
      minCount = timeCount < lessonCount ? timeCount : lessonCount;
    } else if (timeCount != null) {
      minCount = timeCount;
    } else if (lessonCount != null) {
      minCount = lessonCount;
    }
    
    // 빠른 만료일 찾기
    if (timeExpiry != null && lessonExpiry != null) {
      try {
        final timeDate = DateTime.parse(timeExpiry);
        final lessonDate = DateTime.parse(lessonExpiry);
        earliestExpiry = timeDate.isBefore(lessonDate) ? timeExpiry : lessonExpiry;
      } catch (e) {
        earliestExpiry = timeExpiry;
      }
    } else if (timeExpiry != null) {
      earliestExpiry = timeExpiry;
    } else if (lessonExpiry != null) {
      earliestExpiry = lessonExpiry;
    }
    
    if (minCount == null && earliestExpiry == null) {
      return SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (minCount != null) ...[
          Row(
            children: [
              Icon(Icons.confirmation_number, size: 16, color: Color(0xFF6B7280)),
              SizedBox(width: 6),
              Text(
                '잔여횟수 : ${minCount}회',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
        ],
        if (minCount != null && earliestExpiry != null) ...[
          SizedBox(height: 4),
        ],
        if (earliestExpiry != null) ...[
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: Color(0xFF6B7280)),
              SizedBox(width: 6),
              Text(
                '만료일 : ${_formatExpiryDate(earliestExpiry)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                ),
              ),
              SizedBox(height: 12),
              Text(
                '회원권 정보를 조회 중...',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_availableContracts.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        constraints: BoxConstraints(minHeight: 200),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.payment_outlined,
                size: 48,
                color: Color(0xFF9CA3AF),
              ),
              SizedBox(height: 16),
              Text(
                '사용 가능한 회원권이 없습니다',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              SizedBox(height: 8),
              Text(
                '선택한 예약에 사용할 수 있는\n회원권이 없습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목
          Text(
            '결제 방법을 선택하세요',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: 20),
          
          // 예약 정보 요약
          _buildReservationSummary(),
          
          SizedBox(height: 24),
          
          // 회원권 목록
          ..._availableContracts.asMap().entries.map((entry) =>
            _buildContractTile(entry.value, entry.key)
          ),
          
          SizedBox(height: 30),
          
        ],
      ),
    );
  }

  // 예약 정보 요약 위젯
  Widget _buildReservationSummary() {
    final totalTsMin = _getTotalTsMin();
    
    // 날짜 포맷팅 (요일 포함)
    String getFormattedDate() {
      if (widget.selectedDate == null) return '';
      
      final date = widget.selectedDate!;
      final weekdays = ['일', '월', '화', '수', '목', '금', '토'];
      final weekday = weekdays[date.weekday % 7];
      
      return '${date.toString().split(' ')[0]} (${weekday})';
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: Color(0xFF374151)),
            SizedBox(width: 8),
            Text(
              '${getFormattedDate()} ${widget.selectedTime}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.person, size: 18, color: Color(0xFF374151)),
            SizedBox(width: 8),
            Text(
              '${widget.selectedProName} 프로',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            SizedBox(width: 16),
            Icon(Icons.sports_golf, size: 18, color: Color(0xFF374151)),
            SizedBox(width: 8),
            Text(
              '${widget.selectedTsId}번 타석',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        if (totalTsMin > 0) ...[
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 18, color: Color(0xFF374151)),
              SizedBox(width: 8),
              Text(
                '프로그램 시간 : ${totalTsMin}분',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // 회원권 타일 위젯
  Widget _buildContractTile(Map<String, dynamic> contract, int index) {
    final isSelected = _selectedContract == contract;
    final totalTsMin = _getTotalTsMin();
    final totalLsMin = _getTotalLsMin();

    // 색상 선택 (TileDesignService 활용)
    final cardColor = TileDesignService.getColorByIndex(index);

    return GestureDetector(
      onTap: () async {
        setState(() {
          _selectedContract = contract;
        });

        // 회원권 선택 시 상세 정보 출력
        await _printSelectedContractDetails(contract);

        // 회원권 선택 콜백 호출 제거 - 다음 버튼에서만 호출되도록 수정
        // if (widget.onContractSelected != null) {
        //   widget.onContractSelected!(contract);
        // }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? cardColor.withOpacity(0.05)
              : Colors.white,
          border: Border.all(
            color: isSelected
                ? cardColor
                : Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: cardColor.withOpacity(0.2),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // 왼쪽 색상 바 (동적 높이)
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: isSelected ? cardColor : cardColor.withOpacity(0.3),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
              ),
              SizedBox(width: 12),

              // 선택 표시 (체크박스)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected
                        ? cardColor
                        : Color(0xFFD1D5DB),
                    width: 2,
                  ),
                  color: isSelected ? cardColor : Colors.transparent,
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
              SizedBox(width: 12),

              // 회원권 정보
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 회원권명 + 타입 배지
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            contract['contract_name'] ?? '회원권',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: cardColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getContractTypeText(contract['type'], contract),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: cardColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),

                    // 잔액 정보 (컴팩트 표시)
                    _buildCompactMembershipInfo(contract),
                  ],
                ),
              ),
            ),
              SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// Step 6으로 전달할 계산된 데이터 생성
  Future<Map<String, dynamic>> _generateStep6Data(Map<String, dynamic> contract) async {
    // 기본 예약 ID 생성
    final reservationId = _generateReservationId();
    final programId = reservationId.split('_').take(3).join('_');
    
    // 레슨 세션 정보 추출
    final lessonSessions = <Map<String, dynamic>>[];
    final lsIds = <String, String>{};
    final sessionTimings = <Map<String, dynamic>>[];
    
    // 시작 시간 계산
    final startTime = widget.selectedTime ?? '09:00';
    DateTime currentSessionTime = DateTime.parse('2025-01-01 $startTime:00');
    
    // specialSettings에서 세션 정보 추출
    widget.specialSettings.forEach((key, value) {
      if (key.startsWith('ls_min(') && key.endsWith(')')) {
        final sessionNumber = key.substring(7, key.length - 1);
        final lsMin = int.tryParse(value.toString()) ?? 0;
        if (lsMin > 0) {
          // 세션 시작 시간 계산 (이전 세션들의 시간 포함)
          final sessionStartTime = currentSessionTime;
          final sessionEndTime = sessionStartTime.add(Duration(minutes: lsMin));
          
          // LS_id 생성
          final lsId = _generateLsId(int.parse(sessionNumber), sessionStartTime);
          
          lessonSessions.add({
            'session_number': sessionNumber,
            'ls_min': lsMin,
            'start_time': sessionStartTime,
            'end_time': sessionEndTime,
            'ls_id': lsId,
          });
          
          lsIds[sessionNumber] = lsId;
          
          sessionTimings.add({
            'session_number': int.parse(sessionNumber),
            'start_time': '${sessionStartTime.hour.toString().padLeft(2, '0')}:${sessionStartTime.minute.toString().padLeft(2, '0')}:00',
            'end_time': '${sessionEndTime.hour.toString().padLeft(2, '0')}:${sessionEndTime.minute.toString().padLeft(2, '0')}:00',
            'duration_min': lsMin,
          });
          
          // 다음 세션을 위해 현재 세션 종료 시간으로 업데이트
          currentSessionTime = sessionEndTime;
          
          // 브레이크 시간 추가
          final sessionNum = int.parse(sessionNumber);
          final breakKey = 'ls_break_min($sessionNum)';
          final breakMin = int.tryParse(widget.specialSettings[breakKey]?.toString() ?? '0') ?? 0;
          if (breakMin > 0) {
            currentSessionTime = currentSessionTime.add(Duration(minutes: breakMin));
          }
        }
      }
    });
    
    // 요금 정보 계산
    final priceAnalysis = await _classifyProgramTimeSlot();
    
    return {
      // Generated IDs
      'reservation_id': reservationId,
      'program_id': programId,
      'ls_ids': lsIds,
      
      // Timing data
      'total_ts_min': _getTotalTsMin(),
      'total_ls_min': _getTotalLsMin(),
      'lesson_sessions': lessonSessions,
      'session_timings': sessionTimings,
      
      // Pricing data
      'price_analysis': priceAnalysis,
      
      // Selected contract
      'selected_contract': contract,
      
      // Basic reservation info
      'selected_date': widget.selectedDate,
      'selected_pro_id': widget.selectedProId,
      'selected_pro_name': widget.selectedProName,
      'selected_time': widget.selectedTime,
      'selected_ts_id': widget.selectedTsId,
      'special_settings': widget.specialSettings,
    };
  }
}