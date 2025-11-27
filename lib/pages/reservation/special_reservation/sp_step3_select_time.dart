import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import 'package:intl/intl.dart';
import 'sp_ts_availability_service.dart';
import 'sp_ls_availability_service.dart';
import 'sp_integrated_availability_service.dart';

class SpStep3SelectTime extends StatefulWidget {
  final Function(String, List<Map<String, dynamic>>) onTimeSelected;
  final DateTime? selectedDate;
  final int? selectedProId;
  final String? selectedProName;
  final Map<String, dynamic> specialSettings;
  final Map<String, dynamic>? selectedMember;

  const SpStep3SelectTime({
    Key? key,
    required this.onTimeSelected,
    this.selectedDate,
    this.selectedProId,
    this.selectedProName,
    required this.specialSettings,
    this.selectedMember,
  }) : super(key: key);

  @override
  State<SpStep3SelectTime> createState() => _SpStep3SelectTimeState();
}

class _SpStep3SelectTimeState extends State<SpStep3SelectTime> {
  Map<String, dynamic>? _lessonCountingData;
  Map<String, Map<String, dynamic>> _proInfoMap = {};
  Map<String, Map<String, Map<String, dynamic>>> _proScheduleMap = {};
  bool _isLoading = true;
  List<Map<String, dynamic>> _integratedOptions = [];
  List<Map<String, dynamic>> _availableTimeRanges = [];
  String? _selectedTimeSlot;
  String? _selectedTimeRange;

  @override
  void initState() {
    super.initState();
    print('');
    print('═══════════════════════════════════════════════════════════');
    print('🚀 [STEP3 시간선택] initState 시작');
    print('═══════════════════════════════════════════════════════════');
    _debugPrintAllInfo();
    print('');
    print('🔄 프로 스케줄 데이터 로드 시작...');
    _loadProScheduleData();
    print('');
    print('🔄 통합 가용성 로드 시작...');
    _loadIntegratedAvailability();
  }

  @override
  void didUpdateWidget(SpStep3SelectTime oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 프로 선택 정보가 변경된 경우 디버깅 정보 출력
    if (widget.selectedProId != oldWidget.selectedProId ||
        widget.selectedProName != oldWidget.selectedProName) {
      print('');
      print('🔄 Step3 위젯 업데이트됨 - 프로 선택 정보 변경');
      print('이전 프로 ID: ${oldWidget.selectedProId}');
      print('새로운 프로 ID: ${widget.selectedProId}');
      print('이전 프로 이름: ${oldWidget.selectedProName}');
      print('새로운 프로 이름: ${widget.selectedProName}');
      print('');
      
      // 프로 정보가 변경된 경우 통합 가용성 다시 로드
      _loadIntegratedAvailability();
    }
  }

  void _debugPrintAllInfo() {
    print('');
    print('═══════════════════════════════════════════════════════════');
    print('STEP3 디버깅 정보');
    print('═══════════════════════════════════════════════════════════');

    // 기본 정보
    final branchId = ApiService.getCurrentBranchId();
    final currentUser = widget.selectedMember ?? ApiService.getCurrentUser();
    final memberId = currentUser?['member_id']?.toString();

    print('branch_id: $branchId (ApiService.getCurrentBranchId())');
    print('member_id: $memberId');
    
    // hasInstructorOption 계산
    int totalLsMin = 0;
    widget.specialSettings.forEach((key, value) {
      if (key.startsWith('ls_min(')) {
        int minValue = 0;
        if (value != null && value.toString().isNotEmpty) {
          minValue = int.tryParse(value.toString()) ?? 0;
        }
        totalLsMin += minValue;
      }
    });
    final hasInstructorOption = totalLsMin > 0;
    print('hasInstructorOption: $hasInstructorOption (총 레슨시간: ${totalLsMin}분)');
    
    // 저장된 설정 변수들
    print('');
    print('저장된 설정 변수들:');
    widget.specialSettings.forEach((key, value) {
      print('$key = $value');
    });
    
    // 선택된 정보들 (이전 단계에서 전달받은 정보만)
    print('');
    print('이전 단계에서 전달받은 정보:');
    print('selectedDate: ${widget.selectedDate != null ? DateFormat('yyyy-MM-dd').format(widget.selectedDate!) : 'null'}');
    print('selectedProId: ${widget.selectedProId ?? 'null'}');
    print('selectedProName: ${widget.selectedProName ?? 'null'}');
    
    print('═══════════════════════════════════════════════════════════');
    print('');
  }

