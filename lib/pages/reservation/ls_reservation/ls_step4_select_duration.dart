import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';

class LsStep4SelectDuration extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;
  final DateTime? selectedDate;
  final String? selectedInstructor;
  final String? selectedTime;
  final Function(int) onDurationSelected;
  final int? selectedDuration;
  final Map<String, dynamic>? lessonCountingData;
  final Map<String, Map<String, dynamic>> proInfoMap;
  final Map<String, Map<String, Map<String, dynamic>>> proScheduleMap;

  const LsStep4SelectDuration({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
    this.selectedDate,
    this.selectedInstructor,
    this.selectedTime,
    required this.onDurationSelected,
    this.selectedDuration,
    this.lessonCountingData,
    required this.proInfoMap,
    required this.proScheduleMap,
  }) : super(key: key);

  @override
  _LsStep4SelectDurationState createState() => _LsStep4SelectDurationState();
}

class _LsStep4SelectDurationState extends State<LsStep4SelectDuration> {
  List<Map<String, dynamic>> _reservations = [];
  int _minServiceMin = 0;
  int _serviceUnitMin = 5;
  String _workStart = '09:00:00';
  String _workEnd = '18:00:00';
  bool _isLoadingReservations = false;
  double _currentDuration = 30; // 기본값
  int _minDuration = 30;
  int _maxDuration = 90;

  @override
  void initState() {
    super.initState();
    _initializeDurationData();
  }

  @override
  void didUpdateWidget(LsStep4SelectDuration oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 날짜, 강사, 시간이 변경된 경우 데이터 다시 로드
    if (widget.selectedDate != oldWidget.selectedDate ||
        widget.selectedInstructor != oldWidget.selectedInstructor ||
        widget.selectedTime != oldWidget.selectedTime) {
      _initializeDurationData();
    }
  }

  Future<void> _initializeDurationData() async {
    if (widget.selectedDate == null || 
        widget.selectedInstructor == null || 
        widget.selectedTime == null) return;

    print('\n=== 레슨시간 선택 단계에서 호출된 정보 ===');
    print('날짜: ${DateFormat('yyyy-MM-dd').format(widget.selectedDate!)}');
    print('선택된 프로 ID: ${widget.selectedInstructor}');
    print('선택된 시작시간: ${widget.selectedTime}');

    // 프로 정보 가져오기
    final proInfo = widget.proInfoMap[widget.selectedInstructor];
    if (proInfo == null) {
      print('❌ 프로 정보를 찾을 수 없습니다.');
      return;
    }

    print('프로 이름: ${proInfo['pro_name']}');

    // 최소 레슨시간 및 레슨시간 단위 설정
    _minServiceMin = int.tryParse(proInfo['min_service_min']?.toString() ?? '0') ?? 0;
    _serviceUnitMin = int.tryParse(proInfo['svc_time_unit']?.toString() ?? '5') ?? 5;
    print('최소 레슨시간: ${_minServiceMin}분');
    print('레슨시간 단위: ${_serviceUnitMin}분');

    // 근무시간 설정
    final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate!);
    final proSchedule = widget.proScheduleMap[widget.selectedInstructor]?[dateStr];
    if (proSchedule != null) {
      _workStart = proSchedule['work_start'] ?? '09:00:00';
      _workEnd = proSchedule['work_end'] ?? '18:00:00';
      print('근무시간: ${_workStart} ~ ${_workEnd}');
    } else {
      print('프로 스케줄 정보를 찾을 수 없습니다. 기본 근무시간 사용: 09:00:00 ~ 18:00:00');
    }

    // 예약내역 로드
    await _loadReservations();
    
    // 최대 레슨시간 계산
    _calculateMaxDuration();
    
    // 초기 레슨시간 설정
    _currentDuration = widget.selectedDuration?.toDouble() ?? _minServiceMin.toDouble();
    if (_currentDuration < _minDuration) _currentDuration = _minDuration.toDouble();
    if (_currentDuration > _maxDuration) _currentDuration = _maxDuration.toDouble();
    
    // 조정된 값으로 콜백 호출
    widget.onDurationSelected(_currentDuration.toInt());
    
