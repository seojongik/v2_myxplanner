import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';

/// 특수 예약 DB 업데이트 서비스
class SpDbUpdateService {
  /// 예약 정보 데이터 클래스
  static Map<String, dynamic> _createReservationData({
    required DateTime selectedDate,
    required int selectedProId,
    required String selectedProName,
    required String selectedTime,
    required String selectedTsId,
    required Map<String, dynamic> specialSettings,
    required Map<String, dynamic> selectedContract,
  }) {
    return {
      'selectedDate': selectedDate,
      'selectedProId': selectedProId,
      'selectedProName': selectedProName,
      'selectedTime': selectedTime,
      'selectedTsId': selectedTsId,
      'specialSettings': specialSettings,
      'selectedContract': selectedContract,
    };
  }

  /// 메인 DB 업데이트 함수 (트랜잭션 방식)
  /// 모든 데이터를 수집한 후 한 번에 원자적으로 처리
  /// → 타석 + 레슨이 모두 성공해야 커밋, 하나라도 실패하면 전체 롤백
  static Future<bool> updateDatabaseForReservation({
    required DateTime selectedDate,
    required int selectedProId,
    required String selectedProName,
    required String selectedTime,
    required String selectedTsId,
    required Map<String, dynamic> specialSettings,
    required Map<String, dynamic> selectedContract,
    required String? specialType,
    Map<String, dynamic>? selectedMember,
  }) async {
    try {
      print('');
      print('═══════════════════════════════════════════════════════════');
      print('🔐 특수 예약 트랜잭션 DB 업데이트 시작');
      print('═══════════════════════════════════════════════════════════');
      
      // 예약 정보 출력
      await _printReservationInfo(
        selectedDate: selectedDate,
        selectedProId: selectedProId,
        selectedProName: selectedProName,
        selectedTime: selectedTime,
        selectedTsId: selectedTsId,
        specialSettings: specialSettings,
        selectedContract: selectedContract,
      );

      // 회원권 상세 정보 출력
      await _printSelectedContractDetails(
        selectedContract,
        selectedMember: selectedMember,
      );

      // ============================================================
      // 트랜잭션용 데이터 수집 (INSERT 안함, 데이터만 준비)
      // ============================================================
      List<Map<String, dynamic>> tsRecords = [];      // 타석 예약 데이터
      List<Map<String, dynamic>> billTimes = [];      // 타석 차감 데이터
      List<Map<String, dynamic>> lsOrders = [];       // 레슨 예약 데이터
      List<Map<String, dynamic>> lsCountings = [];    // 레슨 카운팅 데이터

      // 1. 타석 시간이 있는 경우 데이터 수집
      final tsMin = _getTotalTsMin(specialSettings);
      if (tsMin > 0 && selectedContract['time_balance'] != null) {
        final timeSlotAnalysis = await _classifyProgramTimeSlot(
          selectedDate: selectedDate,
          selectedTime: selectedTime,
          selectedTsId: selectedTsId,
          specialSettings: specialSettings,
        );
        
        final reservationId = _generateReservationId(
          selectedDate: selectedDate,
          selectedTsId: selectedTsId,
          selectedTime: selectedTime,
          specialSettings: specialSettings,
        );

        // 타석 예약 데이터 수집
        tsRecords = await _collectTsRecords(
          reservationId: reservationId,
          timeSlotAnalysis: timeSlotAnalysis,
          selectedDate: selectedDate,
          selectedTime: selectedTime,
          selectedTsId: selectedTsId,
          selectedProId: selectedProId,
          selectedProName: selectedProName,
          specialSettings: specialSettings,
          specialType: specialType,
          selectedMember: selectedMember,
        );
        
        // 타석 차감 데이터 수집
        billTimes = await _collectBillTimes(
          reservationId: reservationId,
          contract: selectedContract,
          selectedDate: selectedDate,
          selectedTime: selectedTime,
          selectedTsId: selectedTsId,
          specialSettings: specialSettings,
          selectedMember: selectedMember,
        );
      }

      // 2. 레슨 시간이 있는 경우 데이터 수집
      final lsMin = _getTotalLsMin(specialSettings);
      if (lsMin > 0 && selectedContract['lesson_balance'] != null) {
        final reservationId = _generateReservationId(
          selectedDate: selectedDate,
          selectedTsId: selectedTsId,
          selectedTime: selectedTime,
          specialSettings: specialSettings,
        );

        // 레슨 예약 데이터 수집
        lsOrders = await _collectLsOrders(
          reservationId: reservationId,
          contract: selectedContract,
          selectedDate: selectedDate,
          selectedProId: selectedProId,
          selectedProName: selectedProName,
          selectedTime: selectedTime,
          selectedTsId: selectedTsId,
          specialSettings: specialSettings,
          selectedMember: selectedMember,
        );
        
        // 레슨 카운팅 데이터 수집
        lsCountings = await _collectLsCountings(
          reservationId: reservationId,
          contract: selectedContract,
          selectedDate: selectedDate,
          selectedProId: selectedProId,
          selectedProName: selectedProName,
          selectedTime: selectedTime,
          selectedTsId: selectedTsId,
          specialSettings: specialSettings,
          selectedMember: selectedMember,
        );
      }

      print('');
      print('📦 수집된 데이터:');
      print('  - 타석 예약: ${tsRecords.length}건');
      print('  - 타석 차감: ${billTimes.length}건');
      print('  - 레슨 예약: ${lsOrders.length}건');
      print('  - 레슨 카운팅: ${lsCountings.length}건');

      // ============================================================
      // 트랜잭션으로 한 번에 처리 (모두 성공 or 모두 롤백)
      // ============================================================
      final result = await ApiService.insertSpecialReservation(
        tsRecords: tsRecords,
        lsOrders: lsOrders,
        lsCountings: lsCountings,
        billTimes: billTimes,
      );

      if (result['success'] == true) {
        print('');
        print('═══════════════════════════════════════════════════════════');
        print('✅ 특수 예약 트랜잭션 완료 - 모든 데이터 저장 성공!');
        print('═══════════════════════════════════════════════════════════');
        print('');
        return true;
      } else {
        print('');
        print('═══════════════════════════════════════════════════════════');
        print('❌ 특수 예약 트랜잭션 실패 - 모든 변경 롤백됨');
        print('  에러: ${result['error']}');
        if (result['isDuplicate'] == true || result['is_duplicate'] == true) {
          print('  🚫 중복 예약 감지됨');
        }
        print('═══════════════════════════════════════════════════════════');
        print('');
        return false;
      }

    } catch (e) {
      print('❌ 특수 예약 DB 업데이트 오류: $e');
      return false;
    }
  }

  // ===========================================
  // 트랜잭션용 데이터 수집 함수들 (INSERT 안함)
  // ===========================================

  /// 타석 예약 데이터 수집 (트랜잭션용)
  static Future<List<Map<String, dynamic>>> _collectTsRecords({
    required String reservationId,
    required Map<String, dynamic> timeSlotAnalysis,
    required DateTime selectedDate,
    required String selectedTime,
    required String selectedTsId,
    required int selectedProId,
    required String selectedProName,
    required Map<String, dynamic> specialSettings,
    required String? specialType,
    Map<String, dynamic>? selectedMember,
  }) async {
    final List<Map<String, dynamic>> records = [];
    
    try {
      final currentUser = selectedMember ?? ApiService.getCurrentUser();
      if (currentUser == null) {
        print('❌ 현재 사용자 정보를 가져올 수 없습니다.');
        return records;
      }

      final memberId = currentUser['member_id']?.toString() ?? '';
      final memberName = currentUser['member_name']?.toString() ?? '';
      final memberType = currentUser['member_type']?.toString() ?? 'regular';
      final branchId = ApiService.getCurrentBranchId();
      final programId = _generateProgramId(selectedDate, selectedProId, selectedTime, specialSettings);
      
      // 타석 정보
      final proName = selectedProName;
      
      // 시간 블록 분석
      final timeBlocks = _parseTimeBlocks(specialSettings);
      
      DateTime? baseTime;
      try {
        baseTime = DateTime.parse('2025-01-01 ${selectedTime}:00');
      } catch (e) {
        baseTime = DateTime.parse('2025-01-01 ${selectedTime}');
      }
      
      DateTime? currentTime = baseTime;
      int tsBlockIndex = 0;
      
      for (final block in timeBlocks) {
        if (currentTime == null) break;
        
        final blockType = block['type'] as String;
        final duration = block['duration'] as int;
        final blockEndTime = currentTime.add(Duration(minutes: duration));
        
        if (blockType == 'ts') {
          tsBlockIndex++;
          final startTimeStr = '${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}';
          final endTimeStr = '${blockEndTime.hour.toString().padLeft(2, '0')}:${blockEndTime.minute.toString().padLeft(2, '0')}';
          
          final blockReservationId = '${reservationId}_ts$tsBlockIndex';
          
          // 타석 타입 및 상태 결정
          String tsType = specialType ?? '프로그램';
          String tsStatus = '예약완료';
          
          final tsRecord = {
            'branch_id': branchId,
            'reservation_id': blockReservationId,
            'ts_id': selectedTsId,
            'ts_date': DateFormat('yyyy-MM-dd').format(selectedDate),
            'ts_start': startTimeStr,
            'ts_end': endTimeStr,
            'ts_type': tsType,
            'ts_status': tsStatus,
            'ts_buffer': 0,
            'member_id': memberId,
            'member_name': memberName,
            'member_type': memberType,
            'pro_id': selectedProId,
            'pro_name': proName,
            'program_id': programId,
            'routine_id': null,
            'unit_price': 0,
            'transaction_type': '회원권차감',
          };
          
          records.add(tsRecord);
          print('📦 타석 블록 $tsBlockIndex 수집: $startTimeStr ~ $endTimeStr');
        }
        
        currentTime = blockEndTime;
      }
      
      print('✅ 타석 데이터 ${records.length}건 수집 완료');
      return records;
      
    } catch (e) {
      print('❌ 타석 데이터 수집 오류: $e');
      return records;
    }
  }

