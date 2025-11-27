import 'package:flutter/material.dart';
import '../../../services/tile_design_service.dart';
import '../../../services/api_service.dart';
import 'package:intl/intl.dart';

class LsStep2SelectInstructor extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;
  final DateTime? selectedDate;
  final Function(String) onInstructorSelected;
  final String? selectedInstructor;
  final Map<String, dynamic>? lessonCountingData;
  final Map<String, Map<String, dynamic>> proInfoMap;
  final Map<String, Map<String, Map<String, dynamic>>> proScheduleMap;
  final Function(DateTime) onDateChanged;

  const LsStep2SelectInstructor({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
    this.selectedDate,
    required this.onInstructorSelected,
    this.selectedInstructor,
    this.lessonCountingData,
    required this.proInfoMap,
    required this.proScheduleMap,
    required this.onDateChanged,
  }) : super(key: key);

  @override
  _LsStep2SelectInstructorState createState() => _LsStep2SelectInstructorState();
}

class _LsStep2SelectInstructorState extends State<LsStep2SelectInstructor> {
  List<Map<String, dynamic>> _getProItems() {
    final items = <Map<String, dynamic>>[];
    final dateKey = DateFormat('yyyy-MM-dd').format(widget.selectedDate!);

    print('\n=== _getProItems() 함수 실행 ===');
    print('총 프로 수: ${widget.proInfoMap.keys.length}');
    print('선택된 날짜 키: $dateKey');
    print('');

    for (final proId in widget.proInfoMap.keys) {
      final proInfo = widget.proInfoMap[proId];
      final proSchedule = widget.proScheduleMap[proId];

      print('--- 프로 처리 시작: $proId ---');
      print('proInfo 존재: ${proInfo != null}');
      print('proSchedule 존재: ${proSchedule != null}');

      if (proInfo != null && proSchedule != null) {
        final daySchedule = proSchedule[dateKey];
        final proName = proInfo['pro_name']?.toString() ?? '프로 $proId';
        final reservationAheadDays = int.tryParse(proInfo['reservation_ahead_days']?.toString() ?? '0') ?? 0;
        final minServiceMin = int.tryParse(proInfo['min_service_min']?.toString() ?? '0') ?? 0;
        final minReservationTerm = int.tryParse(proInfo['min_reservation_term']?.toString() ?? '0') ?? 0;

        print('프로 이름: $proName');
        print('daySchedule[$dateKey] 존재: ${daySchedule != null}');
        if (daySchedule != null) {
          print('  - is_day_off: ${daySchedule['is_day_off']}');
          print('  - work_start: ${daySchedule['work_start']}');
          print('  - work_end: ${daySchedule['work_end']}');
        }
        print('예약 가능 일수: $reservationAheadDays일');
        print('최소 서비스 시간: ${minServiceMin}분');
        print('최소 예약 기간: ${minReservationTerm}분');

        // 예약 가능 일수 체크
        final today = DateTime.now();
        final todayOnly = DateTime(today.year, today.month, today.day);
        final selectedDayOnly = DateTime(widget.selectedDate!.year, widget.selectedDate!.month, widget.selectedDate!.day);
        final maxAllowedDate = todayOnly.add(Duration(days: reservationAheadDays));
        final isDateExceedingLimit = selectedDayOnly.isAfter(maxAllowedDate);

        print('오늘: $todayOnly');
        print('선택된 날짜: $selectedDayOnly');
        print('최대 허용 날짜: $maxAllowedDate');
        print('날짜 초과 여부: $isDateExceedingLimit');

        // 근무 시간 정보
        String workTimeInfo = '';
        String availabilityInfo = '';
        bool isAvailable = true;
        bool isDayOff = false;

        if (isDateExceedingLimit) {
          workTimeInfo = '오픈 전';
          isAvailable = false;
          isDayOff = false;
          print('→ 결과: 오픈 전 (예약 불가)');
        } else if (daySchedule != null) {
          if (daySchedule['is_day_off'] == '휴무') {
            workTimeInfo = '휴무일';
            isAvailable = false;
            isDayOff = true;
            print('→ 결과: 휴무일');
          } else {
            final workStart = daySchedule['work_start'].toString().substring(0, 5);
            final workEnd = daySchedule['work_end'].toString().substring(0, 5);
            workTimeInfo = '$workStart~$workEnd';

            // 최소 예약 시간 정보
            availabilityInfo = minServiceMin > 0
                ? '최소 ${minServiceMin}분 / ${minReservationTerm}분 뒤부터'
                : '즉시 예약가능';
            print('→ 결과: 근무일 ($workTimeInfo)');
            print('   예약 가능 정보: $availabilityInfo');
          }
        } else {
          workTimeInfo = '09:00~18:00';
          availabilityInfo = minServiceMin > 0
              ? '최소 ${minServiceMin}분 / ${minReservationTerm}분 뒤부터'
              : '즉시 예약가능';
          print('→ 결과: 스케줄 없음, 기본 근무시간 적용 ($workTimeInfo)');
          print('   예약 가능 정보: $availabilityInfo');
        }

        print('화면 표시:');
        print('  - title: $proName');
        print('  - subtitle: $workTimeInfo');
        print('  - info: $availabilityInfo');
        print('  - isDayOff: $isDayOff');
        print('  - isAvailable: $isAvailable');
        print('');

        items.add({
          'title': proName,
          'subtitle': workTimeInfo,
          'info': availabilityInfo,
          'isDayOff': isDayOff,
          'type': proId,
          'isAvailable': isAvailable,
          'icon': isDayOff ? Icons.event_busy :
                 !isAvailable ? Icons.block :
                 Icons.person,
        });
      } else {
        print('프로 정보 또는 스케줄이 없어 건너뜁니다.');
      }
      print('');
    }

    print('=== _getProItems() 함수 완료 ===');
    print('최종 생성된 프로 항목 수: ${items.length}');
    print('');

    return items;
  }

