import 'package:flutter/material.dart';
import '../../../../services/tab_design_service.dart';
import 'step1_select_date.dart';
import 'step2_select_time.dart';
import 'step3_select_duration.dart';
import 'step4_select_ts.dart';
import 'step5_pricing.dart';
import 'step6_paying.dart';
import 'step7_db_updates.dart';
import '../../../../services/api_service.dart';
import '../../../../services/holiday_service.dart';
import 'package:intl/intl.dart';
import '../../../services/stepper/stepper_service.dart';
import '../../../services/stepper/step_model.dart';
import '../../../widgets/custom_stepper.dart';
import '../../../main_page.dart';

class Step0Structure extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const Step0Structure({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _Step0StructureState createState() => _Step0StructureState();
}

class _Step0StructureState extends State<Step0Structure> with TickerProviderStateMixin {
  late StepperService _stepperService;
  
  // 애니메이션 컨트롤러
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Step 위젯들의 GlobalKey
  final List<GlobalKey> _stepKeys = [
    GlobalKey(), // Step1
    GlobalKey(), // Step2
    GlobalKey(), // Step3
    GlobalKey(), // Step4
    GlobalKey(), // Step5
    GlobalKey<Step6PayingState>(), // Step6 - 특별히 State 타입 지정
  ];
  
  // Step 간 데이터 전달을 위한 상태 변수들
  DateTime? _selectedDate;
  Map<String, dynamic>? _scheduleInfo;
  String? _selectedTime;
  int? _selectedDuration;
  String? _selectedTs;
  
  // Step5 가격 정보 추가
  int? _totalPrice;
  int? _originalPrice; // 할인 전 원가 저장
  int? _finalPaymentMinutes; // 할인 후 시간 저장
  Map<String, int>? _pricingAnalysis;
  
  // 할인권 정보 추가
  List<Map<String, dynamic>> _selectedCoupons = []; // 여러 할인권 지원

  // 안전한 int 변환 헬퍼 함수
  int _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

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
        content: Step1SelectDate(
          isAdminMode: widget.isAdminMode,
          selectedMember: widget.selectedMember,
          branchId: widget.branchId,
          onDateSelected: _onDateSelected,
        ),
      ),
      StepModel(
        title: '시간 선택',
        icon: '🕐',
        color: Color(0xFF8B5CF6),
        content: Step2SelectTime(
          isAdminMode: widget.isAdminMode,
          selectedMember: widget.selectedMember,
          branchId: widget.branchId,
          selectedDate: _selectedDate,
          scheduleInfo: _scheduleInfo,
          selectedTime: _selectedTime,
          onTimeSelected: _onTimeSelected,
        ),
      ),
      StepModel(
        title: '연습 시간',
        icon: '⏱️',
        color: Color(0xFFEF4444),
        content: Step3SelectDuration(
          isAdminMode: widget.isAdminMode,
          selectedMember: widget.selectedMember,
          branchId: widget.branchId,
          selectedDate: _selectedDate,
          selectedTime: _selectedTime,
          scheduleInfo: _scheduleInfo,
          onDurationSelected: _onDurationSelected,
        ),
      ),
      StepModel(
        title: '타석 선택',
        icon: '⛳',
        color: Color(0xFFF59E0B),
        content: Step4SelectTs(
          isAdminMode: widget.isAdminMode,
          selectedMember: widget.selectedMember,
          branchId: widget.branchId,
          selectedDate: _selectedDate,
          selectedTime: _selectedTime,
          selectedDuration: _selectedDuration,
          onTsSelected: _onTsSelected,
          onTimeSelected: _onTimeSelectedFromSchedule,
        ),
      ),
      StepModel(
        title: '할인 적용',
        icon: '🎫',
        color: Color(0xFF10B981),
        content: Step5Pricing(
          isAdminMode: widget.isAdminMode,
          selectedMember: widget.selectedMember,
          branchId: widget.branchId,
          selectedDate: _selectedDate,
          selectedTime: _selectedTime,
          selectedDuration: _selectedDuration,
          selectedTs: _selectedTs,
          onPricingCalculated: _onPricingCalculatedWithDiscount,
          onCouponsSelected: _onCouponsSelected,
        ),
      ),
      StepModel(
        title: '결제',
        icon: '💳',
        color: Color(0xFF6366F1),
        content: Step6Paying(
          key: _stepKeys[5] as GlobalKey<Step6PayingState>,
          isAdminMode: widget.isAdminMode,
          selectedMember: widget.selectedMember,
          branchId: widget.branchId,
          selectedDate: _selectedDate,
          selectedTime: _selectedTime,
          selectedDuration: _finalPaymentMinutes ?? _selectedDuration,
          selectedTs: _selectedTs,
          totalPrice: _totalPrice,
          pricingAnalysis: _pricingAnalysis,
          selectedCoupons: _selectedCoupons,
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
  
  // Step1에서 날짜와 스케줄 정보를 받는 콜백 함수
  void _onDateSelected(DateTime date, Map<String, dynamic> scheduleInfo) {
    setState(() {
      _selectedDate = date;
      _scheduleInfo = scheduleInfo;
    });
    _updateStepValue();
  }
  
  // Step2에서 시간을 받는 콜백 함수
  void _onTimeSelected(String time) {
    setState(() {
      _selectedTime = time;
    });
    _updateStepValue();
  }
  
  // Step3에서 시간을 받는 콜백 함수
  void _onDurationSelected(int duration) {
    setState(() {
      _selectedDuration = duration;
    });
    _updateStepValue();
  }
  
  // Step4에서 타석을 받는 콜백 함수
  void _onTsSelected(String ts) {
    print('🎯 타석 선택됨: $ts');
    setState(() {
      _selectedTs = ts;
    });
    print('🎯 _selectedTs 업데이트됨: $_selectedTs');
    _updateStepValue();
  }
  
  // Step4에서 시간을 선택했을 때 Step2로 돌아가면서 UI가 즉시 업데이트되도록 개선한 콜백 함수
  void _onTimeSelectedFromSchedule(String time) {
    print('🔄 Step4에서 시간 선택됨: $time');
    print('🔄 현재 currentStep: ${_stepperService.currentStep}');
    print('🔄 이전 selectedTime: $_selectedTime');
    
    setState(() {
      _selectedTime = time;
    });
    _stepperService.goToStep(1); // Step2로 이동
    _updateStepValue();
    _refreshStepContent();
    
    print('🔄 새로운 selectedTime 설정됨: $_selectedTime');
    
    // 애니메이션 리셋 및 재시작
    _slideController.reset();
    _slideController.forward();
    
    // 스낵바로 성공 메시지 표시
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('시작 시간이 $time으로 변경되었습니다. 시간 선택 단계로 돌아갑니다.'),
        backgroundColor: Color(0xFF00A86B),
        duration: Duration(seconds: 2),
      ),
    );
    
    print('🔄 Step2로 이동 완료, 최종 선택된 시간: $_selectedTime');
  }
  
  // Step5에서 할인 전 원가, 할인 후 금액, 할인 후 시간을 모두 받는 콜백 함수
  void _onPricingCalculatedWithDiscount(int finalPrice, int originalPrice, int finalMinutes, Map<String, int> pricingAnalysis) {
    setState(() {
      _totalPrice = finalPrice; // 할인 후 금액
      _originalPrice = originalPrice; // 할인 전 원가
      _finalPaymentMinutes = finalMinutes; // 할인 후 시간
      _pricingAnalysis = pricingAnalysis;
    });
    _updateStepValue();
  }
  
  // Step5에서 할인권 정보를 받는 콜백 함수 추가 (여러 할인권 지원)
  void _onCouponSelected(Map<String, dynamic>? coupon) {
    setState(() {
      _selectedCoupons = coupon != null ? [coupon] : []; // 단일 할인권을 리스트로 변환 (호환성)
    });
  }
  
  // 여러 할인권을 받는 새로운 콜백 함수
  void _onCouponsSelected(List<Map<String, dynamic>> coupons) {
    setState(() {
      _selectedCoupons = coupons;
    });
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
        value = _selectedTime;
        break;
      case 2:
        value = _selectedDuration != null ? '${_selectedDuration}분' : null;
        break;
      case 3:
        value = _selectedTs != null ? '$_selectedTs번 타석' : null;
        break;
      case 4:
        value = _totalPrice != null ? '${NumberFormat('#,###').format(_totalPrice)}원' : null;
        break;
      case 5:
        value = null; // 결제는 선택값 표시 안함
        break;
    }
    
    _stepperService.updateCurrentStepValue(value);
  }

  void _refreshStepContent() {
    // 기존 스텝 데이터를 유지하면서 콘텐츠만 업데이트
    final currentSteps = _stepperService.steps;
    for (int i = 0; i < currentSteps.length; i++) {
      Widget newContent;
      switch (i) {
        case 0:
          newContent = Step1SelectDate(
            isAdminMode: widget.isAdminMode,
            selectedMember: widget.selectedMember,
            branchId: widget.branchId,
            onDateSelected: _onDateSelected,
          );
          break;
        case 1:
          newContent = Step2SelectTime(
            isAdminMode: widget.isAdminMode,
            selectedMember: widget.selectedMember,
            branchId: widget.branchId,
            selectedDate: _selectedDate,
            scheduleInfo: _scheduleInfo,
            selectedTime: _selectedTime,
            onTimeSelected: _onTimeSelected,
          );
          break;
        case 2:
          newContent = Step3SelectDuration(
            isAdminMode: widget.isAdminMode,
            selectedMember: widget.selectedMember,
            branchId: widget.branchId,
            selectedDate: _selectedDate,
            selectedTime: _selectedTime,
            scheduleInfo: _scheduleInfo,
            onDurationSelected: _onDurationSelected,
          );
          break;
        case 3:
          newContent = Step4SelectTs(
            isAdminMode: widget.isAdminMode,
            selectedMember: widget.selectedMember,
            branchId: widget.branchId,
            selectedDate: _selectedDate,
            selectedTime: _selectedTime,
            selectedDuration: _selectedDuration,
            onTsSelected: _onTsSelected,
            onTimeSelected: _onTimeSelectedFromSchedule,
          );
          break;
        case 4:
          newContent = Step5Pricing(
            isAdminMode: widget.isAdminMode,
            selectedMember: widget.selectedMember,
            branchId: widget.branchId,
            selectedDate: _selectedDate,
            selectedTime: _selectedTime,
            selectedDuration: _selectedDuration,
            selectedTs: _selectedTs,
            onPricingCalculated: _onPricingCalculatedWithDiscount,
            onCouponsSelected: _onCouponsSelected,
          );
          break;
        case 5:
          newContent = Step6Paying(
            key: _stepKeys[5] as GlobalKey<Step6PayingState>,
            isAdminMode: widget.isAdminMode,
            selectedMember: widget.selectedMember,
            branchId: widget.branchId,
            selectedDate: _selectedDate,
            selectedTime: _selectedTime,
            selectedDuration: _finalPaymentMinutes ?? _selectedDuration,
            selectedTs: _selectedTs,
            totalPrice: _totalPrice,
            pricingAnalysis: _pricingAnalysis,
            selectedCoupons: _selectedCoupons,
          );
          break;
        default:
          newContent = Container();
      }
      
      // 기존 스텝 정보를 유지하면서 콘텐츠만 업데이트
      _stepperService.steps[i] = currentSteps[i].copyWith(content: newContent);
    }
  }

  // 단계 검증
  bool _validateCurrentStep() {
    switch (_stepperService.currentStep) {
      case 0:
        if (_selectedDate == null) {
          _showErrorSnackBar('날짜를 선택해주세요.');
          return false;
        }
        break;
      case 1:
        if (_selectedTime == null) {
          _showErrorSnackBar('시작 시간을 선택해주세요.');
          return false;
        }
        break;
      case 2:
        if (_selectedDuration == null) {
          _showErrorSnackBar('연습 시간을 선택해주세요.');
          return false;
        }
        break;
      case 3:
        if (_selectedTs == null) {
          _showErrorSnackBar('타석을 선택해주세요.');
          return false;
        }
        break;
    }
    return true;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text(message, style: TextStyle(fontSize: 16))),
          ],
        ),
        backgroundColor: Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        elevation: 8,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _onNext() {
    // 단계별 검증
    if (!_validateCurrentStep()) {
      return;
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
    // 마지막 스텝(결제)일 때 완료 처리
    await _processPaymentCompletion();
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
                  completeButtonText: '결제하기',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processPaymentCompletion() async {
    // Step6Paying에서 결제 완료 디버깅 정보 출력
    final step6PayingState = (_stepKeys[5] as GlobalKey<Step6PayingState>).currentState;
    if (step6PayingState != null) {
      final remainingBalance = step6PayingState.calculateRemainingBalance();
      
      // 결제가 완료된 경우에만 디버깅 정보 출력
      if (remainingBalance['isFullyPaid'] == true) {
        step6PayingState.printPaymentDebugInfo(remainingBalance['usedAmounts']);
        
        // 데이터베이스 업데이트 처리
        try {
          // 요금 계산에 사용된 day_of_week 값 계산 (검증용)
          final isHolidayDate = await HolidayService.isHoliday(_selectedDate!);
          final dayOfWeek = HolidayService.getKoreanDayOfWeek(_selectedDate!);
          final queryDayOfWeek = isHolidayDate ? '공휴일' : dayOfWeek;
          
          print('🗓️ [Step0] DB 저장용 day_of_week 계산: $queryDayOfWeek (실제: $dayOfWeek, 공휴일: $isHolidayDate)');
          
          final result = await Step7DbUpdates.processReservationCompletion(
            branchId: widget.branchId!,
            selectedMember: widget.selectedMember!,
            selectedDate: _selectedDate!,
            selectedTime: _selectedTime!,
            selectedDuration: _selectedDuration!,
            selectedTs: _selectedTs!,
            totalPrice: _totalPrice!,
            originalPrice: _originalPrice ?? _totalPrice!, // null인 경우 totalPrice를 사용
            finalPaymentMinutes: _finalPaymentMinutes, // Step5에서 계산된 할인 후 시간
            pricingAnalysis: _pricingAnalysis ?? {
              'base_price': 0,
              'discount_price': 0,
              'extracharge_price': 0,
            },
            usedAmounts: remainingBalance['usedAmounts'],
            selectedPaymentMethods: step6PayingState.getSelectedPaymentMethods().map((method) => method['type'].toString()).toList(), // Map을 String으로 변환
            selectedCoupons: _selectedCoupons,
            contractInfo: remainingBalance['contractInfo'] ?? {}, // 계약 정보 추가
            dayOfWeek: queryDayOfWeek, // 요금 계산에 사용된 day_of_week 값 전달
          );
          
          if (result['success']) {
            _showCompletionDialog(
              usedCoupons: result['usedCoupons'] ?? [],
              issuedCoupons: result['issuedCoupons'] ?? [],
            );
          }
        } catch (e) {
          print('❌ 데이터베이스 업데이트 오류: $e');
          _showErrorSnackBar('예약 정보 저장 중 오류가 발생했습니다: $e');
          return; // 오류 발생 시 완료 처리하지 않음
        }
      } else {
        // 결제가 완료되지 않은 경우 경고 메시지
        _showErrorSnackBar('결제 방법을 선택하여 미정산 잔액을 모두 결제해주세요.');
        return; // 결제 완료되지 않으면 종료하지 않음
      }
    }
  }

  void _showCompletionDialog({
    List<Map<String, dynamic>> usedCoupons = const [],
    List<Map<String, dynamic>> issuedCoupons = const [],
  }) {
    // 종료 시간 계산
    String endTime = '';
    if (_selectedTime != null && (_finalPaymentMinutes ?? _selectedDuration) != null) {
      final startParts = _selectedTime!.split(':');
      final startHour = int.parse(startParts[0]);
      final startMinute = int.parse(startParts[1]);
      final duration = _finalPaymentMinutes ?? _selectedDuration!;
      
      final endTotalMinutes = startHour * 60 + startMinute + duration;
      final endHour = (endTotalMinutes ~/ 60) % 24;
      final endMinuteValue = endTotalMinutes % 60;
      endTime = '${endHour.toString().padLeft(2, '0')}:${endMinuteValue.toString().padLeft(2, '0')}';
    }

    // 할인 총금액 계산
    int totalDiscountAmount = 0;
    for (final coupon in usedCoupons) {
      final discountAmt = _safeParseInt(coupon['discount_amt']);
      if (discountAmt > 0) {
        totalDiscountAmount += discountAmt;
      }
    }
    
    String discountInfo = '';
    if (totalDiscountAmount > 0) {
      discountInfo = '${NumberFormat('#,###').format(totalDiscountAmount)}원 할인';
    }
    print('🎫 할인 총금액: $totalDiscountAmount원');

    // 결제 방법 정보 생성
    List<String> paymentMethods = [];
    final step6PayingState = (_stepKeys[5] as GlobalKey<Step6PayingState>).currentState;
    print('💳 step6PayingState: $step6PayingState');
    if (step6PayingState != null) {
      final remainingBalance = step6PayingState.calculateRemainingBalance();
      final usedAmounts = remainingBalance['usedAmounts'] as Map<String, dynamic>? ?? {};
      final contractInfo = remainingBalance['contractInfo'] as Map<String, dynamic>? ?? {};
      print('💳 사용된 금액: $usedAmounts');
      print('💳 계약 정보: $contractInfo');
      
      // usedAmounts의 각 항목을 순회하면서 결제 방법 정보 생성
      usedAmounts.forEach((methodType, usedAmount) {
        if (usedAmount != null && usedAmount > 0) {
          try {
            if (methodType.startsWith('time_pass_')) {
              // 시간권 차감
              final contractHistoryId = methodType.replaceFirst('time_pass_', '');
              
              // 계약별 시간권 정보에서 차감 후 잔액 계산
              int afterBalance = 0;
              try {
                // step6PayingState에서 계약 정보 가져오기
                final timePassContracts = step6PayingState.getTimePassContracts();
                final targetContract = timePassContracts.firstWhere(
                  (c) => c['contract_history_id'].toString() == contractHistoryId,
                  orElse: () => {'balance': 0},
                );
                final originalBalance = targetContract['balance'] as int? ?? 0;
                afterBalance = originalBalance - (usedAmount as int);
              } catch (e) {
                print('시간권 잔액 계산 오류: $e');
              }
              
              paymentMethods.add('시간제 이용권 ${usedAmount}분 (잔액 ${NumberFormat('#,###').format(afterBalance)}분)');
              
            } else if (methodType.startsWith('prepaid_credit_')) {
              // 선불크레딧 차감
              final contractHistoryId = methodType.replaceFirst('prepaid_credit_', '');
              
              // 계약별 선불크레딧 정보에서 차감 후 잔액 계산
              int afterBalance = 0;
              try {
                // step6PayingState에서 계약 정보 가져오기
                final prepaidContracts = step6PayingState.getPrepaidCreditContracts();
                final targetContract = prepaidContracts.firstWhere(
                  (c) => c['contract_history_id'].toString() == contractHistoryId,
                  orElse: () => {'balance': 0},
                );
                final originalBalance = targetContract['balance'] as int? ?? 0;
                afterBalance = originalBalance - (usedAmount as int);
              } catch (e) {
                print('선불크레딧 잔액 계산 오류: $e');
              }
              
              paymentMethods.add('선불크레딧 ${NumberFormat('#,###').format(usedAmount)}원 (잔액 ${NumberFormat('#,###').format(afterBalance)}원)');
              
            } else if (methodType == 'card_payment') {
              // 카드결제
              paymentMethods.add('카드결제 ${NumberFormat('#,###').format(usedAmount)}원');
            }
          } catch (e) {
            print('결제 방법 정보 생성 오류: $e');
          }
        }
      });
    }
    print('💳 결제 방법 정보: $paymentMethods');

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      _buildInfoRow('시간', '$_selectedTime ~ $endTime'),
                      _buildInfoRow('타석', '$_selectedTs번'),
                      _buildInfoRow('이용시간', '${_finalPaymentMinutes ?? _selectedDuration}분'),
                      if (discountInfo.isNotEmpty)
                        _buildInfoRow('할인', discountInfo),
                      _buildInfoRow('결제금액', '${NumberFormat('#,###').format(_totalPrice)}원'),
                      if (paymentMethods.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Text(
                          '결제수단',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4A5568),
                          ),
                        ),
                        SizedBox(height: 4),
                        ...paymentMethods.map((method) => Padding(
                          padding: EdgeInsets.only(left: 8, top: 2),
                          child: Text(
                            '• $method',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        )),
                      ],
                      
                      // 쿠폰 정보 표시
                      if (usedCoupons.isNotEmpty || issuedCoupons.isNotEmpty) ...[
                        SizedBox(height: 16),
                        Divider(color: Colors.grey[300]),
                        SizedBox(height: 16),
                        
                        // 사용된 쿠폰 정보
                        if (usedCoupons.isNotEmpty) ...[
                          Text(
                            '사용된 쿠폰 (${usedCoupons.length}개)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4A5568),
                            ),
                          ),
                          SizedBox(height: 4),
                          ...usedCoupons.map((coupon) => Padding(
                            padding: EdgeInsets.only(left: 8, top: 2),
                            child: Text(
                              '• ${coupon['coupon_description'] ?? '할인쿠폰'} (${NumberFormat('#,###').format(_safeParseInt(coupon['discount_amt']))}원)',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          )),
                          SizedBox(height: 8),
                        ],
                        
                        // 발행된 쿠폰 정보
                        if (issuedCoupons.isNotEmpty) ...[
                          Text(
                            '발행된 쿠폰 (${issuedCoupons.length}개)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF00A86B),
                            ),
                          ),
                          SizedBox(height: 4),
                          ...issuedCoupons.map((coupon) {
                            // 할인 금액 계산
                            String discountText = '';
                            final discountAmt = _safeParseInt(coupon['discount_amt']);
                            final discountRatio = _safeParseInt(coupon['discount_ratio']);
                            final discountMin = _safeParseInt(coupon['discount_min']);
                            
                            if (discountAmt > 0) {
                              discountText = '${NumberFormat('#,###').format(discountAmt)}원';
                            } else if (discountRatio > 0) {
                              discountText = '${discountRatio}%';
                            } else if (discountMin > 0) {
                              discountText = '${discountMin}분';
                            }
                            
                            // 유효기간 포맷 (~25.07.24)
                            String expiryText = '';
                            if (coupon['coupon_expiry_date'] != null) {
                              final expiryDate = coupon['coupon_expiry_date'].toString();
                              if (expiryDate.length >= 10) {
                                final parts = expiryDate.split('-');
                                if (parts.length >= 3) {
                                  final year = parts[0].substring(2); // 2025 -> 25
                                  final month = parts[1];
                                  final day = parts[2];
                                  expiryText = '(~$year.$month.$day)';
                                }
                              }
                            }
                            
                            return Padding(
                              padding: EdgeInsets.only(left: 8, top: 2),
                              child: Text(
                                '• ${coupon['coupon_description'] ?? '할인쿠폰'} $discountText $expiryText',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF00A86B),
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 24),
                
                // 확인 버튼
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [Color(0xFF00A86B), Color(0xFF00A86B).withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF00A86B).withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      // 다이얼로그 닫기
                      Navigator.of(context).pop();

                      // 관리자 모드인 경우: 팝업 내부에서만 네비게이션 (rootNavigator: false)
                      // 일반 모드인 경우: 일반 네비게이션
                      final navigator = widget.isAdminMode
                          ? Navigator.of(context, rootNavigator: false)
                          : Navigator.of(context);

                      // 메인 페이지의 조회 탭(index 1)으로 이동
                      navigator.pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => MainPage(
                            isAdminMode: widget.isAdminMode,
                            selectedMember: widget.selectedMember,
                            branchId: widget.branchId,
                            initialIndex: 1, // 조회 탭 선택
                          ),
                        ),
                      );
                    },
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