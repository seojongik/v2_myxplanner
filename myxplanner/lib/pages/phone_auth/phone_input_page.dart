import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/sms_auth_service.dart';
import '../../services/api_service.dart';
import 'sms_verification_page.dart';

class PhoneInputPage extends StatefulWidget {
  const PhoneInputPage({Key? key}) : super(key: key);

  @override
  State<PhoneInputPage> createState() => _PhoneInputPageState();
}

class _PhoneInputPageState extends State<PhoneInputPage> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  @override
  void initState() {
    super.initState();
    _loadCurrentUserPhone();
  }
  
  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
  
  // 현재 로그인한 사용자의 전화번호 가져오기
  void _loadCurrentUserPhone() {
    final currentUser = ApiService.getCurrentUser();
    if (currentUser != null && currentUser['member_phone'] != null) {
      _phoneController.text = currentUser['member_phone'];
    }
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return '전화번호를 입력해주세요';
    }
    
    // 숫자만 추출
    String digits = value.replaceAll(RegExp(r'[^\d]'), '');
    
    // 010으로 시작하는 11자리 검증
    if (digits.length == 11 && digits.startsWith('010')) {
      return null;
    }
    
    return '올바른 전화번호를 입력해주세요 (010-XXXX-XXXX)';
  }

  void _formatPhoneNumber() {
    String text = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
    
    if (text.length <= 3) {
      _phoneController.text = text;
    } else if (text.length <= 7) {
      _phoneController.text = '${text.substring(0, 3)}-${text.substring(3)}';
    } else if (text.length <= 11) {
      _phoneController.text = '${text.substring(0, 3)}-${text.substring(3, 7)}-${text.substring(7)}';
    }
    
    _phoneController.selection = TextSelection.fromPosition(
      TextPosition(offset: _phoneController.text.length),
    );
  }

  Future<void> _sendSMS() async {
    if (!_formKey.currentState!.validate()) return;

    final phoneAuth = Provider.of<SmsAuthService>(context, listen: false);
    
    try {
      final success = await phoneAuth.sendSMSVerification(_phoneController.text);
      
      if (success && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SMSVerificationPage(),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('전화번호 인증'),
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
                '전화번호를 입력해주세요',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // 설명
              Text(
                '등록된 회원 전화번호로\n인증번호를 전송합니다.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // 전화번호 입력 필드
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                readOnly: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                decoration: const InputDecoration(
                  labelText: '전화번호',
                  hintText: '010-1234-5678',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.lock, color: Colors.grey),
                ),
                validator: _validatePhoneNumber,
                onChanged: (_) => _formatPhoneNumber(),
              ),
              
              const SizedBox(height: 24),
              
              // 인증번호 전송 버튼
              Consumer<SmsAuthService>(
                builder: (context, phoneAuth, child) {
                  return ElevatedButton(
                    onPressed: phoneAuth.isLoading ? null : _sendSMS,
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
                            '인증번호 전송',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  );
                },
              ),
              
              const SizedBox(height: 20),
              
              // 안내 문구
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '알아두세요',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 관리자가 등록한 회원만 인증 가능합니다\n'
                      '• 인증번호는 SMS로 전송됩니다\n'
                      '• 인증번호 유효시간은 5분입니다',
                      style: TextStyle(
                        color: Colors.blue.shade700,
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