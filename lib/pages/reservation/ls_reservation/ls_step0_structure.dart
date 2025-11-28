import 'package:flutter/material.dart';
import 'ls_step1_select_date.dart';
import 'ls_step2_select_instructor.dart';
import 'ls_step3_select_time.dart';
import 'ls_step4_select_duration.dart';
import 'ls_step5_paying.dart';
import 'ls_step6_request.dart';
import 'package:intl/intl.dart';
import '../../../services/stepper/stepper_service.dart';
import '../../../services/stepper/step_model.dart';
import '../../../widgets/custom_stepper.dart';
import '../../../services/api_service.dart';
import '../../../main_page.dart';
import '../../../widgets/ad_banner_widget.dart';

class LsStep0Structure extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const LsStep0Structure({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _LsStep0StructureState createState() => _LsStep0StructureState();
}

class _LsStep0StructureState extends State<LsStep0Structure> with TickerProviderStateMixin {
  late StepperService _stepperService;

  // GlobalKey 리스트 추가
  final List<GlobalKey> _stepKeys = List.generate(6, (index) => GlobalKey());

  // 애니메이션 컨트롤러
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // 예약 정보
  DateTime? _selectedDate;
  String? _selectedInstructorId;
  String? _selectedInstructorName;
  String? _selectedTime;
  int? _selectedDuration;
  dynamic _selectedMembership;
  String? _selectedRequest;

  // 레슨 관련 데이터
  Map<String, dynamic>? _lessonCountingData;  // 레슨 카운팅 데이터
  Map<String, Map<String, dynamic>> _proInfoMap = {};  // 프로 정보
  Map<String, Map<String, Map<String, dynamic>>> _proScheduleMap = {};  // 프로 스케줄
  
  // 날짜 선택 시 데이터 업데이트
  void _updateLessonData({
    required Map<String, dynamic>? lessonCountingData,
    required Map<String, Map<String, dynamic>> proInfoMap,
    required Map<String, Map<String, Map<String, dynamic>>> proScheduleMap,
  }) {
    setState(() {
      _lessonCountingData = lessonCountingData;
      _proInfoMap = proInfoMap;
      _proScheduleMap = proScheduleMap;
    });
  }

  // 각 스텝에서 사용할 수 있는 데이터 접근자
  Map<String, dynamic>? get lessonCountingData => _lessonCountingData;
  Map<String, Map<String, dynamic>> get proInfoMap => _proInfoMap;
  Map<String, Map<String, Map<String, dynamic>>> get proScheduleMap => _proScheduleMap;

  @override
  void initState() {
    super.initState();
    _stepperService = StepperService();
    _initAnimations();
    _initializeSteps();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  void _initializeSteps() {
    final steps = [
      StepModel(
        title: '날짜 선택',
        icon: '📅',
        color: Color(0xFF3B82F6),
        content: LsStep1SelectDate(
          key: _stepKeys[0],  // GlobalKey 추가
          isAdminMode: widget.isAdminMode,
          selectedMember: widget.selectedMember,
          branchId: widget.branchId,
          onDateSelected: _onDateSelected,
          selectedDate: _selectedDate,
        ),
      ),
      StepModel(
        title: '프로 선택',
        icon: '👨‍🏫',
        color: Color(0xFF8B5CF6),
        content: LsStep2SelectInstructor(
          isAdminMode: widget.isAdminMode,
          selectedMember: widget.selectedMember,
          branchId: widget.branchId,
          selectedDate: _selectedDate,
          onInstructorSelected: _onInstructorSelected,
          selectedInstructor: _selectedInstructorId,
          lessonCountingData: _lessonCountingData,
          proInfoMap: _proInfoMap,
          proScheduleMap: _proScheduleMap,
          onDateChanged: _onDateChanged,  // 새로운 콜백 메서드 사용
        ),
      ),
      StepModel(
        title: '시작시간',
        icon: '🕐',
        color: Color(0xFFEF4444),
        content: LsStep3SelectTime(
          isAdminMode: widget.isAdminMode,
          selectedMember: widget.selectedMember,
          branchId: widget.branchId,
          selectedDate: _selectedDate,
          selectedInstructor: _selectedInstructorId,
          onTimeSelected: _onTimeSelected,
          selectedTime: _selectedTime,
          lessonCountingData: _lessonCountingData,
          proInfoMap: _proInfoMap,
          proScheduleMap: _proScheduleMap,
        ),
      ),
      StepModel(
        title: '레슨시간',
        icon: '⏱️',
        color: Color(0xFFF59E0B),
        content: LsStep4SelectDuration(
          isAdminMode: widget.isAdminMode,
          selectedMember: widget.selectedMember,
          branchId: widget.branchId,
          selectedDate: _selectedDate,
          selectedInstructor: _selectedInstructorId,
          selectedTime: _selectedTime,
          onDurationSelected: _onDurationSelected,
          selectedDuration: _selectedDuration,
          lessonCountingData: _lessonCountingData,
          proInfoMap: _proInfoMap,
          proScheduleMap: _proScheduleMap,
        ),
      ),
      StepModel(
        title: '회원권선택',
        icon: '💳',
        color: Color(0xFF10B981),
        content: LsStep5Paying(
          isAdminMode: widget.isAdminMode,
          selectedMember: widget.selectedMember,
          branchId: widget.branchId,
          selectedDate: _selectedDate,
          selectedInstructor: _selectedInstructorId,
          selectedTime: _selectedTime,
          selectedDuration: _selectedDuration,
          onMembershipSelected: _onMembershipSelected,
          selectedMembership: _selectedMembership,
          lessonCountingData: _lessonCountingData,
          proInfoMap: _proInfoMap,
          proScheduleMap: _proScheduleMap,
        ),
      ),
      StepModel(
        title: '요청사항',
        icon: '📝',
        color: Color(0xFF6B7280),
        content: LsStep6Request(
          isAdminMode: widget.isAdminMode,
          selectedMember: widget.selectedMember,
          branchId: widget.branchId,
          selectedDate: _selectedDate,
          selectedInstructor: _selectedInstructorId,
          selectedTime: _selectedTime,
          selectedDuration: _selectedDuration,
          selectedMembership: _selectedMembership,
          onRequestSubmitted: _onRequestSelected,
          requestText: _selectedRequest,
          lessonCountingData: _lessonCountingData,
          proInfoMap: _proInfoMap,
          proScheduleMap: _proScheduleMap,
        ),
      ),
    ];

    _stepperService.initialize(steps);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _stepperService.dispose();
    super.dispose();
  }
  
  // 간단한 콜백 함수들
  void _onDateSelected(DateTime date, Map<String, dynamic> data) {
    setState(() {
      _selectedDate = date;
      if (data['lessonCountingData'] != null) {
        _updateLessonData(
          lessonCountingData: data['lessonCountingData'],
          proInfoMap: data['proInfoMap'] ?? {},
          proScheduleMap: data['proScheduleMap'] ?? {},
        );
      }
    });
    _updateStepValue();
  }
  
  void _onInstructorSelected(String instructor) {
    print('Instructor selected: $instructor'); // 디버깅용 로그 추가
    setState(() {
      _selectedInstructorId = instructor;
      // proInfoMap에서 프로 이름 가져오기
      final proName = _proInfoMap[instructor]?['pro_name'] ?? instructor;
      _selectedInstructorName = instructor.isEmpty ? null : '$proName 프로';
    });
    _updateStepValue();
    _refreshStepContent(); // 스텝 콘텐츠 새로고침 추가
  }
  
  void _onTimeSelected(String time) {
    setState(() {
      _selectedTime = time;
    });
    _updateStepValue();
    _refreshStepContent(); // UI 즉시 업데이트를 위해 추가
  }
  
  void _onDurationSelected(int duration) {
    setState(() {
      _selectedDuration = duration;
    });
    _updateStepValue();
  }
  
  void _onMembershipSelected(dynamic membership) {
    setState(() {
      _selectedMembership = membership;
    });
    _updateStepValue();
  }
  
  void _onRequestSelected(String request) {
    setState(() {
      _selectedRequest = request;
    });
    _updateStepValue();
  }

  void _updateStepValue() {
    final currentStep = _stepperService.currentStep;
    String? value;
    
    switch (currentStep) {
      case 0:
        if (_selectedDate != null) {
          final weekdays = ['', '월', '화', '수', '목', '금', '토', '일'];
          final weekday = weekdays[_selectedDate!.weekday];
          value = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}($weekday)';
        }
        break;
      case 1:
        value = _selectedInstructorName;
        break;
      case 2:
        value = _selectedTime;
        break;
      case 3:
        value = _selectedDuration != null ? '${_selectedDuration}분' : null;
        break;
      case 4:
        // 회원권선택 - List인 경우 복수 회원권, Map인 경우 단일 회원권
        if (_selectedMembership is List) {
          final membershipList = _selectedMembership as List;
          if (membershipList.isNotEmpty) {
            // 첫 번째 회원권 이름 추출
            String firstName = '';
            final firstItem = membershipList[0];

            if (firstItem is Map<String, dynamic>) {
              firstName = firstItem['contract_name'] ?? '';
            }

            // 여러 개 선택된 경우
            if (membershipList.length > 1) {
              value = '$firstName 외 ${membershipList.length - 1}개';
            } else {
              value = firstName;
            }
          }
        } else if (_selectedMembership is Map<String, dynamic>) {
          final membershipMap = _selectedMembership as Map<String, dynamic>;
          value = membershipMap['contract_name'] ?? '선택된 계약';
        }
        break;
      case 5:
        // 요청사항 간략 표시 로직
        if (_selectedRequest != null && _selectedRequest!.isNotEmpty) {
          // 집중 분야와 추가 요청사항 분리
          final lines = _selectedRequest!.split('\n');
          String focusAreas = '';
          String additionalRequest = '';
          
          for (String line in lines) {
            if (line.startsWith('집중 분야:')) {
              focusAreas = line.substring(6).trim(); // '집중 분야:' 제거
            } else if (line.startsWith('추가 요청사항:')) {
              additionalRequest = line.substring(8).trim(); // '추가 요청사항:' 제거
            } else if (focusAreas.isEmpty) {
              // 집중 분야 없이 바로 텍스트인 경우
              additionalRequest = line.trim();
            }
          }
          
          // 집중 분야 간략 표시
          if (focusAreas.isNotEmpty) {
            final areas = focusAreas.split(', ');
            int totalCount = areas.length;
            
            // 추가 요청사항이 있으면 카운트에 1 추가
            if (additionalRequest.isNotEmpty) {
              totalCount += 1;
            }
            
            if (totalCount == 1) {
              value = areas[0];
            } else {
              value = '${areas[0]} 외 ${totalCount - 1}';
            }
          } else if (additionalRequest.isNotEmpty) {
            // 집중 분야 없이 추가 요청사항만 있는 경우
            value = additionalRequest.length > 15 
                ? '${additionalRequest.substring(0, 15)}...' 
                : additionalRequest;
          }
        }
        break;
    }
    
    _stepperService.updateCurrentStepValue(value);
  }

  void _onDateChanged(DateTime newDate) {
    // 날짜 선택 스텝으로 이동
    _stepperService.goToStep(0);
    
    // 날짜 선택 처리
    if (_selectedDate != newDate) {
      setState(() {
        _selectedDate = newDate;
      });
      
      // 날짜가 변경되었으므로 관련 데이터 초기화
      _selectedInstructorId = null;
      _selectedInstructorName = null;
      _selectedTime = null;
      _selectedDuration = null;
      _selectedMembership = null;
      _selectedRequest = null;

      // 스텝 값 업데이트 (상단 날짜 표시 업데이트)
      _updateStepValue();
      
      // 스텝 콘텐츠 새로고침
      _refreshStepContent();

      // 날짜 선택 이벤트 발생 (캘린더 업데이트)
      final Map<String, dynamic> data = {
        'lessonCountingData': _lessonCountingData,
        'proInfoMap': _proInfoMap,
        'proScheduleMap': _proScheduleMap,
      };
      _onDateSelected(newDate, data);
    }
  }

  void _refreshStepContent() {
    // 기존 스텝 데이터를 유지하면서 콘텐츠만 업데이트
    final currentSteps = _stepperService.steps;
    for (int i = 0; i < currentSteps.length; i++) {
      Widget newContent;
      switch (i) {
        case 0:
          newContent = LsStep1SelectDate(
            key: _stepKeys[0],
            isAdminMode: widget.isAdminMode,
            selectedMember: widget.selectedMember,
            branchId: widget.branchId,
            onDateSelected: _onDateSelected,
            selectedDate: _selectedDate,
          );
          break;
        case 1:
          newContent = LsStep2SelectInstructor(
            key: _stepKeys[1], // GlobalKey 추가
            isAdminMode: widget.isAdminMode,
            selectedMember: widget.selectedMember,
            branchId: widget.branchId,
            selectedDate: _selectedDate,
            onInstructorSelected: _onInstructorSelected,
            selectedInstructor: _selectedInstructorId,
            lessonCountingData: _lessonCountingData,
            proInfoMap: _proInfoMap,
            proScheduleMap: _proScheduleMap,
            onDateChanged: _onDateChanged,
          );
          break;
        case 2:
          newContent = LsStep3SelectTime(
            isAdminMode: widget.isAdminMode,
            selectedMember: widget.selectedMember,
            branchId: widget.branchId,
            selectedDate: _selectedDate,
            selectedInstructor: _selectedInstructorId,
            onTimeSelected: _onTimeSelected,
            selectedTime: _selectedTime,
            lessonCountingData: _lessonCountingData,
            proInfoMap: _proInfoMap,
            proScheduleMap: _proScheduleMap,
          );
          break;
        case 3:
          newContent = LsStep4SelectDuration(
            isAdminMode: widget.isAdminMode,
            selectedMember: widget.selectedMember,
            branchId: widget.branchId,
            selectedDate: _selectedDate,
            selectedInstructor: _selectedInstructorId,
            selectedTime: _selectedTime,
            onDurationSelected: _onDurationSelected,
            selectedDuration: _selectedDuration,
            lessonCountingData: _lessonCountingData,
            proInfoMap: _proInfoMap,
            proScheduleMap: _proScheduleMap,
          );
          break;
        case 4:
          newContent = LsStep5Paying(
            key: _stepKeys[4],
            isAdminMode: widget.isAdminMode,
            selectedMember: widget.selectedMember,
            branchId: widget.branchId,
            selectedDate: _selectedDate,
            selectedInstructor: _selectedInstructorId,
            selectedTime: _selectedTime,
            selectedDuration: _selectedDuration,
            onMembershipSelected: _onMembershipSelected,
            selectedMembership: _selectedMembership,
            lessonCountingData: _lessonCountingData,
            proInfoMap: _proInfoMap,
            proScheduleMap: _proScheduleMap,
          );
          break;
        case 5:
          newContent = LsStep6Request(
            isAdminMode: widget.isAdminMode,
            selectedMember: widget.selectedMember,
            branchId: widget.branchId,
            selectedDate: _selectedDate,
            selectedInstructor: _selectedInstructorId,
            selectedTime: _selectedTime,
            selectedDuration: _selectedDuration,
            selectedMembership: _selectedMembership,
            onRequestSubmitted: _onRequestSelected,
            requestText: _selectedRequest,
            lessonCountingData: _lessonCountingData,
            proInfoMap: _proInfoMap,
            proScheduleMap: _proScheduleMap,
          );
          break;
        default:
          newContent = Container();
      }
      
      _stepperService.steps[i] = currentSteps[i].copyWith(content: newContent);
    }
  }

  // 유효성 검사 다이얼로그 표시
  void _showValidationDialog(String title, String message) {
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('확인'),
            ),
          ],
        );
      },
    );
  }

  void _onNext() async {
    // Step5 (결제수단 선택)에서 유효성 검사
    if (_stepperService.currentStep == 4) { // Step5 (0-based index)
      if (_selectedMembership == null) {
        // 선택된 결제수단이 없으면 경고 메시지 표시
        _showValidationDialog('결제수단을 선택해주세요', '이용 가능한 레슨권을 선택한 후 다음 단계로 진행할 수 있습니다.');
        return;
      }

      // Step5 위젯에 접근하여 결제 완료 여부 확인
      final step5Key = _stepKeys[4];
      final step5State = step5Key.currentState;
      if (step5State != null) {
        try {
          // dynamic으로 접근하여 isPaymentComplete 메서드 호출
          final isComplete = (step5State as dynamic).isPaymentComplete();
          if (!isComplete) {
            // 결제가 완료되지 않았으면 경고 메시지 표시
            _showValidationDialog(
              '결제가 완료되지 않았습니다',
              '선택하신 레슨권으로 레슨 시간을 모두 커버할 수 없습니다.\n추가 레슨권을 선택하거나 레슨 시간을 조정해주세요.',
            );
            return;
          }
        } catch (e) {
          print('결제 완료 여부 확인 중 오류: $e');
        }
      }
    }

    _stepperService.nextStep();
    // 다음 단계로 이동 후 콘텐츠 새로고침
    setState(() {
      _refreshStepContent();
    });
  }

  void _onPrevious() {
    _stepperService.previousStep();
    // 이전 단계로 이동 후 콘텐츠 새로고침
    setState(() {
      _refreshStepContent();
    });
  }

  void _onComplete() async {
    try {
      // 로딩 다이얼로그 표시
      showDialog(
        context: context,
        barrierDismissible: false,
      useRootNavigator: false,
        builder: (BuildContext context) {
          return Dialog(
            child: Container(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text('예약을 저장하고 있습니다...'),
                ],
              ),
            ),
          );
        },
      );

      // 선택된 멤버십에서 필요한 정보 추출
      String? memberId;
      String? memberName;
      String? memberType;

      if (widget.selectedMember != null) {
        memberId = widget.selectedMember!['member_id']?.toString();
        memberName = widget.selectedMember!['member_name']?.toString();
        memberType = widget.selectedMember!['member_type']?.toString();
      }

      // LS_id 생성 (레슨 예약과 동일한 형식)
      final dateFormat = DateFormat('yyMMdd');
      final timeFormat = DateFormat('HHmm');
      final dateStr = dateFormat.format(_selectedDate!);
      final timeStr = timeFormat.format(DateFormat('HH:mm').parse(_selectedTime!));
      final lsId = '${dateStr}_${_selectedInstructorId!}_$timeStr';

      // v2_LS_orders: 레슨 예약 저장 (1건)
      await ApiService.saveLessonOrder(
        selectedDate: _selectedDate!,
        selectedTime: _selectedTime!,
        proId: _selectedInstructorId!,
        proName: _proInfoMap[_selectedInstructorId!]?['pro_name'] ?? '',
        memberId: memberId ?? '',
        memberName: memberName ?? '',
        memberType: memberType ?? 'regular',
        netMinutes: _selectedDuration!,
        request: _selectedRequest,
        branchId: widget.branchId,
      );

      // v3_LS_countings: 레슨 카운팅 데이터 저장 (레슨권별로 저장)
      if (_selectedMembership != null) {
        List<Map<String, dynamic>> lessonInfoList = [];

        // List인 경우 (복수 레슨권)
        if (_selectedMembership is List) {
          lessonInfoList = (_selectedMembership as List)
              .map((item) => item as Map<String, dynamic>)
              .toList();
          print('=== 복수 레슨권 저장 ===');
          print('레슨권 개수: ${lessonInfoList.length}개');
        }
        // Map인 경우 (단일 레슨권)
        else if (_selectedMembership is Map<String, dynamic>) {
          lessonInfoList = [_selectedMembership as Map<String, dynamic>];
          print('=== 단일 레슨권 저장 ===');
        }

        // 각 레슨권별로 카운팅 데이터 저장
        for (int i = 0; i < lessonInfoList.length; i++) {
          final lessonInfo = lessonInfoList[i];

          final contractHistoryId = lessonInfo['contract_history_id']?.toString();
          final balanceMinBefore = int.tryParse(lessonInfo['LS_balance_min_before']?.toString() ?? '0');
          final balanceMinAfter = int.tryParse(lessonInfo['LS_balance_min_after']?.toString() ?? '0');
          final lsExpiryDate = lessonInfo['LS_expiry_date']?.toString();
          final netMinutes = int.tryParse(lessonInfo['LS_net_min']?.toString() ?? '0') ?? 0;

          print('\n=== 레슨권 ${i + 1} 저장 정보 ===');
          print('contract_history_id: $contractHistoryId');
          print('contract_name: ${lessonInfo['contract_name']}');
          print('LS_net_min: $netMinutes분');
          print('LS_balance_min_before: $balanceMinBefore');
          print('LS_balance_min_after: $balanceMinAfter');
          print('LS_expiry_date: $lsExpiryDate');

          if (contractHistoryId != null &&
              balanceMinBefore != null &&
              balanceMinAfter != null &&
              lsExpiryDate != null &&
              netMinutes > 0) {

            await ApiService.saveLessonCounting(
              lsId: lsId,
              selectedDate: _selectedDate!,
              memberId: memberId ?? '',
              memberName: memberName ?? '',
              memberType: memberType ?? 'regular',
              proId: _selectedInstructorId!,
              proName: _proInfoMap[_selectedInstructorId!]?['pro_name'] ?? '',
              contractHistoryId: contractHistoryId,
              netMinutes: netMinutes,
              balanceMinBefore: balanceMinBefore,
              balanceMinAfter: balanceMinAfter,
              lsExpiryDate: lsExpiryDate,
              branchId: widget.branchId,
            );

            print('✅ 레슨권 ${i + 1} 카운팅 저장 완료');
          } else {
            print('⚠️ 레슨권 ${i + 1} 저장 조건 불충족 - 건너뜀');
          }
        }

        print('======================\n');
      }

      // 로딩 다이얼로그 닫기
      Navigator.of(context).pop();
      
      // 성공 다이얼로그 표시
      _showSuccessDialog();
      
    } catch (e) {
      // 로딩 다이얼로그 닫기
      Navigator.of(context).pop();

      // 오류 다이얼로그 표시
      showDialog(
        context: context,
        useRootNavigator: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('예약 저장 실패'),
            content: Text('예약 저장 중 오류가 발생했습니다:\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('확인'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              // 메인 콘텐츠 - 커스텀 스테퍼
              Expanded(
                child: CustomStepper(
                  stepperService: _stepperService,
                  onPrevious: _onPrevious,
                  onNext: _onNext,
                  onComplete: _onComplete,
                  previousButtonText: '이전',
                  nextButtonText: '다음',
                  completeButtonText: '완료',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 성공 다이얼로그
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false,
      builder: (BuildContext context) {
        bool isButtonEnabled = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            // 2초 후 버튼 활성화 타이머
            Future.delayed(Duration(seconds: 2), () {
              if (!isButtonEnabled) {
                setDialogState(() => isButtonEnabled = true);
              }
            });

            return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [Colors.white, Color(0xFFF8FAFC)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 성공 아이콘
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Color(0xFF00A86B),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                SizedBox(height: 24),

                // 제목
                Text(
                  '레슨 예약이 완료되었습니다!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A202C),
                  ),
                ),
                SizedBox(height: 16),
                
                // 예약 정보
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('날짜', () {
                        final weekdays = ['', '월', '화', '수', '목', '금', '토', '일'];
                        final weekday = weekdays[_selectedDate!.weekday];
                        return '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}($weekday)';
                      }()),
                      _buildInfoRow('프로', '$_selectedInstructorName'),
                      _buildInfoRow('시간', '$_selectedTime'),
                      _buildInfoRow('레슨시간', '${_selectedDuration}분'),
                      _buildMembershipInfoRow('회원권'),
                      _buildInfoRow('요청사항', '$_selectedRequest'),
                    ],
                  ),
                ),
                SizedBox(height: 8),

                // 배너 광고
                AdBannerWidget(
                  onAdLoaded: () {
                    setDialogState(() => isButtonEnabled = true);
                  },
                ),
                SizedBox(height: 8),

                // 확인 버튼
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: isButtonEnabled
                        ? [Color(0xFF00A86B), Color(0xFF00A86B).withOpacity(0.8)]
                        : [Colors.grey, Colors.grey.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: isButtonEnabled ? [
                      BoxShadow(
                        color: Color(0xFF00A86B).withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ] : [],
                  ),
                  child: ElevatedButton(
                    onPressed: isButtonEnabled ? () {
                      // 다이얼로그 닫기
                      Navigator.of(context).pop();

                      // 메인 페이지의 조회 탭(index 1)으로 이동
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => MainPage(
                            isAdminMode: widget.isAdminMode,
                            selectedMember: widget.selectedMember,
                            branchId: widget.branchId,
                            initialIndex: 1, // 조회 탭 선택
                          ),
                        ),
                      );
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '확인',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),
          ),
        );
          },
        );
      },
    );
  }

  Widget _buildMembershipInfoRow(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4A5568),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedMembership is List) ...[
                  // 복수 회원권 선택 시 모든 회원권 정보 표시
                  ...(_selectedMembership as List).asMap().entries.map((entry) {
                    final index = entry.key;
                    final membership = entry.value as Map<String, dynamic>;
                    final contractName = membership['contract_name'] ?? '선택된 계약';
                    final netMin = membership['LS_net_min'] ?? 0;
                    final balanceBefore = membership['LS_balance_min_before'] ?? 0;
                    final balanceAfter = membership['LS_balance_min_after'] ?? 0;

                    return Padding(
                      padding: EdgeInsets.only(bottom: index < (_selectedMembership as List).length - 1 ? 8 : 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contractName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '차감: ${netMin}분 / 잔여: ${balanceBefore}분 → ${balanceAfter}분',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ] else if (_selectedMembership is Map<String, dynamic>) ...[
                  // 단일 회원권 선택 시
                  Builder(
                    builder: (context) {
                      final membership = _selectedMembership as Map<String, dynamic>;
                      final contractName = membership['contract_name'] ?? '선택된 계약';
                      final netMin = membership['LS_net_min'] ?? 0;
                      final balanceBefore = membership['LS_balance_min_before'] ?? 0;
                      final balanceAfter = membership['LS_balance_min_after'] ?? 0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contractName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '차감: ${netMin}분 / 잔여: ${balanceBefore}분 → ${balanceAfter}분',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ] else ...[
                  Text(
                    '선택된 계약',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4A5568),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF1A202C),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 