import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../services/calendar_format_service.dart';
import '../ls_reservation/ls_calendar_logic.dart';
import '../ts_reservation/ts_calendar_logic.dart';

class SpStep1SelectDate extends StatefulWidget {
  final Function(DateTime) onDateSelected;
  final Map<String, dynamic> specialSettings;
  final bool hasValidMemberships;
  final String? membershipErrorMessage;
  final Map<String, dynamic>? selectedMember;

  const SpStep1SelectDate({
    Key? key,
    required this.onDateSelected,
    required this.specialSettings,
    this.hasValidMemberships = true,
    this.membershipErrorMessage,
    this.selectedMember,
  }) : super(key: key);

  @override
  State<SpStep1SelectDate> createState() => _SpStep1SelectDateState();
}

class _SpStep1SelectDateState extends State<SpStep1SelectDate> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, Map<String, dynamic>> _scheduleData = {};
  bool _isLoading = true;
  
  // 달력 로직 인스턴스
  LsCalendarLogic? _lsCalendarLogic;
  TsCalendarLogic? _tsCalendarLogic;
  
  // 사용할 달력 로직 타입
  bool _isLessonReservation = false;
  
  // 회원권 검증을 위한 데이터
  Map<String, dynamic>? _lessonCountingData;
  Map<String, Map<String, dynamic>> _proInfoMap = {};
  Map<String, Map<String, Map<String, dynamic>>> _proScheduleMap = {};
  List<Map<String, dynamic>> _timePassContracts = [];

  @override
  void initState() {
    super.initState();
    _initializeCalendarLogic();
    _loadScheduleData();
  }

  void _initializeCalendarLogic() {
    // ls_min 값에 따라 달력 로직 결정
    print('전체 특수 설정값들:');
    widget.specialSettings.forEach((key, value) {
      print('  $key = $value');
    });
    
    // ls_min(숫자) 형태의 키들을 찾아서 모두 합계 계산
    int totalLsMin = 0;
    
    widget.specialSettings.forEach((key, value) {
      if (key.startsWith('ls_min(')) {
        // 안전한 int 변환
        int minValue = 0;
        if (value != null && value.toString().isNotEmpty) {
          minValue = int.tryParse(value.toString()) ?? 0;
        }
        print('$key 값: $minValue');
        totalLsMin += minValue;
      }
    });
    
    print('총 레슨 시간(ls_min 합계): $totalLsMin분');
    
    if (totalLsMin > 1) {
      _isLessonReservation = true;
      _lsCalendarLogic = LsCalendarLogic();
      print('레슨 예약 달력 로직 사용 (총 레슨 시간: $totalLsMin분)');
    } else {
      _isLessonReservation = false;
      _tsCalendarLogic = TsCalendarLogic();
      print('타석 예약 달력 로직 사용 (총 레슨 시간: $totalLsMin분)');
    }
  }

  Future<void> _loadScheduleData() async {
    print('🔥🔥🔥 _loadScheduleData() 시작! 🔥🔥🔥');
    print('   _isLessonReservation: $_isLessonReservation');
    print('   _lsCalendarLogic: ${_lsCalendarLogic != null ? "존재" : "NULL"}');
    print('   _tsCalendarLogic: ${_tsCalendarLogic != null ? "존재" : "NULL"}');

    try {
      setState(() {
        _isLoading = true;
      });

      // 선택된 달력 로직에 따라 설정 로드
      if (_isLessonReservation && _lsCalendarLogic != null) {
        print('   ✅ 레슨 예약 분기로 진입');
        await _lsCalendarLogic!.loadLessonCountingData();
        // 회원권 검증을 위한 데이터 로드
        await _loadLessonCountingData();
        await _loadTimePassContracts();
      } else if (_tsCalendarLogic != null) {
        await _tsCalendarLogic!.loadReservationSettings();
        // 타석 예약도 시간권 검증 필요
        await _loadTimePassContracts();
      }

      // 스케줄 데이터 로드 (현재 월의 스케줄 데이터 로드)
      final now = DateTime.now();
      final schedules = await ApiService.getTsSchedule(year: now.year, month: now.month);
      
      final Map<String, Map<String, dynamic>> scheduleMap = {};
      for (final schedule in schedules) {
        final dateStr = schedule['ts_date']?.toString();
        if (dateStr != null) {
          scheduleMap[dateStr] = schedule;
        }
      }
      
      setState(() {
        _scheduleData = scheduleMap;
        _isLoading = false;
      });
    } catch (e) {
      print('💥💥💥 스케줄 데이터 로드 실패: $e 💥💥💥');
      print('   스택 트레이스: ${StackTrace.current}');
      setState(() {
        _isLoading = false;
      });
    }
    print('🔥🔥🔥 _loadScheduleData() 종료! 🔥🔥🔥');
  }

  // 회원권 검증을 위한 레슨 카운팅 데이터 로드
  Future<void> _loadLessonCountingData() async {
    print('🟢🟢🟢 _loadLessonCountingData() 호출됨! 🟢🟢🟢');
    try {
      // widget.selectedMember 우선, 없으면 getCurrentUser()
      final memberInfo = widget.selectedMember ?? ApiService.getCurrentUser();
      print('   memberInfo 출처: ${widget.selectedMember != null ? "widget.selectedMember" : "getCurrentUser()"}');
      print('   memberInfo: ${memberInfo != null ? "존재" : "NULL"}');
      if (memberInfo != null && memberInfo['member_id'] != null) {
        final memberId = memberInfo['member_id'].toString();
        print('   memberId: $memberId');
        print('   API 호출 시작: getMemberLsCountingDataForProgram');
        final result = await ApiService.getMemberLsCountingDataForProgram(memberId: memberId);
        print('   API 호출 완료: success=${result["success"]}, debug_info=${result["debug_info"] != null ? "존재" : "NULL"}');
        
        if (result['success'] == true && result['debug_info'] != null) {
          final debugInfo = result['debug_info'] as Map<String, dynamic>;
          final proInfo = debugInfo['pro_info'] as Map<String, dynamic>?;
          final proSchedule = debugInfo['pro_schedule'] as Map<String, dynamic>?;

          print('📅 프로그램 달력: debug_info 확인');
          print('   proInfo ${proInfo != null ? "존재 (${proInfo.length}명)" : "NULL"}');
          print('   proSchedule ${proSchedule != null ? "존재 (${proSchedule.length}명)" : "NULL"}');

          if (proInfo != null) {
            _proInfoMap = proInfo.map((key, value) =>
              MapEntry(key, value as Map<String, dynamic>));
            print('   ✅ _proInfoMap 저장 완료: ${_proInfoMap.length}명');
          }

          if (proSchedule != null) {
            _proScheduleMap = proSchedule.map((proId, scheduleData) =>
              MapEntry(proId, (scheduleData as Map<String, dynamic>).map((date, data) =>
                MapEntry(date, data as Map<String, dynamic>))));
            print('   ✅ _proScheduleMap 저장 완료: ${_proScheduleMap.length}명');

            // 각 프로별 스케줄 날짜 수 출력
            _proScheduleMap.forEach((proId, schedules) {
              print('      프로 $proId: ${schedules.length}개 날짜 스케줄');
              if (schedules.isNotEmpty) {
                final firstDate = schedules.keys.first;
                final firstSchedule = schedules[firstDate];
                print('         예시: $firstDate - ${firstSchedule?['is_day_off']}');
              }
            });
          } else {
            print('   ❌ proSchedule이 NULL이어서 _proScheduleMap이 비어있음!');
          }

          _lessonCountingData = result;
        } else {
          print('❌ 프로그램 달력: API 결과가 성공이 아니거나 debug_info가 없음');
        }
      } else {
        print('❌ currentUser 또는 member_id가 없음');
      }
    } catch (e) {
      print('💥💥💥 레슨 카운팅 데이터 로드 실패: $e 💥💥💥');
      print('   스택 트레이스: ${StackTrace.current}');
    }
    print('🟢🟢🟢 _loadLessonCountingData() 종료! 🟢🟢🟢');
  }

  // 시간권 계약 데이터 로드
  Future<void> _loadTimePassContracts() async {
    try {
      // widget.selectedMember 우선, 없으면 getCurrentUser()
      final memberInfo = widget.selectedMember ?? ApiService.getCurrentUser();
      if (memberInfo != null && memberInfo['member_id'] != null) {
        final memberId = memberInfo['member_id'].toString();
        final contracts = await ApiService.getMemberTimePassesByContractForProgram(memberId: memberId);
        
        setState(() {
          _timePassContracts = contracts;
        });
        
        print('달력 검증용 시간권 계약 로드 완료: ${contracts.length}개');
      }
    } catch (e) {
      print('시간권 계약 데이터 로드 실패: $e');
      setState(() {
        _timePassContracts = [];
      });
    }
  }

  bool _isDateDisabled(DateTime day) {
    // 회원권이 유효하지 않으면 모든 날짜 비활성화
    if (!widget.hasValidMemberships) {
      return true;
    }

    if (_isLessonReservation && _lsCalendarLogic != null) {
      // 기본 날짜 비활성화 체크 (과거 날짜, 휴무일)
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      final dayOnly = DateTime(day.year, day.month, day.day);
      
      if (dayOnly.isBefore(todayOnly)) {
        return true;
      }
      
      final dateStr = DateFormat('yyyy-MM-dd').format(day);
      final schedule = _scheduleData[dateStr];
      if (schedule != null && schedule['is_holiday'] == 'close') {
        return true;
      }
      
      // 회원권 검증을 포함한 프로별 검증
      if (_proInfoMap.isNotEmpty && _lessonCountingData != null) {
        bool hasAvailablePro = false;
        
        // 유효한 레슨 계약이 있는 프로들만 확인
        if (_lessonCountingData!['success'] == true && _lessonCountingData!['data'] != null) {
          final validRecords = _lessonCountingData!['data'] as List<dynamic>;
          final validProIds = validRecords.map((record) => record['pro_id']?.toString()).toSet();
          
          for (final proId in validProIds) {
            if (proId == null) continue;
            
            final proInfo = _proInfoMap[proId];
            if (proInfo != null) {
              // 프로별 예약 가능일수 체크
              final reservationAheadDays = int.tryParse(proInfo['reservation_ahead_days']?.toString() ?? '0') ?? 0;
              final maxAllowedDateForPro = todayOnly.add(Duration(days: reservationAheadDays));
              
              if (dayOnly.isAfter(maxAllowedDateForPro)) {
                continue;
              }
              
              // 프로 스케줄 체크
              final proSchedule = _proScheduleMap[proId];
              print('🔍 날짜 $dateStr 체크: proId=$proId, proSchedule=${proSchedule != null ? "존재" : "NULL"}');

              if (proSchedule != null) {
                final daySchedule = proSchedule[dateStr];
                print('   daySchedule=${daySchedule != null ? "존재" : "NULL"}');

                if (daySchedule == null) {
                  print('   ✅ daySchedule이 NULL이어서 활성화됨 (기본 근무 가능)');
                  hasAvailablePro = true;
                  break;
                }

                final isDayOff = daySchedule['is_day_off']?.toString();
                print('   is_day_off="$isDayOff"');
                if (isDayOff != '휴무') {
                  print('   ✅ 휴무 아니어서 활성화됨');
                  hasAvailablePro = true;
                  break;
                } else {
                  print('   ❌ 휴무일이어서 다음 프로 체크');
                }
              } else {
                print('   ⚠️ proSchedule이 NULL이어서 활성화됨!');
                hasAvailablePro = true;
                break;
              }
            }
          }
        }
        
        // 시간권 계약 검증 추가
        if (hasAvailablePro) {
          hasAvailablePro = _hasValidTimePassForDate(dayOnly);
        }
        
        if (!hasAvailablePro) {
          return true;
        }
      }
      
      return false;
    } else if (_tsCalendarLogic != null) {
      return _tsCalendarLogic!.isDateDisabled(day, _scheduleData);
    }
    return true;
  }

  // 특정 날짜에 사용 가능한 회원권 세트가 있는지 검증 (프로그램 = 세트 개념)
  bool _hasValidTimePassForDate(DateTime date) {
    if (_timePassContracts.isEmpty) {
      print('프로그램 달력: 시간권 계약이 없음');
      return false;
    }

    // 필요한 시간 계산
    int totalTsMin = int.tryParse(widget.specialSettings['ts_min']?.toString() ?? '0') ?? 0;
    int totalLsMin = 0;
    
    widget.specialSettings.forEach((key, value) {
      if (key.startsWith('ls_min(')) {
        int minValue = int.tryParse(value?.toString() ?? '0') ?? 0;
        totalLsMin += minValue;
      }
    });
    
    print('프로그램 달력 검증: 날짜 ${DateFormat('yyyy-MM-dd').format(date)}');
    print('필요한 시간 - 타석: ${totalTsMin}분, 레슨: ${totalLsMin}분');
    
    if (totalTsMin <= 0) {
      return true; // 타석 시간 요구사항이 없으면 통과
    }

    // 레슨이 없는 프로그램 (타석만)
    if (totalLsMin == 0) {
      return _hasValidTimePassOnly(date, totalTsMin);
    }
    
    // 레슨이 있는 프로그램 (타석 + 레슨 세트)
    return _hasValidProgramSet(date, totalTsMin, totalLsMin);
  }

  // 타석만 있는 프로그램 검증
  bool _hasValidTimePassOnly(DateTime date, int neededTsMin) {
    for (final contract in _timePassContracts) {
      final balance = int.tryParse(contract['balance']?.toString() ?? '0') ?? 0;
      final expiryDateStr = contract['expiry_date']?.toString();
      
      // 잔액 검증
      if (balance < neededTsMin) {
        continue;
      }
      
      // 만료일 검증
      if (expiryDateStr != null && expiryDateStr.isNotEmpty && expiryDateStr != 'null') {
        try {
          final expiryDate = DateTime.parse(expiryDateStr);
          if (date.isAfter(expiryDate)) {
            continue;
          }
        } catch (e) {
          continue;
        }
      }
      
      // program_reservation_availability 검증 추가
      final programAvailability = contract['program_reservation_availability']?.toString() ?? '';
      if (programAvailability.isNotEmpty) {
        // 특정 프로그램 전용 계약인 경우, 현재 프로그램 ID와 매칭되는지 확인
        final currentProgramId = widget.specialSettings['program_id']?.toString() ?? '';
        final availablePrograms = programAvailability.split(',').map((e) => e.trim()).toList();
        
        if (currentProgramId.isNotEmpty && !availablePrograms.contains(currentProgramId)) {
          print('프로그램 달력: 계약 ${contract['contract_history_id']} 다른 프로그램 전용으로 제외 (현재: $currentProgramId, 허용: $programAvailability)');
          continue;
        }
      }
      
      print('프로그램 달력: 타석전용 계약 발견 - 잔액: ${balance}분');
      return true;
    }
    
    print('프로그램 달력: 사용 가능한 타석전용 계약이 없음');
    return false;
  }

  // 타석 + 레슨 세트 프로그램 검증
  bool _hasValidProgramSet(DateTime date, int neededTsMin, int neededLsMin) {
    // 레슨 데이터가 없으면 프로그램 세트 불가능
    if (_lessonCountingData == null || _lessonCountingData!['data'] == null) {
      print('프로그램 달력: 레슨 데이터가 없어서 프로그램 세트 불가능');
      return false;
    }

    final validLessonRecords = _lessonCountingData!['data'] as List<dynamic>;
    
    // 선택된 날짜에 유효한 레슨 계약 필터링
    final validLessonsForDate = validLessonRecords.where((record) {
      final expiryDateStr = record['LS_expiry_date']?.toString();
      if (expiryDateStr == null || expiryDateStr.isEmpty) return true;
      
      try {
        final expiryDate = DateTime.parse(expiryDateStr);
        return !date.isAfter(expiryDate);
      } catch (e) {
        return false;
      }
    }).toList();

    if (validLessonsForDate.isEmpty) {
      print('프로그램 달력: 선택된 날짜에 유효한 레슨 계약이 없음');
      return false;
    }

    // 시간권과 레슨권 매칭 검증
    for (final timeContract in _timePassContracts) {
      final timeBalance = int.tryParse(timeContract['balance']?.toString() ?? '0') ?? 0;
      final timeExpiryStr = timeContract['expiry_date']?.toString();
      final timeHistoryId = timeContract['contract_history_id']?.toString();
      
      // 시간권 잔액 및 만료일 검증
      if (timeBalance < neededTsMin) continue;
      
      if (timeExpiryStr != null && timeExpiryStr.isNotEmpty && timeExpiryStr != 'null') {
        try {
          final timeExpiry = DateTime.parse(timeExpiryStr);
          if (date.isAfter(timeExpiry)) continue;
        } catch (e) {
          continue;
        }
      }
      
      // program_reservation_availability 검증 추가
      final programAvailability = timeContract['program_reservation_availability']?.toString() ?? '';
      if (programAvailability.isNotEmpty) {
        // 특정 프로그램 전용 계약인 경우, 현재 프로그램 ID와 매칭되는지 확인
        final currentProgramId = widget.specialSettings['program_id']?.toString() ?? '';
        final availablePrograms = programAvailability.split(',').map((e) => e.trim()).toList();
        
        if (currentProgramId.isNotEmpty && !availablePrograms.contains(currentProgramId)) {
          print('프로그램 달력: 시간권 계약 ${timeContract['contract_history_id']} 다른 프로그램 전용으로 제외 (현재: $currentProgramId, 허용: $programAvailability)');
          continue;
        }
      }
      
      // 같은 contract_history_id를 가진 레슨 계약 찾기
      Map<String, dynamic>? matchingLesson;
      try {
        matchingLesson = validLessonsForDate.firstWhere(
          (lesson) => lesson['contract_history_id']?.toString() == timeHistoryId,
        );
      } catch (e) {
        matchingLesson = null;
      }
      
      if (matchingLesson != null) {
        final lessonBalance = int.tryParse(matchingLesson['LS_balance_min_after']?.toString() ?? '0') ?? 0;
        
        if (lessonBalance >= neededLsMin) {
          print('프로그램 달력: 프로그램 세트 계약 발견 - 시간권: ${timeBalance}분, 레슨권: ${lessonBalance}분');
          return true;
        }
      }
    }
    
    print('프로그램 달력: 프로그램 세트 조건을 만족하는 계약이 없음');
    return false;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (_isDateDisabled(selectedDay)) {
      return;
    }

    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });

    // 선택된 달력 로직에 따라 날짜 선택 처리
    if (_isLessonReservation && _lsCalendarLogic != null) {
      _lsCalendarLogic!.onDateSelected(selectedDay, _scheduleData);
    } else if (_tsCalendarLogic != null) {
      _tsCalendarLogic!.onDateSelected(selectedDay, _scheduleData);
    }

    widget.onDateSelected(selectedDay);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return CalendarFormatService.buildLoadingIndicator('스케줄 데이터를 불러오는 중...');
    }

    final config = CalendarFormatService.getCommonCalendarConfig();
    final selectedColor = _isLessonReservation ? Colors.blue[600] : Colors.green[600];
    final chevronColor = _isLessonReservation ? Colors.blue[600] : Colors.green[600];

    return Container(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 회원권 오류 메시지 표시
          if (!widget.hasValidMemberships) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[200]!, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red[600],
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.membershipErrorMessage ?? '사용 가능한 회원권이 없습니다.',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // 달력
          TableCalendar<String>(
              firstDay: config['firstDay'],
              lastDay: config['lastDay'],
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: _onDaySelected,
              calendarFormat: config['calendarFormat'],
              availableCalendarFormats: config['availableCalendarFormats'],
              startingDayOfWeek: config['startingDayOfWeek'],
              rowHeight: config['rowHeight'],
              daysOfWeekHeight: config['daysOfWeekHeight'],
              enabledDayPredicate: (day) {
                return !_isDateDisabled(day);
              },
              headerStyle: CalendarFormatService.getHeaderStyle(chevronColor: chevronColor),
              calendarStyle: CalendarFormatService.getCalendarStyle(selectedColor: selectedColor),
              daysOfWeekStyle: CalendarFormatService.getDaysOfWeekStyle(),
              calendarBuilders: CalendarFormatService.getCalendarBuilders(_scheduleData),
              locale: config['locale'],
            ),
        ],
      ),
    );
  }
} 