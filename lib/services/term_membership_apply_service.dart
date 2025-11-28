import 'holiday_service.dart';
import 'api_service.dart';

/// 기간권 사용 가능 분수 계산을 전담하는 서비스 클래스
class TermMembershipApplyService {

  /// 기간권 사용 가능 분수 계산 (메인 함수)
  /// 
  /// [branchId] 지점 ID
  /// [memberId] 회원 ID
  /// [selectedDate] 선택한 날짜 (YYYY-MM-DD 형식)
  /// [selectedStartTime] 선택한 시작 시간 (HH:MM 형식)
  /// [selectedEndTime] 선택한 종료 시간 (HH:MM 형식)
  /// [selectedTs] 선택한 타석 번호
  /// 
  /// 반환값: 사용 가능한 분수 (0~60분)
  static Future<int> calculateUsableMinutes({
    required String branchId,
    required String memberId,
    required String selectedDate,
    required String selectedStartTime,
    required String selectedEndTime,
    required String selectedTs,
  }) async {
    try {
      print('=== TermMembershipApplyService.calculateUsableMinutes 시작 ===');
      print('지점 ID: $branchId');
      print('회원 ID: $memberId');
      print('선택 날짜: $selectedDate');
      print('선택 시간: $selectedStartTime ~ $selectedEndTime');
      print('선택 타석: $selectedTs');
      
      // 1. 선택한 시간의 분수 계산
      final selectedDuration = _calculateDurationMinutes(selectedStartTime, selectedEndTime);
      print('선택한 이용 시간: ${selectedDuration}분');
      
      if (selectedDuration <= 0) {
        print('잘못된 시간 범위');
        return 0;
      }
      
      // 2. 해당 날짜에 이미 사용한 기간권 시간 확인
      final existingUsedMinutes = await _checkExistingPeriodPassDiscount(
        branchId: branchId,
        memberId: memberId,
        date: selectedDate,
      );
      
      // 하루 최대 60분 제한
      final remainingMinutes = 60 - existingUsedMinutes;
      if (remainingMinutes <= 0) {
        print('오늘 기간권 사용 한도(60분) 도달: 이미 ${existingUsedMinutes}분 사용');
        return 0;
      }
      print('오늘 사용 가능한 기간권 시간: ${remainingMinutes}분 (이미 사용: ${existingUsedMinutes}분)');
      
      // 3. 회원의 유효한 기간권 정보 조회 (홀드 체크 포함)
      final periodPasses = await _getMemberPeriodPass(
        branchId: branchId,
        memberId: memberId,
        reservationDate: selectedDate,
      );
      
      if (periodPasses.isEmpty) {
        print('유효한 기간권이 없음');
        return 0;
      }
      
      // 4. 선택한 날짜 정보 분석
      final selectedDateTime = DateTime.tryParse(selectedDate);
      if (selectedDateTime == null) {
        print('잘못된 날짜 형식');
        return 0;
      }
      
      final isHolidayDate = await HolidayService.isHoliday(selectedDateTime);
      final dayOfWeek = HolidayService.getKoreanDayOfWeek(selectedDateTime);
      
      print('선택 날짜 요일: $dayOfWeek');
      print('공휴일 여부: $isHolidayDate');
      
      // 5. 각 기간권에 대해 매칭 확인 및 최대 사용 가능 분수 계산
      int maxUsableMinutes = 0;
      
      for (final periodPass in periodPasses) {
        final usableMinutes = _calculatePeriodPassMatch(
          periodPass: periodPass,
          selectedDuration: selectedDuration,
          selectedStartTime: selectedStartTime,
          selectedTs: selectedTs,
          dayOfWeek: dayOfWeek,
          isHolidayDate: isHolidayDate,
        );
        
        if (usableMinutes > maxUsableMinutes) {
          maxUsableMinutes = usableMinutes;
          print('최대 사용 가능 분수 업데이트: $maxUsableMinutes분 (${periodPass['contract_name']})');
        }
      }
      
      // 남은 사용 가능 시간과 비교하여 최종 결과 결정
      final finalUsableMinutes = maxUsableMinutes > remainingMinutes ? remainingMinutes : maxUsableMinutes;
      
      print('=== 최종 계산 결과 ===');
      print('매칭된 기간권 최대 시간: $maxUsableMinutes분');
      print('오늘 남은 사용 가능 시간: $remainingMinutes분');
      print('최종 사용 가능 분수: $finalUsableMinutes분');
      
      return finalUsableMinutes;
      
    } catch (e) {
      print('기간권 사용 가능 분수 계산 실패: $e');
      return 0;
    }
  }

