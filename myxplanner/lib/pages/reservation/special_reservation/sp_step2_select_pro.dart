import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../services/tile_design_service.dart';

class SpStep2SelectPro extends StatefulWidget {
  final Function(int, String) onProSelected; // proId, proName 전달
  final DateTime? selectedDate;
  final int? selectedProId;
  final String? selectedProName;
  final Map<String, dynamic> specialSettings;
  final Map<String, dynamic>? selectedMember;

  const SpStep2SelectPro({
    Key? key,
    required this.onProSelected,
    this.selectedDate,
    this.selectedProId,
    this.selectedProName,
    required this.specialSettings,
    this.selectedMember,
  }) : super(key: key);

  @override
  State<SpStep2SelectPro> createState() => _SpStep2SelectProState();
}

class _SpStep2SelectProState extends State<SpStep2SelectPro> {
  List<Map<String, dynamic>> _availablePros = [];
  bool _isLoading = true;
  
  // 회원권 검증을 위한 데이터
  Map<String, dynamic>? _lessonCountingData;
  Map<String, Map<String, dynamic>> _proInfoMap = {};
  Map<String, Map<String, Map<String, dynamic>>> _proScheduleMap = {};

  @override
  void initState() {
    super.initState();
    _loadAvailablePros();
  }

  @override
  void didUpdateWidget(SpStep2SelectPro oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 날짜가 변경된 경우 데이터 다시 로드
    if (widget.selectedDate != oldWidget.selectedDate) {
      _loadAvailablePros();
    }
  }

