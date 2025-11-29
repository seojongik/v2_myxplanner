import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/api_service.dart';
import '../../../services/password_service.dart';

class PasswordAccountPage extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const PasswordAccountPage({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _PasswordAccountPageState createState() => _PasswordAccountPageState();
}

class _PasswordAccountPageState extends State<PasswordAccountPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('비밀번호 관리'),
        backgroundColor: Color(0xFF00A86B),
        foregroundColor: Colors.white,
      ),
      body: PasswordAccountContent(
        isAdminMode: widget.isAdminMode,
        selectedMember: widget.selectedMember,
        branchId: widget.branchId,
      ),
    );
  }
}

// 임베드 가능한 비밀번호 관리 콘텐츠 위젯
class PasswordAccountContent extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const PasswordAccountContent({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _PasswordAccountContentState createState() => _PasswordAccountContentState();
}

class _PasswordAccountContentState extends State<PasswordAccountContent> {
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
      final currentUser = ApiService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('사용자 정보가 없습니다');
      }

      final currentPassword = _currentPasswordController.text;
      final newPassword = _newPasswordController.text;
      
      // 현재 비밀번호 확인 (PasswordService 사용 - bcrypt, SHA-256, 평문 모두 지원)
      final storedPassword = currentUser['member_password']?.toString() ?? '';
      final isCurrentPasswordValid = PasswordService.verifyPassword(
        currentPassword,
        storedPassword,
      );
      
      if (!isCurrentPasswordValid) {
        throw Exception('현재 비밀번호가 올바르지 않습니다');
      }

      // 새 비밀번호 해시 처리 (bcrypt 사용)
      final hashedNewPassword = PasswordService.hashPassword(newPassword);
      final phoneNumber = currentUser['member_phone'];
      
      // 데이터베이스 업데이트 (전체 지점)
      final result = await ApiService.updateData(
        table: 'v3_members',
        data: {
          'member_password': hashedNewPassword,
          'member_update': DateTime.now().toIso8601String(),
        },
        where: [
          {'field': 'member_phone', 'operator': '=', 'value': phoneNumber}
        ],
      );

      if (result['success'] == true) {
        // 현재 사용자 정보 업데이트
        final updatedUser = Map<String, dynamic>.from(currentUser);
        updatedUser['member_password'] = hashedNewPassword;
        ApiService.setCurrentUser(updatedUser, isAdminLogin: ApiService.isAdminLogin());
        
        _showSuccessDialog();
      } else {
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
                '모든 지점의 비밀번호가\\n성공적으로 변경되었습니다.',
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
                Navigator.of(context).pop();
                // 폼 초기화
                _currentPasswordController.clear();
                _newPasswordController.clear();
                _confirmPasswordController.clear();
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
    return Container(
      color: const Color(0xFFF8F9FA),
      child: Padding(
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
                  color: const Color(0xFF00A86B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00A86B).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, color: const Color(0xFF00A86B), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '비밀번호 변경',
                          style: TextStyle(
                            color: const Color(0xFF00A86B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 6자리 이상\\n• 숫자 및 특수문자 포함\\n• 전화번호 뒤 4자리 사용 금지\\n• 모든 지점에 동시 적용됩니다',
                      style: TextStyle(
                        color: const Color(0xFF00A86B),
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
                  backgroundColor: const Color(0xFF00A86B),
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
              
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
} 