  /// 시작시간과 종료시간으로부터 분수 계산
  static int _calculateDurationMinutes(String startTime, String endTime) {
    try {
      int timeToMinutes(String timeStr) {
        final parts = timeStr.split(':');
        return int.parse(parts[0]) * 60 + int.parse(parts[1]);
      }
      
      final startMinutes = timeToMinutes(startTime);
      final endMinutes = timeToMinutes(endTime);
      
      return endMinutes - startMinutes;
    } catch (e) {
      print('시간 계산 오류: $e');
      return 0;
    }
  }

  /// 기존 기간권 할인 사용 여부 확인
  static Future<int> _checkExistingPeriodPassDiscount({
    required String branchId,
    required String memberId,
    required String date,
  }) async {
    try {
      print('=== 기존 기간권 사용 시간 확인 (v2_bill_term) ===');
      print('지점 ID: $branchId, 회원 ID: $memberId, 날짜: $date');
      
      // v2_bill_term에서 해당 날짜의 기간권 사용 시간 조회
      final result = await ApiService.getData(
        table: 'v2_bill_term',
        fields: ['bill_term_min'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
          {'field': 'bill_date', 'operator': '=', 'value': date},
          {'field': 'bill_status', 'operator': '=', 'value': '결제완료'},
        ],
      );
      
      int totalUsedMinutes = 0;
      for (final record in result) {
        final usedMinutes = int.tryParse(record['bill_term_min']?.toString() ?? '0') ?? 0;
        totalUsedMinutes += usedMinutes;
      }
      
      print('기존 기간권 사용 총합: ${totalUsedMinutes}분');
      return totalUsedMinutes;
    } catch (e) {
      print('기존 기간권 사용 확인 실패: $e');
      return 0;
    }
  }

  /// 회원의 유효한 기간권 정보 조회 (v2_bill_term 기반, 홀드 체크 포함)
  static Future<List<Map<String, dynamic>>> _getMemberPeriodPass({
    required String branchId,
    required String memberId,
    String? reservationDate, // 예약 날짜 추가 (홀드 체크용)
  }) async {
    try {
      print('=== 회원 기간권 정보 조회 (v2_bill_term 기반) ===');
      print('지점 ID: $branchId, 회원 ID: $memberId');
      print('예약 날짜: $reservationDate');
      
      // 오늘 날짜
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      // 1. v2_bill_term에서 유효한 기간권 조회
      final billTerms = await ApiService.getData(
        table: 'v2_bill_term',
        fields: ['bill_term_id', 'contract_history_id', 'contract_term_month_expiry_date', 'bill_text'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
          {'field': 'contract_term_month_expiry_date', 'operator': '>=', 'value': todayStr},
        ],
        orderBy: [
          {'field': 'bill_term_id', 'direction': 'DESC'}
        ],
      );
      
      print('조회된 v2_bill_term 레코드 수: ${billTerms.length}');
      
      if (billTerms.isEmpty) {
        print('유효한 기간권이 없음');
        return [];
      }
      
      // 2. contract_history_id별로 가장 최신 bill_term_id 기준으로 정보 추출
      final validContractHistoryIds = <String>{};
      final contractInfo = <String, Map<String, dynamic>>{};
      final contractBillTermIds = <String, int>{}; // contract_history_id별 최대 bill_term_id 추적
      
      for (final term in billTerms) {
        final contractHistoryId = term['contract_history_id']?.toString();
        final expiryDate = term['contract_term_month_expiry_date']?.toString();
        final billTermId = int.tryParse(term['bill_term_id']?.toString() ?? '0') ?? 0;
        
        if (contractHistoryId != null && contractHistoryId.isNotEmpty) {
          // 이미 존재하는 경우 더 큰 bill_term_id로 업데이트
          if (contractInfo.containsKey(contractHistoryId)) {
            final existingBillTermId = contractBillTermIds[contractHistoryId] ?? 0;
            if (billTermId > existingBillTermId) {
              contractInfo[contractHistoryId] = {
                'contract_history_id': contractHistoryId,
                'expiry_date': expiryDate,
                'bill_text': term['bill_text'],
              };
              contractBillTermIds[contractHistoryId] = billTermId;
              print('기간권 정보 업데이트 (최신 bill_term_id: $billTermId) - contract_history_id: $contractHistoryId, 만료일: $expiryDate');
            }
          } else {
            validContractHistoryIds.add(contractHistoryId);
            contractInfo[contractHistoryId] = {
              'contract_history_id': contractHistoryId,
              'expiry_date': expiryDate,
              'bill_text': term['bill_text'],
            };
            contractBillTermIds[contractHistoryId] = billTermId;
            print('유효한 기간권 발견 (bill_term_id: $billTermId) - contract_history_id: $contractHistoryId, 만료일: $expiryDate');
          }
        }
      }
      
      if (validContractHistoryIds.isEmpty) {
        print('유효한 contract_history_id가 없음');
        return [];
      }
      
      // 3. contract_history_id로 v3_contract_history 조회하여 contract_id 획득
      final contractHistories = await ApiService.getData(
        table: 'v3_contract_history',
        fields: ['contract_history_id', 'contract_id'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'contract_history_id', 'operator': 'IN', 'value': validContractHistoryIds.toList()},
        ],
      );
      
      if (contractHistories.isEmpty) {
        print('contract_history 정보를 찾을 수 없음');
        return [];
      }
      
      // 4. contract_id 수집
      final contractIds = <String>[];
      final historyToContractMap = <String, String>{};
      
      for (final history in contractHistories) {
        final contractHistoryId = history['contract_history_id']?.toString();
        final contractId = history['contract_id']?.toString();
        
        if (contractHistoryId != null && contractId != null) {
          contractIds.add(contractId);
          historyToContractMap[contractHistoryId] = contractId;
        }
      }
      
      // 5. v2_contracts에서 이용 조건 조회
      final contractDetails = await ApiService.getData(
        table: 'v2_contracts',
        fields: ['contract_id', 'contract_name', 'available_days', 'available_start_time', 'available_end_time', 'available_ts_id', 'program_reservation_availability'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'contract_id', 'operator': 'IN', 'value': contractIds},
        ],
      );
      
