import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/password_service.dart';

class PasswordChangePage extends StatefulWidget {
  const PasswordChangePage({Key? key}) : super(key: key);

  @override
  State<PasswordChangePage> createState() => _PasswordChangePageState();
}

class _PasswordChangePageState extends State<PasswordChangePage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }


  // 기본 비밀번호 확인 (1111 또는 전화번호 뒤 4자리)
  bool _isDefaultPassword(String password, String phoneNumber) {
    if (password == '1111') return true;
    
    // 전화번호 뒤 4자리 추출
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.length >= 4) {
      final lastFour = cleanPhone.substring(cleanPhone.length - 4);
      return password == lastFour;
    }
    
    return false;
  }

  // 비밀번호 유효성 검사
  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return '새 비밀번호를 입력해주세요';
    }
    
    if (value.length < 6) {
      return '비밀번호는 6자리 이상이어야 합니다';
    }
    
    // 전화번호 뒤 4자리 금지
    final currentUser = ApiService.getCurrentUser();
    if (currentUser != null && currentUser['member_phone'] != null) {
      final cleanPhone = currentUser['member_phone'].toString().replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanPhone.length >= 4) {
        final lastFour = cleanPhone.substring(cleanPhone.length - 4);
        if (value.contains(lastFour)) {
          return '전화번호 뒤 4자리는 사용할 수 없습니다';
        }
      }
    }
    
    // 숫자 포함 확인
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return '숫자를 최소 1개 포함해야 합니다';
    }
    
    // 특수문자 포함 확인
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return '특수문자를 최소 1개 포함해야 합니다';
    }
    
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return '비밀번호 확인을 입력해주세요';
    }
    
    if (value != _newPasswordController.text) {
      return '비밀번호가 일치하지 않습니다';
    }
    
    return null;
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('🔄 비밀번호 변경 시작');
      final currentUser = ApiService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('사용자 정보가 없습니다');
      }

      print('👤 현재 사용자: ${currentUser['member_name']} (${currentUser['member_id']})');
      
      final currentPassword = _currentPasswordController.text;
      final newPassword = _newPasswordController.text;
      
      print('🔐 비밀번호 검증 시작');
      print('입력된 현재 비밀번호: "$currentPassword"');
      print('입력된 새 비밀번호: "$newPassword"');
      
      // 현재 비밀번호 확인 (PasswordService 사용 - bcrypt, SHA-256, 평문 모두 지원)
      final storedPassword = currentUser['member_password']?.toString() ?? '';
      print('저장된 비밀번호: "$storedPassword" (길이: ${storedPassword.length})');
      
      final isCurrentPasswordValid = PasswordService.verifyPassword(
        currentPassword,
        storedPassword,
      );
      
      if (!isCurrentPasswordValid) {
        print('❌ 현재 비밀번호 불일치');
        throw Exception('현재 비밀번호가 올바르지 않습니다');
      }

      print('✅ 현재 비밀번호 확인 완료');
      
      // 새 비밀번호 해시 처리 (bcrypt 사용)
      final hashedNewPassword = PasswordService.hashPassword(newPassword);
      print('🔐 새 비밀번호 해시: $hashedNewPassword');
      
      // 데이터베이스 업데이트 (전체 지점)
      print('📝 전체 지점 비밀번호 업데이트 시작');
      final phoneNumber = currentUser['member_phone'];
      
      final updateData = {
        'member_password': hashedNewPassword,
        'member_update': DateTime.now().toIso8601String(),
      };
      final whereConditions = [
        {'field': 'member_phone', 'operator': '=', 'value': phoneNumber}
      ];
      
      print('업데이트 데이터: $updateData');
      print('WHERE 조건 (전화번호 기준): $whereConditions');
      
      final result = await ApiService.updateData(
        table: 'v3_members',
        data: updateData,
        where: whereConditions,
      );

      print('📊 업데이트 결과: $result');

      if (result['success'] == true) {
        print('✅ 데이터베이스 업데이트 성공');
        print('영향받은 행 수: ${result['affectedRows']}');
        
        // 현재 사용자 정보 업데이트
        final updatedUser = Map<String, dynamic>.from(currentUser);
        updatedUser['member_password'] = hashedNewPassword;
        ApiService.setCurrentUser(updatedUser, isAdminLogin: ApiService.isAdminLogin());
        
        print('🔄 현재 사용자 정보 업데이트 완료');
        _showSuccessDialog();
      } else {
        print('❌ 데이터베이스 업데이트 실패: ${result['error']}');
        throw Exception(result['error'] ?? '비밀번호 변경에 실패했습니다');
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
                '비밀번호 변경 완료!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '비밀번호가 성공적으로\\n변경되었습니다.',
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
                Navigator.of(context).pop(); // 비밀번호 변경 페이지 닫기
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('비밀번호 변경'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              
              // 안내 메시지
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '보안을 위해 비밀번호를 변경해주세요',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 6자리 이상\\n• 숫자 및 특수문자 포함\\n• 전화번호 뒤 4자리 사용 금지',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // 현재 비밀번호
              TextFormField(
                controller: _currentPasswordController,
                obscureText: !_showCurrentPassword,
                decoration: InputDecoration(
                  labelText: '현재 비밀번호',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_showCurrentPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showCurrentPassword = !_showCurrentPassword),
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '현재 비밀번호를 입력해주세요';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 20),
              
              // 새 비밀번호
              TextFormField(
                controller: _newPasswordController,
                obscureText: !_showNewPassword,
                decoration: InputDecoration(
                  labelText: '새 비밀번호',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_showNewPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showNewPassword = !_showNewPassword),
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: _validateNewPassword,
              ),
              
              const SizedBox(height: 20),
              
              // 비밀번호 확인
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: !_showConfirmPassword,
                decoration: InputDecoration(
                  labelText: '비밀번호 확인',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_showConfirmPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: _validateConfirmPassword,
              ),
              
              const SizedBox(height: 30),
              
              // 변경 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        '비밀번호 변경',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}