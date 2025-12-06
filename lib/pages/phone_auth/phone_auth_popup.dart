import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/aligo_sms_service.dart';
import '../../services/api_service.dart';

/// 전화번호 인증 전체 플로우 관리
/// 
/// 플로우: 안내 → 전화번호 확인 → 인증번호 입력 → 완료
class PhoneAuthPopup {
  static void show({
    required BuildContext context,
    VoidCallback? onComplete,
    VoidCallback? onLater,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: _PhoneAuthFlow(
            onComplete: onComplete,
            onLater: onLater ?? () => Navigator.of(context).pop(),
          ),
        );
      },
    );
  }
}

/// 인증 플로우 상태 관리
enum _AuthStep { intro, sendCode, verifyCode, complete }

class _PhoneAuthFlow extends StatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback onLater;

  const _PhoneAuthFlow({
    this.onComplete,
    required this.onLater,
  });

  @override
  State<_PhoneAuthFlow> createState() => _PhoneAuthFlowState();
}

class _PhoneAuthFlowState extends State<_PhoneAuthFlow> {
  _AuthStep _currentStep = _AuthStep.intro;
  final _codeController = TextEditingController();
  String? _phoneNumber;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPhoneNumber();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _loadPhoneNumber() {
    final currentUser = ApiService.getCurrentUser();
    if (currentUser != null) {
      _phoneNumber = currentUser['member_phone']?.toString();
    }
  }

  // 인증번호 발송
  Future<void> _sendCode() async {
    if (_phoneNumber == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final smsService = Provider.of<AligoSmsService>(context, listen: false);
      final success = await smsService.sendSMSVerification(_phoneNumber!);
      
      if (success && mounted) {
        setState(() {
          _currentStep = _AuthStep.verifyCode;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  // 인증번호 검증
  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = '6자리 인증번호를 입력해주세요');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final smsService = Provider.of<AligoSmsService>(context, listen: false);
      final success = await smsService.verifySMSCode(code);
      
      if (success && mounted) {
        setState(() {
          _currentStep = _AuthStep.complete;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  // 재발송
  Future<void> _resendCode() async {
    _codeController.clear();
    await _sendCode();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildCurrentStep(),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case _AuthStep.intro:
        return _IntroStep(
          onVerify: () => setState(() => _currentStep = _AuthStep.sendCode),
          onLater: widget.onLater,
        );
      case _AuthStep.sendCode:
        return _SendCodeStep(
          phoneNumber: _phoneNumber ?? '',
          isLoading: _isLoading,
          errorMessage: _errorMessage,
          onSend: _sendCode,
          onBack: () => setState(() => _currentStep = _AuthStep.intro),
        );
      case _AuthStep.verifyCode:
        return _VerifyCodeStep(
          phoneNumber: _phoneNumber ?? '',
          codeController: _codeController,
          isLoading: _isLoading,
          errorMessage: _errorMessage,
          onVerify: _verifyCode,
          onResend: _resendCode,
          onBack: () => setState(() => _currentStep = _AuthStep.sendCode),
        );
      case _AuthStep.complete:
        return _CompleteStep(
          onConfirm: () {
            Navigator.of(context).pop();
            widget.onComplete?.call();
          },
        );
    }
  }
}

// ============================================================
// Step 1: 안내 화면
// ============================================================
class _IntroStep extends StatelessWidget {
  final VoidCallback onVerify;
  final VoidCallback onLater;

  const _IntroStep({
    required this.onVerify,
    required this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 2),
          
          _buildIcon(Icons.verified_user_rounded),
          const SizedBox(height: 32),
          
          const Text(
            '전화번호 인증이 필요합니다',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          
          Text(
            '전화번호 인증은 계정당 최초 1회만 진행되며,\n장기 미인증 계정은 삭제될 수 있습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              height: 1.6,
            ),
          ),
          
          const Spacer(flex: 3),
          
          _buildPrimaryButton('인증하기', onVerify),
          const SizedBox(height: 12),
          _buildSecondaryButton('나중에', onLater),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ============================================================
// Step 2: 전화번호 확인 & 발송
// ============================================================
class _SendCodeStep extends StatelessWidget {
  final String phoneNumber;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSend;
  final VoidCallback onBack;

  const _SendCodeStep({
    required this.phoneNumber,
    required this.isLoading,
    this.errorMessage,
    required this.onSend,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          
          // 뒤로가기
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios, size: 20),
              color: Colors.grey[600],
            ),
          ),
          
          const Spacer(flex: 2),
          
          _buildIcon(Icons.phone_android),
          const SizedBox(height: 32),
          
          const Text(
            '인증번호를 받을\n전화번호를 확인해주세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.5,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 24),
          
          // 전화번호 표시
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              phoneNumber,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
                letterSpacing: 1,
              ),
            ),
          ),
          
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
          
          const Spacer(flex: 3),
          
          _buildPrimaryButton(
            isLoading ? '발송 중...' : '인증번호 받기',
            isLoading ? null : onSend,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ============================================================
// Step 3: 인증번호 입력
// ============================================================
class _VerifyCodeStep extends StatelessWidget {
  final String phoneNumber;
  final TextEditingController codeController;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onBack;

  const _VerifyCodeStep({
    required this.phoneNumber,
    required this.codeController,
    required this.isLoading,
    this.errorMessage,
    required this.onVerify,
    required this.onResend,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          
          // 뒤로가기
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios, size: 20),
              color: Colors.grey[600],
            ),
          ),
          
          const Spacer(flex: 2),
          
          _buildIcon(Icons.sms_outlined),
          const SizedBox(height: 32),
          
          const Text(
            '인증번호를 입력해주세요',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          
          Text(
            '$phoneNumber로 전송된\n6자리 인증번호를 입력하세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          
          // 인증번호 입력
          TextField(
            controller: codeController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              letterSpacing: 8,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              hintText: '000000',
              hintStyle: TextStyle(
                color: Colors.grey[300],
                letterSpacing: 8,
              ),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
            ),
          ),
          
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
          
          const SizedBox(height: 16),
          
          // 재발송 버튼
          TextButton(
            onPressed: isLoading ? null : onResend,
            child: Text(
              '인증번호 재발송',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          
          const Spacer(flex: 3),
          
          _buildPrimaryButton(
            isLoading ? '확인 중...' : '확인',
            isLoading ? null : onVerify,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ============================================================
// Step 4: 완료
// ============================================================
class _CompleteStep extends StatelessWidget {
  final VoidCallback onConfirm;

  const _CompleteStep({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 2),
          
          // 체크 아이콘
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 56,
              color: Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(height: 32),
          
          const Text(
            '인증 완료!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          
          Text(
            '전화번호 인증이\n성공적으로 완료되었습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          
          const Spacer(flex: 3),
          
          _buildPrimaryButton('확인', onConfirm, color: const Color(0xFF4CAF50)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ============================================================
// 공통 위젯
// ============================================================
Widget _buildIcon(IconData icon) {
  return Container(
    width: 100,
    height: 100,
    decoration: const BoxDecoration(
      color: Color(0xFFF0F7FF),
      shape: BoxShape.circle,
    ),
    child: Icon(
      icon,
      size: 48,
      color: const Color(0xFF2196F3),
    ),
  );
}

Widget _buildPrimaryButton(String text, VoidCallback? onPressed, {Color? color}) {
  return SizedBox(
    width: double.infinity,
    height: 54,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey[300],
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

Widget _buildSecondaryButton(String text, VoidCallback onPressed) {
  return SizedBox(
    width: double.infinity,
    height: 54,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.grey[600],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}