      print('=== 조회된 기간권 이용 조건 ===');
      for (final detail in contractDetails) {
        print('계약 ID: ${detail['contract_id']}');
        print('계약명: ${detail['contract_name']}');
        print('이용 가능 요일: ${detail['available_days']}');
        print('이용 가능 시간: ${detail['available_start_time']} ~ ${detail['available_end_time']}');
        print('이용 가능 타석 ID: ${detail['available_ts_id']}');
        print('program_reservation_availability: "${detail['program_reservation_availability']}"');
        print('---');
      }
      
      // 6. 결과 조합 (프로그램 예약 전용 제외)
      final result = <Map<String, dynamic>>[];
      
      print('=== 타석 예약용 기간권 필터링 시작 ===');
      
      for (final detail in contractDetails) {
        final contractId = detail['contract_id']?.toString();
        final programAvailability = detail['program_reservation_availability']?.toString() ?? '';
        
        // 프로그램 예약 전용인지 확인
        final isValidForTsReservation = programAvailability.isEmpty || 
                                       programAvailability.toLowerCase() == 'null';
        
        print('계약 ID: $contractId → program_availability: "$programAvailability" → 타석예약가능: $isValidForTsReservation');
        
        if (!isValidForTsReservation) {
          print('필터링으로 제외된 기간권: $contractId (프로그램 예약 전용)');
          continue;
        }
        
        // contract_history_id 찾기
        String? matchingHistoryId;
        for (final entry in historyToContractMap.entries) {
          if (entry.value == contractId) {
            matchingHistoryId = entry.key;
            break;
          }
        }
        
        if (matchingHistoryId != null && contractInfo.containsKey(matchingHistoryId)) {
          result.add({
            ...detail,
            'contract_history_id': matchingHistoryId,
            'expiry_date': contractInfo[matchingHistoryId]!['expiry_date'],
          });
        }
      }
      
      print('=== 타석 예약용 기간권 필터링 완료 ===');
      
      // 6. 홀드된 기간권 필터링 (예약 날짜가 제공된 경우)
      if (reservationDate != null && result.isNotEmpty) {
        final filteredResult = await _filterHoldPeriodPasses(
          branchId: branchId,
          periodPasses: result,
          reservationDate: reservationDate,
        );
        print('홀드 필터링 후 기간권 정보 수: ${filteredResult.length}');
        return filteredResult;
      }
      
