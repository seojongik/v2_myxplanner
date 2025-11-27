import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../services/api_service.dart';
import '../../../services/calendar_format_service.dart';

class TsCalendarLogic {
  int? _maxReservationDays;
  DateTime? _maxReservationDate;
  int _minUsageTime = 60;
  bool _isLoadingSettings = false;

  // 예약 설정 로드
  Future<void> loadReservationSettings() async {
    if (_isLoadingSettings) return;
    
    _isLoadingSettings = true;
    
    try {
      // 최대 예약 가능 일수 조회
      final maxDaysStr = await ApiService.getReservationSetting(
        fieldName: 'max_ts_reservation',
      );
      
      if (maxDaysStr != null) {
        _maxReservationDays = int.tryParse(maxDaysStr);
        if (_maxReservationDays != null) {
          _maxReservationDate = DateTime.now().add(Duration(days: _maxReservationDays!));
          print('최대 예약 가능 일수: $_maxReservationDays일');
          print('최대 예약 가능 날짜: $_maxReservationDate');
        }
      }
      
      // 최소 이용 시간 조회
      try {
        _minUsageTime = await ApiService.getTsMinimumTime();
        print('최소 이용 시간: $_minUsageTime분');
      } catch (e) {
        print('최소 이용 시간 조회 실패: $e');
        _minUsageTime = 60;
      }
    } catch (e) {
      print('예약 설정 로드 실패: $e');
    } finally {
      _isLoadingSettings = false;
    }
  }

  // 타석 예약용 날짜 비활성화 확인
  bool isDateDisabled(DateTime day, Map<String, Map<String, dynamic>> scheduleData) {
    // 1. 과거 날짜는 비활성화
    if (day.isBefore(DateTime.now().subtract(Duration(days: 1)))) {
      return true;
    }
    
    // 2. 예약 가능 기간을 벗어나면 비활성화
    if (_maxReservationDate != null && day.isAfter(_maxReservationDate!)) {
      return true;
    }
    
    // 3. 스케줄 데이터가 있고 휴무일인 경우 비활성화
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    final schedule = scheduleData[dateStr];
    if (schedule != null && schedule['is_holiday'] == 'close') {
      return true;
    }
    
    // 4. 오늘 날짜인 경우 현재 시간 이후에 예약 가능한 시간이 있는지 확인
    final now = DateTime.now();
    if (day.year == now.year && day.month == now.month && day.day == now.day) {
      return _isTodayUnavailable(schedule);
    }
    
    return false;
  }

  // 오늘 날짜에 예약 가능한 시간이 있는지 확인
  bool _isTodayUnavailable(Map<String, dynamic>? schedule) {
    if (schedule == null) return true;
    
    final businessStart = schedule['business_start'];
    final businessEnd = schedule['business_end'];
    
    if (businessStart == null || businessEnd == null) return true;
    
    try {
      final startParts = businessStart.toString().split(':');
      final endParts = businessEnd.toString().split(':');
      
      final startHour = int.parse(startParts[0]);
      final startMinute = int.parse(startParts[1]);
      final endHour = int.parse(endParts[0]);
      final endMinute = int.parse(endParts[1]);
      
      final now = DateTime.now();
      final currentHour = now.hour;
      final currentMinute = now.minute;
      
      // 현재 시간을 5분 단위로 올림 처리
      int adjustedMinute = ((currentMinute / 5).ceil() * 5) % 60;
      int adjustedHour = currentHour;
      if (currentMinute > 55) {
        adjustedHour = (currentHour + 1) % 24;
        adjustedMinute = 0;
      }
      
      // 영업 종료 시간을 분으로 변환
      int endTotalMinutes = endHour * 60 + endMinute;
      if (endTotalMinutes == 0) endTotalMinutes = 1440;
      
      // 영업 시작 시간과 현재 시간 중 더 늦은 시간을 최소 시간으로 설정
      final businessStartMinutes = startHour * 60 + startMinute;
      final currentTimeMinutes = adjustedHour * 60 + adjustedMinute;
      
      int actualStartMinutes = businessStartMinutes;
      if (currentTimeMinutes > businessStartMinutes) {
        actualStartMinutes = currentTimeMinutes;
      }
      
      // 최대 시작 시간 계산 (영업 종료 - 최소 이용 시간)
      int maxStartMinutes = endTotalMinutes - _minUsageTime;
      
      // 실제 시작 가능한 시간이 최대 시작 시간보다 늦으면 예약 불가능
      if (actualStartMinutes > maxStartMinutes) {
        return true;
      }
      
      return false;
    } catch (e) {
      print('오늘 날짜 예약 가능 시간 확인 오류: $e');
      return true;
    }
  }

  // 날짜 선택 시 타석 정보 출력
  void onDateSelected(DateTime selectedDay, Map<String, Map<String, dynamic>> scheduleData) {
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDay);
    final scheduleInfo = scheduleData[dateKey] ?? {};
    
    print('\n=== 선택된 날짜의 타석 정보 ===');
    print('날짜: $dateKey');
    print('스케줄 정보: $scheduleInfo');
    print('최소 이용 시간: $_minUsageTime분');
    print('최대 예약 가능 일수: $_maxReservationDays일');
    print('================================\n');
  }

  // 타석 관련 데이터 반환
  Map<String, dynamic> getTsData() {
    return {
      'maxReservationDays': _maxReservationDays,
      'maxReservationDate': _maxReservationDate,
      'minUsageTime': _minUsageTime,
    };
  }

  // 로딩 상태 확인
  bool get isLoadingSettings => _isLoadingSettings;

  // 공통 캘린더 위젯 생성
  Widget buildCalendarWidget({
    required DateTime focusedDay,
    required DateTime? selectedDay,
    required Map<String, Map<String, dynamic>> scheduleData,
    required Function(DateTime, DateTime) onDaySelected,
    required Function(DateTime) onPageChanged,
    CalendarFormat? calendarFormat,
    Function(CalendarFormat)? onFormatChanged,
    Color? selectedColor,
    Color? chevronColor,
    bool isLoading = false,
    String loadingMessage = '영업일정을 불러오는 중...',
  }) {
    final config = CalendarFormatService.getCommonCalendarConfig();
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 로딩 표시
          if (isLoading)
            CalendarFormatService.buildLoadingIndicator(loadingMessage),
          
          // 캘린더 (기본 동작 유지)
          TableCalendar<String>(
            firstDay: config['firstDay'],
            lastDay: config['lastDay'],
            focusedDay: focusedDay,
            calendarFormat: calendarFormat ?? config['calendarFormat'],
            availableCalendarFormats: config['availableCalendarFormats'],
            rowHeight: config['rowHeight'],
            daysOfWeekHeight: config['daysOfWeekHeight'],
            selectedDayPredicate: (day) => isSameDay(selectedDay, day),
            enabledDayPredicate: (day) => !isDateDisabled(day, scheduleData),
            onDaySelected: onDaySelected,
            onFormatChanged: onFormatChanged,
            onPageChanged: onPageChanged,
            calendarStyle: CalendarFormatService.getCalendarStyle(selectedColor: selectedColor),
            calendarBuilders: CalendarFormatService.getCalendarBuilders(scheduleData),
            headerStyle: CalendarFormatService.getHeaderStyle(chevronColor: chevronColor),
            daysOfWeekStyle: CalendarFormatService.getDaysOfWeekStyle(),
            locale: config['locale'],
          ),
        ],
      ),
    );
  }
} 