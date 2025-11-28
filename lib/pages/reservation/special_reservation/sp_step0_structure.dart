import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/stepper/stepper_service.dart';
import '../../../services/stepper/step_model.dart';
import '../../../widgets/custom_stepper.dart';
import '../../../services/api_service.dart';
import 'sp_step1_select_date.dart';
import 'sp_step2_select_pro.dart';
import 'sp_step3_select_time.dart';
import 'sp_step4_select_ts.dart';
import 'sp_step5_paying.dart';
import 'sp_step6_group.dart';
import 'sp_db_update.dart';
import '../../../main_page.dart';
import '../../../widgets/ad_banner_widget.dart';

class SpStep0Structure extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;
  final String? specialType;

  const SpStep0Structure({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
    this.specialType,
  }) : super(key: key);

  @override
  _SpStep0StructureState createState() => _SpStep0StructureState();
}

class _SpStep0StructureState extends State<SpStep0Structure> with TickerProviderStateMixin {
  late StepperService _stepperService;
  
  // GlobalKey 리스트 (5단계 + 그룹레슨 초대 단계)
  final List<GlobalKey<State>> _stepKeys = List.generate(6, (index) => GlobalKey());
  
  // 애니메이션 컨트롤러
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // 특수 예약 설정 변수들 - 조회된 모든 설정을 개별 변수로 저장
  Map<String, dynamic> _specialSettings = {};
  bool _isSettingsLoaded = false;
  
  // 예약 정보 (향후 step에서 사용할 데이터들)
  DateTime? _selectedDate;
  int? _selectedInstructorId;
  String? _selectedInstructorName;
  String? _selectedTime;
  List<Map<String, dynamic>>? _availableTsList; // 가용 타석 정보 추가
  String? _selectedTsId;
  dynamic _selectedMembership;
  Map<String, dynamic>? _selectedContract; // 선택된 회원권 계약
  List<Map<String, dynamic>>? _invitedMembers; // 그룹레슨 초대 멤버들
  Map<String, dynamic>? _step5CalculatedData; // Step 5에서 계산된 데이터
  
  // 캐시된 회원권 데이터
  List<Map<String, dynamic>>? _cachedTimePassContracts; // 시간권 계약 데이터
  List<Map<String, dynamic>>? _cachedLessonContracts; // 레슨 계약 데이터
  bool _isMembershipDataLoaded = false; // 회원권 데이터 로드 상태
  
