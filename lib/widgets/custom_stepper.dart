import 'package:flutter/material.dart';
import '../services/stepper/stepper_service.dart';
import '../services/stepper/step_model.dart';

class CustomStepper extends StatelessWidget {
  final StepperService stepperService;
  final Function()? onPrevious;
  final Function()? onNext;
  final Function()? onComplete;
  final String? previousButtonText;
  final String? nextButtonText;
  final String? completeButtonText;
  final EdgeInsets? padding;

  const CustomStepper({
    Key? key,
    required this.stepperService,
    this.onPrevious,
    this.onNext,
    this.onComplete,
    this.previousButtonText,
    this.nextButtonText,
    this.completeButtonText,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: stepperService,
      builder: (context, child) {
        return Container(
          color: Color(0xFFF8FAFC),
          child: SingleChildScrollView(
            padding: padding ?? EdgeInsets.all(16),
            child: Column(
              children: [
                // 커스텀 스테퍼 구현
                for (int index = 0; index < stepperService.steps.length; index++) ...[
                  _buildCustomStep(index),
                  if (index < stepperService.steps.length - 1) _buildStepConnector(index),
                ],
                // 하단 여백 (버튼이 가려지지 않도록)
                SizedBox(height: 150),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomStep(int index) {
    final step = stepperService.steps[index];
    final isCurrentStep = stepperService.currentStep == index;
    final isCompletedStep = stepperService.isStepCompleted(index);

    // 디버그: step 6일 때 로그 출력
    if (index == 5) {
      print('🔍 [CustomStepper] Step 6 렌더링');
      print('  - isCurrentStep: $isCurrentStep');
      print('  - currentStep: ${stepperService.currentStep}');
      print('  - 버튼 렌더링 여부: $isCurrentStep');
    }

    // 현재 스텝인 경우에만 큰 높이 사용, 나머지는 최소 높이
    final containerHeight = isCurrentStep ? 176.0 : 80.0;
    
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: containerHeight),
      child: Stack(
        children: [
          // 컨텐츠 영역 (전체 너비 사용)
          Container(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 스텝 헤더 (아이콘 너비만큼 왼쪽 마진)
                Container(
                  margin: EdgeInsets.only(left: 72), // 아이콘(56) + 간격(16)
                  child: GestureDetector(
                    onTap: isCompletedStep ? () {
                      stepperService.goToStep(index);
                    } : null,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.transparent,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isCompletedStep || isCurrentStep ? step.color : Colors.black).withOpacity(0.06),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              step.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isCompletedStep || isCurrentStep 
                                    ? Color(0xFF1A202C)
                                    : Color(0xFF64748B),
                              ),
                            ),
                          ),
                          if (step.selectedValue != null) ...[
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: step.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: step.color.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                step.selectedValue!,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: step.color,
                                ),
                              ),
                            ),
                          ],
                          // 완료된 스텝인 경우 클릭 가능함을 나타내는 아이콘 추가
                          if (isCompletedStep) ...[
                            SizedBox(width: 8),
                            Icon(
                              Icons.touch_app,
                              size: 16,
                              color: step.color.withOpacity(0.6),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                
                // 스텝 콘텐츠 (현재 활성화된 스텝만 표시, 전체 너비 사용)
                if (isCurrentStep) ...[
                  SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    child: _buildStepContent(step.content),
                  ),
                  SizedBox(height: 24),
                  // 현재 단계의 네비게이션 버튼들 (전체 너비 사용)
                  Container(
                    child: _buildNavigationButtons(),
                  ),
                ],
              ],
            ),
          ),
          
          // 왼쪽 아이콘 (절대 위치)
          Positioned(
            left: 0,
            top: 0,
            child: GestureDetector(
              onTap: isCompletedStep ? () {
                stepperService.goToStep(index);
              } : null,
              child: Container(
                width: 56,
                height: containerHeight,
                child: Stack(
                  children: [
                    // 위쪽으로 올라가는 연결선 (첫 번째 스텝이 아닌 경우)
                    if (index > 0)
                      Positioned(
                        left: 28 - 1.5,
                        top: 0,
                        child: Container(
                          width: 3,
                          height: 0, // 아이콘 위쪽 테두리까지만
                          decoration: BoxDecoration(
                            color: (stepperService.currentStep > index - 1) 
                                ? stepperService.steps[index - 1].color
                                : Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    // 아래쪽으로 내려가는 연결선 (마지막 스텝이 아니고 현재 스텝이 아닌 경우만)
                    if (index < stepperService.steps.length - 1 && !isCurrentStep)
                      Positioned(
                        left: 28 - 1.5,
                        top: 56, // 아이콘 아래쪽 테두리부터 시작
                        child: Container(
                          width: 3,
                          height: containerHeight - 56, // 아이콘 아래쪽부터 끝까지
                          decoration: BoxDecoration(
                            color: isCompletedStep 
                                ? step.color
                                : Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    // 아이콘
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isCompletedStep || isCurrentStep 
                            ? step.color.withOpacity(0.1)
                            : Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCompletedStep || isCurrentStep 
                              ? step.color
                              : Color(0xFFE2E8F0),
                          width: 2,
                        ),
                        boxShadow: isCurrentStep ? [
                          BoxShadow(
                            color: step.color.withOpacity(0.2),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ] : null,
                      ),
                      child: Center(
                        child: isCompletedStep 
                            ? Icon(
                                Icons.check_circle,
                                color: step.color,
                                size: 28,
                              )
                            : Text(
                                step.icon,
                                style: TextStyle(fontSize: 24),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int index) {
    // 현재 스텝 다음에만 간격 추가
    if (index == stepperService.currentStep) {
      return SizedBox(height: 24);
    }
    return SizedBox.shrink();
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 이전 버튼 (첫 번째 단계가 아닐 때만 표시)
          if (!stepperService.isFirstStep) ...[
            Expanded(
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFFE2E8F0), width: 1.5),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    if (onPrevious != null) {
                      onPrevious!();
                    } else {
                      stepperService.previousStep();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    previousButtonText ?? '이전',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A5568),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
          ],
          
          // 다음/완료 버튼 (항상 표시)
          Expanded(
            child: Container(
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
                  print('');
                  print('🔴🔴🔴 버튼 클릭됨! 🔴🔴🔴');
                  print('  현재 스텝: ${stepperService.currentStep}');
                  print('  총 스텝 수: ${stepperService.totalSteps}');
                  print('  isLastStep: ${stepperService.isLastStep}');
                  print('  onComplete 존재: ${onComplete != null}');
                  print('  onNext 존재: ${onNext != null}');
                  
                  if (stepperService.isLastStep) {
                    print('  → 마지막 스텝이므로 onComplete 호출 시도');
                    if (onComplete != null) {
                      print('    ✅ onComplete 호출됨!');
                      onComplete!();
                    } else {
                      print('    ❌ onComplete가 null임');
                    }
                  } else {
                    print('  → 마지막 스텝이 아니므로 onNext 호출 시도');
                    if (onNext != null) {
                      print('    ✅ onNext 호출됨!');
                      onNext!();
                    } else {
                      print('    → onNext가 null이므로 기본 동작 실행');
                      stepperService.nextStep();
                    }
                  }
                  print('🔴🔴🔴 버튼 클릭 처리 완료 🔴🔴🔴');
                  print('');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  stepperService.isLastStep 
                      ? (completeButtonText ?? '완료') 
                      : (nextButtonText ?? '다음'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(Widget content) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: content,
    );
  }
} 