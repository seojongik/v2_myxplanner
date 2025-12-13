import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../../services/api_service.dart';
import 'ts_calendar_logic.dart';

class Step1SelectDate extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;
  final Function(DateTime, Map<String, dynamic>)? onDateSelected;

  const Step1SelectDate({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
    this.onDateSelected,
  }) : super(key: key);

  @override
  _Step1SelectDateState createState() => _Step1SelectDateState();
}

class _Step1SelectDateState extends State<Step1SelectDate> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<String, Map<String, dynamic>> _scheduleData = {}; // 날짜별 스케줄 데이터
  bool _isLoadingSchedule = false;
  
  // 타석 캘린더 로직 인스턴스
  final TsCalendarLogic _calendarLogic = TsCalendarLogic();

  @override
  void initState() {
    super.initState();
    _loadReservationSettings();
  }

  // 예약 설정 로드
  Future<void> _loadReservationSettings() async {
    await _calendarLogic.loadReservationSettings();
    _loadScheduleForMonth(_focusedDay);
  }

  // 특정 월의 스케줄 데이터 로드
  Future<void> _loadScheduleForMonth(DateTime month) async {
    if (_isLoadingSchedule) return;
    
    if (!mounted) return;
    setState(() {
      _isLoadingSchedule = true;
    });

    try {
      final schedules = await ApiService.getTsSchedule(
        year: month.year,
        month: month.month,
      );

      if (!mounted) return;
      
      final Map<String, Map<String, dynamic>> scheduleMap = {};
      for (final schedule in schedules) {
        final dateStr = schedule['ts_date'].toString();
        scheduleMap[dateStr] = schedule;
      }

      setState(() {
        _scheduleData = scheduleMap;
        _isLoadingSchedule = false;
      });
    } catch (e) {
      print('스케줄 로드 실패: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingSchedule = false;
      });
    }
  }


  // 날짜 선택 처리
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });

      // 선택된 날짜가 비활성화되지 않은 경우에만 처리
      if (!_calendarLogic.isDateDisabled(selectedDay, _scheduleData)) {
        // 선택된 날짜에 대한 스케줄 정보 가져오기
        final dateKey = DateFormat('yyyy-MM-dd').format(selectedDay);
        final scheduleInfo = _scheduleData[dateKey] ?? {};
        
        print('Step1: 선택된 날짜 = $dateKey, 스케줄 정보 = $scheduleInfo');
        
        // 부모에게 선택된 날짜와 스케줄 정보 전달
        if (widget.onDateSelected != null) {
          widget.onDateSelected!(selectedDay, scheduleInfo);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _calendarLogic.buildCalendarWidget(
      focusedDay: _focusedDay,
      selectedDay: _selectedDay,
      scheduleData: _scheduleData,
      onDaySelected: _onDaySelected,
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
        });
        _loadScheduleForMonth(focusedDay);
      },
      calendarFormat: _calendarFormat,
      onFormatChanged: (format) {
        if (_calendarFormat != format) {
          setState(() {
            _calendarFormat = format;
          });
        }
      },
      isLoading: _isLoadingSchedule,
      loadingMessage: '영업일정을 불러오는 중...',
    );
  }
} 