      print('최종 반환할 기간권 정보 수: ${result.length}');
      return result;
      
    } catch (e) {
      print('기간권 정보 조회 실패: $e');
      return [];
    }
  }

  /// 홀드된 기간권 필터링
  static Future<List<Map<String, dynamic>>> _filterHoldPeriodPasses({
    required String branchId,
    required List<Map<String, dynamic>> periodPasses,
    required String reservationDate,
  }) async {
    try {
      print('=== 홀드된 기간권 필터링 시작 ===');
      print('예약 날짜: $reservationDate');
      
      if (periodPasses.isEmpty) {
        return periodPasses;
      }
      
      // contract_history_id 목록 추출
      final contractHistoryIds = periodPasses
          .map((pass) => pass['contract_history_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .toList();
      
      if (contractHistoryIds.isEmpty) {
        print('contract_history_id가 없는 기간권들');
        return periodPasses;
      }
      
      print('홀드 체크할 contract_history_id: $contractHistoryIds');
      
      // v2_bill_term_hold에서 해당 예약 날짜에 홀드된 기간권 조회
      final holdRecords = await ApiService.getData(
        table: 'v2_bill_term_hold',
        fields: ['contract_history_id', 'term_hold_start', 'term_hold_end', 'term_hold_reason'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'contract_history_id', 'operator': 'IN', 'value': contractHistoryIds},
          {'field': 'term_hold_start', 'operator': '<=', 'value': reservationDate},
          {'field': 'term_hold_end', 'operator': '>=', 'value': reservationDate},
        ],
      );
      
      print('조회된 홀드 레코드 수: ${holdRecords.length}');
      
      if (holdRecords.isEmpty) {
        print('홀드된 기간권 없음 - 모든 기간권 사용 가능');
        return periodPasses;
      }
      
      // 홀드된 contract_history_id 세트 생성
      final holdContractHistoryIds = holdRecords
          .map((record) => record['contract_history_id']?.toString())
          .where((id) => id != null)
          .toSet();
      
      print('홀드된 contract_history_id: $holdContractHistoryIds');
      
      // 홀드 정보 출력
      for (final record in holdRecords) {
        print('홀드된 기간권: contract_history_id=${record['contract_history_id']}, '
              '홀드기간=${record['term_hold_start']}~${record['term_hold_end']}, '
              '사유=${record['term_hold_reason']}');
      }
      
      // 홀드되지 않은 기간권만 필터링
      final filteredPasses = periodPasses.where((pass) {
        final contractHistoryId = pass['contract_history_id']?.toString();
        final isHold = holdContractHistoryIds.contains(contractHistoryId);
        
        if (isHold) {
          print('홀드로 인해 제외된 기간권: ${pass['contract_name']} (contract_history_id: $contractHistoryId)');
        }
        
        return !isHold;
      }).toList();
      
      print('홀드 필터링 완료: ${periodPasses.length}개 → ${filteredPasses.length}개');
      return filteredPasses;
      
    } catch (e) {
      print('홀드된 기간권 필터링 실패: $e');
      // 실패 시 원본 목록 반환
      return periodPasses;
    }
  }

  /// 개별 기간권과 예약 조건 매칭 및 사용 가능 분수 계산
  static int _calculatePeriodPassMatch({
    required Map<String, dynamic> periodPass,
    required int selectedDuration,
    required String selectedStartTime,
    required String selectedTs,
    required String dayOfWeek,
    required bool isHolidayDate,
  }) {
    try {
      final contractName = periodPass['contract_name']?.toString() ?? '';
      final availableDays = periodPass['available_days']?.toString() ?? '';
      final availableStartTime = periodPass['available_start_time']?.toString();
      final availableEndTime = periodPass['available_end_time']?.toString();
      final availableTsId = periodPass['available_ts_id']?.toString() ?? '';
      
      print('--- 기간권 매칭 확인: $contractName ---');
      print('이용 가능 요일: $availableDays');
      print('이용 가능 시간: $availableStartTime ~ $availableEndTime');
      print('이용 가능 타석: $availableTsId');
      
      // 1. 요일 매칭 확인
      bool dayMatches = false;
      
      if (availableDays == '전체') {
        print('전체 요일 이용 가능');
        dayMatches = true;
      } else {
        // availableDays를 리스트로 변환
        final availableDaysList = availableDays.split(',').map((e) => e.trim()).toList();
        
        // 공휴일인 경우 '공휴일'이 포함되어 있는지 확인
        if (isHolidayDate && availableDaysList.contains('공휴일')) {
          print('공휴일 매칭됨');
          dayMatches = true;
        }
        // 공휴일이 아닌 경우 해당 요일이 포함되어 있는지 확인
        else if (!isHolidayDate && availableDaysList.contains(dayOfWeek)) {
          print('요일 매칭됨: $dayOfWeek');
          dayMatches = true;
        }
      }
      
      if (!dayMatches) {
        if (isHolidayDate) {
          print('요일이 매칭되지 않음: 공휴일이지만 이용 가능 요일에 "공휴일"이 포함되지 않음');
          print('  → 오늘: $dayOfWeek(공휴일), 이용 가능: $availableDays');
        } else {
          print('요일이 매칭되지 않음: $dayOfWeek요일은 이용 가능 요일에 포함되지 않음');
          print('  → 오늘: $dayOfWeek, 이용 가능: $availableDays');
        }
        return 0;
      }
      
      // 2. 타석 매칭 확인
      bool tsMatches = false;
      if (availableTsId.isEmpty || availableTsId == '전체') {
        print('전체 타석 이용 가능');
        tsMatches = true;
      } else {
        final availableTsList = availableTsId.split(',').map((e) => e.trim()).toList();
        if (availableTsList.contains(selectedTs)) {
          print('타석 매칭됨: $selectedTs');
          tsMatches = true;
        }
      }
      
      if (!tsMatches) {
        print('타석이 매칭되지 않음');
        return 0;
      }
      
      // 3. 시간 매칭 확인 및 사용 가능 분수 계산
      int usableMinutes = 0;
      
      if (availableStartTime == null || availableEndTime == null || 
          availableStartTime.isEmpty || availableEndTime.isEmpty ||
          availableStartTime == 'null' || availableEndTime == 'null') {
        // 시간 제한 없음
        print('시간 제한 없음 - 전체 시간 사용 가능');
        usableMinutes = selectedDuration;
      } else {
        // 시간 제한 있음 - 겹치는 시간 계산
        usableMinutes = _calculateTimeOverlap(
          selectedStartTime: selectedStartTime,
          selectedDuration: selectedDuration,
          availableStartTime: availableStartTime,
          availableEndTime: availableEndTime,
        );
        print('시간 제한 적용 - 사용 가능 분수: $usableMinutes분');
      }
      
      // 4. 최대 60분 제한
      usableMinutes = usableMinutes > 60 ? 60 : usableMinutes;
      
      print('기간권 매칭 결과: $usableMinutes분');
      return usableMinutes;
      
    } catch (e) {
      print('기간권 매칭 계산 오류: $e');
      return 0;
    }
  }

  /// 시간 겹침 계산
  static int _calculateTimeOverlap({
    required String selectedStartTime,
    required int selectedDuration,
    required String availableStartTime,
    required String availableEndTime,
  }) {
    try {
      print('--- 시간 겹침 계산 ---');
      print('선택 시작시간: $selectedStartTime');
      print('선택 시간(분): $selectedDuration');
      print('이용 가능 시간: $availableStartTime ~ $availableEndTime');
      
      // 시간을 분으로 변환하는 함수
      int timeToMinutes(String timeStr) {
        final parts = timeStr.split(':');
        return int.parse(parts[0]) * 60 + int.parse(parts[1]);
      }
      
      final selectedStartMin = timeToMinutes(selectedStartTime);
      final selectedEndMin = selectedStartMin + selectedDuration;
      final availableStartMin = timeToMinutes(availableStartTime.substring(0, 5));
      final availableEndMin = timeToMinutes(availableEndTime.substring(0, 5));
      
      print('선택 시간(분): $selectedStartMin ~ $selectedEndMin');
      print('이용 가능 시간(분): $availableStartMin ~ $availableEndMin');
      
      // 겹치는 구간 계산
      final overlapStart = selectedStartMin > availableStartMin ? selectedStartMin : availableStartMin;
      final overlapEnd = selectedEndMin < availableEndMin ? selectedEndMin : availableEndMin;
      
      if (overlapStart >= overlapEnd) {
        print('겹치는 시간 없음');
        return 0;
      }
      
      final overlapMinutes = overlapEnd - overlapStart;
      print('겹치는 시간: $overlapMinutes분');
      
      return overlapMinutes;
      
    } catch (e) {
      print('시간 겹침 계산 오류: $e');
      return 0;
    }
  }
}
