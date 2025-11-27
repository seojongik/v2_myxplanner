import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../services/calendar_format_service.dart';

class LsStep1SelectDate extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;
  final Function(DateTime, Map<String, dynamic>) onDateSelected;
  final DateTime? selectedDate;

  const LsStep1SelectDate({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
    required this.onDateSelected,
    this.selectedDate,
  }) : super(key: key);

  @override
  _LsStep1SelectDateState createState() => _LsStep1SelectDateState();
}

class _LsStep1SelectDateState extends State<LsStep1SelectDate> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<String, Map<String, dynamic>> _scheduleData = {}; // 영업시간 데이터
  bool _isLoadingSchedule = false;
  
  // 레슨 카운팅 데이터 및 프로 정보
  Map<String, dynamic>? _lessonCountingData;
  Map<String, Map<String, dynamic>> _proInfoMap = {};
  Map<String, Map<String, Map<String, dynamic>>> _proScheduleMap = {}; // 프로별 스케줄 데이터
  int _maxReservationAheadDays = 0; // 최대 예약 가능 일수
  bool _isLoadingLessonData = false;

  // max_ls_per_day 체크용 데이터
  Map<String, dynamic> _contractDetailsMap = {}; // contract_history_id -> {max_ls_per_day, ...}
  Map<String, Map<String, int>> _dailyUsageCache = {}; // 날짜(yyyy-MM-dd) -> {contract_history_id -> 사용량}

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.selectedDate;
    _focusedDay = widget.selectedDate ?? DateTime.now();  // selectedDate가 있으면 해당 날짜로 초기화
    _loadScheduleForMonth(_focusedDay);
    
    // 레슨 카운팅 데이터 및 프로 정보 로드
    _loadLessonCountingData();
  }

  @override
  void didUpdateWidget(LsStep1SelectDate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      setState(() {
        _selectedDay = widget.selectedDate;
        _focusedDay = widget.selectedDate ?? _focusedDay;  // selectedDate가 있으면 해당 날짜로 업데이트
      });
    }
  }

  // 레슨 카운팅 데이터 및 프로 정보 로드
  Future<void> _loadLessonCountingData() async {
    print('\n🔵🔵🔵 _loadLessonCountingData 시작 🔵🔵🔵');

    if (_isLoadingLessonData) {
      print('⚠️ 이미 로딩 중이므로 종료');
      return;
    }

    setState(() {
      _isLoadingLessonData = true;
    });

    try {
      // 회원 정보 가져오기 (props 우선, 없으면 getCurrentUser)
      final memberInfo = widget.selectedMember ?? ApiService.getCurrentUser();
      print('📱 회원 정보 출처: ${widget.selectedMember != null ? "props (selectedMember)" : "getCurrentUser()"}');
      print('📱 회원 정보: $memberInfo');

      if (memberInfo != null && memberInfo['member_id'] != null) {
        final memberId = memberInfo['member_id'].toString();
        print('✅ 회원 ID: $memberId');
        print('✅ 회원 이름: ${memberInfo['member_name']}');
        print('🌐 API 호출 시작: getMemberLsCountingData');

        final result = await ApiService.getMemberLsCountingData(memberId: memberId);

        print('📊 API 응답:');
        print('  - success: ${result['success']}');
        print('  - data 존재: ${result['data'] != null}');
        print('  - data 개수: ${result['data']?.length ?? 0}');
        print('  - debug_info 존재: ${result['debug_info'] != null}');

        if (result['success'] == true && result['debug_info'] != null) {
          final debugInfo = result['debug_info'] as Map<String, dynamic>;
          final proInfo = debugInfo['pro_info'] as Map<String, dynamic>?;
          final proSchedule = debugInfo['pro_schedule'] as Map<String, dynamic>?;
          final maxReservationAheadDays = debugInfo['max_reservation_ahead_days'] as int? ?? 0;

          print('📋 debug_info 내용:');
          print('  - pro_info 존재: ${proInfo != null}, 프로 수: ${proInfo?.length ?? 0}');
          print('  - pro_schedule 존재: ${proSchedule != null}, 프로 수: ${proSchedule?.length ?? 0}');
          print('  - max_reservation_ahead_days: $maxReservationAheadDays');

          if (proInfo != null) {
            print('🎯 프로 정보 저장 시작:');
            proInfo.forEach((key, value) {
              print('  - 프로 ID: $key, 이름: ${(value as Map)['pro_name']}');
            });

            // 프로 정보 저장
            _proInfoMap = proInfo.map((key, value) =>
              MapEntry(key, value as Map<String, dynamic>));

            // 최대 예약 가능 일수 저장
            _maxReservationAheadDays = maxReservationAheadDays;

            print('✅ 프로 정보 저장 완료: ${_proInfoMap.length}명');
          } else {
            print('❌ proInfo가 null입니다');
          }

          if (proSchedule != null) {
            print('📅 프로 스케줄 저장 시작:');
            // 프로 스케줄 정보 저장
            _proScheduleMap = proSchedule.map((proId, scheduleData) =>
              MapEntry(proId, (scheduleData as Map<String, dynamic>).map((date, data) =>
                MapEntry(date, data as Map<String, dynamic>))));

            print('✅ 프로 스케줄 저장 완료: ${_proScheduleMap.length}명');
          } else {
            print('❌ proSchedule이 null입니다');
          }

          _lessonCountingData = result;
          print('✅ lessonCountingData 저장 완료');

          // 계약 상세 정보 로드 (max_ls_per_day 체크용)
          await _loadContractDetails();

          // 현재 달의 일별 사용량 로드
          await _loadMonthlyUsage();
        } else {
          print('❌ API 응답이 성공이 아니거나 debug_info가 없습니다');
          print('   result: $result');
        }
      } else {
        print('❌ 현재 사용자 정보가 없거나 member_id가 없습니다');
      }
    } catch (e) {
      print('💥 레슨 카운팅 데이터 로드 실패: $e');
      print('스택 트레이스: ${StackTrace.current}');
    } finally {
      setState(() {
        _isLoadingLessonData = false;
      });
      print('🔵🔵🔵 _loadLessonCountingData 종료 🔵🔵🔵\n');
    }
  }

  // 계약 상세 정보 로드 (max_ls_per_day 조회)
  Future<void> _loadContractDetails() async {
    if (_lessonCountingData == null || _lessonCountingData!['success'] != true) {
      return;
    }

    final validRecords = _lessonCountingData!['data'] as List<dynamic>?;
    if (validRecords == null || validRecords.isEmpty) {
      return;
    }

    // contract_history_id 목록 수집
    final contractHistoryIds = validRecords
        .map((record) => record['contract_history_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (contractHistoryIds.isEmpty) {
      return;
    }

    try {
      print('📋 계약 상세 정보 조회 중: $contractHistoryIds');
      final contractDetails = await ApiService.getContractDetails(
        contractHistoryIds: contractHistoryIds,
      );

      setState(() {
        _contractDetailsMap = contractDetails;
      });

      print('✅ 계약 상세 정보 로드 완료: ${contractDetails.length}건');
      contractDetails.forEach((contractHistoryId, details) {
        print('  - contract_history_id: $contractHistoryId, max_ls_per_day: ${details['max_ls_per_day']}');
      });
    } catch (e) {
      print('💥 계약 상세 정보 로드 실패: $e');
    }
  }

  // 현재 달의 일별 사용량 로드
  Future<void> _loadMonthlyUsage() async {
    final memberInfo = widget.selectedMember ?? ApiService.getCurrentUser();
    if (memberInfo == null || memberInfo['member_id'] == null) {
      return;
    }

    final memberId = memberInfo['member_id'].toString();

    // 현재 focusedDay 기준으로 해당 월의 모든 날짜에 대한 사용량 조회
    final year = _focusedDay.year;
    final month = _focusedDay.month;
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);

    try {
      print('📊 월별 사용량 조회 중: $year-$month');

      // 각 날짜별로 사용량 조회
      for (int day = firstDay.day; day <= lastDay.day; day++) {
        final date = DateTime(year, month, day);
        final dateStr = DateFormat('yyyy-MM-dd').format(date);

        final dailyUsage = await ApiService.getLessonDailyUsageByContract(
          memberId: memberId,
          lessonDate: dateStr,
        );

        if (dailyUsage.isNotEmpty) {
          _dailyUsageCache[dateStr] = dailyUsage;
        }
      }

      print('✅ 월별 사용량 로드 완료: ${_dailyUsageCache.length}일');
    } catch (e) {
      print('💥 월별 사용량 로드 실패: $e');
    }
  }

  // 영업시간 스케줄 로드 (타석 예약과 동일한 로직 사용)
  Future<void> _loadScheduleForMonth(DateTime month) async {
    if (_isLoadingSchedule) return;
    
    setState(() {
      _isLoadingSchedule = true;
    });

    try {
      final year = month.year;
      final monthNum = month.month;
      
      // 타석 예약과 동일한 영업시간 테이블 사용
      final schedules = await ApiService.getTsSchedule(year: year, month: monthNum);
      
      final Map<String, Map<String, dynamic>> scheduleMap = {};
      for (final schedule in schedules) {
        final dateStr = schedule['ts_date']?.toString();
        if (dateStr != null) {
          scheduleMap[dateStr] = schedule;
        }
      }
      
      setState(() {
        _scheduleData = scheduleMap;
        _isLoadingSchedule = false;
      });
    } catch (e) {
      print('영업시간 로드 실패: $e');
      setState(() {
        _isLoadingSchedule = false;
      });
    }
  }

  // 날짜가 비활성화되어야 하는지 확인
  bool _isDateDisabled(DateTime day) {
    // 1. 과거 날짜는 비활성화
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dayOnly = DateTime(day.year, day.month, day.day);

    if (dayOnly.isBefore(todayOnly)) {
      return true;
    }

    // 2. 영업시간 체크 (휴무일 비활성화)
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    final schedule = _scheduleData[dateStr];
    if (schedule != null && schedule['is_holiday'] == 'close') {
      return true;
    }

    // 3. 유효한 레슨 계약이 있는 프로만 체크
    if (_lessonCountingData == null || _lessonCountingData!['success'] != true) {
      // 계약 데이터가 없거나 로드 실패 시 비활성화
      return true;
    }

    final validRecords = _lessonCountingData!['data'] as List<dynamic>?;
    if (validRecords == null || validRecords.isEmpty) {
      // 유효한 계약이 없으면 비활성화
      return true;
    }

    // 유효한 계약이 있는 프로 ID 목록 추출
    final validProIds = validRecords
        .map((record) => record['pro_id']?.toString())
        .where((proId) => proId != null && proId.isNotEmpty)
        .toSet();

    if (validProIds.isEmpty) {
      // 유효한 프로가 없으면 비활성화
      return true;
    }

    // 4. 유효한 계약이 있는 프로 중 예약 가능한 프로가 있는지 체크
    bool hasAvailablePro = false;

    for (final proId in validProIds) {
      final proInfo = _proInfoMap[proId];
      if (proInfo == null) continue;

      // 4-1. 프로별 예약 가능 일수 체크
      final reservationAheadDays = int.tryParse(proInfo['reservation_ahead_days']?.toString() ?? '0') ?? 0;
      final maxAllowedDateForPro = todayOnly.add(Duration(days: reservationAheadDays));

      // 해당 프로의 예약 가능 일수를 초과하는 경우 이 프로는 예약 불가
      if (dayOnly.isAfter(maxAllowedDateForPro)) {
        continue; // 다음 프로 체크
      }

      // 4-2. max_ls_per_day 체크 (당일 사용 한도)
      // 해당 프로와의 계약 중 사용 가능한 계약이 있는지 체크
      bool hasAvailableContract = false;
      final proContracts = validRecords
          .where((record) => record['pro_id']?.toString() == proId)
          .toList();

      for (final contract in proContracts) {
        final contractHistoryId = contract['contract_history_id']?.toString();
        if (contractHistoryId == null || contractHistoryId.isEmpty) continue;

        // 계약 상세 정보에서 max_ls_per_day 가져오기
        final contractDetail = _contractDetailsMap[contractHistoryId];
        final maxLsPerDay = contractDetail?['max_ls_per_day'];

        // max_ls_per_day 제약이 없으면 사용 가능
        if (maxLsPerDay == null || maxLsPerDay == 'null' || maxLsPerDay == '') {
          hasAvailableContract = true;
          break;
        }

        // max_ls_per_day 제약이 있는 경우
        try {
          final maxDailyMinutes = int.tryParse(maxLsPerDay.toString());
          if (maxDailyMinutes == null || maxDailyMinutes <= 0) {
            // 파싱 실패하거나 0 이하면 사용 가능으로 간주
            hasAvailableContract = true;
            break;
          }

          // 당일 사용량 확인
          final dailyUsage = _dailyUsageCache[dateStr] ?? {};
          final usedToday = dailyUsage[contractHistoryId] ?? 0;
          final remainingToday = maxDailyMinutes - usedToday;

          // 조금이라도 남은 시간이 있으면 사용 가능
          if (remainingToday > 0) {
            hasAvailableContract = true;
            break;
          }
        } catch (e) {
          // 오류 발생 시 안전하게 사용 가능으로 간주
          hasAvailableContract = true;
          break;
        }
      }

      // 사용 가능한 계약이 없으면 이 프로는 예약 불가
      if (!hasAvailableContract) {
        continue; // 다음 프로 체크
      }

      // 4-3. 프로 스케줄 체크
      final proSchedule = _proScheduleMap[proId];

      // 프로 스케줄 데이터가 없으면 확인 불가 → 이 프로는 예약 불가
      if (proSchedule == null) {
        continue; // 다음 프로 체크
      }

      final daySchedule = proSchedule[dateStr];

      // 해당 날짜 스케줄이 없으면 확인 불가 → 이 프로는 예약 불가
      if (daySchedule == null) {
        continue; // 다음 프로 체크
      }

      // is_day_off가 '휴무'가 아니면 근무 가능
      final isDayOff = daySchedule['is_day_off']?.toString();
      if (isDayOff != '휴무') {
        hasAvailablePro = true;
        break;
      }
    }

    // 예약 가능한 프로가 없는 경우 비활성화
    if (!hasAvailablePro) {
      return true;
    }

    return false;
  }

  void onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      
      // 선택된 날짜가 비활성화되지 않은 경우에만 처리
      if (!_isDateDisabled(selectedDay)) {
        final dateKey = DateFormat('yyyy-MM-dd').format(selectedDay);
        final scheduleInfo = <String, dynamic>{};
        
        print('\n=== 선택된 날짜의 레슨 정보 ===');
        print('날짜: $dateKey');
        
        // 유효한 레슨 계약 정보 출력 및 데이터 전달 준비
        Map<String, dynamic> dataToPass = {
          'lessonCountingData': _lessonCountingData,
          'proInfoMap': _proInfoMap,
          'proScheduleMap': _proScheduleMap,
        };
        
        // 디버깅 정보 출력
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
        // 선택된 날짜의 프로별 근무시간 출력
        for (final proId in _proInfoMap.keys) {
          final proInfo = _proInfoMap[proId];
          final proSchedule = _proScheduleMap[proId];
          if (proInfo != null && proSchedule != null) {
            final daySchedule = proSchedule[dateKey];
            final proName = proInfo['pro_name']?.toString() ?? '프로 $proId';
            final reservationAheadDays = int.tryParse(proInfo['reservation_ahead_days']?.toString() ?? '0') ?? 0;
            
            // 선택된 날짜가 예약 가능 일수를 초과하는지 확인
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
        
        // 부모에게 선택된 날짜와 레슨 관련 데이터 전달
        widget.onDateSelected(selectedDay, dataToPass);
      }
    }
  }

  // 레슨 카운팅 데이터 조회 테스트
  Future<void> _testLsCountingData() async {
    try {
      // 현재 사용자 정보 가져오기
      final currentUser = ApiService.getCurrentUser();
      if (currentUser != null && currentUser['member_id'] != null) {
        final memberId = currentUser['member_id'].toString();
        print('=== 레슨 카운팅 데이터 조회 테스트 시작 ===');
        print('테스트 대상 회원 ID: $memberId');
        
        final result = await ApiService.getMemberLsCountingData(memberId: memberId);
        
        print('=== 레슨 카운팅 조회 결과 ===');
        print('성공 여부: ${result['success']}');
        print('데이터 개수: ${result['data']?.length ?? 0}');
        print('디버그 정보: ${result['debug_info']}');
        
        if (result['success'] == true && result['data'] != null) {
          final data = result['data'] as List;
          print('=== 상세 데이터 ===');
          for (int i = 0; i < data.length; i++) {
            final record = data[i];
            print('레코드 ${i + 1}:');
            print('  - LS_counting_id: ${record['LS_counting_id']}');
            print('  - LS_contract_id: ${record['LS_contract_id']}');
            print('  - LS_balance_min_after: ${record['LS_balance_min_after']}');
            print('  - pro_id: ${record['pro_id']}');
            print('  - LS_expiry_date: ${record['LS_expiry_date']}');
          }
          
          // 프로 정보 출력
          final debugInfo = result['debug_info'] as Map<String, dynamic>;
          if (debugInfo['pro_info'] != null) {
            final proInfo = debugInfo['pro_info'] as Map<String, dynamic>;
            print('=== 프로 정보 ===');
            proInfo.forEach((proId, info) {
              final proData = info as Map<String, dynamic>;
              print('프로 ID: $proId');
              print('  - 이름: ${proData['pro_name']}');
              print('  - 최소 서비스 시간: ${proData['min_service_min']}분');
              print('  - 서비스 시간 단위: ${proData['svc_time_unit']}분');
              print('  - 최소 예약 기간: ${proData['min_reservation_term']}일');
              print('  - 예약 가능 일수: ${proData['reservation_ahead_days']}일');
            });
          }
        }
        
        print('=== 레슨 카운팅 데이터 조회 테스트 완료 ===');
      } else {
        print('현재 사용자 정보가 없어 레슨 카운팅 테스트를 건너뜁니다.');
      }
    } catch (e) {
      print('레슨 카운팅 데이터 조회 테스트 실패: $e');
    }
  }

  // 날짜 변경 처리 메서드 추가
  void handleDateChange(DateTime newDate) {
    if (!_isDateDisabled(newDate)) {
      setState(() {
        _selectedDay = newDate;
        _focusedDay = newDate;  // focusedDay도 함께 업데이트
      });
      
      // 해당 월의 스케줄 로드
      _loadScheduleForMonth(newDate);
      
      onDaySelected(newDate, newDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = CalendarFormatService.getCommonCalendarConfig();
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 로딩 표시
          if (_isLoadingSchedule || _isLoadingLessonData)
            CalendarFormatService.buildLoadingIndicator(
              _isLoadingSchedule ? '영업일정을 불러오는 중...' : '레슨 정보를 불러오는 중...'
            ),
          
          // 캘린더
          TableCalendar<String>(
              firstDay: config['firstDay'],
              lastDay: config['lastDay'],
              focusedDay: _focusedDay,
              calendarFormat: config['calendarFormat'],
              availableCalendarFormats: config['availableCalendarFormats'],
              rowHeight: config['rowHeight'],
              daysOfWeekHeight: config['daysOfWeekHeight'],
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              enabledDayPredicate: (day) => !_isDateDisabled(day),
              onDaySelected: onDaySelected,
              onFormatChanged: (format) {
                if (_calendarFormat != format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                }
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                _loadScheduleForMonth(focusedDay); // 월 변경 시 스케줄 다시 로드
                _loadMonthlyUsage(); // 월 변경 시 사용량 캐시 다시 로드
              },
              calendarStyle: CalendarFormatService.getCalendarStyle(),
              calendarBuilders: CalendarFormatService.getCalendarBuilders(_scheduleData),
              headerStyle: CalendarFormatService.getHeaderStyle(),
              daysOfWeekStyle: CalendarFormatService.getDaysOfWeekStyle(),
              locale: config['locale'],
            ),
        ],
      ),
    );
  }
} 