  @override
  void initState() {
    super.initState();
    _stepperService = StepperService();
    _initAnimations();
    _loadSpecialReservationSettings(); // 설정 먼저 로드
    // _loadMembershipData()는 설정 로드 완료 후에 호출됨
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

  // 특수 예약 설정 정보 로드
  Future<void> _loadSpecialReservationSettings() async {
    if (widget.specialType == null || widget.branchId == null) {
      print('특수 예약 타입 또는 지점 정보가 없습니다.');
      return;
    }

    try {
      print('');
      print('═══════════════════════════════════════════════════════════');
      print('특수 예약 설정 정보 조회');
      print('═══════════════════════════════════════════════════════════');
      print('특수 예약 타입: ${widget.specialType}');
      print('지점 ID: ${widget.branchId}');
      print('───────────────────────────────────────────────────────────');

      final settings = await ApiService.getData(
        table: 'v2_base_option_setting',
        fields: ['field_name', 'option_value', 'setting_status'],
        where: [
          {'field': 'category', 'operator': '=', 'value': '특수타석예약'},
          {'field': 'table_name', 'operator': '=', 'value': widget.specialType},
          {'field': 'branch_id', 'operator': '=', 'value': widget.branchId},
        ],
        orderBy: [
          {'field': 'field_name', 'direction': 'ASC'}
        ],
      );

      print('조회된 설정 수: ${settings.length}개');
      print('');

      if (settings.isEmpty) {
        print('설정 정보가 없습니다.');
      } else {
        // 조회된 모든 설정을 개별 변수로 저장하고 출력
        for (final setting in settings) {
          final fieldName = setting['field_name']?.toString() ?? '';
          final optionValue = setting['option_value']?.toString() ?? '';
          final settingStatus = setting['setting_status']?.toString() ?? '';
          
          // 변수로 저장 (field_name 원본을 키로 사용)
          _specialSettings[fieldName] = optionValue;
          
          // 출력
          print('$fieldName : $optionValue ($settingStatus)');
        }
      }
      
      print('');
      print('저장된 설정 변수들:');
      print('───────────────────────────────────────────────────────────');
      _specialSettings.forEach((fieldName, value) {
        print('$fieldName = $value');
      });
      
      print('═══════════════════════════════════════════════════════════');
      print('');

      setState(() {
        _isSettingsLoaded = true;
      });

      // 설정 로드 완료 후 회원권 데이터 로드
      print('🔧 설정 로드 완료 - 이제 회원권 데이터 로드 시작');
      await _loadMembershipData();
      print('🔧 회원권 데이터 로드 완료');


      // 회원권 검증 후 step 초기화
      _initializeSteps();

    } catch (e) {
      print('특수 예약 설정 조회 실패: $e');
      setState(() {
        _isSettingsLoaded = true;
        _hasValidMemberships = false;
        _membershipErrorMessage = '설정 정보를 불러오는 중 오류가 발생했습니다.';
        _isMembershipDataLoaded = true;
      });
      _initializeSteps();
    }
  }

  // 날짜 선택 콜백 메서드
  void _onDateSelected(DateTime? date) {
    setState(() {
      _selectedDate = date;
    });
    
    // StepperService에 선택된 값 업데이트 (사용자 친화적 형식으로)
    String? displayDate;
    if (date != null) {
      final weekdays = ['', '월', '화', '수', '목', '금', '토', '일'];
      final weekday = weekdays[date.weekday];
      displayDate = '${DateFormat('MM월 dd일').format(date)}($weekday)';
    }
    
    print('선택된 날짜: ${date != null ? DateFormat('yyyy-MM-dd').format(date) : '없음'}');
    
    // 날짜 선택 후 step들을 다시 초기화하여 새로운 날짜 정보를 전달
    _initializeSteps();
    
    // step 초기화 후 선택된 값을 다시 설정
    Future.microtask(() {
      _stepperService.updateCurrentStepValue(displayDate);
    });
  }

  // 프로 선택 콜백 메서드
  void _onProSelected(int proId, String proName) {
    print('선택된 프로: $proName ($proId)');
    
    setState(() {
      _selectedInstructorId = proId;
      _selectedInstructorName = proName;
    });
    
    // 현재 스텝 위치를 기억해놓기
    final currentStepIndex = _stepperService.currentStep;
    
    // 프로 선택 후 step들을 다시 초기화하여 새로운 프로 정보를 전달
    _initializeSteps();
    
    // step 초기화 후 원래 스텝 위치로 복원하고 선택된 값 설정
    Future.microtask(() {
      // 원래 스텝으로 돌아가기
      if (currentStepIndex >= 0) {
        _stepperService.goToStep(currentStepIndex);
      }
      _stepperService.updateCurrentStepValue(proName);
      
      // 이전 스텝들의 선택된 값들도 복원
      _restoreStepValues();
    });
  }

  // 시간 선택 콜백 메서드
  void _onTimeSelected(String time, List<Map<String, dynamic>> availableTsList) {
    setState(() {
      _selectedTime = time.isEmpty ? null : time;
      _availableTsList = availableTsList;
    });
    
    print('선택된 시간: ${time.isEmpty ? '없음' : time}');
    print('가용 타석 수: ${availableTsList.length}개');
    
    // 현재 스텝 위치를 기억해놓기
    final currentStepIndex = _stepperService.currentStep;
    
    // 시간 선택 후 step들을 다시 초기화하여 새로운 타석 정보를 전달
    _initializeSteps();
    
    // step 초기화 후 원래 스텝 위치로 복원하고 선택된 값 설정
    Future.microtask(() {
      // 원래 스텝으로 돌아가기
      if (currentStepIndex >= 0) {
        _stepperService.goToStep(currentStepIndex);
      }
      // 현재 스텝의 선택된 값 업데이트
      _stepperService.updateCurrentStepValue(time.isEmpty ? null : time);
      
      // 이전 스텝들의 선택된 값들도 복원
      _restoreStepValues();
    });
  }

  // 선택된 값들을 스텝에 복원하는 메서드
  void _restoreStepValues() {
    // 날짜 선택 값 복원
    if (_selectedDate != null) {
      final weekdays = ['', '월', '화', '수', '목', '금', '토', '일'];
      final weekday = weekdays[_selectedDate!.weekday];
      final displayDate = '${DateFormat('MM월 dd일').format(_selectedDate!)}($weekday)';
      _stepperService.updateStepValue(0, displayDate);
    }
    
    // 프로 선택 값 복원 (레슨이 있는 경우)
    if (_selectedInstructorName != null) {
      final hasInstructorOption = _hasInstructorOption();
      if (hasInstructorOption) {
        _stepperService.updateStepValue(1, _selectedInstructorName);
      }
    }
    
    // 시간 선택 값 복원
    if (_selectedTime != null) {
      final hasInstructorOption = _hasInstructorOption();
      final timeStepIndex = hasInstructorOption ? 2 : 1;
      _stepperService.updateStepValue(timeStepIndex, _selectedTime);
    }
    
    // 타석 선택 값 복원
    if (_selectedTsId != null) {
      final hasInstructorOption = _hasInstructorOption();
      final tsStepIndex = hasInstructorOption ? 3 : 2;
      _stepperService.updateStepValue(tsStepIndex, '${_selectedTsId}번 타석');
    }
    
  }

  // 레슨 옵션이 있는지 확인하는 헬퍼 메서드
  bool _hasInstructorOption() {
    int totalLsMin = 0;
    _specialSettings.forEach((key, value) {
      if (key.startsWith('ls_min(')) {
        int minValue = 0;
        if (value != null && value.toString().isNotEmpty) {
          minValue = int.tryParse(value.toString()) ?? 0;
        }
        totalLsMin += minValue;
      }
    });
    return totalLsMin > 0;
  }

  // 타석 선택 콜백 메서드
  void _onTsSelected(String tsId) {
    print('');
    print('🎯 타석 선택됨: $tsId');
    
    setState(() {
      _selectedTsId = tsId;
    });
    
    print('타석 선택 후 _initializeSteps 호출 전 상태:');
    print('  현재 스텝: ${_stepperService.currentStep}');
    print('  총 스텝 수: ${_stepperService.totalSteps}');
    
    // 타석 선택 후 step들을 다시 초기화하여 새로운 타석 정보를 전달
    _initializeSteps();
    
    print('_initializeSteps 호출 후 상태:');
    print('  현재 스텝: ${_stepperService.currentStep}');
    print('  총 스텝 수: ${_stepperService.totalSteps}');
    
    // step 초기화 후 결제 단계로 이동
    Future.microtask(() {
      // 결제 단계의 정확한 인덱스 계산
      final hasInstructorOption = _hasInstructorOption();
      final paymentStepIndex = hasInstructorOption ? 4 : 3; // 프로 선택 여부에 따라 인덱스 계산
      
      print('');
      print('🚀 결제 단계로 이동 시도:');
      print('  프로 선택 여부: $hasInstructorOption');
      print('  계산된 결제 단계 인덱스: $paymentStepIndex');
      print('  현재 총 스텝 수: ${_stepperService.totalSteps}');
      print('  이동 가능 여부: ${paymentStepIndex < _stepperService.totalSteps}');
      
      if (paymentStepIndex < _stepperService.totalSteps) {
        print('  ✅ 결제 단계로 이동 실행');
        _stepperService.goToStep(paymentStepIndex);
        
        print('  이동 후 현재 스텝: ${_stepperService.currentStep}');
        print('  이동 후 현재 스텝 제목: ${_stepperService.steps[_stepperService.currentStep].title}');
        
        // 이전 스텝들의 선택된 값들 복원
        _restoreStepValues();
        
        // 현재 스텝(타석 선택)의 값 설정
        _stepperService.updateStepValue(paymentStepIndex - 1, '${tsId}번 타석');
        
        print('  ✅ 타석 선택 완료 및 결제 단계 이동 완료');
      } else {
        print('  ❌ 결제 단계 인덱스가 범위를 벗어남');
        print('  paymentStepIndex: $paymentStepIndex, totalSteps: ${_stepperService.totalSteps}');
      }
      print('');
    });
  }

  // 회원권 선택 콜백 메서드
  void _onContractSelected(Map<String, dynamic> contract) {
    print('회원권 선택됨: ${contract['contract_name']}');
    
    setState(() {
      _selectedContract = contract;
    });
    
    // 회원권 선택 시에는 상태만 업데이트하고 DB 업데이트는 "다음" 버튼에서 실행
    print('회원권 선택 완료 - 다음 버튼을 눌러 계속 진행하세요.');
  }

  // 동반자 초대 완료 콜백 메서드
  void _onGroupCompleted(List<Map<String, dynamic>> invitedMembers) {
    print('동반자 초대 완료됨');
    print('초대된 동반자 수: ${invitedMembers.length}명');

    setState(() {
      _invitedMembers = invitedMembers;
    });

    // 그룹 레슨 예약 완료 다이얼로그 표시
    if (mounted) {
      _showCompletionDialog();
    }
  }

  // 스텝 다음 버튼 클릭 처리
  void _onStepNext() {
    print('');
    print('🟢🟢🟢 _onStepNext 호출됨! 🟢🟢🟢');
    
    // STEP5 (결제 단계)에서 다음 버튼 클릭 시 회원권 선택 정보 전달
    final currentStepIndex = _stepperService.currentStep;
    final step5Index = _hasInstructorOption() ? 4 : 3;
    
    print('  현재 스텝 인덱스: $currentStepIndex');
    print('  Step5 인덱스: $step5Index');
    print('  프로 옵션 여부: ${_hasInstructorOption()}');
    
    if (currentStepIndex == step5Index) {
      // GlobalKey를 사용하여 Step5 State에 접근
      final step5Key = _stepKeys[step5Index];
      final step5State = step5Key.currentState;
      
      if (step5State != null) {
        final selectedContract = (step5State as dynamic).selectedContract;
        if (selectedContract != null) {
          print('');
          print('🎯 STEP5 다음 버튼 클릭 - 선택된 회원권 정보 전달');
          print('회원권명: ${selectedContract['contract_name']}');
          print('회원권 타입: ${selectedContract['type']}');
          print('');
          
          // DB 업데이트 실행 및 Step6 이동
          _processPaymentAndMoveToNextStep(selectedContract);
          return; // 자동 진행 방지
        } else {
          print('❌ 회원권이 선택되지 않았습니다.');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('회원권을 선택해주세요.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return; // 회원권 선택 없이는 다음 단계로 진행하지 않음
        }
      }
    }
    
    // 다른 스텝에서는 기본 다음 단계 진행
    _stepperService.nextStep();
  }

  // 결제 완료 콜백 메서드
  void _onPaymentCompleted(Map<String, dynamic> calculatedData) {
    print('결제 완료됨');
    print('Step 5에서 계산된 데이터 수신: ${calculatedData.keys.join(', ')}');
    
    // Step 5에서 계산된 데이터 저장
    setState(() {
      _step5CalculatedData = calculatedData;
    });
    
    // 그룹레슨인 경우 Step 6으로 이동, 아니면 종료
    final maxPlayerNo = int.tryParse(_specialSettings['max_player_no']?.toString() ?? '1') ?? 1;
    if (maxPlayerNo > 1) {
      // 그룹레슨인 경우 Step 6으로 이동
      _stepperService.nextStep();
      print('✅ 회원권 선택 완료 및 동반자 초대 단계 이동 완료');
    } else {
      // 개인레슨인 경우 조회 탭으로 이동
      if (mounted) {
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
      }
    }
  }

  // 초기 회원권 유효성 검증
  bool _hasValidMemberships = true;
  String? _membershipErrorMessage;

  // 회원권 데이터 로드 (캐시)
  Future<void> _loadMembershipData() async {
    print('🚀🚀🚀 _loadMembershipData 함수 시작! 🚀🚀🚀');
    try {
      // widget.selectedMember를 우선 사용, 없으면 ApiService에서 가져오기
      final memberData = widget.selectedMember ?? ApiService.getCurrentUser();
      final memberId = memberData?['member_id'];

      if (memberId == null) {
        print('❌ 회원 ID를 찾을 수 없어 회원권 데이터를 로드할 수 없습니다.');
        setState(() {
          _hasValidMemberships = false;
          _membershipErrorMessage = '회원 정보를 찾을 수 없습니다.';
          _isMembershipDataLoaded = true;
        });
        return;
      }

      print('✅ 회원 ID 확인: $memberId');

      print('');
      print('🔄 회원권 데이터 캐시 로딩 시작 (회원 ID: $memberId)');

      // 예약 날짜 문자열 생성 (선택된 날짜가 있으면 사용, 없으면 null)
      String? reservationDateStr;
      if (_selectedDate != null) {
        reservationDateStr = _selectedDate!.toString().split(' ')[0];
        print('예약 날짜 기준으로 만료일 검증: $reservationDateStr');
      } else {
        print('예약 날짜 미선택 - 오늘 기준으로 만료일 검증');
      }

      // 프로그램 예약용 시간권 계약 데이터 조회 (예약 날짜 기준 만료일 검증 포함)
      final timePassContracts = await ApiService.getMemberTimePassesByContractForProgram(
        memberId: memberId.toString(),
        reservationDate: reservationDateStr,
      );
      
      // 프로그램 예약용 레슨 계약 데이터 조회 (예약 날짜 기준 만료일 검증 포함)
      final lessonContractsResponse = await ApiService.getMemberLsCountingDataForProgram(
        memberId: memberId.toString(),
        reservationDate: reservationDateStr,
      );
      final lessonContracts = lessonContractsResponse['data'] as List<Map<String, dynamic>>? ?? [];

      // 레슨 계약 데이터 확인 (v3_LS_countings에서 contract_history_id 이미 포함)
      print('📋 레슨 계약 원본 데이터 확인:');
      for (int i = 0; i < lessonContracts.length && i < 3; i++) {
        final contract = lessonContracts[i];
        print('  레슨 $i: contract_history_id=${contract['contract_history_id']}, 잔액=${contract['LS_balance_min_after']}분');
      }

      // v3_LS_countings에서 이미 필요한 데이터를 모두 가져왔으므로 enrichment 불필요
      // 초기 회원권 유효성 검증 수행
      print('🔥🔥🔥 초기 회원권 유효성 검증 호출 시도 🔥🔥🔥');
      final validationResult = _validateInitialMembership(timePassContracts, lessonContracts);
      print('🔥🔥🔥 초기 회원권 유효성 검증 결과: $validationResult 🔥🔥🔥');

      setState(() {
        _cachedTimePassContracts = timePassContracts;
        _cachedLessonContracts = lessonContracts;
        _isMembershipDataLoaded = true;
        _hasValidMemberships = validationResult['isValid'];
        _membershipErrorMessage = validationResult['errorMessage'];
      });

      print('✅ 회원권 데이터 캐시 완료');
      print('   시간권 계약 수: ${timePassContracts.length}개');
      print('   레슨 계약 수: ${lessonContracts.length}개');
      print('   회원권 유효성: ${_hasValidMemberships ? '유효' : '무효'}');
      if (!_hasValidMemberships) {
        print('   오류 메시지: $_membershipErrorMessage');
      }
      print('🔥🔥🔥 최종 _hasValidMemberships: $_hasValidMemberships 🔥🔥🔥');
      print('');

    } catch (e) {
      print('❌ 회원권 데이터 캐시 실패: $e');
      setState(() {
        _cachedTimePassContracts = [];
        _cachedLessonContracts = [];
        _isMembershipDataLoaded = true; // 실패해도 로드 완료로 표시
        _hasValidMemberships = false;
        _membershipErrorMessage = '회원권 정보를 불러오는 중 오류가 발생했습니다.';
      });
    }
  }

  // 초기 회원권 유효성 검증 (step5 기준 적용)
  Map<String, dynamic> _validateInitialMembership(
    List<Map<String, dynamic>> timePassContracts,
    List<Map<String, dynamic>> lessonContracts,
  ) {
    print('');
    print('🔍🔍🔍 초기 회원권 유효성 검증 시작 🔍🔍🔍');
    print('   시간권 계약 수: ${timePassContracts.length}');
    print('   레슨 계약 수: ${lessonContracts.length}');
    
    // 필요한 시간 계산
    final totalTsMin = int.tryParse(_specialSettings['ts_min']?.toString() ?? '0') ?? 0;
    int totalLsMin = 0;
    _specialSettings.forEach((key, value) {
      if (key.startsWith('ls_min(')) {
        int minValue = int.tryParse(value?.toString() ?? '0') ?? 0;
        totalLsMin += minValue;
      }
    });

    print('   필요한 시간 - 타석: ${totalTsMin}분, 레슨: ${totalLsMin}분');

    // program_id 추출
    final currentProgramId = _specialSettings['program_id']?.toString() ?? '';
    print('   현재 프로그램 ID: $currentProgramId');

    // 시간권 데이터 상세 출력
    print('   📋 시간권 계약 상세:');
    for (final contract in timePassContracts) {
      final balance = contract['balance'];
      final historyId = contract['contract_history_id'];
      final availability = contract['program_reservation_availability'];
      print('     - 계약 $historyId: 잔액 $balance분, availability: $availability');
    }

    // 레슨권 데이터 상세 출력
    print('   📋 레슨 계약 상세:');
    for (final contract in lessonContracts) {
      final balance = contract['LS_balance_min_after'];
      final historyId = contract['contract_history_id'];
      final contractId = contract['actual_contract_id'];
      print('     - 계약 $historyId: 잔액 $balance분, contract_id: $contractId');
    }

    if (totalTsMin <= 0) {
      print('   ✅ 타석 시간 요구사항이 없음 - 검증 통과');
      return {'isValid': true, 'errorMessage': null};
    }

    // 레슨이 없는 프로그램 (타석만)
    if (totalLsMin == 0) {
      print('   📋 타석 전용 프로그램 검증');
      return _validateTimePassOnly(timePassContracts, totalTsMin, currentProgramId);
    }
    
    // 레슨이 있는 프로그램 (타석 + 레슨 세트)
    print('   📋 타석+레슨 세트 프로그램 검증');
    final result = _validateProgramSet(timePassContracts, lessonContracts, totalTsMin, totalLsMin, currentProgramId);
    print('🔍🔍🔍 초기 회원권 유효성 검증 완료: ${result['isValid'] ? '통과' : '실패'} 🔍🔍🔍');
    return result;
  }

  // 타석만 있는 프로그램 검증
  Map<String, dynamic> _validateTimePassOnly(
    List<Map<String, dynamic>> timePassContracts,
    int neededTsMin,
    String currentProgramId,
  ) {
    print('   📋 프로그램 전용 시간권 계약 검증 시작 (필요: ${neededTsMin}분)');
    
    for (final contract in timePassContracts) {
      final balance = int.tryParse(contract['balance']?.toString() ?? '0') ?? 0;
      final contractId = contract['actual_contract_id']?.toString() ?? '';
      final historyId = contract['contract_history_id']?.toString() ?? '';
      
      print('   🔍 계약 ${historyId} 검토: 잔액 ${balance}분, contract_id: ${contractId}');
      
      // 프로그램 예약 대상 계약인지 먼저 확인
      final programAvailability = contract['program_reservation_availability']?.toString() ?? '';
      bool isProgramContract = false;
      
      if (programAvailability.isNotEmpty && currentProgramId.isNotEmpty) {
        final availablePrograms = programAvailability.split(',').map((e) => e.trim()).toList();
        isProgramContract = availablePrograms.contains(currentProgramId);
      }
      
      if (!isProgramContract) {
        print('   ❌ 계약 ${historyId}: 프로그램 예약 대상이 아님 (availability: ${programAvailability})');
        continue;
      }
      
      // 잔액 검증
      if (balance < neededTsMin) {
        print('   ❌ 계약 ${historyId}: 잔액 부족 (${balance}분 < ${neededTsMin}분)');
        continue;
      }
      
      print('   ✅ 사용 가능한 프로그램 전용 시간권 발견 (계약: ${historyId}, 잔액: ${balance}분)');
      return {'isValid': true, 'errorMessage': null};
    }
    
    print('   ❌ 사용 가능한 프로그램 전용 시간권이 없음');
    return {
      'isValid': false,
      'errorMessage': '이 프로그램을 이용할 수 있는 시간권이 없습니다.\n회원권을 구매하세요.'
    };
  }

  // 타석 + 레슨 세트 프로그램 검증 (별도 회원권 검증)
  Map<String, dynamic> _validateProgramSet(
    List<Map<String, dynamic>> timePassContracts,
    List<Map<String, dynamic>> lessonContracts,
    int neededTsMin,
    int neededLsMin,
    String currentProgramId,
  ) {
    print('   📋 프로그램 세트 검증 시작 (별도 검증: 시간권 ${neededTsMin}분 + 레슨권 ${neededLsMin}분)');
    
    // 1. 시간권 검증 (프로그램용 시간권 중 잔액 충분한 것이 있는가?)
    bool hasValidTimePass = false;
    Map<String, dynamic>? validTimeContract;
    
    print('   🔍 시간권 검증 시작...');
    for (final timeContract in timePassContracts) {
      final timeBalance = int.tryParse(timeContract['balance']?.toString() ?? '0') ?? 0;
      final timeHistoryId = timeContract['contract_history_id']?.toString();
      final contractId = timeContract['actual_contract_id']?.toString() ?? '';
      
      print('   🔍 시간권 계약 ${timeHistoryId} 검토: 잔액 ${timeBalance}분, contract_id: ${contractId}');
      
      // 프로그램 예약 대상 시간권인지 확인
      final programAvailability = timeContract['program_reservation_availability']?.toString() ?? '';
      bool isProgramTimeContract = false;
      
      if (programAvailability.isNotEmpty && currentProgramId.isNotEmpty) {
        final availablePrograms = programAvailability.split(',').map((e) => e.trim()).toList();
        isProgramTimeContract = availablePrograms.contains(currentProgramId);
      }
      
      if (!isProgramTimeContract) {
        print('   ❌ 시간권 ${timeHistoryId}: 프로그램 예약 대상이 아님 (availability: ${programAvailability})');
        continue;
      }
      
      // 시간권 잔액 검증
      if (timeBalance < neededTsMin) {
        print('   ❌ 시간권 ${timeHistoryId}: 잔액 부족 (${timeBalance}분 < ${neededTsMin}분)');
        continue;
      }
      
      print('   ✅ 사용 가능한 프로그램용 시간권 발견: ${timeHistoryId} (잔액: ${timeBalance}분)');
      hasValidTimePass = true;
      validTimeContract = timeContract;
      break; // 하나만 찾으면 충분
    }
    
    if (!hasValidTimePass) {
      print('   ❌ 프로그램용 시간권이 없거나 잔액이 부족함');
      return {
        'isValid': false,
        'errorMessage': '이 프로그램을 이용할 수 있는 시간권이 없습니다.\n회원권을 구매하세요.'
      };
    }
    
    // 2. 레슨권 검증 (프로그램용 레슨권 중 잔액 충분한 것이 있는가?)
    bool hasValidLesson = false;
    Map<String, dynamic>? validLessonContract;
    
    print('   🔍 레슨권 검증 시작...');
    if (lessonContracts.isEmpty) {
      print('   ❌ 레슨 계약이 없음');
      return {
        'isValid': false,
        'errorMessage': '레슨 이용 가능한 회원권이 없습니다.\n회원권을 구매하세요.'
      };
    }
    
    for (final lessonContract in lessonContracts) {
      final lessonBalance = int.tryParse(lessonContract['LS_balance_min_after']?.toString() ?? '0') ?? 0;
      final lessonHistoryId = lessonContract['contract_history_id']?.toString();
      final contractId = lessonContract['actual_contract_id']?.toString() ?? '';
      
      print('   🔍 레슨권 계약 ${lessonHistoryId} 검토: 잔액 ${lessonBalance}분, contract_id: ${contractId}');
      
      // API에서 이미 프로그램 전용 레슨권만 필터링해서 가져옴
      if (lessonBalance >= neededLsMin) {
        print('   ✅ 사용 가능한 프로그램용 레슨권 발견: ${lessonHistoryId} (잔액: ${lessonBalance}분)');
        hasValidLesson = true;
        validLessonContract = lessonContract;
        break; // 하나만 찾으면 충분
      } else {
        print('   ❌ 레슨권 ${lessonHistoryId}: 잔액 부족 (${lessonBalance}분 < ${neededLsMin}분)');
      }
    }
    
    if (!hasValidLesson) {
      print('   ❌ 프로그램용 레슨권이 없거나 잔액이 부족함');
      return {
        'isValid': false,
        'errorMessage': '이 프로그램을 이용할 수 있는 레슨권이 없습니다.\n회원권을 구매하세요.'
      };
    }
    
    // 3. 둘 다 통과한 경우
    final timeBalance = int.tryParse(validTimeContract!['balance']?.toString() ?? '0') ?? 0;
    final lessonBalance = int.tryParse(validLessonContract!['LS_balance_min_after']?.toString() ?? '0') ?? 0;
    
    print('   ✅ 프로그램 세트 검증 통과!');
    print('   📋 사용 가능한 시간권: ${validTimeContract['contract_history_id']} (${timeBalance}분)');
    print('   📋 사용 가능한 레슨권: ${validLessonContract['contract_history_id']} (${lessonBalance}분)');
    
    return {'isValid': true, 'errorMessage': null};
  }


  void _initializeSteps() {
    // 설정값 확인
    final maxPlayerNo = int.tryParse(_specialSettings['max_player_no']?.toString() ?? '1') ?? 1;
    final isGroupLesson = maxPlayerNo >= 2;
    
    // ls_min 설정 확인 - 모든 ls_min 값들을 합계로 계산
    int totalLsMin = 0;
    _specialSettings.forEach((key, value) {
      if (key.startsWith('ls_min(')) {
        // 안전한 int 변환
        int minValue = 0;
        if (value != null && value.toString().isNotEmpty) {
          minValue = int.tryParse(value.toString()) ?? 0;
        }
        totalLsMin += minValue;
      }
    });
    
    final hasInstructorOption = totalLsMin > 0;
    final step5Index = hasInstructorOption ? 4 : 3;
    
    print('');
    print('🔧 _initializeSteps 실행');
    print('max_player_no: $maxPlayerNo, 그룹레슨 여부: $isGroupLesson');
    print('총 레슨 시간(ls_min 합계): $totalLsMin분');
    print('프로 선택 가능 여부: $hasInstructorOption');
    
    // 현재 선택된 값들을 디버깅용으로 출력
    print('_initializeSteps 호출 시점의 선택된 값들:');
    print('  _selectedDate: $_selectedDate');
    print('  _selectedInstructorId: $_selectedInstructorId');
    print('  _selectedInstructorName: $_selectedInstructorName');
    print('  _selectedTime: $_selectedTime');
    print('  _selectedTsId: $_selectedTsId');
    
    final steps = <StepModel>[
      // 1단계: 날짜 선택
      StepModel(
        title: '날짜 선택',
        icon: '📅',
        color: Color(0xFF3B82F6),
        content: SpStep1SelectDate(
          onDateSelected: _onDateSelected,
          specialSettings: _specialSettings,
          hasValidMemberships: _hasValidMemberships,
          membershipErrorMessage: _membershipErrorMessage,
          selectedMember: widget.selectedMember,
        ),
      ),
    ];
    
    print('1단계 (날짜 선택) 추가됨');
    
    // 2단계: 프로 선택 (총 레슨 시간이 0분 초과인 경우만 추가)
    if (hasInstructorOption) {
      steps.add(
        StepModel(
          title: '프로 선택',
          icon: '👨‍🏫',
          color: Color(0xFF8B5CF6),
          content: SpStep2SelectPro(
            onProSelected: _onProSelected,
            selectedDate: _selectedDate,
            selectedProId: _selectedInstructorId,
            selectedProName: _selectedInstructorName,
            specialSettings: _specialSettings,
            selectedMember: widget.selectedMember,
          ),
        ),
      );
      print('2단계 (프로 선택) 추가됨');
    } else {
      print('2단계 (프로 선택) 스킵됨 - 레슨 시간 없음');
    }
    
    // 3단계: 시간 선택
    steps.add(
      StepModel(
        title: '시간 선택',
        icon: '🕐',
        color: Color(0xFFEF4444),
        content: SpStep3SelectTime(
          onTimeSelected: _onTimeSelected,
          selectedDate: _selectedDate,
          selectedProId: _selectedInstructorId,
          selectedProName: _selectedInstructorName,
          specialSettings: _specialSettings,
          selectedMember: widget.selectedMember,
        ),
      ),
    );
    print('${hasInstructorOption ? '3' : '2'}단계 (시간 선택) 추가됨');
    
    // 4단계: 타석 선택
    steps.add(
      StepModel(
        title: '타석 선택',
        icon: '🏌️',
        color: Color(0xFF06B6D4),
        content: SpStep4SelectTs(
          onTsSelected: _onTsSelected,
          selectedDate: _selectedDate,
          selectedProId: _selectedInstructorId,
          selectedProName: _selectedInstructorName,
          selectedTime: _selectedTime,
          availableTsList: _availableTsList, // 가용 타석 정보 전달
          specialSettings: _specialSettings,
          selectedMember: widget.selectedMember,
        ),
      ),
    );
    print('${hasInstructorOption ? '4' : '3'}단계 (타석 선택) 추가됨');
    
    // 5단계: 결제
    steps.add(
      StepModel(
        title: '결제',
        icon: '💳',
        color: Color(0xFF10B981),
        content: SpStep5Paying(
          key: _stepKeys[step5Index],
          onPaymentCompleted: _onPaymentCompleted,
          onContractSelected: _onContractSelected, // 회원권 선택 콜백 추가
          selectedDate: _selectedDate,
          selectedProId: _selectedInstructorId,
          selectedProName: _selectedInstructorName,
          selectedTime: _selectedTime,
          selectedTsId: _selectedTsId,
          specialSettings: _specialSettings,
          cachedTimePassContracts: _cachedTimePassContracts,
          cachedLessonContracts: _cachedLessonContracts,
          isMembershipDataLoaded: _isMembershipDataLoaded,
          specialType: widget.specialType,
          selectedMember: widget.selectedMember,
        ),
      ),
    );
    print('${hasInstructorOption ? '5' : '4'}단계 (결제) 추가됨');
    
    // 6단계: 그룹레슨 초대 (max_player_no가 2 이상인 경우만 추가)
    if (isGroupLesson) {
      steps.add(
        StepModel(
          title: '동반자 초대',
          icon: '👥',
          color: Color(0xFFF59E0B),
          content: SpStep6Group(
            onGroupCompleted: _onGroupCompleted,
            selectedDate: _selectedDate,
            selectedProId: _selectedInstructorId,
            selectedProName: _selectedInstructorName,
            selectedTime: _selectedTime,
            selectedTsId: _selectedTsId,
            selectedContract: _selectedContract,
            specialSettings: _specialSettings,
            step5CalculatedData: _step5CalculatedData,
          ),
        ),
      );
      print('${hasInstructorOption ? '6' : '5'}단계 (동반자 초대) 추가됨');
    } else {
      print('동반자 초대 단계 스킵됨 - 개인 레슨');
    }

    print('총 생성된 단계 수: ${steps.length}');
    for (int i = 0; i < steps.length; i++) {
      print('  단계 $i: ${steps[i].title}');
    }
    
    _stepperService.initialize(steps);
    print('StepperService 초기화 완료');
    print('현재 스텝: ${_stepperService.currentStep}');
    print('총 스텝 수: ${_stepperService.totalSteps}');
    print('');
  }

  // 각 스텝에서 사용할 수 있는 설정 데이터 접근자
  Map<String, dynamic> get specialSettings => _specialSettings;
  bool get isSettingsLoaded => _isSettingsLoaded;
  
  // 그룹레슨 여부 확인
  bool get isGroupLesson {
    final maxPlayerNo = int.tryParse(_specialSettings['max_player_no']?.toString() ?? '1') ?? 1;
    return maxPlayerNo >= 2;
  }
  
  // 최대 인원 수 반환
  int get maxPlayerCount {
    return int.tryParse(_specialSettings['max_player_no']?.toString() ?? '1') ?? 1;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: _isSettingsLoaded
          ? _buildContent()
          : _buildLoading(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
            strokeWidth: 2.5,
          ),
          SizedBox(height: 20),
          Text(
            '설정 정보를 불러오는 중...',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF8E8E8E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // 회원권 유효성 검증 실패 시 오류 화면 표시
    if (_isMembershipDataLoaded && !_hasValidMemberships) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red[200]!, width: 1),
                ),
                child: Icon(
                  Icons.credit_card_off,
                  size: 64,
                  color: Colors.red[400],
                ),
              ),
              SizedBox(height: 24),
              Text(
                '예약 불가',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
              SizedBox(height: 16),
              Text(
                _membershipErrorMessage ?? '사용 가능한 회원권이 없습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '돌아가기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            // Stepper 영역
            Expanded(
              child: _stepperService.steps.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                            strokeWidth: 2.5,
                          ),
                          SizedBox(height: 20),
                          Text(
                            '단계를 준비하는 중...',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8E8E8E),
                            ),
                          ),
                        ],
                      ),
                    )
                  : CustomStepper(
                      stepperService: _stepperService,
                      onNext: _onStepNext,
                      onComplete: _onStepNext, // 완료 버튼도 동일한 핸들러 사용
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // 결제 처리 및 다음 단계 이동
  Future<void> _processPaymentAndMoveToNextStep(Map<String, dynamic> selectedContract) async {
    final hasInstructorOption = _hasInstructorOption();
    final maxPlayerNo = int.tryParse(_specialSettings['max_player_no']?.toString() ?? '1') ?? 1;
    final isGroupLesson = maxPlayerNo > 1;
    
    // 그룹 레슨이 아닌 경우 다음 단계가 없음 (Step 5가 마지막)
    final nextStepIndex = isGroupLesson ? (hasInstructorOption ? 5 : 4) : -1;
    
    print('');
    print('🚀 예약 처리 진행:');
    print('  프로 선택 여부: $hasInstructorOption');
    print('  그룹 레슨 여부: $isGroupLesson (최대 인원: $maxPlayerNo)');
    print('  계산된 다음 단계 인덱스: ${nextStepIndex == -1 ? "없음 (마지막 단계)" : nextStepIndex}');
    print('  현재 총 스텝 수: ${_stepperService.totalSteps}');
    
    // DB 업데이트 실행
    print('');
    print('🔥🔥🔥 DB 업데이트 실행 시작 🔥🔥🔥');
    
    // 필수 데이터 null 체크
    if (_selectedDate == null || 
        _selectedInstructorId == null || 
        _selectedInstructorName == null ||
        _selectedTime == null ||
        _selectedTsId == null) {
      print('❌ 필수 예약 정보가 누락되었습니다.');
      print('  selectedDate: $_selectedDate');
      print('  selectedInstructorId: $_selectedInstructorId');
      print('  selectedInstructorName: $_selectedInstructorName');
      print('  selectedTime: $_selectedTime');
      print('  selectedTsId: $_selectedTsId');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('필수 예약 정보가 누락되었습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    try {
      await SpDbUpdateService.updateDatabaseForReservation(
        selectedDate: _selectedDate!,
        selectedProId: _selectedInstructorId!,
        selectedProName: _selectedInstructorName!,
        selectedTime: _selectedTime!,
        selectedTsId: _selectedTsId!,
        specialSettings: _specialSettings,
        selectedContract: selectedContract,
        specialType: widget.specialType,
        selectedMember: widget.selectedMember,
      );
      
      print('✅ DB 업데이트 완료');
      
      // 선택된 회원권 정보 업데이트
      setState(() {
        _selectedContract = selectedContract;
      });
      
      // 그룹 레슨인 경우 Step 6으로 이동
      if (isGroupLesson && nextStepIndex >= 0 && nextStepIndex < _stepperService.totalSteps) {
        print('  그룹 레슨이므로 동반자 초대 단계로 이동');
        
        // step들을 다시 초기화하여 새로운 계약 정보를 전달
        _initializeSteps();
        
        // step 초기화 후 Step6으로 이동
        Future.microtask(() {
          _stepperService.goToStep(nextStepIndex);
          
          // 이전 스텝들의 선택된 값들 복원
          _restoreStepValues();
          
          print('  ✅ 회원권 선택 완료 및 동반자 초대 단계 이동 완료');
        });
      } else {
        // 개인 레슨인 경우 예약 완료 처리
        print('  개인 레슨이므로 예약 완료 처리');

        // 예약 완료 다이얼로그 표시
        if (mounted) {
          _showCompletionDialog();
        }
      }
      
    } catch (e) {
      print('❌ DB 업데이트 실패: $e');
      // DB 업데이트 실패 시 사용자에게 알림
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('예약 처리 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    print('');
  }

  // 프로그램 예약 완료 다이얼로그 표시
  void _showCompletionDialog() {
    // 종료 시간 계산
    String endTime = '';
    if (_selectedTime != null && _specialSettings['ts_min'] != null) {
      final startParts = _selectedTime!.split(':');
      final startHour = int.parse(startParts[0]);
      final startMinute = int.parse(startParts[1]);

      // 타석 시간 + 레슨 시간 계산
      final tsMin = int.tryParse(_specialSettings['ts_min']?.toString() ?? '0') ?? 0;
      final lsMinTotal = _calculateTotalLessonMinutes();
      final totalDuration = tsMin + lsMinTotal;

      final endTotalMinutes = startHour * 60 + startMinute + totalDuration;
      final endHour = (endTotalMinutes ~/ 60) % 24;
      final endMinuteValue = endTotalMinutes % 60;
      endTime = '${endHour.toString().padLeft(2, '0')}:${endMinuteValue.toString().padLeft(2, '0')}';
    }

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
                  '예약이 완료되었습니다!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A202C),
                  ),
                ),
                SizedBox(height: 16),

                // 예약 정보
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('날짜', _selectedDate != null
                        ? '${_selectedDate!.year}.${_selectedDate!.month.toString().padLeft(2, '0')}.${_selectedDate!.day.toString().padLeft(2, '0')}'
                        : '-'),
                      _buildInfoRow('시간', '$_selectedTime ~ $endTime'),
                      _buildInfoRow('프로', _selectedInstructorName ?? '-'),
                      _buildInfoRow('타석', _selectedTsId != null ? '$_selectedTsId번' : '-'),
                      if (_selectedContract != null) ...[
                        SizedBox(height: 8),
                        Divider(color: Color(0xFFE2E8F0)),
                        SizedBox(height: 8),
                        _buildInfoRow('회원권', _selectedContract!['contract_name'] ?? '-'),
                      ],
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

                      // 조회 탭으로 이동
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
                color: Color(0xFF718096),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF1A202C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 전체 레슨 시간 계산
  int _calculateTotalLessonMinutes() {
    int total = 0;
    _specialSettings.forEach((key, value) {
      if (key.startsWith('ls_min(') && value != null) {
        total += int.tryParse(value.toString()) ?? 0;
      }
      if (key.startsWith('ls_break_min(') && value != null) {
        total += int.tryParse(value.toString()) ?? 0;
      }
    });
    return total;
  }
} 