  Future<void> _loadProScheduleData() async {
    try {
      final currentUser = widget.selectedMember ?? ApiService.getCurrentUser();
      if (currentUser != null && currentUser['member_id'] != null) {
        final memberId = currentUser['member_id'].toString();
        print('   🔍 getMemberLsCountingData 호출 (memberId: $memberId)');
        final result = await ApiService.getMemberLsCountingData(memberId: memberId);
        
        if (result['success'] == true) {
          _lessonCountingData = result;
          
          if (result['debug_info'] != null) {
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
          }
        }
      }
    } catch (e) {
      print('프로 스케줄 데이터 로드 실패: $e');
    }
  }

  // 통합 가용성 로드
  Future<void> _loadIntegratedAvailability() async {
    print('');
    print('╔═══════════════════════════════════════════════════════════╗');
    print('║  [STEP3] 통합 가용성 로드 시작                           ║');
    print('╚═══════════════════════════════════════════════════════════╝');
    print('');

    try {
      setState(() {
        _isLoading = true;
        _integratedOptions = [];
        _availableTimeRanges = [];
        _selectedTimeSlot = null;
        _selectedTimeRange = null;
      });

      print('✅ 1단계: 로딩 상태 설정 완료');

      // branchId는 ApiService에서 가져오기
      final branchId = ApiService.getCurrentBranchId();
      if (branchId == null || branchId.isEmpty) {
        print('');
        print('❌❌❌ branchId 없음! ❌❌❌');
        print('   ApiService.getCurrentBranchId(): $branchId');
        return;
      }

      // memberId는 selectedMember 또는 currentUser에서 가져오기
      final currentUser = widget.selectedMember ?? ApiService.getCurrentUser();
      if (currentUser == null) {
        print('');
        print('❌❌❌ 현재 사용자 정보 없음! ❌❌❌');
        print('   widget.selectedMember: ${widget.selectedMember}');
        print('   ApiService.getCurrentUser(): ${ApiService.getCurrentUser()}');
        return;
      }

      final memberId = currentUser['member_id']?.toString();
      if (memberId == null || memberId.isEmpty) {
        print('');
        print('❌❌❌ memberId 없음! ❌❌❌');
        print('   memberId: $memberId');
        print('   currentUser 전체: $currentUser');
        return;
      }

      print('✅ 2단계: branchId, memberId 확인 완료');
      print('   branchId: $branchId (ApiService.getCurrentBranchId())');
      print('   memberId: $memberId (currentUser[member_id])');

      if (widget.selectedDate == null) {
        print('');
        print('❌❌❌ 선택된 날짜 없음! ❌❌❌');
        return;
      }

      print('✅ 3단계: 선택된 날짜 확인 완료');
      print('   selectedDate: ${widget.selectedDate}');
      print('   selectedProId: ${widget.selectedProId}');
      print('   selectedProName: ${widget.selectedProName}');

      // 통합 가용성 조회
      print('');
      print('🔄 4단계: SpIntegratedAvailabilityService.findIntegratedAvailableOptions 호출');
      print('   매개변수:');
      print('     - branchId: $branchId');
      print('     - memberId: $memberId');
      print('     - selectedDate: ${widget.selectedDate}');
      print('     - selectedProId: ${widget.selectedProId}');
      print('     - selectedProName: ${widget.selectedProName}');
      print('     - specialSettings: ${widget.specialSettings}');
      print('');

      final result = await SpIntegratedAvailabilityService.findIntegratedAvailableOptions(
        branchId: branchId,
        memberId: memberId,
        selectedDate: widget.selectedDate!,
        selectedProId: widget.selectedProId?.toString(),
        selectedProName: widget.selectedProName,
        specialSettings: widget.specialSettings,
      );

      print('');
      print('✅ 5단계: 통합 가용성 서비스 호출 완료');
      print('   result success: ${result['success']}');
      print('   result error: ${result['error']}');

      if (result['success'] == true) {
        final integratedOptions = result['integrated_options'] as List<Map<String, dynamic>>;
        print('✅ 6단계: 통합 옵션 파싱 완료');
        print('   통합 옵션 개수: ${integratedOptions.length}');

        setState(() {
          _integratedOptions = integratedOptions;
        });

        // 시간 범위 계산
        _calculateTimeRanges();

        print('✅ 7단계: UI 상태 업데이트 완료');
        print('   _integratedOptions.length: ${_integratedOptions.length}');
        print('   _availableTimeRanges.length: ${_availableTimeRanges.length}');

      } else {
        print('❌ 통합 가용성 조회 실패: ${result['error']}');
        setState(() {
          _integratedOptions = [];
          _availableTimeRanges = [];
        });
      }
      
    } catch (e, stackTrace) {
      print('❌ 통합 가용성 로드 실패: $e');
      print('❌ 스택 트레이스: $stackTrace');
      setState(() {
        _integratedOptions = [];
        _availableTimeRanges = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      print('✅ 최종: 로딩 상태 해제 완료');
      print('   최종 _integratedOptions.length: ${_integratedOptions.length}');
      print('   최종 _availableTimeRanges.length: ${_availableTimeRanges.length}');
      print('   최종 _isLoading: $_isLoading');
    }
  }

  // 시간 범위 계산
  void _calculateTimeRanges() {
    _availableTimeRanges = [];

    if (_integratedOptions.isEmpty) return;

    print('\n=== 시간 범위 계산 시작 ===');

    // 시작시간들을 분 단위로 추출하고 정렬
    List<int> startTimeMinutes = [];
    for (var option in _integratedOptions) {
      final startTime = option['start_time']?.toString() ?? '';
      if (startTime.isNotEmpty) {
        final minutes = _timeToMinutes(startTime);
        if (!startTimeMinutes.contains(minutes)) {
          startTimeMinutes.add(minutes);
        }
      }
    }
    startTimeMinutes.sort();

    print('가용한 시작시간들: ${startTimeMinutes.map((m) => _minutesToTime(m)).join(", ")}');

    // 연속된 시간들을 범위로 그룹핑
    if (startTimeMinutes.isNotEmpty) {
      int rangeStart = startTimeMinutes[0];
      int rangeEnd = startTimeMinutes[0];

      for (int i = 1; i < startTimeMinutes.length; i++) {
        final timeDiff = startTimeMinutes[i] - rangeEnd;
        // 5~15분 이내 차이면 연속으로 간주
        if (timeDiff > 0 && timeDiff <= 15) {
          rangeEnd = startTimeMinutes[i];
        } else {
          // 연속이 끊어짐 - 이전 범위 추가
          _addTimeRange(rangeStart, rangeEnd);
          rangeStart = startTimeMinutes[i];
          rangeEnd = startTimeMinutes[i];
        }
      }
      // 마지막 범위 추가
      _addTimeRange(rangeStart, rangeEnd);
    }

    print('계산된 시간 범위: ${_availableTimeRanges.length}개');
    for (var range in _availableTimeRanges) {
      print('  • ${range['formatted']}');
    }
    print('================================\n');

    if (mounted) {
      setState(() {});
    }
  }

  // 시간 문자열을 분 단위로 변환 (HH:MM)
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

  // 시간 범위 추가
  void _addTimeRange(int startMinutes, int endMinutes) {
    // 프로그램 최소 시간 가져오기
    int totalProgramMin = int.tryParse(widget.specialSettings['ts_min']?.toString() ?? '0') ?? 0;

    // 범위의 실제 종료시간은 마지막 시작시간 + 프로그램 시간
    final actualEndMinutes = endMinutes + totalProgramMin;

    _availableTimeRanges.add({
      'formatted': '${_minutesToTime(startMinutes)}~${_minutesToTime(actualEndMinutes)}',
      'startMinutes': startMinutes,
      'endMinutes': endMinutes, // 마지막으로 시작 가능한 시간
    });
  }

  // 시간대 선택 시 모달 팝업 표시
  void _showTimeOptionsModal(Map<String, dynamic> timeRange) {
    final startMinutes = timeRange['startMinutes'] as int;
    final endMinutes = timeRange['endMinutes'] as int;

    // 총 프로그램 시간은 ts_min 값 사용
    int totalProgramMin = int.tryParse(widget.specialSettings['ts_min']?.toString() ?? '0') ?? 0;

    // 이 시간 범위 내의 모든 시작시간 옵션들 필터링
    List<String> validStartTimes = [];
    for (var option in _integratedOptions) {
      final startTime = option['start_time']?.toString() ?? '';
      if (startTime.isNotEmpty) {
        final timeMinutes = _timeToMinutes(startTime);
        if (timeMinutes >= startMinutes && timeMinutes <= endMinutes) {
          if (!validStartTimes.contains(startTime)) {
            validStartTimes.add(startTime);
          }
        }
      }
    }
    validStartTimes.sort();

    if (validStartTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이 시간대에는 선택 가능한 시작시간이 없습니다.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 헤더
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: Color(0xFF3B82F6),
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '시작시간 선택',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: Color(0xFF666666)),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    '최소 프로그램 시간: ${totalProgramMin}분',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // 시간 조합 그리드 (3열)
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 2.0,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: validStartTimes.length,
                      itemBuilder: (context, index) {
                        final startTime = validStartTimes[index];

                        return InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            setState(() {
                              _selectedTimeRange = timeRange['formatted'];
                            });
                            _onTimeSlotSelected(startTime);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Color(0xFF3B82F6),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF3B82F6).withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                startTime,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E40AF),
                                ),
                                textAlign: TextAlign.center,
                              ),
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
        );
      },
    );
  }

  // 시간 선택 처리
  void _onTimeSlotSelected(String timeSlot) {
    setState(() {
      _selectedTimeSlot = timeSlot;
    });
    
    print('🔍 시간 선택 디버깅 시작: $timeSlot');
    print('🔍 전체 _integratedOptions 개수: ${_integratedOptions.length}');
    
    // 선택된 시간에 해당하는 타석 정보 찾기
    List<Map<String, dynamic>> availableTsList = [];
    Map<String, dynamic> allTsDetails = {};
    
    for (int i = 0; i < _integratedOptions.length; i++) {
      final option = _integratedOptions[i];
      final startTime = option['start_time']?.toString() ?? '';
      
      print('🔍 옵션 $i: start_time = "$startTime", 비교 대상 = "$timeSlot"');
      
      if (startTime == timeSlot) {
        print('🎯 매칭된 옵션 발견!');
        print('🔍 옵션 전체 내용: $option');
        
        // 가용한 타석 정보
        final tsList = option['available_ts'] as List<dynamic>?;
        if (tsList != null) {
          availableTsList = tsList.map((ts) => ts as Map<String, dynamic>).toList();
          print('🔍 타석 목록 변환 완료: ${availableTsList.length}개');
          for (int j = 0; j < availableTsList.length; j++) {
            print('🔍 타석 $j: ${availableTsList[j]}');
          }
        } else {
          print('🔍 available_ts가 null입니다');
        }
        
        // 타석 상세 정보 구성 (가용/불가용 모든 타석 정보)
        allTsDetails = {
          'available_ts': availableTsList,
          'selected_time': timeSlot,
          'option_details': option,
        };
        
        break;
      }
    }
    
    print('🎯 시간 선택됨: $timeSlot');
    print('🎯 가용 타석 정보: ${availableTsList.length}개');
    
    // 시간과 타석 정보를 함께 전달
    widget.onTimeSelected(timeSlot, availableTsList);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('예약 가능한 시간을 검색하는 중...'),
          ],
        ),
      );
    }

    if (_availableTimeRanges.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.schedule_outlined,
                size: 48,
                color: Color(0xFF9CA3AF),
              ),
              SizedBox(height: 12),
              Text(
                '예약 가능한 시간이 없습니다',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF4B5563),
                ),
              ),
              SizedBox(height: 4),
              Text(
                '다른 날짜나 조건을 선택해주세요',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9CA3AF),
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
          // 시간대 선택 그리드
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.5,
            ),
            itemCount: _availableTimeRanges.length,
            itemBuilder: (context, index) {
              final timeRange = _availableTimeRanges[index];
              final isSelected = _selectedTimeRange == timeRange['formatted'];

              return InkWell(
                onTap: () => _showTimeOptionsModal(timeRange),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? Color(0xFF3B82F6) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Color(0xFF3B82F6) : Color(0xFFE5E7EB),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      timeRange['formatted'],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : Color(0xFF4B5563),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // 선택된 시간 표시
          Container(
            margin: EdgeInsets.only(top: 24),
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 12),
                Text(
                  _selectedTimeSlot != null
                      ? '프로그램 시작시간  $_selectedTimeSlot'
                      : '시작시간 범위를 선택해주세요',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _selectedTimeSlot != null ? Color(0xFF1F2937) : Color(0xFF9CA3AF),
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