import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../../../../services/api_service.dart';

class Step2SelectTime extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;
  final DateTime? selectedDate;
  final Map<String, dynamic>? scheduleInfo;
  final String? selectedTime;
  final Function(String)? onTimeSelected;

  const Step2SelectTime({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
    this.selectedDate,
    this.scheduleInfo,
    this.selectedTime,
    this.onTimeSelected,
  }) : super(key: key);

  @override
  _Step2SelectTimeState createState() => _Step2SelectTimeState();
}

class _Step2SelectTimeState extends State<Step2SelectTime> {
  TimeOfDay _selectedTime = TimeOfDay(hour: 9, minute: 0);
  int _minUsageTime = 60; // 최소 이용 시간 (분)
  TimeOfDay? _maxStartTime; // 최대 시작 시간
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeTimeSelection();
  }

  @override
  void didUpdateWidget(Step2SelectTime oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // selectedTime이 외부에서 변경되었을 때 내부 상태 업데이트
    if (oldWidget.selectedTime != widget.selectedTime && widget.selectedTime != null) {
      print('🕐 Step2: 외부에서 시간 변경됨 - 내부 상태 업데이트');
      print('🕐 이전 시간: ${oldWidget.selectedTime}');
      print('🕐 새로운 시간: ${widget.selectedTime}');
      
      // 즉시 상태 업데이트
      _updateSelectedTimeFromExternal(widget.selectedTime!);
      
      // 다음 프레임에서 한 번 더 업데이트하여 UI 반영 보장
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateSelectedTimeFromExternal(widget.selectedTime!);
        }
      });
    }
    
    // selectedDate 또는 scheduleInfo가 변경되었을 때 다시 초기화
    else if (oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.scheduleInfo != widget.scheduleInfo) {
      print('🔄 Step2: 날짜 또는 스케줄 정보 변경됨 - 다시 초기화');
      print('🔄 이전 날짜: ${oldWidget.selectedDate}');
      print('🔄 새로운 날짜: ${widget.selectedDate}');
      print('🔄 새로운 스케줄 정보: ${widget.scheduleInfo}');
      
      _initializeTimeSelection();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  // 시간 선택 초기화
  Future<void> _initializeTimeSelection() async {
    print('🚀 시간 선택 초기화 시작');
    
    try {
      // 최소 이용 시간 조회
      print('📊 최소 이용 시간 조회 중...');
      _minUsageTime = await ApiService.getTsMinimumTime();
      print('✅ 최소 이용 시간: ${_minUsageTime}분');
      
      // 영업 시간 파싱 및 최대 시작 시간 계산
      print('⏰ 최대 시작 시간 계산 중...');
      _calculateMaxStartTime();
      
      // 초기 선택 시간 설정 (영업 시작 시간)
      print('🎯 초기 선택 시간 설정 중...');
      _setInitialTime();
      
      setState(() {
        _isLoading = false;
      });
      
      // 초기화 완료 후 부모 컴포넌트에 초기 시간 전달
      if (widget.onTimeSelected != null) {
        widget.onTimeSelected!(_formatTime(_selectedTime));
        print('✅ 초기화 완료 후 콜백 호출: ${_formatTime(_selectedTime)}');
      }
      
      print('🎉 시간 선택 초기화 완료');
      
    } catch (e) {
      print('❌ 시간 선택 초기화 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 최대 시작 시간 계산 (영업 종료 시간 - 최소 이용 시간)
  void _calculateMaxStartTime() {
    if (widget.scheduleInfo == null) return;

    final businessEnd = widget.scheduleInfo!['business_end'];
    if (businessEnd == null || businessEnd.toString().isEmpty) return;

    try {
      final endParts = businessEnd.toString().split(':');
      final endHour = int.parse(endParts[0]);
      final endMinute = int.parse(endParts[1]);
      
      // 영업 종료 시간을 분으로 변환
      int endTotalMinutes = endHour * 60 + endMinute;
      
      // 00:00인 경우 24:00(1440분)으로 처리
      if (endTotalMinutes == 0) {
        endTotalMinutes = 1440;
      }
      
      // 최소 이용 시간을 빼서 최대 시작 시간 계산
      int maxStartMinutes = endTotalMinutes - _minUsageTime;
      
      // 음수가 되면 영업 시작 시간으로 설정
      if (maxStartMinutes < 0) {
        final businessStart = widget.scheduleInfo!['business_start'];
        if (businessStart != null) {
          final startParts = businessStart.toString().split(':');
          final startHour = int.parse(startParts[0]);
          final startMinute = int.parse(startParts[1]);
          _maxStartTime = TimeOfDay(hour: startHour, minute: startMinute);
        }
      } else {
        final maxHour = (maxStartMinutes ~/ 60) % 24;
        final maxMinute = maxStartMinutes % 60;
        _maxStartTime = TimeOfDay(hour: maxHour, minute: maxMinute);
      }
    } catch (e) {
      print('최대 시작 시간 계산 오류: $e');
    }
  }

  // 초기 선택 시간 설정
  void _setInitialTime() {
    // 1. 먼저 외부에서 전달된 selectedTime이 있는지 확인
    if (widget.selectedTime != null && widget.selectedTime!.isNotEmpty) {
      try {
        final timeParts = widget.selectedTime!.split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        
        _selectedTime = TimeOfDay(hour: hour, minute: minute);
        print('✅ 외부에서 전달된 시간으로 설정: ${_formatTime(_selectedTime)}');
        print('✅ scheduleInfo: ${widget.scheduleInfo}');
        return; // 외부 시간이 있으면 여기서 종료
      } catch (e) {
        print('❌ 외부 시간 파싱 오류: $e - 기본 로직으로 진행');
      }
    }
    
    // 2. 외부 시간이 없는 경우 기본 로직 실행
    // 기본 시작 시간 설정 (09:00)
    int finalHour = 9;
    int finalMinute = 0;
    
    // scheduleInfo가 있으면 영업 시작 시간으로 설정
    if (widget.scheduleInfo != null) {
      final businessStart = widget.scheduleInfo!['business_start'];
      if (businessStart != null && businessStart.toString().isNotEmpty) {
        try {
          final startParts = businessStart.toString().split(':');
          finalHour = int.parse(startParts[0]);
          finalMinute = int.parse(startParts[1]);
          print('✅ 영업 시작 시간으로 설정: ${finalHour}:${finalMinute.toString().padLeft(2, '0')}');
        } catch (e) {
          print('❌ 영업 시작 시간 파싱 오류: $e - 기본값(09:00) 사용');
        }
      } else {
        print('⚠️ business_start가 null이거나 비어있음 - 기본값(09:00) 사용');
      }
    } else {
      print('⚠️ scheduleInfo가 null - 기본값(09:00) 사용');
    }
    
    // 오늘 날짜인지 확인하고 현재 시간 이후로 조정
    final now = DateTime.now();
    final selectedDate = widget.selectedDate;
    
    print('🔍 날짜 비교 디버깅');
    print('현재 날짜: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}');
    print('선택된 날짜: ${selectedDate?.year}-${selectedDate?.month.toString().padLeft(2, '0')}-${selectedDate?.day.toString().padLeft(2, '0')}');
    print('selectedDate가 null인가? ${selectedDate == null}');
    if (selectedDate != null) {
      print('년도 비교: ${selectedDate.year} == ${now.year} ? ${selectedDate.year == now.year}');
      print('월 비교: ${selectedDate.month} == ${now.month} ? ${selectedDate.month == now.month}');
      print('일 비교: ${selectedDate.day} == ${now.day} ? ${selectedDate.day == now.day}');
    }
    
    if (selectedDate != null && 
        selectedDate.year == now.year && 
        selectedDate.month == now.month && 
        selectedDate.day == now.day) {
      
      print('📅 오늘 날짜 선택됨 - 현재 시간 제한 적용');
      print('현재 시간: ${now.hour}:${now.minute.toString().padLeft(2, '0')}');
      print('기본 시작 시간: ${finalHour}:${finalMinute.toString().padLeft(2, '0')}');
      
      // 현재 시간을 5분 단위로 올림 처리
      int adjustedMinute = ((now.minute / 5).ceil() * 5) % 60;
      int adjustedHour = now.hour;
      if (now.minute > 55) {
        adjustedHour = (now.hour + 1) % 24;
        adjustedMinute = 0;
      }
      
      print('조정된 현재 시간: ${adjustedHour}:${adjustedMinute.toString().padLeft(2, '0')}');
      
      // 기본 시작 시간과 현재 시간 중 더 늦은 시간을 선택
      final defaultStartMinutes = finalHour * 60 + finalMinute;
      final currentTimeMinutes = adjustedHour * 60 + adjustedMinute;
      
      if (currentTimeMinutes > defaultStartMinutes) {
        finalHour = adjustedHour;
        finalMinute = adjustedMinute;
        print('✅ 현재 시간이 기본 시작 시간보다 늦음 - 현재 시간으로 설정');
      } else {
        print('✅ 기본 시작 시간이 현재 시간보다 늦음 - 기본 시작 시간으로 설정');
      }
    } else {
      print('📅 오늘이 아닌 날짜 - 현재 시간 제한 미적용');
    }
    
    _selectedTime = TimeOfDay(hour: finalHour, minute: finalMinute);
    
    print('✅ 최종 초기 시간 설정 완료: ${_formatTime(_selectedTime)}');
    print('✅ scheduleInfo: ${widget.scheduleInfo}');
  }

  // 외부에서 전달받은 시간으로 내부 상태 업데이트
  void _updateSelectedTimeFromExternal(String timeString) {
    try {
      final timeParts = timeString.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      final newTime = TimeOfDay(hour: hour, minute: minute);
      
      // 현재 시간과 다른 경우에만 업데이트
      if (_selectedTime.hour != newTime.hour || _selectedTime.minute != newTime.minute) {
        setState(() {
          _selectedTime = newTime;
        });
        
        print('✅ Step2: 외부 시간으로 업데이트 완료: ${_formatTime(_selectedTime)}');
        
        // 부모 컴포넌트에도 변경된 시간 알림
        if (widget.onTimeSelected != null) {
          widget.onTimeSelected!(_formatTime(_selectedTime));
        }
      } else {
        print('ℹ️ Step2: 동일한 시간이므로 업데이트 생략');
      }
      
    } catch (e) {
      print('❌ Step2: 외부 시간 파싱 오류: $e');
    }
  }

  // 시간을 문자열로 포맷 (HH:mm)
  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // 영업시간 포맷 (00:00을 24:00으로 표시)
  String _formatBusinessHours() {
    if (widget.scheduleInfo == null) return '영업시간 정보 없음';

    final businessStart = widget.scheduleInfo!['business_start'];
    final businessEnd = widget.scheduleInfo!['business_end'];
    final isHoliday = widget.scheduleInfo!['is_holiday'];

    if (isHoliday == 'close') {
      return '휴무일';
    }

    if (businessStart == null || businessEnd == null || 
        businessStart.toString().isEmpty || businessEnd.toString().isEmpty) {
      return '영업시간 미정';
    }

    String startTime = businessStart.toString().substring(0, 5);
    String endTime = businessEnd.toString().substring(0, 5);
    
    // 00:00을 24:00으로 표시
    if (endTime == '00:00') {
      endTime = '24:00';
    }

    return '$startTime - $endTime';
  }

  // 날짜 포맷
  String _formatDate() {
    if (widget.selectedDate == null) return '';
    
    final weekdays = ['', '월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdays[widget.selectedDate!.weekday];
    
    return DateFormat('yyyy-MM-dd').format(widget.selectedDate!) + '($weekday)';
  }

  // 시간 선택기 표시
  void _showTimePicker() {
    if (widget.scheduleInfo == null) return;

    final businessStart = widget.scheduleInfo!['business_start'];
    final businessEnd = widget.scheduleInfo!['business_end'];
    
    if (businessStart == null || businessEnd == null) return;

    try {
      final startParts = businessStart.toString().split(':');
      final endParts = businessEnd.toString().split(':');
      
      int startHour = int.parse(startParts[0]);
      int startMinute = int.parse(startParts[1]);
      final endHour = int.parse(endParts[0]);
      final endMinute = int.parse(endParts[1]);
      
      // 오늘 날짜인지 확인하고 현재 시간 이후로 제한
      final now = DateTime.now();
      final selectedDate = widget.selectedDate;
      
      if (selectedDate != null && 
          selectedDate.year == now.year && 
          selectedDate.month == now.month && 
          selectedDate.day == now.day) {
        // 오늘 날짜인 경우 현재 시간 이후로 제한
        final currentHour = now.hour;
        final currentMinute = now.minute;
        
        print('🕐 시간 선택기 - 오늘 날짜 현재 시간 제한 적용');
        print('현재 시간: ${currentHour}:${currentMinute.toString().padLeft(2, '0')}');
        print('기존 영업 시작 시간: ${startHour}:${startMinute.toString().padLeft(2, '0')}');
        
        // 현재 시간을 5분 단위로 올림 처리
        int adjustedMinute = ((currentMinute / 5).ceil() * 5) % 60;
        int adjustedHour = currentHour;
        if (currentMinute > 55) {
          adjustedHour = (currentHour + 1) % 24;
          adjustedMinute = 0;
        }
        
        print('조정된 현재 시간: ${adjustedHour}:${adjustedMinute.toString().padLeft(2, '0')}');
        
        // 영업 시작 시간과 현재 시간 중 더 늦은 시간을 최소 시간으로 설정
        final businessStartMinutes = startHour * 60 + startMinute;
        final currentTimeMinutes = adjustedHour * 60 + adjustedMinute;
        
        if (currentTimeMinutes > businessStartMinutes) {
          startHour = adjustedHour;
          startMinute = adjustedMinute;
          print('✅ 최소 시간을 현재 시간으로 변경: ${startHour}:${startMinute.toString().padLeft(2, '0')}');
        } else {
          print('✅ 최소 시간을 영업 시작 시간으로 유지: ${startHour}:${startMinute.toString().padLeft(2, '0')}');
        }
      } else {
        print('📅 오늘이 아닌 날짜 - 현재 시간 제한 미적용');
      }
      
      // 영업 종료 시간을 분으로 변환
      int endTotalMinutes = endHour * 60 + endMinute;
      if (endTotalMinutes == 0) endTotalMinutes = 1440; // 00:00 = 24:00

      // 최대 시작 시간 계산 (영업 종료 - 최소 이용 시간)
      int maxStartMinutes = endTotalMinutes - _minUsageTime;
      final maxStartHour = (maxStartMinutes ~/ 60) % 24;
      final maxStartMinute = maxStartMinutes % 60;

      // 디버깅 로그 추가
      print('🔍 [시간 선택기] 디버깅 정보:');
      print('  - 현재 선택된 시간 (_selectedTime): ${_formatTime(_selectedTime)} (hour: ${_selectedTime.hour}, minute: ${_selectedTime.minute})');
      print('  - 영업 시작 시간 (startHour:startMinute): $startHour:${startMinute.toString().padLeft(2, '0')}');
      print('  - 영업 종료 시간 (endHour:endMinute): $endHour:${endMinute.toString().padLeft(2, '0')}');
      print('  - 최대 시작 시간 (maxStartHour:maxStartMinute): $maxStartHour:${maxStartMinute.toString().padLeft(2, '0')}');
      print('  - minimumDate: DateTime(2023, 1, 1, $startHour, $startMinute)');
      print('  - maximumDate: DateTime(2023, 1, 1, $maxStartHour, $maxStartMinute)');

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter modalSetState) {
    return Container(
                height: 300,
                child: Column(
                  children: [
                    // 헤더
                    Container(
      padding: EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('취소', style: TextStyle(color: Colors.grey)),
                          ),
                          Text(
                            '시작 시간 선택',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              setState(() {}); // 메인 화면 업데이트
                              if (widget.onTimeSelected != null) {
                                widget.onTimeSelected!(_formatTime(_selectedTime));
                              }
                            },
                            child: Text(
                              '확인',
                              style: TextStyle(
                                color: Color(0xFF00A86B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 시간 선택기
                    Expanded(
                      child: CupertinoTheme(
                        data: CupertinoThemeData(
                          brightness: Brightness.light,
                          textTheme: CupertinoTextThemeData(
                            dateTimePickerTextStyle: TextStyle(
                              color: Colors.black,
                              fontSize: 22,
                            ),
                          ),
                        ),
                        child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.time,
                          minuteInterval: 5, // 5분 단위
                          use24hFormat: true, // 24시간 형식 명시
                          initialDateTime: () {
                          // 현재 날짜를 사용하여 로컬 시간대 적용
                          final now = DateTime.now();
                          final currentTimeMinutes = _selectedTime.hour * 60 + _selectedTime.minute;
                          final minTimeMinutes = startHour * 60 + startMinute;

                          print('🔍 [initialDateTime 계산]');
                          print('  - 현재 로컬 시간: ${now.toString()}');
                          print('  - currentTimeMinutes: $currentTimeMinutes (${_selectedTime.hour}시 ${_selectedTime.minute}분)');
                          print('  - minTimeMinutes: $minTimeMinutes (${startHour}시 ${startMinute}분)');
                          print('  - currentTimeMinutes < minTimeMinutes: ${currentTimeMinutes < minTimeMinutes}');

                          DateTime result;
                          if (currentTimeMinutes < minTimeMinutes) {
                            print('⚠️ 현재 선택 시간이 최소 시간보다 작음 - 최소 시간으로 조정');
                            result = DateTime(now.year, now.month, now.day, startHour, startMinute);
                            print('  → initialDateTime: $result');
                          } else {
                            print('✅ 현재 선택 시간 사용');
                            result = DateTime(now.year, now.month, now.day, _selectedTime.hour, _selectedTime.minute);
                            print('  → initialDateTime: $result');
                          }
                          return result;
                        }(),
                        minimumDate: () {
                          final now = DateTime.now();
                          return DateTime(now.year, now.month, now.day, startHour, startMinute);
                        }(),
                        maximumDate: () {
                          final now = DateTime.now();
                          return DateTime(now.year, now.month, now.day, maxStartHour, maxStartMinute);
                        }(),
                        onDateTimeChanged: (DateTime newDateTime) {
                          final newTime = TimeOfDay(
                            hour: newDateTime.hour,
                            minute: newDateTime.minute,
                          );
                          
                          // 선택된 시간이 유효한지 확인
                          final newTimeMinutes = newTime.hour * 60 + newTime.minute;
                          final startTimeMinutes = startHour * 60 + startMinute; // 동적으로 설정된 시작 시간
                          final maxTimeMinutes = maxStartHour * 60 + maxStartMinute;
                          
                          // 영업시간 내이고 최소 이용시간을 확보할 수 있는 시간인지 확인
                          if (newTimeMinutes >= startTimeMinutes && newTimeMinutes <= maxTimeMinutes) {
                            // 선택된 시간 + 최소 이용시간이 영업 종료 시간을 넘지 않는지 확인
                            if (newTimeMinutes + _minUsageTime <= endTotalMinutes) {
                              modalSetState(() {
                                _selectedTime = newTime;
                              });
                            }
                          }
                        },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      print('시간 선택기 오류: $e');
    }
  }

  // 프로 선택 팝업 표시
  void _showProSelectionDialog() async {
    try {
      // 프로 목록 조회
      final pros = await ApiService.getActivePros();
      
      if (pros.isEmpty) {
        // 프로가 없는 경우 안내 메시지
        showDialog(
          context: context,
      useRootNavigator: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('알림'),
              content: Text('현재 재직 중인 프로가 없습니다.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('확인'),
                ),
              ],
            );
          },
        );
        return;
      }

      // 프로 선택 팝업 표시
      showDialog(
        context: context,
      useRootNavigator: false,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.7,
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  // 헤더
                  Text(
                    '조회하실 프로를 선택하세요',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: 20),
                  
                  // 프로 목록 (2열 그리드)
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.618, // 황금비율
                      ),
                      itemCount: pros.length,
                      itemBuilder: (context, index) {
                        final pro = pros[index];
                        final proName = pro['pro_name']?.toString() ?? '이름없음';
                        final proId = pro['pro_id']?.toString() ?? '';
                        
                        return GestureDetector(
                          onTap: () {
                            // 선택된 프로 ID 디버깅 출력
                            print('=== 선택된 프로 정보 ===');
                            print('프로 ID: $proId');
                            print('프로 이름: $proName');
                            print('최소 서비스 시간: ${pro['min_service_min']}분');
                            print('서비스 시간 단위: ${pro['svc_time_unit']}분');
                            print('최소 예약 기간: ${pro['min_reservation_term']}분');
                            print('예약 가능 기간: ${pro['reservation_ahead_days']}일');
                            print('========================');
                            
                            Navigator.pop(context);
                            
                            // 레슨 가능 시간 조회 및 표시
                            _showProAvailableTimeSlots(proId, proName, pro);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Color(0xFFE0E0E0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // 프로 아이콘
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Color(0xFF00A86B).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color: Color(0xFF00A86B),
                                    size: 24,
                                  ),
                                ),
                                SizedBox(height: 12),
                                
                                // 프로 이름
                                Text(
                                  '$proName 프로',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // 취소 버튼
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                      ),
                      child: Text(
                        '취소',
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      print('프로 선택 팝업 오류: $e');
      
      // 오류 발생 시 안내 메시지
      showDialog(
        context: context,
      useRootNavigator: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('오류'),
            content: Text('프로 목록을 불러오는 중 오류가 발생했습니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('확인'),
              ),
            ],
          );
        },
      );
    }
  }

  // 프로의 레슨 가능 시간 표시
  void _showProAvailableTimeSlots(String proId, String proName, Map<String, dynamic> proInfo) async {
    if (widget.selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('먼저 날짜를 선택해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A86B)),
                ),
                SizedBox(height: 16),
                Text(
                  '${proName} 프로의\n레슨 가능 시간을 조회 중...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final dateStr = '${widget.selectedDate!.year}-${widget.selectedDate!.month.toString().padLeft(2, '0')}-${widget.selectedDate!.day.toString().padLeft(2, '0')}';
      
      // 레슨 가능 시간 조회
      final availableSlots = await ApiService.getProAvailableTimeSlots(
        proId: proId,
        date: dateStr,
        proInfo: proInfo,
      );

      // 로딩 다이얼로그 닫기
      Navigator.pop(context);

      // 결과 표시
      _showAvailableTimeSlotsDialog(proName, availableSlots, proInfo);

    } catch (e) {
      // 로딩 다이얼로그 닫기
      Navigator.pop(context);

      print('레슨 가능 시간 조회 오류: $e');
      
      showDialog(
        context: context,
      useRootNavigator: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('오류'),
            content: Text('레슨 가능 시간을 조회하는 중 오류가 발생했습니다.\n\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('확인'),
              ),
            ],
          );
        },
      );
    }
  }

  // 레슨 가능 시간 구간 표시 다이얼로그
  void _showAvailableTimeSlotsDialog(String proName, List<Map<String, String>> availableSlots, Map<String, dynamic> proInfo) {
    final minServiceMin = int.tryParse(proInfo['min_service_min']?.toString() ?? '15') ?? 15;
    
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                // 헤더
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: Color(0xFF00A86B),
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${proName} 프로 레슨 가능 시간',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                
                // 날짜 정보
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatDate(),
                  style: TextStyle(
                    fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 16),

                // 가능 시간 목록
                Expanded(
                  child: availableSlots.isEmpty
                      ? _buildNoAvailableTimeWidget(minServiceMin)
                      : _buildAvailableTimesList(availableSlots, minServiceMin),
                ),
                
                SizedBox(height: 16),
                
                // 닫기 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF00A86B),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      '확인',
                  style: TextStyle(
                        fontSize: 16,
                    fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 가능한 시간이 없을 때 위젯
  Widget _buildNoAvailableTimeWidget(int minServiceMin) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule_outlined,
            size: 64,
            color: Color(0xFFCCCCCC),
          ),
          SizedBox(height: 16),
          Text(
            '레슨 가능한 시간이 없습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF666666),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '다른 날짜를 선택해주세요',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF999999),
            ),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '최소 레슨 시간: ${minServiceMin}분',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF666666),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 가능한 시간 목록 위젯
  Widget _buildAvailableTimesList(List<Map<String, String>> availableSlots, int minServiceMin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 안내 텍스트
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Color(0xFFE8F5E8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📅 레슨 예약 가능 시간 구간',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00A86B),
                ),
              ),
              SizedBox(height: 4),
              Text(
                '최소 레슨 시간: ${minServiceMin}분 • 구간을 선택하면 시작시간이 설정됩니다',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
        
        // 시간 구간 목록
        Expanded(
          child: ListView.builder(
            itemCount: availableSlots.length,
            itemBuilder: (context, index) {
              final slot = availableSlots[index];
              final startTime = slot['start'] ?? '';
              final endTime = slot['end'] ?? '';
              
              // 구간 길이 계산 (분)
              final duration = _calculateSlotDuration(startTime, endTime);
              
              return GestureDetector(
                onTap: () {
                  // 선택된 시간 구간의 시작시간을 타석 시작시간으로 설정
                  _selectTimeSlot(startTime);
                },
                child: Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFFE0E0E0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // 시간 아이콘
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(0xFF00A86B).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.access_time,
                          color: Color(0xFF00A86B),
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 16),
                      
                      // 시간 정보
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$startTime - $endTime',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '가능 시간: ${duration}분',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF666666),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // 선택 버튼
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Color(0xFF00A86B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '선택',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward,
                              size: 14,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 시간 구간 길이 계산 (분)
  int _calculateSlotDuration(String startTime, String endTime) {
    try {
      final startParts = startTime.split(':');
      final endParts = endTime.split(':');
      
      final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      
      return endMinutes - startMinutes;
    } catch (e) {
      return 0;
    }
  }

  // 시간 구간 선택 처리
  void _selectTimeSlot(String startTime) {
    try {
      // 시간 문자열을 TimeOfDay로 변환
      final timeParts = startTime.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      // 타석 시작시간 설정
      setState(() {
        _selectedTime = TimeOfDay(hour: hour, minute: minute);
      });
      
      // 콜백 호출 (부모 컴포넌트에 선택된 시간 전달)
      if (widget.onTimeSelected != null) {
        widget.onTimeSelected!(startTime);
      }
      
      // 레슨 시간 다이얼로그만 닫기
      Navigator.pop(context);
      
      // 성공 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('시작시간이 $startTime 으로 설정되었습니다.'),
          backgroundColor: Color(0xFF00A86B),
          duration: Duration(seconds: 2),
        ),
      );
      
      print('=== 시간 구간 선택 완료 ===');
      print('선택된 시작시간: $startTime');
      print('설정된 _selectedTime: ${_formatTime(_selectedTime)}');
      
    } catch (e) {
      print('시간 구간 선택 오류: $e');
      
      // 오류 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('시간 설정 중 오류가 발생했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 회원의 레슨 예약 조회 및 표시
  void _showMemberLessonReservations() async {
    if (widget.selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('먼저 날짜를 선택해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.selectedMember == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('회원 정보가 없습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A86B)),
                ),
                SizedBox(height: 16),
                Text(
                  '레슨 예약을 조회 중...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final dateStr = '${widget.selectedDate!.year}-${widget.selectedDate!.month.toString().padLeft(2, '0')}-${widget.selectedDate!.day.toString().padLeft(2, '0')}';
      final memberId = widget.selectedMember!['member_id'].toString();
      
      // 회원의 레슨 예약 조회
      final lessonReservations = await ApiService.getMemberLessonReservations(
        memberId: memberId,
        date: dateStr,
      );

      // 로딩 다이얼로그 닫기
      Navigator.pop(context);

      // 결과 표시
      _showLessonReservationsDialog(lessonReservations);

    } catch (e) {
      // 로딩 다이얼로그 닫기
      Navigator.pop(context);

      print('레슨 예약 조회 오류: $e');
      
      showDialog(
        context: context,
      useRootNavigator: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('오류'),
            content: Text('레슨 예약을 조회하는 중 오류가 발생했습니다.\n\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('확인'),
              ),
            ],
          );
        },
      );
    }
  }

  // 레슨 예약 목록 표시 다이얼로그
  void _showLessonReservationsDialog(List<Map<String, dynamic>> lessonReservations) {
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                // 헤더
                Row(
                  children: [
                    Icon(
                      Icons.school,
                      color: Color(0xFF00A86B),
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '내 레슨 예약',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                
                // 날짜 정보
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatDate(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 16),

                // 레슨 예약 목록
                Expanded(
                  child: lessonReservations.isEmpty
                      ? _buildNoLessonReservationsWidget()
                      : _buildLessonReservationsList(lessonReservations),
                ),
                
                SizedBox(height: 16),
                
                // 닫기 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF00A86B),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      '확인',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 레슨 예약이 없을 때 위젯
  Widget _buildNoLessonReservationsWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 64,
            color: Color(0xFFCCCCCC),
          ),
          SizedBox(height: 16),
          Text(
            '예약된 레슨이 없습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF666666),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '다른 날짜를 선택하거나\n레슨을 예약해주세요',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF999999),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 레슨 예약 목록 위젯
  Widget _buildLessonReservationsList(List<Map<String, dynamic>> lessonReservations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 안내 텍스트
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Color(0xFFE8F5E8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📚 내 레슨 예약 목록',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00A86B),
                ),
              ),
              SizedBox(height: 4),
              Text(
                '레슨 시간을 선택하면 타석 시작시간이 설정됩니다',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
        
        // 레슨 예약 목록
        Expanded(
          child: ListView.builder(
            itemCount: lessonReservations.length,
            itemBuilder: (context, index) {
              final lesson = lessonReservations[index];
              final startTime = lesson['LS_start_time']?.toString() ?? '';
              final endTime = lesson['LS_end_time']?.toString() ?? '';
              final proName = lesson['pro_name']?.toString() ?? '프로';
              
              // 시간 포맷팅 (HH:mm:ss -> HH:mm)
              final formattedStartTime = startTime.length >= 5 ? startTime.substring(0, 5) : startTime;
              final formattedEndTime = endTime.length >= 5 ? endTime.substring(0, 5) : endTime;
              
              return GestureDetector(
                onTap: () {
                  // 레슨 시작시간을 타석 시작시간으로 설정
                  _selectLessonTime(formattedStartTime);
                },
                child: Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFFE0E0E0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // 레슨 아이콘
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(0xFF00A86B).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.school,
                          color: Color(0xFF00A86B),
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 16),
                      
                      // 레슨 정보
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$formattedStartTime - $formattedEndTime',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '$proName 프로',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF666666),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // 선택 버튼
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Color(0xFF00A86B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '선택',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward,
                              size: 14,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 레슨 시간 선택 처리
  void _selectLessonTime(String startTime) {
    try {
      // 시간 문자열을 TimeOfDay로 변환
      final timeParts = startTime.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      // 타석 시작시간 설정
      setState(() {
        _selectedTime = TimeOfDay(hour: hour, minute: minute);
      });
      
      // 콜백 호출 (부모 컴포넌트에 선택된 시간 전달)
      if (widget.onTimeSelected != null) {
        widget.onTimeSelected!(startTime);
      }
      
      // 레슨 예약 다이얼로그 닫기
      Navigator.pop(context);
      
      // 성공 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('레슨 시간에 맞춰 시작시간이 $startTime 으로 설정되었습니다.'),
          backgroundColor: Color(0xFF00A86B),
          duration: Duration(seconds: 2),
        ),
      );
      
      print('=== 레슨 시간 선택 완료 ===');
      print('선택된 시작시간: $startTime');
      print('설정된 _selectedTime: ${_formatTime(_selectedTime)}');
      
    } catch (e) {
      print('레슨 시간 선택 오류: $e');
      
      // 오류 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('시간 설정 중 오류가 발생했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 현재 선택된 시간을 반환하는 메서드 (부모 컴포넌트에서 호출용)
  String getCurrentSelectedTime() {
    return _formatTime(_selectedTime);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A86B)),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 시간 선택 영역 (타일 제거, 직접 배치)
          Container(
            width: double.infinity,
            height: (MediaQuery.of(context).size.width - 32) / 1.618, // 황금비율
            child: Column(
              children: [
                // 상위 3/4 - 시간 변경 영역
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: _showTimePicker,
                    child: Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 메인 시간 표시
                          Text(
                            _formatTime(_selectedTime),
                            style: TextStyle(
                              fontSize: 48, // 44에서 48로 증가
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 12),
                          // 안내 텍스트
                          Text(
                            '탭하여 시간 변경',
                            style: TextStyle(
                              fontSize: 16, // 15에서 16으로 증가
                              color: Color(0xFFBBBBBB),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 12), // 간격 추가

                // 하위 1/4 - 레슨예약조회 & 프로스케줄확인 버튼
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 0),
                    child: Row(
                      children: [
                        // 레슨예약조회 버튼 (왼쪽)
                        Expanded(
                          child: Container(
                            height: 65, // 62에서 65로 증가
                            child: ElevatedButton(
                              onPressed: _showMemberLessonReservations,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFF5F5F5),
                                foregroundColor: Color(0xFF333333),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                                padding: EdgeInsets.symmetric(horizontal: 8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search, size: 14), // 12에서 14로 증가
                                  SizedBox(width: 6),
                                  Text(
                                    '레슨예약조회',
                                    style: TextStyle(
                                      fontSize: 14, // 13에서 14로 증가
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_ios, size: 12),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SizedBox(width: 12), // 8에서 12로 증가

                        // 프로스케줄확인 버튼 (오른쪽)
                        Expanded(
                          child: Container(
                            height: 65, // 62에서 65로 증가
                            child: ElevatedButton(
                              onPressed: _showProSelectionDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFF5F5F5),
                                foregroundColor: Color(0xFF333333),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                                padding: EdgeInsets.symmetric(horizontal: 8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.schedule, size: 14), // 12에서 14로 증가
                                  SizedBox(width: 6),
                                  Text(
                                    '프로스케줄확인',
                                    style: TextStyle(
                                      fontSize: 14, // 13에서 14로 증가
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_ios, size: 12),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 12), // 8에서 12로 증가
          
          // 영업시간 안내
          Text(
            '${_formatDate()} 영업시간 : ${_formatBusinessHours()}',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }
} 