    setState(() {});
  }

  Future<void> _loadReservations() async {
    if (_isLoadingReservations) return;
    
    setState(() {
      _isLoadingReservations = true;
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate!);
      final orders = await ApiService.getLsOrders(
        proId: widget.selectedInstructor!,
        lsDate: dateStr,
      );

      print('\n[API로 조회한 예약내역]');
      if (orders.isEmpty) {
        print('예약된 레슨이 없습니다.');
      } else {
        for (final order in orders) {
          print('• ${order['LS_start_time']} ~ ${order['LS_end_time']}');
        }
      }

      // 예약내역 정렬
      _reservations = List<Map<String, dynamic>>.from(orders)
        ..sort((a, b) => a['LS_start_time'].compareTo(b['LS_start_time']));

      setState(() {
        _isLoadingReservations = false;
      });
    } catch (e) {
      print('예약내역 조회 실패: $e');
      setState(() {
        _isLoadingReservations = false;
        _reservations = [];
      });
    }
  }

  void _calculateMaxDuration() {
    if (widget.selectedTime == null) return;

    final startTimeMinutes = _timeToMinutes('${widget.selectedTime}:00');
    final workEndMinutes = _timeToMinutes(_workEnd);
    
    // 1. 근무시간 종료까지 남은 시간
    final timeUntilWorkEnd = workEndMinutes - startTimeMinutes;
    
    // 2. 다음 예약까지 남은 시간
    int timeUntilNextReservation = timeUntilWorkEnd;
    for (var reservation in _reservations) {
      final reservationStartMinutes = _timeToMinutes(reservation['LS_start_time']);
      if (reservationStartMinutes > startTimeMinutes) {
        timeUntilNextReservation = reservationStartMinutes - startTimeMinutes;
        break;
      }
    }
    
    // 3. 최대 90분 제한
    final maxAllowedTime = 90;
    
    // 최소값 선택
    int calculatedMax = [timeUntilWorkEnd, timeUntilNextReservation, maxAllowedTime]
        .reduce((a, b) => a < b ? a : b);
    
    // 최소 레슨시간부터 시작해서 svc_time_unit 단위로 증가하는 최대값 계산
    // 예: 최소 15분, 단위 10분 → 15, 25, 35, 45...
    int maxPossible = _minServiceMin;
    while (maxPossible + _serviceUnitMin <= calculatedMax) {
      maxPossible += _serviceUnitMin;
    }
    _maxDuration = maxPossible;
    
    // 최소 레슨시간보다 작을 수 없음
    if (_maxDuration < _minServiceMin) {
      _maxDuration = _minServiceMin;
    }
    
    _minDuration = _minServiceMin;
    
    print('최대 레슨시간 계산:');
    print('- 근무시간 종료까지: ${timeUntilWorkEnd}분');
    print('- 다음 예약까지: ${timeUntilNextReservation}분');
    print('- 최대 허용시간: ${maxAllowedTime}분');
    print('- 계산된 최대값: ${calculatedMax}분');
    print('- 최소 레슨시간(${_minServiceMin}분)부터 svc_time_unit(${_serviceUnitMin}분) 단위로 조정된 최대값: ${_maxDuration}분');
    print('- 최소 레슨시간: ${_minDuration}분');
  }

  // 시간 문자열을 분 단위로 변환 (HH:MM:SS 또는 HH:MM)
  int _timeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return hour * 60 + minute;
  }

  // 분을 시간 문자열로 변환 (HH:MM)
  String _minutesToTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String _getEndTime() {
    if (widget.selectedTime == null) return '--:--';
    
    final startTimeMinutes = _timeToMinutes('${widget.selectedTime}:00');
    final endTimeMinutes = startTimeMinutes + _currentDuration.toInt();
    return _minutesToTime(endTimeMinutes);
  }

  @override
  Widget build(BuildContext context) {
    // 필수 정보가 없는 경우
    if (widget.selectedDate == null || 
        widget.selectedInstructor == null || 
        widget.selectedTime == null) {
      return Container(
        padding: EdgeInsets.all(16),
        constraints: BoxConstraints(minHeight: 200),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.schedule_outlined,
                size: 48,
                color: Color(0xFF9CA3AF),
              ),
              SizedBox(height: 12),
              Text(
                '날짜, 강사, 시작시간을 먼저 선택해주세요',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16),
      constraints: BoxConstraints(minHeight: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 로딩 상태 표시
          if (_isLoadingReservations)
            Container(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Column(
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
                      '예약 현황을 확인하는 중...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: EdgeInsets.all(0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 레슨 시간 선택 영역
                  Container(
                    width: double.infinity,
                    height: (MediaQuery.of(context).size.width - 32) / 1.618, // 황금비율
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 선택된 시간 표시
                          Text(
                            '${widget.selectedTime} - ${_getEndTime()}',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          SizedBox(height: 6),
                          
                          // 슬라이더만 표시
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: Color(0xFF10B981),
                                inactiveTrackColor: Color(0xFFE0E0E0),
                                thumbColor: Color(0xFF10B981),
                                overlayColor: Color(0xFF10B981).withOpacity(0.2),
                                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 18),
                                trackHeight: 8,
                                valueIndicatorShape: PaddleSliderValueIndicatorShape(),
                                valueIndicatorColor: Color(0xFF10B981),
                                valueIndicatorTextStyle: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              child: Slider(
                                value: _maxDuration > 0 ? _currentDuration.clamp(0.0, _maxDuration.toDouble()) : 0.0,
                                min: 0.0,
                                max: _maxDuration > 0 ? _maxDuration.toDouble() : _minDuration.toDouble(),
                                divisions: _maxDuration > 0 ? (_maxDuration ~/ _serviceUnitMin) : 1,
                                label: '${_currentDuration.toInt()}분',
                                onChanged: _maxDuration > 0 ? (value) {
                                  // 최소 레슨시간부터 시작해서 svc_time_unit 단위로 계산
                                  int finalValue;
                                  if (value < _minDuration) {
                                    finalValue = _minDuration;
                                  } else {
                                    // 최소 레슨시간을 기준으로 svc_time_unit 단위로 반올림
                                    final additionalTime = value - _minDuration;
                                    final roundedAdditional = (additionalTime / _serviceUnitMin).round() * _serviceUnitMin;
                                    finalValue = _minDuration + roundedAdditional.toInt();
                                  }
                                  
                                  setState(() {
                                    _currentDuration = finalValue.toDouble();
                                  });
                                  widget.onDurationSelected(finalValue);
                                } : null,
                              ),
                            ),
                          ),
                          
                          SizedBox(height: 6),
                          
                          // 최소/최대값을 슬라이더 아래로 이동
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '0분',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF8E8E8E),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${_maxDuration}분',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF8E8E8E),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: 7),
                          
                          // 안내 텍스트
                          Text(
                            '슬라이더를 움직여 레슨시간을 조정하세요',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFFBBBBBB),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
} 