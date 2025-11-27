import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/sms_auth_service.dart';
import '../../services/api_service.dart';

class SMSVerificationPage extends StatefulWidget {
  const SMSVerificationPage({Key? key}) : super(key: key);

  @override
  State<SMSVerificationPage> createState() => _SMSVerificationPageState();
}

class _SMSVerificationPageState extends State<SMSVerificationPage> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  // 관리자 권한 확인
  bool _isAdminUser(Map<String, dynamic> user) {
    final memberType = user['member_type']?.toString().toLowerCase();
    return memberType == 'admin' || 
           memberType == '관리자' || 
           memberType == 'administrator' ||
           memberType == 'staff' ||
           memberType == '스태프';
  }

  String? _validateCode(String? value) {
    if (value == null || value.isEmpty) {
      return '인증번호를 입력해주세요';
    }
    
    if (value.length != 6) {
      return '6자리 인증번호를 입력해주세요';
    }
    
    return null;
  }

  Future<void> _verifySMSCode() async {
    if (!_formKey.currentState!.validate()) return;

    final phoneAuth = Provider.of<SmsAuthService>(context, listen: false);
    
    try {
      final success = await phoneAuth.verifySMSCode(_codeController.text);
      
      if (success && mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.green.shade700,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '인증 완료!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '전화번호 인증이 성공적으로\n완료되었습니다.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 다이얼로그 닫기
                Navigator.of(context).pop(); // SMS 페이지 닫기
                Navigator.of(context).pop(); // 전화번호 입력 페이지 닫기
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resendSMS() async {
    final phoneAuth = Provider.of<SmsAuthService>(context, listen: false);
    
    try {
      phoneAuth.resetForRetry();
      Navigator.pop(context); // SMS 페이지로 돌아가기
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('전화번호 입력 화면으로 돌아갑니다'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('인증번호 입력'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              
              // 제목
              Text(
                '인증번호를 입력해주세요',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // 설명
              Consumer<SmsAuthService>(
                builder: (context, phoneAuth, child) {
                  // 관리자 권한 확인
                  final currentUser = ApiService.getCurrentUser();
                  final isAdmin = currentUser != null && 
                                  _isAdminUser(currentUser);
                  
                  return Text(
                    isAdmin 
                        ? '관리자 계정입니다.\n인증번호로 "000000"을 입력하세요.'
                        : '${phoneAuth.currentPhoneNumber ?? "등록된 번호"}로\n6자리 인증번호를 전송했습니다.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isAdmin ? Colors.orange[700] : Colors.grey[600],
                      fontWeight: isAdmin ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              
              const SizedBox(height: 40),
              
              // 인증번호 입력 필드
              TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: '인증번호',
                  hintText: '6자리 숫자 입력',
                  prefixIcon: Icon(Icons.sms),
                  border: OutlineInputBorder(),
                ),
                validator: _validateCode,
                style: const TextStyle(
                  fontSize: 18,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // 인증 확인 버튼
              Consumer<SmsAuthService>(
                builder: (context, phoneAuth, child) {
                  return ElevatedButton(
                    onPressed: phoneAuth.isLoading ? null : _verifySMSCode,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: phoneAuth.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            '인증 확인',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              // 재전송 버튼
              TextButton(
                onPressed: _resendSMS,
                child: Text(
                  '인증번호를 받지 못했나요? 다시 전송',
                  style: TextStyle(
                    color: Colors.grey[600],
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 안내 문구
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.timer, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '인증번호 유효시간',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 인증번호는 5분간 유효합니다\n'
                      '• 인증번호가 오지 않으면 스팸함을 확인하세요\n'
                      '• 여러 번 시도해도 안 될 경우 관리자에게 문의하세요',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}