  /// 타석 차감 데이터 수집 (트랜잭션용)
  static Future<List<Map<String, dynamic>>> _collectBillTimes({
    required String reservationId,
    required Map<String, dynamic> contract,
    required DateTime selectedDate,
    required String selectedTime,
    required String selectedTsId,
    required Map<String, dynamic> specialSettings,
    Map<String, dynamic>? selectedMember,
  }) async {
    final List<Map<String, dynamic>> records = [];
    
    try {
      final currentUser = selectedMember ?? ApiService.getCurrentUser();
      if (currentUser == null) return records;

      final memberId = currentUser['member_id']?.toString() ?? '';
      final branchId = ApiService.getCurrentBranchId();
      final contractHistoryId = contract['contract_history_id'];
      // 만료일: time_expiry > expiry_date 순으로 조회
      final contractExpiryDate = contract['time_expiry']?.toString() ?? 
                                  contract['expiry_date']?.toString() ?? '';
      
      // 잔액: contract에서 직접 가져오기 (이미 Step5에서 검증된 값)
      int currentBalance = int.tryParse(contract['time_balance']?.toString() ?? '0') ?? 0;
      print('📊 시간권 초기 잔액 (contract에서): $currentBalance분');
      
      // 시간 블록에서 타석 시간만 추출
      final timeBlocks = _parseTimeBlocks(specialSettings);
      int tsBlockIndex = 0;
      DateTime currentTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        int.parse(selectedTime.split(':')[0]),
        int.parse(selectedTime.split(':')[1]),
      );
      
      for (final block in timeBlocks) {
        if (block['type'] == 'ts') {
          tsBlockIndex++;
          final duration = block['duration'] as int;
          final blockEndTime = currentTime.add(Duration(minutes: duration));
          
          final startTimeStr = '${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}';
          final endTimeStr = '${blockEndTime.hour.toString().padLeft(2, '0')}:${blockEndTime.minute.toString().padLeft(2, '0')}';
          final blockReservationId = '${reservationId}_ts$tsBlockIndex';
          
          // bill_text 생성 (예: "1번 타석(14:00 ~ 14:55)")
          final billText = '${selectedTsId}번 타석($startTimeStr ~ $endTimeStr)';
          
          // 잔액 계산
          final balanceBefore = currentBalance;
          final balanceAfter = currentBalance - duration;
          currentBalance = balanceAfter;
          
          final billTimeRecord = {
            'branch_id': branchId,
            'contract_history_id': contractHistoryId,
            'bill_date': DateFormat('yyyy-MM-dd').format(selectedDate),
            'member_id': memberId,
            'bill_text': billText,
            'bill_type': '타석이용',
            'reservation_id': blockReservationId,
            'bill_total_min': duration,
            'bill_discount_min': 0,
            'bill_min': duration,
            'bill_balance_min_before': balanceBefore,
            'bill_balance_min_after': balanceAfter,
            'bill_status': '결제완료',
            'contract_ts_min_expiry_date': contractExpiryDate,
          };
          
          records.add(billTimeRecord);
          print('📦 타석 차감 블록 $tsBlockIndex 수집: ${duration}분 (잔액: $balanceBefore → $balanceAfter)');
        }
        currentTime = currentTime.add(Duration(minutes: block['duration'] as int));
      }
      
      print('✅ 타석 차감 데이터 ${records.length}건 수집 완료');
      return records;
      
    } catch (e) {
      print('❌ 타석 차감 데이터 수집 오류: $e');
      return records;
    }
  }

  /// 레슨 예약 데이터 수집 (트랜잭션용)
  static Future<List<Map<String, dynamic>>> _collectLsOrders({
    required String reservationId,
    required Map<String, dynamic> contract,
    required DateTime selectedDate,
    required int selectedProId,
    required String selectedProName,
    required String selectedTime,
    required String selectedTsId,
    required Map<String, dynamic> specialSettings,
    Map<String, dynamic>? selectedMember,
  }) async {
    final List<Map<String, dynamic>> records = [];
    
    try {
      final currentUser = selectedMember ?? ApiService.getCurrentUser();
      if (currentUser == null) return records;

      final memberId = currentUser['member_id']?.toString() ?? '';
      final memberName = currentUser['member_name']?.toString() ?? '';
      final memberType = currentUser['member_type']?.toString() ?? 'regular';
      final branchId = ApiService.getCurrentBranchId();
      final programId = _generateProgramId(selectedDate, selectedProId, selectedTime, specialSettings);
      final lsContractId = contract['contract_history_id'];
      final tsId = int.tryParse(selectedTsId) ?? 0;
      
      // 시간 블록 분석
      final timeBlocks = _parseTimeBlocks(specialSettings);
      
      DateTime? baseTime;
      try {
        baseTime = DateTime.parse('2025-01-01 ${selectedTime}:00');
      } catch (e) {
        baseTime = DateTime.parse('2025-01-01 ${selectedTime}');
      }
      
      DateTime? currentTime = baseTime;
      int lessonBlockIndex = 0;
      
      // 그룹레슨 여부 확인
      final maxPlayerNo = int.tryParse(specialSettings['max_player_no']?.toString() ?? '1') ?? 1;
      final isGroupLesson = maxPlayerNo > 1;
      
      for (final block in timeBlocks) {
        if (currentTime == null) break;
        
        final blockType = block['type'] as String;
        final duration = block['duration'] as int;
        final blockEndTime = currentTime.add(Duration(minutes: duration));
        
        if (blockType == 'lesson') {
          lessonBlockIndex++;
          final startTimeStr = '${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}';
          final endTimeStr = '${blockEndTime.hour.toString().padLeft(2, '0')}:${blockEndTime.minute.toString().padLeft(2, '0')}';
          
          if (isGroupLesson) {
            // 그룹 레슨: 슬롯별로 생성
            for (int playerNo = 1; playerNo <= maxPlayerNo; playerNo++) {
              final lsId = _generateLsIdForCollect(
                lessonBlockIndex, currentTime, selectedDate, selectedProId, specialSettings, playerNo, maxPlayerNo
              );
              final isFirstSlot = (playerNo == 1);
              
              final lsOrderRecord = {
                'branch_id': branchId,
                'ls_id': lsId,
                'ls_transaction_type': '레슨예약',
                'ls_date': DateFormat('yyyy-MM-dd').format(selectedDate),
                'member_id': isFirstSlot ? memberId : null,
                'ls_status': isFirstSlot ? '결제완료' : '체크인전',
                'member_name': isFirstSlot ? memberName : null,
                'member_type': isFirstSlot ? memberType : null,
                'ls_type': '프로그램',
                'pro_id': selectedProId,
                'pro_name': selectedProName,
                'ls_order_source': '앱',
                'ls_start_time': startTimeStr,
                'ls_end_time': endTimeStr,
                'ls_net_min': duration,
                'ts_id': tsId,
                'program_id': programId,
                'routine_id': null,
                'ls_request': null,
                'ls_contract_id': isFirstSlot ? lsContractId : null,
              };
              
              records.add(lsOrderRecord);
              print('📦 레슨 블록 $lessonBlockIndex 슬롯 $playerNo/$maxPlayerNo 수집');
            }
          } else {
            // 개인 레슨
            final lsId = _generateLsIdForCollect(
              lessonBlockIndex, currentTime, selectedDate, selectedProId, specialSettings, 1, 1
            );
            
            final lsOrderRecord = {
              'branch_id': branchId,
              'ls_id': lsId,
              'ls_transaction_type': '레슨예약',
              'ls_date': DateFormat('yyyy-MM-dd').format(selectedDate),
              'member_id': memberId,
              'ls_status': '결제완료',
              'member_name': memberName,
              'member_type': memberType,
              'ls_type': '프로그램',
              'pro_id': selectedProId,
              'pro_name': selectedProName,
              'ls_order_source': '앱',
              'ls_start_time': startTimeStr,
              'ls_end_time': endTimeStr,
              'ls_net_min': duration,
              'ts_id': tsId,
              'program_id': programId,
              'routine_id': null,
              'ls_request': null,
              'ls_contract_id': lsContractId,
            };
            
            records.add(lsOrderRecord);
            print('📦 레슨 블록 $lessonBlockIndex 수집: $startTimeStr ~ $endTimeStr');
          }
        }
        
        currentTime = blockEndTime;
      }
      
      print('✅ 레슨 데이터 ${records.length}건 수집 완료');
      return records;
      
    } catch (e) {
      print('❌ 레슨 데이터 수집 오류: $e');
      return records;
    }
  }

  /// 레슨 카운팅 데이터 수집 (트랜잭션용)
  static Future<List<Map<String, dynamic>>> _collectLsCountings({
    required String reservationId,
    required Map<String, dynamic> contract,
    required DateTime selectedDate,
    required int selectedProId,
    required String selectedProName,
    required String selectedTime,
    required String selectedTsId,
    required Map<String, dynamic> specialSettings,
    Map<String, dynamic>? selectedMember,
  }) async {
    final List<Map<String, dynamic>> records = [];
    
    try {
      final currentUser = selectedMember ?? ApiService.getCurrentUser();
      if (currentUser == null) return records;

      final memberId = currentUser['member_id']?.toString() ?? '';
      final memberName = currentUser['member_name']?.toString() ?? '';
      final memberType = currentUser['member_type']?.toString() ?? '일반';
      final branchId = ApiService.getCurrentBranchId();
      final contractHistoryId = contract['contract_history_id'];
      // 만료일: lesson_expiry > ls_expiry_date > expiry_date 순으로 조회
      final contractExpiryDate = contract['lesson_expiry']?.toString() ?? 
                                  contract['ls_expiry_date']?.toString() ?? 
                                  contract['expiry_date']?.toString() ?? '';
      final programId = _generateProgramId(selectedDate, selectedProId, selectedTime, specialSettings);
      
      // 잔액: _getCurrentLessonBalance와 동일하게 DB에서 최신 잔액 조회 (Step5에서 검증된 방식)
      int currentBalance = await _getCurrentLessonBalance(contract);
      print('📊 레슨권 초기 잔액 (DB 조회): $currentBalance분');
      
      // 시간 블록에서 레슨만 추출
      final timeBlocks = _parseTimeBlocks(specialSettings);
      
      DateTime? baseTime;
      try {
        baseTime = DateTime.parse('2025-01-01 ${selectedTime}:00');
      } catch (e) {
        baseTime = DateTime.parse('2025-01-01 ${selectedTime}');
      }
      
      DateTime? currentTime = baseTime;
      int lessonBlockIndex = 0;
      
      for (final block in timeBlocks) {
        if (currentTime == null) break;
        
        final blockType = block['type'] as String;
        final duration = block['duration'] as int;
        final blockEndTime = currentTime.add(Duration(minutes: duration));
        
        if (blockType == 'lesson') {
          lessonBlockIndex++;
          
          final lsId = _generateLsIdForCollect(
            lessonBlockIndex, currentTime, selectedDate, selectedProId, specialSettings, 1, 1
          );
          
          // 잔액 계산
          final balanceBefore = currentBalance;
          final balanceAfter = currentBalance - duration;
          currentBalance = balanceAfter;
          
          final countingRecord = {
            'branch_id': branchId,
            'ls_id': lsId,
            'ls_transaction_type': '레슨차감',
            'ls_date': DateFormat('yyyy-MM-dd').format(selectedDate),
            'member_id': memberId,
            'member_name': memberName,
            'member_type': memberType,
            'ls_status': '차감완료',
            'ls_type': '프로그램',
            'ls_contract_id': contractHistoryId,
            'contract_history_id': contractHistoryId,
            'ls_balance_min_before': balanceBefore,
            'ls_net_min': duration,
            'ls_balance_min_after': balanceAfter,
            'ls_counting_source': '앱',
            'program_id': programId,
            'pro_id': selectedProId,
            'pro_name': selectedProName,
            'ls_expiry_date': contractExpiryDate,
          };
          
          records.add(countingRecord);
          print('📦 레슨 카운팅 블록 $lessonBlockIndex 수집: ${duration}분 (잔액: $balanceBefore → $balanceAfter)');
        }
        
        currentTime = blockEndTime;
      }
      
      print('✅ 레슨 카운팅 데이터 ${records.length}건 수집 완료');
      return records;
      
    } catch (e) {
      print('❌ 레슨 카운팅 데이터 수집 오류: $e');
      return records;
    }
  }

  /// LS_id 생성 (데이터 수집용)
  static String _generateLsIdForCollect(
    int sessionNum,
    DateTime sessionTime,
    DateTime selectedDate,
    int proId,
    Map<String, dynamic> specialSettings,
    int playerNo,
    int maxPlayerNo,
  ) {
    final dateStr = DateFormat('yyMMdd').format(selectedDate);
    final timeStr = '${sessionTime.hour.toString().padLeft(2, '0')}${sessionTime.minute.toString().padLeft(2, '0')}';
    
    if (maxPlayerNo > 1) {
      return '${dateStr}_${proId}_${timeStr}_$playerNo/$maxPlayerNo';
    } else {
      return '${dateStr}_${proId}_${timeStr}';
    }
  }

  /// program_id 생성 헬퍼 함수
  static String _generateProgramId(
    DateTime selectedDate,
    int selectedProId,
    String selectedTime,
    Map<String, dynamic> specialSettings,
  ) {
    final dateStr = selectedDate.toString().substring(2, 10).replaceAll('-', '');
    final timeStr = selectedTime.replaceAll(':', '');
    return '${dateStr}_${selectedProId}_$timeStr';
  }

  /// 타석 이름 조회 헬퍼 함수
  static Future<String> _getTsName(String tsId) async {
    // 간단히 "N번 타석" 형식으로 반환
    return '${tsId}번 타석';
  }

  /// 시간 블록 파싱 헬퍼 함수 (specialSettings → timeBlocks)
  static List<Map<String, dynamic>> _parseTimeBlocks(Map<String, dynamic> specialSettings) {
    // ls_min과 ls_break_min, ts_min을 순서 번호 기준으로 수집
    final Map<int, int> lsMinMap = {};
    final Map<int, int> lsBreakMinMap = {};
    final Map<int, int> tsMinMap = {};

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
        if (orderNum > 0 && duration > 0) {
          lsBreakMinMap[orderNum] = duration;
        }
      } else if (key.startsWith('ts_min(') && key.endsWith(')')) {
        final orderNum = int.tryParse(key.substring(7, key.length - 1)) ?? 0;
        final duration = int.tryParse(value?.toString() ?? '0') ?? 0;
        if (orderNum > 0 && duration > 0) {
          tsMinMap[orderNum] = duration;
        }
      } else if (key == 'ts_min') {
        // 단일 ts_min의 경우 order 1로 처리
        final duration = int.tryParse(value?.toString() ?? '0') ?? 0;
        if (duration > 0) {
          tsMinMap[1] = duration;
        }
      }
    });

    // 모든 순서 번호를 수집하고 정렬
    final allOrderNumbers = <int>{};
    allOrderNumbers.addAll(lsMinMap.keys);
    allOrderNumbers.addAll(lsBreakMinMap.keys);
    allOrderNumbers.addAll(tsMinMap.keys);
    final sortedOrders = allOrderNumbers.toList()..sort();

    // 순서대로 시간 블록 구성
    final timeBlocks = <Map<String, dynamic>>[];
    int lessonNumber = 1;
    int tsNumber = 1;

    for (final orderNum in sortedOrders) {
      final breakTime = lsBreakMinMap[orderNum] ?? 0;
      final lessonDuration = lsMinMap[orderNum] ?? 0;
      final tsDuration = tsMinMap[orderNum] ?? 0;

      // 휴식시간이 있으면 먼저 추가
      if (breakTime > 0) {
        timeBlocks.add({
          'type': 'break',
          'order': orderNum,
          'duration': breakTime,
        });
      }

      // 타석시간이 있으면 추가
      if (tsDuration > 0) {
        timeBlocks.add({
          'type': 'ts',
          'order': orderNum,
          'ts_number': tsNumber,
          'duration': tsDuration,
        });
        tsNumber++;
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

    return timeBlocks;
  }

  // ===========================================
  // 헬퍼 함수들
  // ===========================================

  /// 예약 정보 출력
  static Future<void> _printReservationInfo({
    required DateTime selectedDate,
    required int selectedProId,
    required String selectedProName,
    required String selectedTime,
    required String selectedTsId,
    required Map<String, dynamic> specialSettings,
    required Map<String, dynamic> selectedContract,
  }) async {
    print('선택된 예약 정보:');
    print('선택된 날짜: ${selectedDate.toString().split(' ')[0]}');
    print('선택된 프로: $selectedProName (ID: $selectedProId)');
    print('선택된 시간: $selectedTime');
    print('선택된 타석: ${selectedTsId}번 타석');
    print('');
    print('특수 예약 설정:');
    specialSettings.forEach((key, value) {
      print('  $key = $value');
    });
    print('');
  }

  /// ts_min 합계 계산
  static int _getTotalTsMin(Map<String, dynamic> specialSettings) {
    int totalTsMin = 0;
    specialSettings.forEach((key, value) {
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

  /// ls_min 합계 계산
  static int _getTotalLsMin(Map<String, dynamic> specialSettings) {
    int totalLsMin = 0;
    specialSettings.forEach((key, value) {
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

  /// 선택된 회원권 상세 정보 출력
  static Future<void> _printSelectedContractDetails(
    Map<String, dynamic> contract, {
    Map<String, dynamic>? selectedMember,
  }) async {
    final currentUser = selectedMember ?? ApiService.getCurrentUser();
    
    print('선택된 회원권 상세 정보:');
    print('회원권명: ${contract['contract_name'] ?? 'null'}');
    print('회원권 타입: ${contract['type'] ?? 'null'}');
    print('contract_history_id: ${contract['contract_history_id'] ?? 'null'}');
    print('contract_id: ${contract['contract_id'] ?? 'null'}');
    
    if (contract['type'] == 'combined') {
      print('시간권 잔액: ${contract['time_balance'] ?? 'null'}분');
      final currentLessonBalance = await _getCurrentLessonBalance(contract);
      print('레슨권 잔액: ${currentLessonBalance}분');
    } else if (contract['type'] == 'time_only') {
      print('시간권 잔액: ${contract['time_balance'] ?? 'null'}분');
    } else if (contract['type'] == 'lesson_only') {
      final currentLessonBalance = await _getCurrentLessonBalance(contract);
      print('레슨권 잔액: ${currentLessonBalance}분');
    }
    print('');
  }

  /// 최신 레슨권 잔액 조회
  static Future<int> _getCurrentLessonBalance(Map<String, dynamic> contract) async {
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

  /// reservation_id 생성 함수
  static String _generateReservationId({
    required DateTime selectedDate,
    required String selectedTsId,
    required String selectedTime,
    required Map<String, dynamic> specialSettings,
  }) {
    // 날짜를 yymmdd 형식으로 변환
    final dateStr = selectedDate.toString().substring(2, 10).replaceAll('-', '');
    
    // 시간을 hhmm 형식으로 변환
    final timeStr = selectedTime.replaceAll(':', '');
    
    // 타석 번호
    final tsId = selectedTsId;
    
    // 최대인원 (그룹레슨 대응)
    final maxPlayerNo = specialSettings['max_player_no'] ?? 1;
    
    return '${dateStr}_${tsId}_${timeStr}_1/${maxPlayerNo}';
  }

  /// LS_id 생성 함수
  static String _generateLsId({
    required int sessionNum,
    required DateTime? sessionStartTime,
    required DateTime selectedDate,
    required int selectedProId,
    required Map<String, dynamic> specialSettings,
  }) {
    if (sessionStartTime == null) {
      return 'null';
    }
    
    // 날짜를 yymmdd 형식으로 변환
    final dateStr = selectedDate.toString().substring(2, 10).replaceAll('-', '');
    
    // 세션 시작 시간을 hhmm 형식으로 변환
    final timeStr = '${sessionStartTime.hour.toString().padLeft(2, '0')}${sessionStartTime.minute.toString().padLeft(2, '0')}';
    
    // 프로 ID
    final proId = selectedProId;
    
    // 최대인원
    final maxPlayerNo = specialSettings['max_player_no'] ?? 1;
    
    return '${dateStr}_${proId}_${timeStr}_1/${maxPlayerNo}';
  }

  /// 프로그램 시간대 분류 및 요금 계산 함수
  static Future<Map<String, dynamic>> _classifyProgramTimeSlot({
    required DateTime selectedDate,
    required String selectedTime,
    required String selectedTsId,
    required Map<String, dynamic> specialSettings,
  }) async {
    try {
      // 타석 시간 가져오기
      final tsMin = _getTotalTsMin(specialSettings);
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
      final endTime = _calculateEndTime(selectedTime, tsMin);
      
      // 요금 정책 조회
      final pricingPolicies = await ApiService.getTsPricingPolicy(date: selectedDate);
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
        startTime: selectedTime,
        endTime: endTime,
        pricingPolicies: pricingPolicies,
      );
      
      // 타석 정보 조회 (단가 정보)
      final tsInfo = await ApiService.getTsInfoById(tsId: selectedTsId);
      if (tsInfo == null) {
        print('타석 정보 조회 실패: $selectedTsId');
        return {
          'discount_min': timeAnalysis['discount_price'] ?? 0,
          'normal_min': timeAnalysis['base_price'] ?? 0,
          'extracharge_min': timeAnalysis['extracharge_price'] ?? 0,
          'total_amt': 0,
          'price_analysis': {},
        };
      }
      
      // 요금 계산
      final priceAnalysis = _calculatePricing(tsInfo, timeAnalysis);
      final totalAmt = priceAnalysis.values.fold(0, (sum, price) => sum + price);
      
      return {
        'discount_min': timeAnalysis['discount_price'] ?? 0,
        'normal_min': timeAnalysis['base_price'] ?? 0,
        'extracharge_min': timeAnalysis['extracharge_price'] ?? 0,
        'total_amt': totalAmt,
        'price_analysis': priceAnalysis,
      };
      
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

  /// 요금 계산 함수
  static Map<String, int> _calculatePricing(
    Map<String, dynamic> tsInfo,
    Map<String, int> timeAnalysis,
  ) {
    try {
      // 타석 단가 정보 (60분 기준)
      final basePricePerHour = int.tryParse(tsInfo['base_price']?.toString() ?? '0') ?? 0;
      final discountPricePerHour = int.tryParse(tsInfo['discount_price']?.toString() ?? '0') ?? 0;
      final extrachargePricePerHour = int.tryParse(tsInfo['extracharge_price']?.toString() ?? '0') ?? 0;
      
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
          
          // 분 단위로 요금 계산
          final finalPrice = ((pricePerHour / 60) * minutes).round();
          priceAnalysis[policyKey] = finalPrice;
        }
      });
      
      return priceAnalysis;
      
    } catch (e) {
      print('요금 계산 오류: $e');
      return {};
    }
  }

  /// 종료 시간 계산 함수
  static String _calculateEndTime(String startTime, int durationMinutes) {
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

  /// v2_priced_TS 테이블 업데이트 함수
  static Future<bool> _updatePricedTsTable({
    required String reservationId,
    required Map<String, dynamic> timeSlotAnalysis,
    required DateTime selectedDate,
    required String selectedTime,
    required String selectedTsId,
    required int selectedProId,
    required Map<String, dynamic> specialSettings,
    required String? specialType,
    Map<String, dynamic>? selectedMember,
  }) async {
    try {
      final currentUser = selectedMember ?? ApiService.getCurrentUser();
      if (currentUser == null) {
        print('❌ 현재 사용자 정보를 가져올 수 없습니다.');
        return false;
      }

      // 필요한 정보들
      final branchId = ApiService.getCurrentBranchId() ?? '';
      final tsId = selectedTsId;
      final tsDate = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
      final tsStart = '${selectedTime}:00';
      final tsMin = _getTotalTsMin(specialSettings);
      final tsEnd = '${_calculateEndTime(selectedTime, tsMin)}:00';

      // 회원 정보
      final memberId = currentUser['member_id']?.toString() ?? '';
      final memberType = currentUser['member_type']?.toString() ?? '일반';
      final memberName = currentUser['member_name']?.toString() ?? '';
      final memberPhone = currentUser['member_phone']?.toString() ?? '';

      // 시간대 분류 및 요금 정보
      final discountMin = timeSlotAnalysis['discount_min'] ?? 0;
      final normalMin = timeSlotAnalysis['normal_min'] ?? 0;
      final extrachargeMin = timeSlotAnalysis['extracharge_min'] ?? 0;
      final totalAmt = timeSlotAnalysis['total_amt'] ?? 0;

      // program_id 생성 (프로 ID 사용) - 레슨과 동일한 형식
      final dateStr = selectedDate.toString().substring(2, 10).replaceAll('-', '');
      final timeStr = selectedTime.replaceAll(':', '');
      final programId = '${dateStr}_${selectedProId}_${timeStr}';

      // 그룹레슨 여부 확인
      final maxPlayerNo = int.tryParse(specialSettings['max_player_no']?.toString() ?? '1') ?? 1;
      final isGroupLesson = maxPlayerNo > 1;

      print('=== v2_priced_TS 테이블 업데이트 시작 ===');
      print('그룹레슨 여부: ${isGroupLesson ? "예 (최대 ${maxPlayerNo}명)" : "아니오"}');

      if (isGroupLesson) {
        // 그룹레슨인 경우 모든 슬롯 생성
        bool allSuccess = true;

        for (int playerNo = 1; playerNo <= maxPlayerNo; playerNo++) {
          // 각 슬롯의 reservation_id 생성
          final slotReservationId = reservationId.replaceFirst('1/$maxPlayerNo', '$playerNo/$maxPlayerNo');

          // 첫 번째 슬롯은 현재 사용자 정보로, 나머지는 빈 정보로
          final isFirstSlot = playerNo == 1;
          final slotPricedTsData = <String, dynamic>{
            'branch_id': branchId,
            'reservation_id': slotReservationId,
            'ts_id': tsId,
            'ts_date': tsDate,
            'ts_start': tsStart,
            'ts_end': tsEnd,
            'ts_payment_method': '프로그램',
            'ts_status': isFirstSlot ? '결제완료' : '체크인전',
            'total_amt': totalAmt,
            'term_discount': 0,
            'coupon_discount': 0,
            'total_discount': 0,
            'net_amt': totalAmt,
            'discount_min': discountMin,
            'normal_min': normalMin,
            'extracharge_min': extrachargeMin,
            'ts_min': tsMin,
            'bill_min': isFirstSlot ? tsMin : 0,
            'time_stamp': DateTime.now().toIso8601String(),
            'program_id': programId,
            'program_name': specialType ?? '',
          };
          
          // 첫 번째 슬롯인 경우에만 회원 정보 추가
          if (isFirstSlot) {
            slotPricedTsData['member_id'] = memberId;
            slotPricedTsData['member_type'] = memberType;
            slotPricedTsData['member_name'] = memberName;
            slotPricedTsData['member_phone'] = memberPhone;
          }

          print('슬롯 $playerNo/$maxPlayerNo 생성 중...');
          print('reservation_id: $slotReservationId');

          // API 호출하여 테이블 업데이트
          final result = await ApiService.updatePricedTsTable(slotPricedTsData);

          if (result['success'] == true) {
            print('✅ 슬롯 $playerNo/$maxPlayerNo v2_priced_TS 업데이트 성공');
          } else {
            print('❌ 슬롯 $playerNo/$maxPlayerNo v2_priced_TS 업데이트 실패: ${result['error']}');
            allSuccess = false;
            // 중복 에러인 경우 즉시 중단
            if (result['isDuplicate'] == true) {
              print('🚫 중복 예약 감지 - 처리 중단');
              return false;
            }
          }
        }

        return allSuccess;

      } else {
        // 개인 레슨인 경우 기존 로직 그대로
        final pricedTsData = {
          'branch_id': branchId,
          'reservation_id': reservationId,
          'ts_id': tsId,
          'ts_date': tsDate,
          'ts_start': tsStart,
          'ts_end': tsEnd,
          'ts_payment_method': '프로그램',
          'ts_status': '결제완료',
          'member_id': memberId,
          'member_type': memberType,
          'member_name': memberName,
          'member_phone': memberPhone,
          'total_amt': totalAmt,
          'term_discount': 0,
          'coupon_discount': 0,
          'total_discount': 0,
          'net_amt': totalAmt,
          'discount_min': discountMin,
          'normal_min': normalMin,
          'extracharge_min': extrachargeMin,
          'ts_min': tsMin,
          'bill_min': tsMin,
          'time_stamp': DateTime.now().toIso8601String(),
          'program_id': programId,
          'program_name': specialType ?? '',
        };

        print('reservation_id: $reservationId');

        // API 호출하여 테이블 업데이트
        final result = await ApiService.updatePricedTsTable(pricedTsData);

        if (result['success'] == true) {
          print('✅ v2_priced_TS 테이블 업데이트 성공');
          return true;
        } else {
          print('❌ v2_priced_TS 테이블 업데이트 실패: ${result['error']}');
          if (result['isDuplicate'] == true) {
            print('🚫 중복 예약 감지');
          }
          return false;
        }
      }

    } catch (e) {
      print('❌ v2_priced_TS 테이블 업데이트 오류: $e');
      return false;
    }
  }

  /// v2_bill_times 테이블 업데이트 함수
  static Future<bool> _updateBillTimesTable({
    required String reservationId,
    required Map<String, dynamic> contract,
    required DateTime selectedDate,
    required String selectedTime,
    required String selectedTsId,
    required Map<String, dynamic> specialSettings,
  }) async {
    try {
      final currentUser = ApiService.getCurrentUser();
      if (currentUser == null) {
        print('❌ 현재 사용자 정보를 가져올 수 없습니다.');
        return false;
      }

      // 필요한 정보들
      final branchId = ApiService.getCurrentBranchId() ?? '';
      final memberId = currentUser['member_id']?.toString() ?? '';
      final tsId = selectedTsId;
      final tsMin = _getTotalTsMin(specialSettings);
      final billDate = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
      final endTime = _calculateEndTime(selectedTime, tsMin);

      // bill_text 생성
      final billText = '${tsId}번 타석(${selectedTime} ~ $endTime)';

      // 회원권 정보
      final contractHistoryId = contract['contract_history_id']?.toString() ?? '';
      final contractExpiryDate = contract['time_expiry']?.toString() ?? '';
      
      // 잔액 계산
      final beforeBalance = contract['time_balance'] as int;
      final afterBalance = beforeBalance - tsMin;

      // 그룹레슨 여부 확인
      final maxPlayerNo = int.tryParse(specialSettings['max_player_no']?.toString() ?? '1') ?? 1;
      final isGroupLesson = maxPlayerNo > 1;

      print('=== v2_bill_times 테이블 업데이트 시작 ===');
      print('그룹레슨 여부: ${isGroupLesson ? "예 (최대 ${maxPlayerNo}명)" : "아니오"}');

      if (isGroupLesson) {
        // 그룹레슨인 경우 모든 슬롯 생성
        bool allSuccess = true;

        for (int playerNo = 1; playerNo <= maxPlayerNo; playerNo++) {
          // 각 슬롯의 reservation_id 생성
          final slotReservationId = reservationId.replaceFirst('1/$maxPlayerNo', '$playerNo/$maxPlayerNo');
          final isFirstSlot = playerNo == 1;

          // v2_bill_times 테이블 업데이트 데이터
          final billTimesData = <String, dynamic>{
            'bill_date': billDate,
            'bill_type': '타석이용',
            'bill_text': billText,
            'bill_timestamp': DateTime.now().toIso8601String(),
            'reservation_id': slotReservationId,
            'bill_status': isFirstSlot ? '결제완료' : '체크인전',
            'routine_id': null,
            'branch_id': branchId,
            'bill_total_min': tsMin,
            'bill_discount_min': 0,
          };

          // 첫 번째 슬롯만 회원 정보와 차감 정보 포함
          if (isFirstSlot) {
            billTimesData['member_id'] = memberId;
            billTimesData['bill_min'] = tsMin;
            billTimesData['bill_balance_min_before'] = beforeBalance;
            billTimesData['bill_balance_min_after'] = afterBalance;
            billTimesData['contract_history_id'] = contractHistoryId;
            billTimesData['contract_TS_min_expiry_date'] = contractExpiryDate;
          } else {
            billTimesData['bill_min'] = 0;
          }

          print('슬롯 $playerNo/$maxPlayerNo 생성 중...');
          print('reservation_id: $slotReservationId');

          // API 호출하여 테이블 업데이트
          final result = await ApiService.addData(
            table: 'v2_bill_times',
            data: billTimesData,
          );
          final success = result['success'] == true;

          if (success) {
            print('✅ 슬롯 $playerNo/$maxPlayerNo v2_bill_times 업데이트 성공');
          } else {
            print('❌ 슬롯 $playerNo/$maxPlayerNo v2_bill_times 업데이트 실패');
            allSuccess = false;
          }
        }

        return allSuccess;

      } else {
        // 개인 레슨인 경우 기존 로직 그대로
        final billMinId = await ApiService.updateBillTimesTable(
          memberId: memberId,
          billDate: billDate,
          billText: billText,
          billMin: tsMin,
          billTotalMin: tsMin,
          billDiscountMin: 0,
          reservationId: reservationId,
          contractHistoryId: contractHistoryId,
          branchId: branchId,
          contractTsMinExpiryDate: contractExpiryDate,
        );

        if (billMinId != null && billMinId > 0) {
          print('✅ v2_bill_times 테이블 업데이트 성공 (bill_min_id: $billMinId)');
          return true;
        } else {
          print('❌ v2_bill_times 테이블 업데이트 실패');
          return false;
        }
      }

    } catch (e) {
      print('❌ v2_bill_times 테이블 업데이트 오류: $e');
      return false;
    }
  }

  /// v2_LS_orders 테이블 업데이트 함수
  static Future<bool> _updateLsOrdersTable({
    required String reservationId,
    required Map<String, dynamic> contract,
    required DateTime selectedDate,
    required int selectedProId,
    required String selectedProName,
    required String selectedTime,
    required String selectedTsId,
    required Map<String, dynamic> specialSettings,
    Map<String, dynamic>? selectedMember,
  }) async {
    try {
      final currentUser = selectedMember ?? ApiService.getCurrentUser();
      if (currentUser == null) {
        print('❌ 현재 사용자 정보를 가져올 수 없습니다.');
        return false;
      }

      // ls_min과 ls_break_min을 순서 번호 기준으로 수집
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

      // 레슨 블록만 추출
      final lessonSessions = timeBlocks.where((block) => block['type'] == 'lesson').toList();

      if (lessonSessions.isEmpty) {
        print('❌ 레슨 세션 정보가 없습니다.');
        return false;
      }

      // 필요한 정보들
      final branchId = ApiService.getCurrentBranchId() ?? '';
      final memberId = currentUser['member_id']?.toString() ?? '';
      final memberName = currentUser['member_name']?.toString() ?? '';
      final memberType = currentUser['member_type']?.toString() ?? '일반';
      final tsId = selectedTsId;
      final lsDate = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
      final proId = selectedProId.toString();
      final proName = selectedProName;
      final lsContractId = contract['contract_id']?.toString() ?? '';
      
      // program_id 생성 (프로 ID 사용)
      final dateStr = selectedDate.toString().substring(2, 10).replaceAll('-', '');
      final timeStr = selectedTime.replaceAll(':', '');
      final programId = '${dateStr}_${selectedProId}_${timeStr}';

      // 각 세션의 시작 시간 계산
      DateTime? baseTime;
      if (selectedTime.isNotEmpty) {
        baseTime = DateTime.parse('2025-01-01 ${selectedTime}:00');
      }
      
      DateTime? currentSessionTime = baseTime;
      bool allSuccess = true;

      // 그룹레슨 여부 확인
      final maxPlayerNo = int.tryParse(specialSettings['max_player_no']?.toString() ?? '1') ?? 1;
      final isGroupLesson = maxPlayerNo > 1;

      print('=== v2_LS_orders 테이블 업데이트 시작 ===');
      print('program_id: $programId');
      print('총 세션 수: ${lessonSessions.length}');
      print('그룹레슨 여부: ${isGroupLesson ? "예 (최대 ${maxPlayerNo}명)" : "아니오"}');

      // 모든 블록을 순회하면서 레슨 블록만 DB에 저장
      for (final block in timeBlocks) {
        if (currentSessionTime == null) {
          print('❌ 세션 시간 계산 실패');
          allSuccess = false;
          break;
        }

        final blockType = block['type'] as String;
        final duration = block['duration'] as int;
        final blockEndTime = currentSessionTime.add(Duration(minutes: duration));

        if (blockType == 'lesson') {
          // 레슨 블록인 경우에만 DB 저장
          final lessonNum = block['lesson_number'] as int;
          final orderNum = block['order'] as int;

          final lsStartTime = '${currentSessionTime.hour.toString().padLeft(2, '0')}:${currentSessionTime.minute.toString().padLeft(2, '0')}:00';
          final lsEndTime = '${blockEndTime.hour.toString().padLeft(2, '0')}:${blockEndTime.minute.toString().padLeft(2, '0')}:00';

          if (isGroupLesson) {
            // 그룹레슨인 경우 모든 참가자 슬롯 생성
            for (int playerNo = 1; playerNo <= maxPlayerNo; playerNo++) {
              final isFirstSlot = playerNo == 1;

              // 각 슬롯의 LS_id 생성
              final lsId = _generateLsId(
                sessionNum: orderNum,
                sessionStartTime: currentSessionTime,
                selectedDate: selectedDate,
                selectedProId: selectedProId,
                specialSettings: specialSettings,
              );
              final slotLsId = lsId.replaceFirst('1/$maxPlayerNo', '$playerNo/$maxPlayerNo');

              // v2_LS_orders 데이터 생성
              final lsOrderData = <String, dynamic>{
                'branch_id': branchId,
                'LS_id': slotLsId,
                'LS_transaction_type': '레슨예약',
                'LS_date': lsDate,
                'LS_status': isFirstSlot ? '결제완료' : '체크인전',
                'LS_type': '프로그램',
                'pro_id': proId,
                'pro_name': proName,
                'LS_order_source': '앱',
                'LS_start_time': lsStartTime,
                'LS_end_time': lsEndTime,
                'LS_net_min': duration,
                'updated_at': DateTime.now().toIso8601String(),
                'TS_id': tsId,
                'program_id': programId,
                'routine_id': null,
                'LS_request': null,
              };

              // 첫 번째 슬롯인 경우에만 회원 정보 추가
              if (isFirstSlot) {
                lsOrderData['member_id'] = memberId;
                lsOrderData['member_name'] = memberName;
                lsOrderData['member_type'] = memberType;
                lsOrderData['LS_contract_id'] = lsContractId;
              }

              print('레슨 ${lessonNum} (순서 ${orderNum}) 슬롯 $playerNo/$maxPlayerNo: ${lsStartTime} ~ ${lsEndTime}');

              // API 호출하여 테이블 업데이트
              final result = await ApiService.addData(
                table: 'v2_LS_orders',
                data: lsOrderData,
              );
              final success = result['success'] == true;

              if (success) {
                print('✅ 레슨 ${lessonNum} 슬롯 $playerNo/$maxPlayerNo v2_LS_orders 업데이트 성공');
              } else {
                final errorMsg = result['message']?.toString() ?? '';
                print('❌ 레슨 ${lessonNum} 슬롯 $playerNo/$maxPlayerNo v2_LS_orders 업데이트 실패: $errorMsg');
                allSuccess = false;
                // 중복 에러인 경우 즉시 중단
                if (errorMsg.contains('23505') || errorMsg.contains('이미 레슨 예약이 존재합니다')) {
                  print('🚫 레슨 중복 감지 - 처리 중단');
                  return false;
                }
              }
            }
          } else {
            // 개인 레슨인 경우
            final lsId = _generateLsId(
              sessionNum: orderNum,
              sessionStartTime: currentSessionTime,
              selectedDate: selectedDate,
              selectedProId: selectedProId,
              specialSettings: specialSettings,
            );

            // v2_LS_orders 데이터 생성
            final lsOrderData = {
              'branch_id': branchId,
              'LS_id': lsId,
              'LS_transaction_type': '레슨예약',
              'LS_date': lsDate,
              'member_id': memberId,
              'LS_status': '결제완료',
              'member_name': memberName,
              'member_type': memberType,
              'LS_type': '프로그램',
              'pro_id': proId,
              'pro_name': proName,
              'LS_order_source': '앱',
              'LS_start_time': lsStartTime,
              'LS_end_time': lsEndTime,
              'LS_net_min': duration,
              'updated_at': DateTime.now().toIso8601String(),
              'TS_id': tsId,
              'program_id': programId,
              'routine_id': null,
              'LS_request': null,
              'LS_contract_id': lsContractId,
            };

            print('레슨 ${lessonNum} (순서 ${orderNum}): ${lsStartTime} ~ ${lsEndTime}');

            // API 호출하여 테이블 업데이트
            final result = await ApiService.addData(
              table: 'v2_LS_orders',
              data: lsOrderData,
            );
            final success = result['success'] == true;

            if (success) {
              print('✅ 레슨 ${lessonNum} v2_LS_orders 업데이트 성공');
            } else {
              final errorMsg = result['message']?.toString() ?? '';
              print('❌ 레슨 ${lessonNum} v2_LS_orders 업데이트 실패: $errorMsg');
              allSuccess = false;
              // 중복 에러인 경우 즉시 중단
              if (errorMsg.contains('23505') || errorMsg.contains('이미 레슨 예약이 존재합니다')) {
                print('🚫 레슨 중복 감지 - 처리 중단');
                return false;
              }
            }
          }
        } else {
          // 휴식 블록인 경우 시간만 누적
          print('휴식 시간: ${currentSessionTime.hour.toString().padLeft(2, '0')}:${currentSessionTime.minute.toString().padLeft(2, '0')} ~ ${blockEndTime.hour.toString().padLeft(2, '0')}:${blockEndTime.minute.toString().padLeft(2, '0')} (${duration}분)');
        }

        // 다음 블록 시작 시간 = 현재 블록 종료 시간
        currentSessionTime = blockEndTime;
      }

      if (allSuccess) {
        print('✅ 모든 세션 v2_LS_orders 테이블 업데이트 성공');
        return true;
      } else {
        print('❌ 일부 세션 v2_LS_orders 테이블 업데이트 실패');
        return false;
      }

    } catch (e) {
      print('❌ v2_LS_orders 테이블 업데이트 오류: $e');
      return false;
    }
  }

  /// v3_LS_countings 테이블 업데이트 함수
  static Future<bool> _updateLsCountingsTable({
    required String reservationId,
    required Map<String, dynamic> contract,
    required DateTime selectedDate,
    required int selectedProId,
    required String selectedProName,
    required String selectedTime,
    required String selectedTsId,
    required Map<String, dynamic> specialSettings,
    Map<String, dynamic>? selectedMember,
  }) async {
    try {
      final currentUser = selectedMember ?? ApiService.getCurrentUser();
      if (currentUser == null) {
        print('❌ 현재 사용자 정보를 가져올 수 없습니다.');
        return false;
      }

      // ls_min과 ls_break_min을 순서 번호 기준으로 수집
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

      // 레슨 블록만 추출
      final lessonSessions = timeBlocks.where((block) => block['type'] == 'lesson').toList();

      if (lessonSessions.isEmpty) {
        print('❌ 레슨 세션 정보가 없습니다.');
        return false;
      }

      // 필요한 정보들
      final branchId = ApiService.getCurrentBranchId() ?? '';
      final memberId = currentUser['member_id']?.toString() ?? '';
      final memberName = currentUser['member_name']?.toString() ?? '';
      final memberType = currentUser['member_type']?.toString() ?? '일반';
      final lsDate = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
      final proId = selectedProId.toString();
      final proName = selectedProName;
      final lsContractId = contract['lesson_contract_id']?.toString() ?? 
                          contract['contract_id']?.toString() ?? '';
      final contractHistoryId = contract['contract_history_id']?.toString() ?? '';
      final lsExpiryDate = contract['lesson_expiry']?.toString() ?? '';
      
      // program_id 생성 (프로 ID 사용)
      final dateStr = selectedDate.toString().substring(2, 10).replaceAll('-', '');
      final timeStr = selectedTime.replaceAll(':', '');
      final programId = '${dateStr}_${selectedProId}_${timeStr}';

      // 각 세션의 시작 시간 계산
      DateTime? baseTime;
      if (selectedTime.isNotEmpty) {
        baseTime = DateTime.parse('2025-01-01 ${selectedTime}:00');
      }
      
      DateTime? currentSessionTime = baseTime;
      bool allSuccess = true;

      // 그룹레슨 여부 확인
      final maxPlayerNo = int.tryParse(specialSettings['max_player_no']?.toString() ?? '1') ?? 1;
      final isGroupLesson = maxPlayerNo > 1;

      // 레슨권 잔액 계산 - 최신 잔액 조회
      int currentBalance;
      try {
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

      print('=== v3_LS_countings 테이블 업데이트 시작 ===');
      print('program_id: $programId');
      print('총 세션 수: ${lessonSessions.length}');
      print('레슨권 시작 잔액: ${currentBalance}분');
      print('그룹레슨 여부: ${isGroupLesson ? "예 (최대 ${maxPlayerNo}명)" : "아니오"}');

      // 모든 블록을 순회하면서 레슨 블록만 DB에 저장
      for (final block in timeBlocks) {
        if (currentSessionTime == null) {
          print('❌ 세션 시간 계산 실패');
          allSuccess = false;
          break;
        }

        final blockType = block['type'] as String;
        final duration = block['duration'] as int;
        final blockEndTime = currentSessionTime.add(Duration(minutes: duration));

        if (blockType == 'lesson') {
          // 레슨 블록인 경우에만 DB 저장
          final lessonNum = block['lesson_number'] as int;
          final orderNum = block['order'] as int;

          if (isGroupLesson) {
            // 그룹레슨인 경우 모든 참가자 슬롯 생성
            final balanceBefore = currentBalance;
            final balanceAfter = currentBalance - duration;
          
          for (int playerNo = 1; playerNo <= maxPlayerNo; playerNo++) {
            final isFirstSlot = playerNo == 1;
            
              // 각 슬롯의 LS_id 생성
              final lsId = _generateLsId(
                sessionNum: orderNum,
                sessionStartTime: currentSessionTime,
                selectedDate: selectedDate,
                selectedProId: selectedProId,
                specialSettings: specialSettings,
              );
              final slotLsId = lsId.replaceFirst('1/$maxPlayerNo', '$playerNo/$maxPlayerNo');

              // v3_LS_countings 데이터 생성
              final lsCountingData = <String, dynamic>{
                'LS_transaction_type': '레슨차감',
                'LS_date': lsDate,
                'LS_status': isFirstSlot ? '차감완료' : '체크인전',
                'LS_type': '프로그램',
                'LS_id': slotLsId,
                'LS_net_min': duration,
              'LS_counting_source': '앱',
              'updated_at': DateTime.now().toIso8601String(),
              'program_id': programId,
              'branch_id': branchId,
              'pro_id': proId,
              'pro_name': proName,
            };

            // LS_expiry_date가 유효한 경우만 추가 (빈 문자열 방지)
            if (lsExpiryDate != null && lsExpiryDate.isNotEmpty) {
              lsCountingData['LS_expiry_date'] = lsExpiryDate;
            }

            // 첫 번째 슬롯만 회원 정보와 차감 정보 포함
            if (isFirstSlot) {
              lsCountingData['member_id'] = memberId;
              lsCountingData['member_name'] = memberName;
              lsCountingData['member_type'] = memberType;
              lsCountingData['LS_contract_id'] = lsContractId;
              lsCountingData['contract_history_id'] = contractHistoryId;
              lsCountingData['LS_balance_min_before'] = balanceBefore;
              lsCountingData['LS_balance_min_after'] = balanceAfter;
            }

              print('레슨 ${lessonNum} (순서 ${orderNum}) 슬롯 $playerNo/$maxPlayerNo: ${currentSessionTime.hour.toString().padLeft(2, '0')}:${currentSessionTime.minute.toString().padLeft(2, '0')} ~ ${blockEndTime.hour.toString().padLeft(2, '0')}:${blockEndTime.minute.toString().padLeft(2, '0')}');

              // API 호출하여 테이블 업데이트
              final result = await ApiService.addData(
                table: 'v3_LS_countings',
                data: lsCountingData,
              );
              final success = result['success'] == true;

              if (success) {
                if (isFirstSlot) {
                  print('✅ 레슨 ${lessonNum} 슬롯 $playerNo/$maxPlayerNo v3_LS_countings 업데이트 성공 (${balanceBefore}분 → ${balanceAfter}분)');
                  currentBalance = balanceAfter.toInt();
                } else {
                  print('✅ 레슨 ${lessonNum} 슬롯 $playerNo/$maxPlayerNo v3_LS_countings 업데이트 성공 (빈 슬롯)');
                }
              } else {
                print('❌ 레슨 ${lessonNum} 슬롯 $playerNo/$maxPlayerNo v3_LS_countings 업데이트 실패');
                allSuccess = false;
              }
            }
          } else {
            // 개인 레슨인 경우
            final balanceBefore = currentBalance;
            final balanceAfter = currentBalance - duration;
            final lsId = _generateLsId(
              sessionNum: orderNum,
              sessionStartTime: currentSessionTime,
              selectedDate: selectedDate,
              selectedProId: selectedProId,
              specialSettings: specialSettings,
            );

            // v3_LS_countings 데이터 생성
            final lsCountingData = <String, dynamic>{
              'LS_transaction_type': '레슨차감',
              'LS_date': lsDate,
              'member_id': memberId,
              'member_name': memberName,
              'member_type': memberType,
              'LS_status': '차감완료',
              'LS_type': '프로그램',
              'LS_contract_id': lsContractId,
              'contract_history_id': contractHistoryId,
              'LS_id': lsId,
              'LS_balance_min_before': balanceBefore,
              'LS_net_min': duration,
              'LS_balance_min_after': balanceAfter,
              'LS_counting_source': '앱',
              'updated_at': DateTime.now().toIso8601String(),
              'program_id': programId,
              'branch_id': branchId,
              'pro_id': proId,
              'pro_name': proName,
            };

            // LS_expiry_date가 유효한 경우만 추가 (빈 문자열 방지)
            if (lsExpiryDate != null && lsExpiryDate.isNotEmpty) {
              lsCountingData['LS_expiry_date'] = lsExpiryDate;
            }

            print('레슨 ${lessonNum} (순서 ${orderNum}): ${currentSessionTime.hour.toString().padLeft(2, '0')}:${currentSessionTime.minute.toString().padLeft(2, '0')} ~ ${blockEndTime.hour.toString().padLeft(2, '0')}:${blockEndTime.minute.toString().padLeft(2, '0')}');

            // API 호출하여 테이블 업데이트
            final result = await ApiService.addData(
              table: 'v3_LS_countings',
              data: lsCountingData,
            );
            final success = result['success'] == true;

            if (success) {
              print('✅ 레슨 ${lessonNum} v3_LS_countings 업데이트 성공 (${balanceBefore}분 → ${balanceAfter}분)');
              currentBalance = balanceAfter.toInt();
            } else {
              print('❌ 레슨 ${lessonNum} v3_LS_countings 업데이트 실패');
              allSuccess = false;
            }
          }
        } else {
          // 휴식 블록인 경우 시간만 누적
          print('휴식 시간: ${currentSessionTime.hour.toString().padLeft(2, '0')}:${currentSessionTime.minute.toString().padLeft(2, '0')} ~ ${blockEndTime.hour.toString().padLeft(2, '0')}:${blockEndTime.minute.toString().padLeft(2, '0')} (${duration}분)');
        }

        // 다음 블록 시작 시간 = 현재 블록 종료 시간
        currentSessionTime = blockEndTime;
      }

      if (allSuccess) {
        print('✅ 모든 세션 v3_LS_countings 테이블 업데이트 성공');
        return true;
      } else {
        print('❌ 일부 세션 v3_LS_countings 테이블 업데이트 실패');
        return false;
      }

    } catch (e) {
      print('❌ v3_LS_countings 테이블 업데이트 오류: $e');
      return false;
    }
  }

  /// AI PK 수집을 포함한 v2_bill_times 테이블 업데이트 함수
  static Future<Map<String, dynamic>> _updateBillTimesTableWithPkCollection({
    required String reservationId,
    required Map<String, dynamic> contract,
    required DateTime selectedDate,
    required String selectedTime,
    required String selectedTsId,
    required Map<String, dynamic> specialSettings,
    Map<String, dynamic>? selectedMember,
  }) async {
    try {
      final currentUser = selectedMember ?? ApiService.getCurrentUser();
      if (currentUser == null) {
        print('❌ 현재 사용자 정보를 가져올 수 없습니다.');
        return {'success': false, 'billMinIds': <int>[]};
      }

      // 필요한 정보들
      final branchId = ApiService.getCurrentBranchId() ?? '';
      final memberId = currentUser['member_id']?.toString() ?? '';
      final tsId = selectedTsId;
      final tsMin = _getTotalTsMin(specialSettings);
      final billDate = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
      final endTime = _calculateEndTime(selectedTime, tsMin);

      // bill_text 생성
      final billText = '${tsId}번 타석(${selectedTime} ~ $endTime)';

      // 회원권 정보
      final contractHistoryId = contract['contract_history_id']?.toString() ?? '';
      final contractExpiryDate = contract['time_expiry']?.toString() ?? '';
      
      // 잔액 계산
      final beforeBalance = contract['time_balance'] as int;
      final afterBalance = beforeBalance - tsMin;

      // 그룹레슨 여부 확인
      final maxPlayerNo = int.tryParse(specialSettings['max_player_no']?.toString() ?? '1') ?? 1;
      final isGroupLesson = maxPlayerNo > 1;

      print('=== v2_bill_times 테이블 업데이트 시작 (AI PK 수집) ===');
      print('그룹레슨 여부: ${isGroupLesson ? "예 (최대 ${maxPlayerNo}명)" : "아니오"}');

      List<int> billMinIds = [];
      List<String> reservationIds = [];

      if (isGroupLesson) {
        // 그룹레슨인 경우 모든 슬롯 생성
        bool allSuccess = true;

        for (int playerNo = 1; playerNo <= maxPlayerNo; playerNo++) {
          // 각 슬롯의 reservation_id 생성
          final slotReservationId = reservationId.replaceFirst('1/$maxPlayerNo', '$playerNo/$maxPlayerNo');
          final isFirstSlot = playerNo == 1;

          // v2_bill_times 테이블 업데이트 데이터
          final billTimesData = <String, dynamic>{
            'bill_date': billDate,
            'bill_type': '타석이용',
            'bill_text': billText,
            'bill_timestamp': DateTime.now().toIso8601String(),
            'reservation_id': slotReservationId,
            'bill_status': isFirstSlot ? '결제완료' : '체크인전',
            'routine_id': null,
            'branch_id': branchId,
            'bill_total_min': tsMin,
            'bill_discount_min': 0,
          };

          // 첫 번째 슬롯만 회원 정보와 차감 정보 포함
          if (isFirstSlot) {
            billTimesData['member_id'] = memberId;
            billTimesData['bill_min'] = tsMin;
            billTimesData['bill_balance_min_before'] = beforeBalance;
            billTimesData['bill_balance_min_after'] = afterBalance;
            billTimesData['contract_history_id'] = contractHistoryId;
            billTimesData['contract_TS_min_expiry_date'] = contractExpiryDate;
          } else {
            billTimesData['bill_min'] = 0;
          }

          print('슬롯 $playerNo/$maxPlayerNo 생성 중...');
          print('reservation_id: $slotReservationId');

          // API 호출하여 테이블 업데이트
          final result = await ApiService.addData(
            table: 'v2_bill_times',
            data: billTimesData,
          );
          final success = result['success'] == true;

          if (success) {
            // AI PK와 reservation_id 수집
            final billMinId = result['insertId'];
            if (billMinId != null) {
              final parsedId = int.tryParse(billMinId.toString());
              if (parsedId != null && parsedId > 0) {
                billMinIds.add(parsedId);
                reservationIds.add(slotReservationId);
                print('✅ 슬롯 $playerNo/$maxPlayerNo v2_bill_times 업데이트 성공 (reservation_id: $slotReservationId, bill_min_id: $parsedId)');
              }
            }
          } else {
            print('❌ 슬롯 $playerNo/$maxPlayerNo v2_bill_times 업데이트 실패');
            allSuccess = false;
          }
        }

        return {'success': allSuccess, 'billMinIds': billMinIds, 'reservationIds': reservationIds};

      } else {
        // 개인 레슨인 경우 기존 로직 그대로
        final billMinId = await ApiService.updateBillTimesTable(
          memberId: memberId,
          billDate: billDate,
          billText: billText,
          billMin: tsMin,
          billTotalMin: tsMin,
          billDiscountMin: 0,
          reservationId: reservationId,
          contractHistoryId: contractHistoryId,
          branchId: branchId,
          contractTsMinExpiryDate: contractExpiryDate,
        );

        if (billMinId != null && billMinId > 0) {
          billMinIds.add(billMinId);
          reservationIds.add(reservationId);
          print('✅ v2_bill_times 테이블 업데이트 성공 (reservation_id: $reservationId, bill_min_id: $billMinId)');
          return {'success': true, 'billMinIds': billMinIds, 'reservationIds': reservationIds};
        } else {
          print('❌ v2_bill_times 테이블 업데이트 실패');
          return {'success': false, 'billMinIds': <int>[], 'reservationIds': <String>[]};
        }
      }

    } catch (e) {
      print('❌ v2_bill_times 테이블 업데이트 오류: $e');
      return {'success': false, 'billMinIds': <int>[], 'reservationIds': <String>[]};
    }
  }

  /// v2_priced_TS 테이블에 AI PK 개별 매핑 저장 함수 (그룹 레슨용)
  static Future<bool> _updatePricedTsWithIndividualBillIds({
    required List<String> reservationIds,
    required List<int> billMinIds,
  }) async {
    try {
      print('=== v2_priced_TS에 AI PK 개별 매핑 저장 시작 ===');
      print('총 ${reservationIds.length}개 레코드 업데이트');
      
      bool allSuccess = true;
      
      for (int i = 0; i < reservationIds.length && i < billMinIds.length; i++) {
        final reservationId = reservationIds[i];
        final billMinId = billMinIds[i];
        
        print('${i + 1}/${reservationIds.length}: $reservationId → bill_min_id: $billMinId');
        
        final success = await ApiService.updatePricedTsWithBillIds(
          reservationId: reservationId,
          billIds: null, // 특별예약에서는 선불크레딧 사용 안함
          billMinIds: billMinId.toString(),
        );
        
        if (success) {
          print('✅ v2_priced_TS 업데이트 성공: $reservationId');
        } else {
          print('❌ v2_priced_TS 업데이트 실패: $reservationId');
          allSuccess = false;
        }
      }

      if (allSuccess) {
        print('✅ 모든 v2_priced_TS 레코드에 AI PK 개별 매핑 완료');
      } else {
        print('❌ 일부 v2_priced_TS 레코드 AI PK 매핑 실패');
      }

      return allSuccess;
    } catch (e) {
      print('❌ v2_priced_TS AI PK 개별 매핑 오류: $e');
      return false;
    }
  }

  /// v2_priced_TS 테이블에 AI PK 저장 함수 (개인 레슨용)
  static Future<bool> _updatePricedTsWithBillIds({
    required String reservationId,
    String? billIds,
    String? billMinIds,
  }) async {
    try {
      print('=== v2_priced_TS에 AI PK 저장 시작 ===');
      print('reservation_id: $reservationId');
      print('bill_ids: $billIds');
      print('bill_min_ids: $billMinIds');

      final success = await ApiService.updatePricedTsWithBillIds(
        reservationId: reservationId,
        billIds: billIds,
        billMinIds: billMinIds,
      );

      if (success) {
        print('✅ v2_priced_TS에 AI PK 저장 성공');
      } else {
        print('❌ v2_priced_TS에 AI PK 저장 실패');
      }

      return success;
    } catch (e) {
      print('❌ v2_priced_TS AI PK 저장 오류: $e');
      return false;
    }
  }
} 