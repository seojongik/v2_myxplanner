import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../services/api_service.dart';
import '../../../services/password_service.dart';

class ProfileAccountPage extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const ProfileAccountPage({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _ProfileAccountPageState createState() => _ProfileAccountPageState();
}

class _ProfileAccountPageState extends State<ProfileAccountPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('개인정보 관리'),
        backgroundColor: Color(0xFFFF8C00),
        foregroundColor: Colors.white,
      ),
      body: ProfileAccountContent(
        isAdminMode: widget.isAdminMode,
        selectedMember: widget.selectedMember,
        branchId: widget.branchId,
      ),
    );
  }
}

// 임베드 가능한 개인정보 관리 콘텐츠 위젯
class ProfileAccountContent extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const ProfileAccountContent({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _ProfileAccountContentState createState() => _ProfileAccountContentState();
}

class _ProfileAccountContentState extends State<ProfileAccountContent> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _addressController = TextEditingController();
  final _detailAddressController = TextEditingController();
  final _birthdayController = TextEditingController();
  
  String? _selectedGender;
  bool _isLoading = false;
  bool _isEditing = false;
  Map<String, dynamic>? _memberData;
  bool _hasLoadedData = false;

  // 테마 색상
  static const Color _primaryColor = Color(0xFFFF8C00);
  static const Color _cardBgColor = Colors.white;
  static const Color _textPrimaryColor = Color(0xFF333333);
  static const Color _textSecondaryColor = Color(0xFF666666);
  
  @override
  void initState() {
    super.initState();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoadedData) {
      _hasLoadedData = true;
      _loadMemberData();
    }
  }
  
  @override
  void dispose() {
    _phoneController.dispose();
    _nicknameController.dispose();
    _addressController.dispose();
    _detailAddressController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }
  
  // 회원 정보 불러오기
  Future<void> _loadMemberData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final currentUser = widget.selectedMember ?? ApiService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('사용자 정보가 없습니다');
      }
      
      final memberId = currentUser['member_id']?.toString();
      final branchId = widget.branchId ?? ApiService.getCurrentBranchId();
      
      if (memberId == null) {
        throw Exception('회원 ID가 없습니다');
      }
      
      final members = await ApiService.getData(
        table: 'v3_members',
        where: [
          {'field': 'member_id', 'operator': '=', 'value': memberId},
          if (branchId != null) {'field': 'branch_id', 'operator': '=', 'value': branchId}
        ],
        fields: ['member_phone', 'member_nickname', 'member_gender', 'member_address', 'member_birthday'],
        limit: 1,
      );
      
      if (!mounted) return;
      
      if (members.isNotEmpty) {
        setState(() {
          _memberData = members.first;
          _phoneController.text = _memberData!['member_phone']?.toString().trim() ?? '';
          _nicknameController.text = _memberData!['member_nickname']?.toString().trim() ?? '';
          
          final fullAddress = _memberData!['member_address']?.toString().trim() ?? '';
          _addressController.text = fullAddress;
          _detailAddressController.clear();
          
          final gender = _memberData!['member_gender']?.toString().trim();
          if (gender != null && gender.isNotEmpty && (gender == '남성' || gender == '여성')) {
            _selectedGender = gender;
          } else {
            _selectedGender = null;
          }
          
          final birthdayValue = _memberData!['member_birthday'];
          if (birthdayValue != null && birthdayValue.toString().trim().isNotEmpty) {
            try {
              final birthday = DateTime.parse(birthdayValue.toString().trim());
              _birthdayController.text = DateFormat('yyyy-MM-dd').format(birthday);
            } catch (e) {
              _birthdayController.text = birthdayValue.toString().trim();
            }
          } else {
            _birthdayController.clear();
          }
        });
      } else {
        if (mounted) {
          setState(() {
            _phoneController.text = currentUser['member_phone']?.toString().trim() ?? '';
            _memberData = {};
          });
        }
      }
    } catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('정보 불러오기 실패: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // 정보 업데이트
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final currentUser = widget.selectedMember ?? ApiService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('사용자 정보가 없습니다');
      }
      
      final memberPhone = currentUser['member_phone']?.toString();
      if (memberPhone == null || memberPhone.isEmpty) {
        throw Exception('전화번호가 없습니다');
      }
      
      String fullAddress = _addressController.text.trim();
      if (_detailAddressController.text.trim().isNotEmpty) {
        fullAddress += ' ' + _detailAddressController.text.trim();
      }
      
      final updateData = <String, dynamic>{
        'member_update': DateTime.now().toIso8601String(),
      };
      
      final nickname = _nicknameController.text.trim();
      updateData['member_nickname'] = nickname.isEmpty ? null : nickname;
      updateData['member_gender'] = _selectedGender;
      
      final address = fullAddress.trim();
      updateData['member_address'] = address.isEmpty ? null : address;
      
      final birthday = _birthdayController.text.trim();
      if (birthday.isNotEmpty) {
        try {
          DateTime.parse(birthday);
          updateData['member_birthday'] = birthday;
        } catch (e) {
          updateData['member_birthday'] = null;
        }
      } else {
        updateData['member_birthday'] = null;
      }
      
      final result = await ApiService.updateData(
        table: 'v3_members',
        data: updateData,
        where: [
          {'field': 'member_phone', 'operator': '=', 'value': memberPhone}
        ],
      );
      
      if (result['success'] == true) {
        if (widget.selectedMember == null) {
          final updatedUser = Map<String, dynamic>.from(currentUser);
          updatedUser.addAll(updateData);
          ApiService.setCurrentUser(updatedUser, isAdminLogin: ApiService.isAdminLogin());
        }
        
        _showSuccessDialog('정보 수정 완료!', '모든 지점의 정보가\n성공적으로 수정되었습니다.');
        setState(() {
          _isEditing = false;
        });
        
        await _loadMemberData();
      } else {
        throw Exception(result['error'] ?? '정보 수정에 실패했습니다');
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
  
  void _showSuccessDialog(String title, String message) {
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
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }
  
  // 생일 선택
  Future<void> _selectBirthday() async {
    DateTime initialDate = DateTime.now();
    
    if (_birthdayController.text.isNotEmpty) {
      try {
        initialDate = DateFormat('yyyy-MM-dd').parse(_birthdayController.text);
      } catch (e) {}
    }
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('ko', 'KR'),
    );
    
    if (picked != null) {
      setState(() {
        _birthdayController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }
  
  // 주소 검색 팝업
  Future<void> _searchAddress() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddressSearchPage(),
        fullscreenDialog: true,
      ),
    );
    
    if (result != null) {
      setState(() {
        _addressController.text = result['address'] ?? '';
        _detailAddressController.clear();
      });
      FocusScope.of(context).nextFocus();
    }
  }

  // 비밀번호 변경 팝업
  void _showPasswordChangeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PasswordChangeDialog();
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading && _memberData == null) {
      return Center(
        child: CircularProgressIndicator(color: _primaryColor),
      );
    }
    
    return Container(
      color: Color(0xFFF8F9FA),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ========== 보안 설정 섹션 ==========
              _buildSectionHeader(
                icon: Icons.security,
                title: '보안 설정',
              ),
              SizedBox(height: 12),
              
              // 비밀번호 변경 버튼
              _buildCard(
                child: ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF00A86B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.lock,
                      color: Color(0xFF00A86B),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    '비밀번호 변경',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _textPrimaryColor,
                    ),
                  ),
                  subtitle: Text(
                    '계정 보안을 위해 주기적으로 변경해주세요',
                    style: TextStyle(
                      fontSize: 12,
                      color: _textSecondaryColor,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                  onTap: _showPasswordChangeDialog,
                ),
              ),
              SizedBox(height: 24),
              
              // ========== 개인정보 섹션 ==========
              _buildSectionHeader(
                icon: Icons.person,
                title: '개인정보',
                trailing: _isEditing
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isEditing = false;
                                _loadMemberData();
                              });
                            },
                            child: Text('취소', style: TextStyle(color: Colors.grey[600])),
                          ),
                          SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _updateProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text('저장', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      )
                    : TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _isEditing = true;
                          });
                        },
                        icon: Icon(Icons.edit, size: 16),
                        label: Text('수정'),
                        style: TextButton.styleFrom(
                          foregroundColor: _primaryColor,
                        ),
                      ),
              ),
              SizedBox(height: 12),
              
              // 개인정보 카드
              _buildCard(
                child: Column(
                  children: [
                    // 전화번호 (읽기 전용)
                    _buildInfoRow(
                      icon: Icons.phone,
                      label: '전화번호',
                      value: _phoneController.text,
                      isLocked: true,
                    ),
                    _buildDivider(),
                    
                    // 닉네임
                    _buildEditableRow(
                      icon: Icons.badge,
                      label: '닉네임',
                      controller: _nicknameController,
                      isEditing: _isEditing,
                    ),
                    _buildDivider(),
                    
                    // 성별
                    _buildGenderRow(),
                    _buildDivider(),
                    
                    // 생년월일
                    _buildDateRow(
                      icon: Icons.cake,
                      label: '생년월일',
                      controller: _birthdayController,
                      isEditing: _isEditing,
                      onTap: _selectBirthday,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              
              // 주소 카드
              _buildCard(
                child: Column(
                  children: [
                    // 기본 주소
                    _buildAddressRow(
                      icon: Icons.home,
                      label: '기본 주소',
                      controller: _addressController,
                      isEditing: _isEditing,
                      onTap: _searchAddress,
                    ),
                    _buildDivider(),
                    
                    // 상세 주소
                    _buildEditableRow(
                      icon: Icons.location_on,
                      label: '상세 주소',
                      controller: _detailAddressController,
                      isEditing: _isEditing,
                      hintText: '상세 주소 입력 (선택)',
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              
              // 안내 메시지
              _buildInfoBox(
                title: '개인정보 안내',
                content: '• 전화번호는 직접 변경할 수 없습니다. 센터에 문의하세요\n• 개인정보 수정은 모든 지점에 동시 적용됩니다',
              ),
              SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  // ========== UI 컴포넌트 빌더 ==========

  Widget _buildSectionHeader({required IconData icon, required String title, Widget? trailing}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: _primaryColor,
            size: 22,
          ),
          SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textPrimaryColor,
            ),
          ),
          Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _cardBgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: Color(0xFFF0F0F0),
      indent: 16,
      endIndent: 16,
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isLocked = false,
  }) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _primaryColor, size: 18),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: _textSecondaryColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value.isEmpty ? '-' : value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _textPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
          if (isLocked)
            Icon(Icons.lock, size: 16, color: Colors.grey[400]),
        ],
      ),
    );
  }

  Widget _buildEditableRow({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    String? hintText,
  }) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _primaryColor, size: 18),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: _textSecondaryColor,
                  ),
                ),
                SizedBox(height: 4),
                isEditing
                    ? TextFormField(
                        controller: controller,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: _textPrimaryColor,
                        ),
                        decoration: InputDecoration(
                          hintText: hintText ?? '$label 입력',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(color: _primaryColor),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: _primaryColor, width: 2),
                          ),
                        ),
                      )
                    : Text(
                        controller.text.isEmpty ? '-' : controller.text,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: _textPrimaryColor,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderRow() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.wc, color: _primaryColor, size: 18),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '성별',
                  style: TextStyle(
                    fontSize: 12,
                    color: _textSecondaryColor,
                  ),
                ),
                SizedBox(height: 4),
                _isEditing
                    ? Row(
                        children: [
                          _buildGenderChip('남성'),
                          SizedBox(width: 8),
                          _buildGenderChip('여성'),
                          SizedBox(width: 8),
                          _buildGenderChip(null, label: '선택안함'),
                        ],
                      )
                    : Text(
                        _selectedGender ?? '선택안함',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: _textPrimaryColor,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderChip(String? value, {String? label}) {
    final isSelected = _selectedGender == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = value;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label ?? value ?? '',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : _textSecondaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildDateRow({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _primaryColor, size: 18),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: _textSecondaryColor,
                  ),
                ),
                SizedBox(height: 4),
                GestureDetector(
                  onTap: isEditing ? onTap : null,
                  child: Row(
                    children: [
                      Text(
                        controller.text.isEmpty ? '-' : controller.text,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: _textPrimaryColor,
                        ),
                      ),
                      if (isEditing) ...[
                        SizedBox(width: 8),
                        Icon(Icons.calendar_today, size: 16, color: _primaryColor),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _primaryColor, size: 18),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: _textSecondaryColor,
                  ),
                ),
                SizedBox(height: 4),
                GestureDetector(
                  onTap: isEditing ? onTap : null,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          controller.text.isEmpty ? (isEditing ? '주소 검색' : '-') : controller.text,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: controller.text.isEmpty && isEditing 
                                ? Colors.grey[400] 
                                : _textPrimaryColor,
                          ),
                        ),
                      ),
                      if (isEditing)
                        Icon(Icons.search, size: 18, color: _primaryColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox({required String title, required String content}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFFFF4E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: _primaryColor,
            size: 18,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 비밀번호 변경 다이얼로그
class PasswordChangeDialog extends StatefulWidget {
  const PasswordChangeDialog({Key? key}) : super(key: key);

  @override
  _PasswordChangeDialogState createState() => _PasswordChangeDialogState();
}

class _PasswordChangeDialogState extends State<PasswordChangeDialog> {
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

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return '새 비밀번호를 입력해주세요';
    }
    
    if (value.length < 6) {
      return '비밀번호는 6자리 이상이어야 합니다';
    }
    
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
    
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return '숫자를 최소 1개 포함해야 합니다';
    }
    
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
      
      final storedPassword = currentUser['member_password']?.toString() ?? '';
      final isCurrentPasswordValid = PasswordService.verifyPassword(
        currentPassword,
        storedPassword,
      );
      
      if (!isCurrentPasswordValid) {
        throw Exception('현재 비밀번호가 올바르지 않습니다');
      }

      final hashedNewPassword = PasswordService.hashPassword(newPassword);
      final phoneNumber = currentUser['member_phone'];
      
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
        final updatedUser = Map<String, dynamic>.from(currentUser);
        updatedUser['member_password'] = hashedNewPassword;
        ApiService.setCurrentUser(updatedUser, isAdminLogin: ApiService.isAdminLogin());
        
        Navigator.of(context).pop();
        _showSuccessSnackbar();
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

  void _showSuccessSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('비밀번호가 성공적으로 변경되었습니다'),
          ],
        ),
        backgroundColor: Color(0xFF00A86B),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(maxWidth: 400),
        padding: EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 헤더
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Color(0xFF00A86B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.lock,
                      color: Color(0xFF00A86B),
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '비밀번호 변경',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '모든 지점에 동시 적용됩니다',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.grey[400]),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: 20),
              
              // 비밀번호 규칙 안내
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '비밀번호 규칙',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF666666),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• 6자리 이상  • 숫자 포함  • 특수문자 포함',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              
              // 현재 비밀번호
              _buildPasswordField(
                controller: _currentPasswordController,
                label: '현재 비밀번호',
                showPassword: _showCurrentPassword,
                onToggle: () => setState(() => _showCurrentPassword = !_showCurrentPassword),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '현재 비밀번호를 입력해주세요';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              // 새 비밀번호
              _buildPasswordField(
                controller: _newPasswordController,
                label: '새 비밀번호',
                showPassword: _showNewPassword,
                onToggle: () => setState(() => _showNewPassword = !_showNewPassword),
                validator: _validateNewPassword,
              ),
              SizedBox(height: 16),
              
              // 비밀번호 확인
              _buildPasswordField(
                controller: _confirmPasswordController,
                label: '비밀번호 확인',
                showPassword: _showConfirmPassword,
                onToggle: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                validator: _validateConfirmPassword,
              ),
              SizedBox(height: 24),
              
              // 버튼들
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        '취소',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF00A86B),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              '비밀번호 변경',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool showPassword,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !showPassword,
      validator: validator,
      style: TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
        ),
        prefixIcon: Icon(Icons.lock_outline, size: 20, color: Colors.grey[500]),
        suffixIcon: IconButton(
          icon: Icon(
            showPassword ? Icons.visibility_off : Icons.visibility,
            size: 20,
            color: Colors.grey[500],
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Color(0xFF00A86B), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// 주소 검색 페이지
class AddressSearchPage extends StatefulWidget {
  const AddressSearchPage({Key? key}) : super(key: key);

  @override
  _AddressSearchPageState createState() => _AddressSearchPageState();
}

class _AddressSearchPageState extends State<AddressSearchPage> {
  late WebViewController _webViewController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
      ..addJavaScriptChannel(
        'AddressChannel',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'CLOSE') {
            Navigator.pop(context);
            return;
          }
          
          final addressData = message.message.split('|');
          if (addressData.length >= 1) {
            Navigator.pop(context, {
              'address': addressData[0],
              'zipcode': addressData.length > 1 ? addressData[1] : '',
            });
          }
        },
      )
      ..loadHtmlString(_getAddressSearchHtml());
  }

  String _getAddressSearchHtml() {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>주소 검색</title>
        <script src="//t1.daumcdn.net/mapjsapi/bundle/postcode/prod/postcode.v2.js"></script>
        <style>
            body { margin: 0; padding: 0; }
        </style>
    </head>
    <body>
        <div id="layer" style="display:block;position:fixed;overflow:hidden;z-index:1;-webkit-overflow-scrolling:touch;">
            <img src="//t1.daumcdn.net/postcode/resource/images/close.png" id="btnCloseLayer" style="cursor:pointer;position:absolute;right:-3px;top:-3px;z-index:1" onclick="closeDaumPostcode()" alt="닫기 버튼">
        </div>
        
        <script>
            function closeDaumPostcode() {
                AddressChannel.postMessage('CLOSE');
            }

            var element_layer = document.getElementById('layer');
            
            new daum.Postcode({
                oncomplete: function(data) {
                    var addr = '';
                    var extraAddr = '';

                    if (data.userSelectedType === 'R') {
                        addr = data.roadAddress;
                    } else {
                        addr = data.jibunAddress;
                    }

                    if(data.userSelectedType === 'R'){
                        if(data.bname !== '' && /[동|로|가]\$/g.test(data.bname)){
                            extraAddr += data.bname;
                        }
                        if(data.buildingName !== '' && data.apartment === 'Y'){
                            extraAddr += (extraAddr !== '' ? ', ' + data.buildingName : data.buildingName);
                        }
                        if(extraAddr !== ''){
                            extraAddr = ' (' + extraAddr + ')';
                        }
                        addr += extraAddr;
                    }

                    AddressChannel.postMessage(addr + '|' + data.zonecode);
                },
                width: '100%',
                height: '100%',
                maxSuggestItems: 5
            }).embed(element_layer);

            element_layer.style.width = document.body.scrollWidth + 'px';
            element_layer.style.height = document.body.scrollHeight + 'px';
        </script>
    </body>
    </html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('주소 검색'),
        backgroundColor: Color(0xFFFF8C00),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
