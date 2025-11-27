import 'package:flutter/material.dart';
import 'lib/login_branch_select.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // 로그인 처리 시뮬레이션
    await Future.delayed(Duration(seconds: 2));

    setState(() {
      _isLoading = false;
    });

    // TODO: 실제 로그인 API 연동 시 회원 정보 받아오기
    final memberId = _idController.text; // 임시로 입력된 ID 사용
    final memberData = {
      'member_id': memberId,
      'member_name': '사용자', // TODO: API에서 받아온 실제 이름
      'member_phone': '010-0000-0000', // TODO: API에서 받아온 실제 전화번호
    };

    print('로그인 성공 - 회원 ID: $memberId');

    // 로그인 성공 시 지점 선택 페이지로 이동
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LoginBranchSelectPage(
          memberBranches: ['branch1', 'branch2'], // 임시 지점 목록
          memberData: memberData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final horizontalPadding = isSmallScreen ? 24.0 : 48.0;
    final maxWidth = isSmallScreen ? double.infinity : 400.0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Center(
          child: Container(
            width: maxWidth,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 32.0,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 로고 및 타이틀
                    _buildHeader(isSmallScreen),
                    SizedBox(height: 48.0),
                    
                    // 로그인 폼
                    _buildLoginForm(isSmallScreen),
                    SizedBox(height: 24.0),
                    
                    // 로그인 버튼
                    _buildLoginButton(isSmallScreen),
                    SizedBox(height: 16.0),
                    
                    // 기타 옵션들
                    _buildOptions(),
                    SizedBox(height: 32.0),
                    
                    // 하단 링크들
                    _buildFooterLinks(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSmallScreen) {
    return Column(
      children: [
        // 로고 아이콘
        Container(
          width: isSmallScreen ? 80.0 : 100.0,
          height: isSmallScreen ? 80.0 : 100.0,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(20.0),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 20.0,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            Icons.fitness_center,
            color: Colors.white,
            size: isSmallScreen ? 40.0 : 50.0,
          ),
        ),
        SizedBox(height: 24.0),
        
        // 앱 제목
        Text(
          'FACRM',
          style: TextStyle(
            fontSize: isSmallScreen ? 28.0 : 32.0,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8.0),
        
        // 부제목
        Text(
          '피트니스 관리 시스템',
          style: TextStyle(
            fontSize: isSmallScreen ? 14.0 : 16.0,
            color: Colors.grey[600],
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(bool isSmallScreen) {
    return Column(
      children: [
        // 아이디 입력 필드
        _buildTextField(
          controller: _idController,
          label: '아이디',
          hint: '아이디를 입력하세요',
          icon: Icons.person_outline,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '아이디를 입력해주세요';
            }
            return null;
          },
        ),
        SizedBox(height: 16.0),
        
        // 비밀번호 입력 필드
        _buildTextField(
          controller: _passwordController,
          label: '비밀번호',
          hint: '비밀번호를 입력하세요',
          icon: Icons.lock_outline,
          isPassword: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '비밀번호를 입력해주세요';
            }
            if (value.length < 4) {
              return '비밀번호는 4자 이상이어야 합니다';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8.0),
        TextFormField(
          controller: controller,
          obscureText: isPassword && !_isPasswordVisible,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.grey[600]),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey[600],
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: Colors.blue, width: 2.0),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: Colors.red, width: 1.0),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildLoginButton(bool isSmallScreen) {
    return SizedBox(
      width: double.infinity,
      height: isSmallScreen ? 52.0 : 56.0,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 2.0,
          shadowColor: Colors.blue.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
        child: _isLoading
            ? SizedBox(
                width: 24.0,
                height: 24.0,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.0,
                ),
              )
            : Text(
                '로그인',
                style: TextStyle(
                  fontSize: isSmallScreen ? 16.0 : 18.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildOptions() {
    return Row(
      children: [
        // 로그인 상태 유지
        Expanded(
          child: Row(
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() {
                    _rememberMe = value ?? false;
                  });
                },
                activeColor: Colors.blue,
              ),
              Text(
                '로그인 상태 유지',
                style: TextStyle(
                  fontSize: 14.0,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
        
        // 비밀번호 찾기
        TextButton(
          onPressed: () {
            // 비밀번호 찾기 기능
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('비밀번호 찾기 기능은 준비중입니다.'),
                backgroundColor: Colors.orange,
              ),
            );
          },
          child: Text(
            '비밀번호 찾기',
            style: TextStyle(
              fontSize: 14.0,
              color: Colors.blue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterLinks() {
    return Column(
      children: [
        // 구분선
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[300])),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                '또는',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14.0,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey[300])),
          ],
        ),
        SizedBox(height: 24.0),
        
        // 회원가입 버튼
        SizedBox(
          width: double.infinity,
          height: 48.0,
          child: OutlinedButton(
            onPressed: () {
              // 회원가입 페이지로 이동
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('회원가입 기능은 준비중입니다.'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey[400]!, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: Text(
              '회원가입',
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
        ),
        SizedBox(height: 16.0),
        
        // 게스트 로그인
        TextButton(
          onPressed: () {
            // 게스트로 메인 페이지 이동
            Navigator.pushReplacementNamed(context, '/main');
          },
          child: Text(
            '게스트로 둘러보기',
            style: TextStyle(
              fontSize: 14.0,
              color: Colors.grey[600],
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
} 