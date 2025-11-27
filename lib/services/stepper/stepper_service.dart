import 'package:flutter/material.dart';
import 'step_model.dart';

class StepperService extends ChangeNotifier {
  List<StepModel> _steps = [];
  int _currentStep = 0;

  List<StepModel> get steps => _steps;
  int get currentStep => _currentStep;
  int get totalSteps => _steps.length;
  bool get isFirstStep => _currentStep == 0;
  bool get isLastStep => _currentStep == _steps.length - 1;

  void initialize(List<StepModel> steps) {
    _steps = steps;
    _currentStep = 0;
    notifyListeners();
  }

  void nextStep() {
    if (_currentStep < _steps.length - 1) {
      _currentStep++;
      notifyListeners();
    }
  }

  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }

  void goToStep(int stepIndex) {
    if (stepIndex >= 0 && stepIndex < _steps.length) {
      _currentStep = stepIndex;
      notifyListeners();
    }
  }

  void updateStepValue(int stepIndex, String? value) {
    if (stepIndex >= 0 && stepIndex < _steps.length) {
      _steps[stepIndex] = _steps[stepIndex].copyWith(
        selectedValue: value,
        isCompleted: value != null,
      );
      notifyListeners();
    }
  }

  void updateCurrentStepValue(String? value) {
    updateStepValue(_currentStep, value);
  }

  bool isStepCompleted(int stepIndex) {
    if (stepIndex >= 0 && stepIndex < _steps.length) {
      return _steps[stepIndex].isCompleted || _currentStep > stepIndex;
    }
    return false;
  }

  bool isCurrentStepValid() {
    // 기본 검증 로직 - 개별 구현에서 오버라이드 가능
    return true;
  }

  void reset() {
    _currentStep = 0;
    for (int i = 0; i < _steps.length; i++) {
      _steps[i] = _steps[i].copyWith(
        selectedValue: null,
        isCompleted: false,
      );
    }
    notifyListeners();
  }
} 