  void _showScheduleDialog(BuildContext context, String proId, String proName, Color color) {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day);
    
    // 프로의 예약 가능일수 가져오기
    final proInfo = widget.proInfoMap[proId];
    final reservationAheadDays = int.tryParse(proInfo?['reservation_ahead_days']?.toString() ?? '0') ?? 0;
    
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: StatefulBuilder(
          builder: (context, setState) => Container(
            width: MediaQuery.of(context).size.width * 0.8,
            constraints: BoxConstraints(
              minWidth: 400,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더
                Row(
                  children: [
                    Icon(Icons.calendar_month, color: color, size: 24),
                    SizedBox(width: 12),
                    Text(
                      '$proName 프로 예약가능일정',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: Color(0xFF666666)),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                // 일정 목록
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: reservationAheadDays,
                    separatorBuilder: (context, index) => SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final date = startDate.add(Duration(days: index));
                      final dateKey = DateFormat('yyyy-MM-dd').format(date);
                      final schedule = widget.proScheduleMap[proId]?[dateKey];
                      
                      final today = DateTime.now();
                      final isToday = date.year == today.year && 
                                    date.month == today.month && 
                                    date.day == today.day;
                      
                      String scheduleText = '';
                      bool isSelectable = true;
                      bool isDayOff = false;
                      
                      if (schedule != null) {
                        if (schedule['is_day_off'] == '휴무') {
                          scheduleText = '휴무일';
                          isSelectable = false;
                          isDayOff = true;
                        } else {
                          final workStart = schedule['work_start'].toString().substring(0, 5);
                          final workEnd = schedule['work_end'].toString().substring(0, 5);
                          scheduleText = '$workStart~$workEnd';
                        }
                      } else {
                        scheduleText = '09:00~18:00';
                      }
                      
                      return InkWell(
                        onTap: isSelectable ? () async {
                          bool? confirm = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('날짜 변경'),
                                content: Text('${DateFormat('yyyy-MM-dd').format(date)} 날짜로 변경하시겠습니까?'),
                                actions: [
                                  TextButton(
                                    child: Text('취소'),
                                    onPressed: () => Navigator.of(context).pop(false),
                                  ),
                                  TextButton(
                                    child: Text('확인'),
                                    onPressed: () => Navigator.of(context).pop(true),
                                  ),
                                ],
                              );
                            },
                          );
                          
                          if (confirm == true) {
                            Navigator.pop(context);
                            widget.onDateChanged(date);
                          }
                        } : null,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelectable ? (isToday ? color : color.withOpacity(0.1)) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelectable ? (isToday ? color : color.withOpacity(0.3)) : Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  DateFormat('MM/dd (E)', 'ko_KR').format(date),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                    color: isSelectable 
                                      ? (isToday ? color : Color(0xFF1A1A1A))
                                      : Color(0xFF9CA3AF),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      scheduleText,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: isDayOff ? Color(0xFF9CA3AF) : Color(0xFF4B5563),
                                      ),
                                    ),
                                    if (isSelectable)
                                      Text(
                                        '선택 >',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF3B82F6),
                                        ),
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
            ),
          ),
        ),
      ),
    );
  }

  // 프로 선택 시 예약내역 조회
  void _handleInstructorSelected(String instructor) async {
    // 이미 선택된 프로를 다시 선택하면 선택 해제
    if (widget.selectedInstructor == instructor) {
      widget.onInstructorSelected('');  // 빈 문자열로 선택 해제
      return;
    }
    
    widget.onInstructorSelected(instructor);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedDate == null) {
      return Center(
        child: Text(
          '날짜를 먼저 선택해주세요',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF666666),
          ),
        ),
      );
    }

    // 디버깅: 프로 선택 화면 진입 시 상세 정보 출력
    print('\n========================================');
    print('=== 프로 선택 화면 디버깅 정보 ===');
    print('========================================');
    print('선택된 날짜: ${widget.selectedDate}');
    print('날짜 키: ${DateFormat('yyyy-MM-dd').format(widget.selectedDate!)}');
    print('----------------------------------------');
    print('proInfoMap 전체 데이터:');
    widget.proInfoMap.forEach((proId, proInfo) {
      print('  프로 ID: $proId');
      print('    - pro_name: ${proInfo['pro_name']}');
      print('    - reservation_ahead_days: ${proInfo['reservation_ahead_days']}');
      print('    - min_service_min: ${proInfo['min_service_min']}');
      print('    - min_reservation_term: ${proInfo['min_reservation_term']}');
      print('    - svc_time_unit: ${proInfo['svc_time_unit']}');
    });
    print('----------------------------------------');
    print('proScheduleMap 전체 데이터:');
    widget.proScheduleMap.forEach((proId, schedules) {
      print('  프로 ID: $proId');
      schedules.forEach((date, schedule) {
        print('    날짜: $date');
        print('      - is_day_off: ${schedule['is_day_off']}');
        print('      - work_start: ${schedule['work_start']}');
        print('      - work_end: ${schedule['work_end']}');
      });
    });
    print('----------------------------------------');
    print('lessonCountingData:');
    if (widget.lessonCountingData != null) {
      print('  success: ${widget.lessonCountingData!['success']}');
      print('  data 개수: ${widget.lessonCountingData!['data']?.length ?? 0}');
      if (widget.lessonCountingData!['data'] != null) {
        final data = widget.lessonCountingData!['data'] as List;
        for (var record in data) {
          print('    - pro_id: ${record['pro_id']}, LS_balance_min_after: ${record['LS_balance_min_after']}, LS_expiry_date: ${record['LS_expiry_date']}');
        }
      }
    } else {
      print('  lessonCountingData가 null입니다');
    }
    print('========================================\n');

    final proItems = _getProItems();

    return Container(
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
              ),
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: proItems.length,
              itemBuilder: (context, index) {
                final item = proItems[index];
                final color = TileDesignService.getColorByIndex(index);
                
                return _buildCustomTile(
                  proName: item['title'],
                  workTime: item['subtitle'],
                  availabilityInfo: item['info'],
                  isDayOff: item['isDayOff'],
                  color: color,
                  isAvailable: item['isAvailable'],
                  onTap: () => _handleInstructorSelected(item['type']),
                  proId: item['type'],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTile({
    required String proName,
    required String workTime,
    required String availabilityInfo,
    required bool isDayOff,
    required Color color,
    required VoidCallback onTap,
    required bool isAvailable,
    required String proId,
  }) {
    final bool isUnavailable = !isAvailable && !isDayOff;
    final bool isSelected = widget.selectedInstructor == proId;
    // selectedInstructor가 비어있지 않고(!= '') 현재 타일이 선택되지 않은 경우에만 비활성화
    final bool shouldDisable = widget.selectedInstructor != '' && widget.selectedInstructor != null && !isSelected;

    print('Building tile for $proName:');  // 디버깅용 로그 추가
    print('- proId: $proId');
    print('- selectedInstructor: ${widget.selectedInstructor}');
    print('- isSelected: $isSelected');
    print('- shouldDisable: $shouldDisable');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? color : Colors.grey.withOpacity(0.2),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected 
              ? color.withOpacity(0.3)
              : Colors.black.withOpacity(0.05),
            blurRadius: isSelected ? 12 : 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Opacity(
        opacity: shouldDisable ? 0.5 : 1.0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: (isAvailable && !shouldDisable) ? onTap : null,
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                // 상단 영역 (프로 이름과 아이콘)
                Expanded(
                  flex: 100,  // 황금비율 적용 (1:1.618 ≈ 100:162)
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isSelected 
                        ? color.withOpacity(0.2)
                        : color.withOpacity(0.1),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isDayOff ? Icons.event_busy : 
                          isUnavailable ? Icons.block : 
                          isSelected ? Icons.check_circle : Icons.person,
                          color: color,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            proName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: color,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 하단 영역 (근무시간 및 레슨 정보)
                Expanded(
                  flex: 162,  // 황금비율 적용 (1:1.618 ≈ 100:162)
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            workTime,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isDayOff || isUnavailable ? 
                                Color(0xFFFF5722) : // 휴무일/예약불가 시 빨간색
                                Color(0xFF4B5563),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (isDayOff || isUnavailable) ...[
                          SizedBox(height: 6),
                          TextButton(
                            onPressed: () => _showScheduleDialog(
                              context,
                              proId,
                              proName,
                              color,
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              backgroundColor: color.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              '일정조회',
                              style: TextStyle(
                                fontSize: 13,
                                color: color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 