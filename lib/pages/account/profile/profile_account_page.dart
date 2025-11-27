import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../services/api_service.dart';

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
        backgroundColor: Colors.orange,
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
      // selectedMember가 있으면 우선 사용, 없으면 ApiService.getCurrentUser() 사용
      final currentUser = widget.selectedMember ?? ApiService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('사용자 정보가 없습니다');
      }
      
      final memberId = currentUser['member_id']?.toString();
      final branchId = widget.branchId ?? ApiService.getCurrentBranchId();
      
      if (memberId == null) {
        throw Exception('회원 ID가 없습니다');
      }
      
      // 현재 사용자의 상세 정보 조회
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
          
          // 주소 분리 처리 (기존 주소에 상세주소가 포함되어 있을 수 있음)
          final fullAddress = _memberData!['member_address']?.toString().trim() ?? '';
          _addressController.text = fullAddress;
          _detailAddressController.clear();
          
          // 성별 처리 (빈 문자열이거나 null인 경우, 또는 유효하지 않은 값인 경우 null로 설정)
          final gender = _memberData!['member_gender']?.toString().trim();
          if (gender != null && gender.isNotEmpty && (gender == '남성' || gender == '여성')) {
            _selectedGender = gender;
          } else {
            _selectedGender = null;
          }
          
          // 생일 포맷 처리
          final birthdayValue = _memberData!['member_birthday'];
          if (birthdayValue != null && birthdayValue.toString().trim().isNotEmpty) {
            try {
              final birthday = DateTime.parse(birthdayValue.toString().trim());
              _birthdayController.text = DateFormat('yyyy-MM-dd').format(birthday);
            } catch (e) {
              // 날짜 파싱 실패 시 원본 값 사용
              _birthdayController.text = birthdayValue.toString().trim();
            }
          } else {
            _birthdayController.clear();
          }
        });
      } else {
        // 데이터가 없을 경우 기본값 설정
        if (mounted) {
          setState(() {
            _phoneController.text = currentUser['member_phone']?.toString().trim() ?? '';
            _memberData = {};
          });
        }
      }
    } catch (e) {
      if (mounted) {
        // 에러 메시지는 다음 프레임에서 표시
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
  
  
  
  
  // 정보 업데이트 (전화번호 제외)
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // selectedMember가 있으면 우선 사용, 없으면 ApiService.getCurrentUser() 사용
      final currentUser = widget.selectedMember ?? ApiService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('사용자 정보가 없습니다');
      }
      
      final memberPhone = currentUser['member_phone']?.toString();
      if (memberPhone == null || memberPhone.isEmpty) {
        throw Exception('전화번호가 없습니다');
      }
      
      // 기본 주소와 상세 주소를 하나로 합침
      String fullAddress = _addressController.text.trim();
      if (_detailAddressController.text.trim().isNotEmpty) {
        fullAddress += ' ' + _detailAddressController.text.trim();
      }
      
      // 업데이트 데이터 준비 (빈 값은 null로 처리)
      final updateData = <String, dynamic>{
        'member_update': DateTime.now().toIso8601String(),
      };
      
      // 닉네임 (빈 값이면 null)
      final nickname = _nicknameController.text.trim();
      updateData['member_nickname'] = nickname.isEmpty ? null : nickname;
      
      // 성별
      updateData['member_gender'] = _selectedGender;
      
      // 주소 (빈 값이면 null)
      final address = fullAddress.trim();
      updateData['member_address'] = address.isEmpty ? null : address;
      
      // 생일 (빈 값이면 null, 날짜 형식이어야 함)
      final birthday = _birthdayController.text.trim();
      if (birthday.isNotEmpty) {
        // 날짜 형식 검증
        try {
          DateTime.parse(birthday);
          updateData['member_birthday'] = birthday;
        } catch (e) {
          // 잘못된 날짜 형식이면 null
          updateData['member_birthday'] = null;
        }
      } else {
        updateData['member_birthday'] = null;
      }
      
      // 전체 지점 업데이트 (전화번호 기준)
      final result = await ApiService.updateData(
        table: 'v3_members',
        data: updateData,
        where: [
          {'field': 'member_phone', 'operator': '=', 'value': memberPhone}
        ],
      );
      
      if (result['success'] == true) {
        // selectedMember가 없을 때만 현재 사용자 정보 업데이트
        if (widget.selectedMember == null) {
          final updatedUser = Map<String, dynamic>.from(currentUser);
          updatedUser.addAll(updateData);
          ApiService.setCurrentUser(updatedUser, isAdminLogin: ApiService.isAdminLogin());
        }
        
        _showSuccessDialog();
        setState(() {
          _isEditing = false;
        });
        
        // 정보 새로고침
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
                '정보 수정 완료!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '모든 지점의 정보가\\n성공적으로 수정되었습니다.',
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
              },
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
      } catch (e) {
        // 파싱 실패 시 현재 날짜 사용
      }
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
        _detailAddressController.clear(); // 상세주소는 새로 입력하도록
      });
      // 상세주소 입력 필드로 포커스 이동
      FocusScope.of(context).nextFocus();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading && _memberData == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    return Container(
      color: const Color(0xFFF8F9FA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 정보 표시/편집 모드 토글
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '개인정보',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!_isEditing)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _isEditing = true;
                        });
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('수정'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange,
                      ),
                    )
                  else
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isEditing = false;
                              _loadMemberData(); // 원래 데이터로 복원
                            });
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                          ),
                          child: const Text('취소'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isLoading ? null : () {
                            _updateProfile();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('저장'),
                        ),
                      ],
                    ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // 전화번호 (읽기 전용)
              TextFormField(
                controller: _phoneController,
                enabled: false,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: '전화번호',
                  prefixIcon: const Icon(Icons.phone),
                  suffixIcon: const Icon(Icons.lock, color: Colors.grey),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[100],
                  helperText: '전화번호는 보안상 변경할 수 없습니다',
                  helperStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 닉네임
              TextFormField(
                controller: _nicknameController,
                enabled: _isEditing,
                decoration: InputDecoration(
                  labelText: '닉네임',
                  prefixIcon: const Icon(Icons.badge),
                  border: const OutlineInputBorder(),
                  filled: !_isEditing,
                  fillColor: Colors.grey[100],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 성별
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: InputDecoration(
                  labelText: '성별',
                  prefixIcon: const Icon(Icons.wc),
                  border: const OutlineInputBorder(),
                  filled: !_isEditing,
                  fillColor: Colors.grey[100],
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('선택 안 함')),
                  DropdownMenuItem(value: '남성', child: Text('남성')),
                  DropdownMenuItem(value: '여성', child: Text('여성')),
                ],
                onChanged: _isEditing
                    ? (value) {
                        setState(() {
                          _selectedGender = value;
                        });
                      }
                    : null,
              ),
              
              const SizedBox(height: 20),
              
              // 기본 주소
              TextFormField(
                controller: _addressController,
                enabled: false,
                readOnly: true,
                onTap: _isEditing ? _searchAddress : null,
                decoration: InputDecoration(
                  labelText: '기본 주소',
                  prefixIcon: const Icon(Icons.home),
                  suffixIcon: _isEditing ? IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _searchAddress,
                  ) : null,
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: _isEditing ? Colors.white : Colors.grey[100],
                  hintText: _isEditing ? '주소 검색 버튼을 눌러주세요' : null,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 상세 주소
              TextFormField(
                controller: _detailAddressController,
                enabled: _isEditing,
                decoration: InputDecoration(
                  labelText: '상세 주소',
                  prefixIcon: const Icon(Icons.location_on),
                  border: const OutlineInputBorder(),
                  filled: !_isEditing,
                  fillColor: Colors.grey[100],
                  hintText: _isEditing ? '상세 주소를 입력해주세요 (선택사항)' : null,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 생일
              TextFormField(
                controller: _birthdayController,
                enabled: _isEditing,
                readOnly: true,
                onTap: _isEditing ? _selectBirthday : null,
                decoration: InputDecoration(
                  labelText: '생년월일',
                  prefixIcon: const Icon(Icons.cake),
                  suffixIcon: _isEditing ? const Icon(Icons.calendar_today) : null,
                  border: const OutlineInputBorder(),
                  filled: !_isEditing,
                  fillColor: Colors.grey[100],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // 안내 메시지
              if (!_isEditing)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '개인정보 수정은 모든 지점에 동시 적용됩니다.',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 13,
                          ),
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
          // 주소 선택 시 메시지 받기
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
        backgroundColor: Colors.orange,
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