  Future<void> _loadAvailablePros() async {
    if (widget.selectedDate == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 회원권 정보 로드
      await _loadLessonCountingData();
      
      // 2. 회원권이 있는 프로들만 필터링
      if (_lessonCountingData != null && 
          _lessonCountingData!['success'] == true && 
          _lessonCountingData!['data'] != null) {
        
        final validRecords = _lessonCountingData!['data'] as List<dynamic>;
        final validProIds = validRecords.map((record) => record['pro_id']?.toString()).toSet();
        
        final List<Map<String, dynamic>> availablePros = [];
        final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate!);
        
        for (final proId in validProIds) {
          if (proId == null || proId.isEmpty) continue;
          
          final proInfo = _proInfoMap[proId];
          if (proInfo == null) continue;
          
          // 예약 가능일수 체크
          final reservationAheadDays = int.tryParse(proInfo['reservation_ahead_days']?.toString() ?? '0') ?? 0;
          final today = DateTime.now();
          final todayOnly = DateTime(today.year, today.month, today.day);
          final selectedDayOnly = DateTime(widget.selectedDate!.year, widget.selectedDate!.month, widget.selectedDate!.day);
          final maxAllowedDate = todayOnly.add(Duration(days: reservationAheadDays));
          final isDateExceedingLimit = selectedDayOnly.isAfter(maxAllowedDate);
          
          // 프로 스케줄 체크
          String workStart = '09:00:00';
          String workEnd = '18:00:00';
          bool isDayOff = false;
          
          final proSchedule = _proScheduleMap[proId];
          if (proSchedule != null) {
            final daySchedule = proSchedule[dateStr];
            if (daySchedule != null) {
              if (daySchedule['is_day_off'] == '휴무') {
                isDayOff = true;
              } else {
                workStart = daySchedule['work_start'] ?? '09:00:00';
                workEnd = daySchedule['work_end'] ?? '18:00:00';
              }
            }
          }
          
          // 예약 가능 여부 결정
          bool isAvailable = !isDateExceedingLimit && !isDayOff;
          
          availablePros.add({
            'proId': proId,
            'proName': proInfo['pro_name']?.toString() ?? '프로 $proId',
            'workStart': workStart,
            'workEnd': workEnd,
            'isAvailable': isAvailable,
            'isDayOff': isDayOff,
            'isDateExceedingLimit': isDateExceedingLimit,
            'reservationAheadDays': reservationAheadDays,
            'minServiceMin': int.tryParse(proInfo['min_service_min']?.toString() ?? '0') ?? 0,
            'serviceUnitMin': int.tryParse(proInfo['svc_time_unit']?.toString() ?? '5') ?? 5,
          });
        }
        
        setState(() {
          _availablePros = availablePros;
          _isLoading = false;
        });
      } else {
        setState(() {
          _availablePros = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('예약 가능한 프로 로드 실패: $e');
      setState(() {
        _availablePros = [];
        _isLoading = false;
      });
    }
  }

  // 회원권 검증을 위한 레슨 카운팅 데이터 로드
  Future<void> _loadLessonCountingData() async {
    try {
      // widget.selectedMember를 우선 사용, 없으면 ApiService에서 가져오기
      final memberData = widget.selectedMember ?? ApiService.getCurrentUser();
      if (memberData != null && memberData['member_id'] != null) {
        final memberId = memberData['member_id'].toString();
        final programId = widget.specialSettings['program_id']?.toString();
        print('✅ [프로선택] 회원 ID 확인: $memberId');
        print('✅ [프로선택] 프로그램 ID로 필터링: $programId');

        final result = await ApiService.getMemberLsCountingDataForProgram(
          memberId: memberId,
          programId: programId,
        );

        if (result['success'] == true && result['debug_info'] != null) {
          final debugInfo = result['debug_info'] as Map<String, dynamic>;
          final proInfo = debugInfo['pro_info'] as Map<String, dynamic>?;
          final proSchedule = debugInfo['pro_schedule'] as Map<String, dynamic>?;

          if (proInfo != null) {
            _proInfoMap = proInfo.map((key, value) =>
              MapEntry(key, value as Map<String, dynamic>));
          }

          if (proSchedule != null) {
            _proScheduleMap = proSchedule.map((proId, scheduleData) =>
              MapEntry(proId, (scheduleData as Map<String, dynamic>).map((date, data) =>
                MapEntry(date, data as Map<String, dynamic>))));
          }

          _lessonCountingData = result;
          print('✅ [프로선택] 레슨 카운팅 데이터 로드 완료');
        }
      } else {
        print('❌ [프로선택] 회원 ID를 찾을 수 없습니다');
      }
    } catch (e) {
      print('❌ [프로선택] 레슨 카운팅 데이터 로드 실패: $e');
    }
  }

  void _handleProSelected(String proId, String proName) {
    // 이미 선택된 프로를 다시 선택하면 선택 해제
    if (widget.selectedProId == int.tryParse(proId)) {
      widget.onProSelected(0, '');  // 0으로 선택 해제 (프로 ID는 1부터 시작)
      return;
    }
    
    widget.onProSelected(int.tryParse(proId) ?? 0, proName);
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

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),
            SizedBox(height: 16),
            Text(
              '예약 가능한 프로를 확인하는 중...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF666666),
              ),
            ),
          ],
        ),
      );
    }

    if (_availablePros.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off,
              size: 64,
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(height: 16),
            Text(
              '선택한 날짜에 예약 가능한 프로가 없습니다',
              style: TextStyle(
                fontSize: 16,
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
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로 선택 그리드
            GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
              ),
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _availablePros.length,
              itemBuilder: (context, index) {
                final pro = _availablePros[index];
                final color = TileDesignService.getColorByIndex(index);
                
                return _buildProTile(
                  proId: pro['proId'],
                  proName: pro['proName'],
                  workStart: pro['workStart'],
                  workEnd: pro['workEnd'],
                  isAvailable: pro['isAvailable'],
                  isDayOff: pro['isDayOff'],
                  isDateExceedingLimit: pro['isDateExceedingLimit'],
                  reservationAheadDays: pro['reservationAheadDays'],
                  color: color,
                  onTap: () => _handleProSelected(pro['proId'], pro['proName']),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProTile({
    required String proId,
    required String proName,
    required String workStart,
    required String workEnd,
    required bool isAvailable,
    required bool isDayOff,
    required bool isDateExceedingLimit,
    required int reservationAheadDays,
    required Color color,
    required VoidCallback onTap,
  }) {
    final bool isSelected = widget.selectedProId == int.tryParse(proId);
    final bool shouldDisable = widget.selectedProId != null && widget.selectedProId! > 0 && !isSelected;

    String workTimeInfo = '';

    if (isDateExceedingLimit) {
      workTimeInfo = '오픈 전';
    } else if (isDayOff) {
      workTimeInfo = '휴무';
    } else {
      workTimeInfo = '${workStart.substring(0, 5)} - ${workEnd.substring(0, 5)}';
    }

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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (!isAvailable || shouldDisable) ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단: 프로 이름과 아이콘
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (!isAvailable || shouldDisable) 
                          ? Colors.grey.withOpacity(0.3)
                          : color.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        color: (!isAvailable || shouldDisable) 
                          ? Colors.grey 
                          : color,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        proName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: (!isAvailable || shouldDisable) 
                            ? Colors.grey 
                            : Color(0xFF1A1A1A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 12),
                
                // 하단: 근무 시간
                Text(
                  workTimeInfo,
                  style: TextStyle(
                    fontSize: 14,
                    color: (!isAvailable || shouldDisable) 
                      ? Colors.grey 
                      : Color(0xFF666666),
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