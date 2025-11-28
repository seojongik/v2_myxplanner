import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:intl/intl.dart';
import '../../stubs/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/tab_design_service.dart';
import '../../services/portone_payment_service.dart';
import '../../services/online_sales_terms_service.dart';
import 'portone_payment_page.dart';

// Scaffold 없는 콘텐츠 위젯 (MembershipPage에서 사용)
class ContractSetupPageContent extends StatelessWidget {
  final Map<String, dynamic> contract;
  final String membershipType;
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;
  final VoidCallback onComplete;

  const ContractSetupPageContent({
    Key? key,
    required this.contract,
    required this.membershipType,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
    required this.onComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 기존 ContractSetupPage를 반환하되, isContentMode를 true로 설정
    // _ContractSetupPageState의 build 메서드에서 isContentMode를 확인하여 body만 반환합니다.
    return ContractSetupPage(
      contract: contract,
      membershipType: membershipType,
      isAdminMode: isAdminMode,
      selectedMember: selectedMember,
      branchId: branchId,
      isContentMode: true, // body만 반환하도록 플래그 설정
      onComplete: onComplete, // 콜백 전달
    );
  }
}

// 기존 ContractSetupPage (하위 호환성을 위해 유지)
class ContractSetupPage extends StatefulWidget {
  final Map<String, dynamic> contract;
  final String membershipType;
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;
  final bool isContentMode; // body만 반환할지 여부
  final VoidCallback? onComplete; // 콜백 (isContentMode일 때만 사용)

  const ContractSetupPage({
    Key? key,
    required this.contract,
    required this.membershipType,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
    this.isContentMode = false,
    this.onComplete,
  }) : super(key: key);

  @override
  _ContractSetupPageState createState() => _ContractSetupPageState();
}

class _ContractSetupPageState extends State<ContractSetupPage> {
  // 프로 선택 관련
  List<Map<String, dynamic>> availablePros = [];
  String? selectedProId;
  String? selectedProName;
  bool isLoadingPros = false;

  // 기간권 시작일 관련
  DateTime? termStartDate;
  DateTime? termEndDate;

  // 지점 정보
  Map<String, dynamic>? branchInfo;

  @override
  void initState() {
    super.initState();
    _checkAndLoadRequirements();
    
    // 웹 환경에서 결제 완료 후 리디렉션된 경우 자동으로 결제 처리
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndProcessPendingPayment();
      });
    }
  }
  
  // 대기 중인 결제 확인 및 처리
  void _checkAndProcessPendingPayment() async {
    try {
      final storage = html.window.localStorage;
      final paymentId = storage['mgp_pending_payment_paymentId'];
      final txId = storage['mgp_pending_payment_txId'];
      final status = storage['mgp_pending_payment_status'];
      final expectedPaymentId = storage['mgp_pending_payment_expectedId'];
      
      // 결제 정보 확인
      final savedPaymentId = storage['mgp_payment_paymentId'];
      final channelKey = storage['mgp_payment_channelKey'] ?? PortonePaymentService.defaultChannelKey;
      final proId = storage['mgp_payment_proId'];
      final proName = storage['mgp_payment_proName'];
      final termStartDateStr = storage['mgp_payment_termStartDate'];
      final termEndDateStr = storage['mgp_payment_termEndDate'];
      
      // 결제 결과가 있고, 예상한 결제 ID와 일치하는 경우
      if (paymentId != null && 
          paymentId.isNotEmpty && 
          status == 'success' &&
          (expectedPaymentId == null || paymentId == expectedPaymentId || savedPaymentId == paymentId)) {
        debugPrint('✅ 대기 중인 결제 확인 - 자동 처리 시작: $paymentId');
        
        // 프로 정보 복원
        if (proId != null) {
          setState(() {
            selectedProId = proId;
            selectedProName = proName;
          });
        }
        
        // 기간권 정보 복원
        if (termStartDateStr != null) {
          try {
            setState(() {
              termStartDate = DateTime.parse(termStartDateStr);
              if (termEndDateStr != null) {
                termEndDate = DateTime.parse(termEndDateStr);
              }
            });
          } catch (e) {
            debugPrint('⚠️ 기간권 날짜 파싱 오류: $e');
          }
        }
        
        // 결제 처리 실행
        await _processPaymentAfterPortone(
          portonePaymentId: paymentId,
          portoneTxId: txId,
          channelKey: channelKey,
          shouldClosePaymentPage: false, // 이미 페이지에 있으므로 닫을 필요 없음
        );
      }
    } catch (e) {
      debugPrint('⚠️ 대기 중인 결제 확인 오류: $e');
    }
  }

  // 레슨권/기간권 여부 확인 및 필요한 데이터 로드
  Future<void> _checkAndLoadRequirements() async {
    // 지점 정보 로드
    await _loadBranchInfo();

    // 레슨권이 있으면 프로 목록 로드 (Supabase는 소문자로 반환)
    final contractLS = _safeParseInt(widget.contract['contract_ls_min'] ?? widget.contract['contract_LS_min']);
    if (contractLS > 0) {
      await _loadAvailablePros();
    }

    // 기간권이 있으면 시작일/종료일 자동 설정
    final contractTermMonth = _safeParseInt(widget.contract['contract_term_month']);
    if (contractTermMonth > 0) {
      setState(() {
        termStartDate = DateTime.now();
        termEndDate = DateTime(
          termStartDate!.year,
          termStartDate!.month + contractTermMonth,
          termStartDate!.day,
        ).subtract(Duration(days: 1));
      });
    }
  }

  // 지점 정보 로드
  Future<void> _loadBranchInfo() async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      final data = await ApiService.getData(
        table: 'v2_branch',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId}
        ],
      );

      if (data.isNotEmpty) {
        setState(() {
          branchInfo = data[0];
        });
        debugPrint('지점 정보 로드 완료: ${branchInfo?['branch_name']}');
      }
    } catch (e) {
      debugPrint('지점 정보 로드 오류: $e');
    }
  }

  // 프로 목록 로드
  Future<void> _loadAvailablePros() async {
    try {
      setState(() {
        isLoadingPros = true;
      });

      debugPrint('프로 목록 로드 시작');

      // 재직중인 프로 조회
      final data = await ApiService.getData(
        table: 'v2_staff_pro',
        fields: [
          'pro_id',
          'pro_name',
          'staff_status',
          'pro_contract_round',
        ],
        where: [
          {'field': 'staff_status', 'operator': '=', 'value': '재직'}
        ],
        orderBy: [
          {'field': 'pro_id', 'direction': 'ASC'},
          {'field': 'pro_contract_round', 'direction': 'DESC'},
        ],
      );

      // pro_id별로 최신 레코드만 유지
      final Map<dynamic, Map<String, dynamic>> uniquePros = {};
      for (final pro in data) {
        final proId = pro['pro_id'];
        if (!uniquePros.containsKey(proId)) {
          uniquePros[proId] = pro;
        }
      }

      // 동명이인 처리: 같은 이름이 여러 개 있으면 이름_1, 이름_2 형식으로 표시
      final List<Map<String, dynamic>> prosList = uniquePros.values.toList();
      final Map<String, int> nameCount = {};
      final Map<String, int> nameIndex = {};

      // 각 이름의 출현 횟수 계산
      for (final pro in prosList) {
        final proName = pro['pro_name']?.toString() ?? '';
        nameCount[proName] = (nameCount[proName] ?? 0) + 1;
      }

      // 동명이인이 있는 경우 display_name에 _1, _2 추가
      for (final pro in prosList) {
        final proName = pro['pro_name']?.toString() ?? '';
        if (nameCount[proName]! > 1) {
          nameIndex[proName] = (nameIndex[proName] ?? 0) + 1;
          pro['display_name'] = '${proName}_${nameIndex[proName]}';
        } else {
          pro['display_name'] = proName;
        }
      }

      setState(() {
        availablePros = prosList;
        isLoadingPros = false;
      });

      debugPrint('프로 목록 로드 완료: ${availablePros.length}명');
    } catch (e) {
      debugPrint('프로 목록 로드 오류: $e');
      setState(() {
        isLoadingPros = false;
      });
    }
  }

  // 프로 선택 다이얼로그
  Future<void> _showProSelectionDialog() async {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogHeight = screenHeight * 0.6; // 화면 높이의 60%
    final dialogWidth = screenWidth * 0.85; // 화면 너비의 85%

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            '담당프로 선택',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          content: Container(
            width: dialogWidth,
            height: dialogHeight,
            child: availablePros.isEmpty
                ? Center(
                    child: Text(
                      '선택 가능한 프로가 없습니다',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  )
                : ListView.builder(
                    itemCount: availablePros.length,
                    itemBuilder: (context, index) {
                      final pro = availablePros[index];
                      return Container(
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Color(0xFFE2E8F0)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              selectedProId = _safeToString(pro['pro_id']);
                              selectedProName = pro['display_name'] ?? pro['pro_name'];
                            });
                            Navigator.of(context).pop();
                          },
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF3B82F6).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color: Color(0xFF3B82F6),
                                    size: 24,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    pro['display_name'] ?? pro['pro_name'] ?? '',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '취소',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }

  // 기간권 시작일 선택
  Future<void> _selectTermStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: termStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF10B981),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: child!,
            ),
          ),
        );
      },
    );

    if (picked != null && picked != termStartDate) {
      setState(() {
        termStartDate = picked;
        // 종료일 재계산
        final contractTermMonth = _safeParseInt(widget.contract['contract_term_month']);
        if (contractTermMonth > 0) {
          termEndDate = DateTime(
            termStartDate!.year,
            termStartDate!.month + contractTermMonth,
            termStartDate!.day,
          ).subtract(Duration(days: 1));
        }
      });
    }
  }

  // 회원권 구매약관 페이지로 이동
  void _showTermsDialog() async {
    // DB에서 약관 정보 가져오기
    String termsType = '표준약관 1 (부분환불형)'; // 기본값
    String branchName = '골프연습장'; // 기본값

    try {
      // branch_id로 약관 타입 조회
      final branchData = await ApiService.getData(
        table: 'v2_branch',
        fields: ['branch_name', 'online_sales_term_type'],
        where: [
          {
            'field': 'branch_id',
            'operator': '=',
            'value': widget.branchId,
          }
        ],
        limit: 1,
      );

      if (branchData.isNotEmpty) {
        // 브랜치 이름 설정
        if (branchData[0]['branch_name'] != null) {
          branchName = branchData[0]['branch_name'].toString();
        }

        // 약관 타입 변환
        if (branchData[0]['online_sales_term_type'] != null) {
          termsType = convertTermTypeForDisplay(
            branchData[0]['online_sales_term_type'].toString()
          );
        }
      }
    } catch (e) {
      print('약관 정보 가져오기 실패: $e');
      // 오류 시 기본 약관 사용
    }

    // 약관 내용 가져오기
    final termsContent = getTermsContent(termsType, branchName);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            title: Text(
              '온라인 회원권 판매약관',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: SelectableText(
              termsContent,
              style: TextStyle(
                fontSize: 13,
                height: 1.7,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 약관 섹션 빌더
  Widget _buildTermsSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        SizedBox(height: 6),
        Text(
          content,
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF4B5563),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // 결제 버튼 클릭 - 포트원 결제 페이지 열기
  void _onPaymentButtonPressed() async {
    final contract = widget.contract;
    final totalAmount = (contract['price'] ?? 0) as int;
    final orderName = '${contract['contract_name'] ?? '회원권'} - ${widget.selectedMember?['member_name'] ?? '회원'}';
    
    // 토스페이먼츠 기본 채널키 사용
    final channelKey = PortonePaymentService.defaultChannelKey;
    
    // 결제 ID 생성
    final paymentId = PortonePaymentService.generatePaymentId();
    
    // 웹 환경에서 결제 정보를 localStorage에 저장 (리디렉션 후 복원용)
    if (kIsWeb) {
      try {
        final storage = html.window.localStorage;
        storage['mgp_payment_contract'] = jsonEncode(contract);
        storage['mgp_payment_membershipType'] = widget.membershipType;
        storage['mgp_payment_memberId'] = widget.selectedMember?['member_id']?.toString() ?? '';
        storage['mgp_payment_memberName'] = widget.selectedMember?['member_name'] ?? '';
        storage['mgp_payment_paymentId'] = paymentId;
        storage['mgp_payment_channelKey'] = channelKey;
        storage['mgp_payment_orderName'] = orderName;
        storage['mgp_payment_totalAmount'] = totalAmount.toString();
        if (selectedProId != null) {
          storage['mgp_payment_proId'] = selectedProId!;
          storage['mgp_payment_proName'] = selectedProName ?? '';
        }
        if (termStartDate != null) {
          storage['mgp_payment_termStartDate'] = termStartDate!.toIso8601String();
        }
        if (termEndDate != null) {
          storage['mgp_payment_termEndDate'] = termEndDate!.toIso8601String();
        }
        debugPrint('💾 결제 정보를 localStorage에 저장했습니다.');
      } catch (e) {
        debugPrint('⚠️ localStorage 저장 오류: $e');
      }
    }
    
    // 포트원 결제 페이지 열기
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => PortonePaymentPage(
          paymentId: paymentId,
          channelKey: channelKey,
          orderName: orderName,
          totalAmount: totalAmount,
          onPaymentSuccess: (paymentResult) async {
            // 결제 성공 시 처리 (결제 페이지는 아직 열려있음)
            // paymentId와 txId가 모두 있어야 실제 결제 완료로 간주
            final paymentId = paymentResult['paymentId'] as String?;
            final txId = paymentResult['txId'] as String?;
            final isTest = paymentResult['isTest'] as bool?;
            
            if (paymentId == null || paymentId.isEmpty) {
              debugPrint('❌ 결제 ID가 없습니다. 결제가 완료되지 않았습니다.');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('결제 정보가 올바르지 않습니다. 결제를 다시 시도해주세요.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
              return;
            }
            
            debugPrint('✅ 결제 성공 확인 - PaymentId: $paymentId, TxId: $txId');
            
            // ========== 회원권 부여 로직 ==========
            // 채널 키로 테스트 여부 판별 (DB 조회 전에 이미 판별 완료)
            // channel-key-4103c2a4-ab14-4707-bdb3-6c6254511ba0 → 테스트
            // 나머지 모든 채널 키 → 실연동
            
            // 관리자 로그인 여부 확인
            final isAdminLogin = ApiService.isAdminLogin();
            
            // 1. 테스트 결제인 경우 처리
            if (isTest == true) {
              // 관리자 로그인인 경우: 테스트 결제여도 회원권 부여 진행 (프로그램 테스트용)
              if (isAdminLogin) {
                debugPrint('⚠️⚠️⚠️ 테스트 결제이지만 관리자 로그인입니다. 회원권 부여를 진행합니다. (프로그램 테스트용)');
                await _processPaymentAfterPortone(
                  portonePaymentId: paymentId,
                  portoneTxId: txId,
                  channelKey: channelKey,
                  isTest: isTest, // true (테스트)
                  shouldClosePaymentPage: true, // 처리 완료 후 결제 페이지 닫기
                );
                return;
              }
              
              // 일반 로그인인 경우: 테스트 결제면 회원권 부여 안 함
              debugPrint('⚠️⚠️⚠️ 테스트 결제입니다! 회원권을 부여하지 않습니다.');
              
              // 팝업 다이얼로그로 안내
              if (mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      title: Text('테스트 결제 안내'),
                      content: Text('테스트 결제모듈로 실제 결제 및 회원권 부여가 되지 않았습니다. 관리자에게 문의 바랍니다.'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                          },
                          child: Text('확인'),
                        ),
                      ],
                    );
                  },
                );
              }
              return; // 테스트 결제는 회원권 부여하지 않음
            }
            
            // 2. 실제 결제인 경우 (isTest == false) → 회원권 부여 진행
            // DB는 결과를 저장하는 용도일 뿐, 판별은 이미 끝남
            debugPrint('✅ 실제 결제 확인됨. 회원권 부여를 진행합니다.');
            await _processPaymentAfterPortone(
              portonePaymentId: paymentId,
              portoneTxId: txId,
              channelKey: channelKey,
              isTest: isTest, // false (실연동)
              shouldClosePaymentPage: true, // 처리 완료 후 결제 페이지 닫기
            );
          },
          onPaymentFailed: (error) {
            // 결제 실패 시 처리
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('결제 실패: ${error['message'] ?? '알 수 없는 오류'}'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          },
        ),
      ),
    );
    
    // 결제가 취소된 경우
    if (result == false) {
      // 사용자가 결제를 취소한 경우 아무것도 하지 않음
    }
  }

  // 포트원 결제 완료 후 처리 및 DB 저장
  static final Set<String> _processedPaymentIds = <String>{}; // 처리된 결제 ID 추적
  
  // DB에서 결제 정보를 조회하여 결제 완료 여부 및 테스트 결제 여부 확인
  // payment_status가 'PAID'이고 payment_paid_at이 있으면 결제 완료
  // custom_data에 저장된 isTest 정보를 확인하여 테스트 결제 여부 판단
  Future<Map<String, dynamic>> _verifyPaymentFromDatabase(String paymentId) async {
    try {
      debugPrint('🔍 DB에서 결제 정보 조회 중: $paymentId');
      
      final branchId = ApiService.getCurrentBranchId();
      if (branchId == null) {
        debugPrint('❌ 지점 ID가 없습니다.');
        return {'isPaid': false, 'isTest': null, 'error': '지점 ID가 없습니다.'};
      }
      
      // DB에서 결제 정보 조회
      final payments = await ApiService.getData(
        table: 'v2_portone_payments',
        where: [
          {'field': 'portone_payment_uid', 'operator': '=', 'value': paymentId},
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
        ],
        limit: 1,
      );
      
      if (payments.isEmpty) {
        debugPrint('❌ DB에서 결제 정보를 찾을 수 없습니다.');
        return {'isPaid': false, 'isTest': null, 'error': '결제 정보를 찾을 수 없습니다.'};
      }
      
      final payment = payments.first;
      debugPrint('📋 DB에서 조회한 결제 정보: $payment');
      
      // 결제 상태 확인
      final paymentStatus = payment['payment_status'] as String?;
      final paymentPaidAt = payment['payment_paid_at'] as String?;
      
      if (paymentStatus != 'PAID' || paymentPaidAt == null || paymentPaidAt.isEmpty) {
        debugPrint('❌ DB 확인 결과: 결제가 완료되지 않았습니다. (상태: $paymentStatus, 결제 완료 시간: $paymentPaidAt)');
        return {'isPaid': false, 'isTest': null, 'error': '결제가 완료되지 않았습니다.'};
      }
      
      debugPrint('✅ DB 확인 결과: 결제가 완료되었습니다. (PAID 상태)');
      
      // channel_key_type 필드로 테스트 결제 여부 확인
      final channelKeyType = payment['channel_key_type'] as String?;
      
      if (channelKeyType == null || channelKeyType.isEmpty) {
        debugPrint('⚠️ channel_key_type이 없습니다.');
        return {'isPaid': true, 'isTest': null, 'error': 'channel_key_type이 없습니다.'};
      }
      
      final isTest = channelKeyType == '테스트';
      
      debugPrint('📋 channel_key_type: $channelKeyType');
      debugPrint('${isTest ? "⚠️" : "✅"} ${isTest ? "테스트" : "실제"} 결제입니다.');
      
      return {
        'isPaid': true,
        'isTest': isTest,
        'error': null,
      };
    } catch (e) {
      debugPrint('❌ DB에서 결제 정보 조회 오류: $e');
      return {'isPaid': false, 'isTest': null, 'error': e.toString()};
    }
  }
  
  Future<void> _processPaymentAfterPortone({
    required String portonePaymentId,
    String? portoneTxId,
    String? channelKey,
    bool? isTest, // 결제 응답에서 받은 테스트 결제 여부
    bool shouldClosePaymentPage = false,
  }) async {
    // 결제 ID 검증
    if (portonePaymentId.isEmpty || portonePaymentId.length < 10) {
      debugPrint('❌ 잘못된 결제 ID: $portonePaymentId');
      throw Exception('결제 정보가 올바르지 않습니다.');
    }
    
    // 중복 처리 방지
    if (_processedPaymentIds.contains(portonePaymentId)) {
      debugPrint('⚠️ 이미 처리된 결제 ID입니다: $portonePaymentId');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이미 처리된 결제입니다.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // 처리 중인 결제 ID로 표시
    _processedPaymentIds.add(portonePaymentId);
    
    // 현재 context 저장 (결제 페이지가 열려있는 상태)
    final currentContext = context;
    if (!mounted) {
      _processedPaymentIds.remove(portonePaymentId); // 실패 시 제거
      return;
    }
    
    // 로딩 다이얼로그를 변수로 저장하여 나중에 닫을 수 있도록 함
    BuildContext? dialogContext;
    
    try {
      // 로딩 다이얼로그 표시
      showDialog(
        context: currentContext,
        barrierDismissible: false,
        builder: (BuildContext context) {
          dialogContext = context;
          return Center(
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF3B82F6)),
                  SizedBox(height: 16),
                  Text(
                    '결제 처리 중...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      final contract = widget.contract;
      final branchId = ApiService.getCurrentBranchId();
      final contractDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // 회원 정보
      final memberId = widget.selectedMember?['member_id'] ?? 1;
      final memberName = widget.selectedMember?['member_name'] ?? '테스트회원';

      debugPrint('=== 포트원 결제 완료 후 회원권 등록 시작 ===');
      debugPrint('포트원 결제 ID: $portonePaymentId');
      debugPrint('회원 ID: $memberId');
      debugPrint('계약 ID: ${contract['contract_id']}');
      debugPrint('계약명: ${contract['contract_name']}');

      // 1. v3_contract_history 저장
      final contractHistoryData = {
        'branch_id': branchId,
        'member_id': memberId,
        'member_name': memberName,
        'contract_id': contract['contract_id'],
        'contract_name': contract['contract_name'],
        'contract_type': widget.membershipType,
        'contract_date': contractDate,
        'contract_register': DateTime.now().toIso8601String(),
        'payment_type': '포트원결제', // 포트원 결제로 변경
        'contract_history_status': '활성',
        'price': contract['price'] ?? 0,
        'contract_credit': contract['contract_credit'] ?? 0,
        'contract_ls_min': contract['contract_ls_min'] ?? contract['contract_LS_min'] ?? 0,
        'contract_games': contract['contract_games'] ?? 0,
        'contract_ts_min': contract['contract_ts_min'] ?? contract['contract_TS_min'] ?? 0,
        'contract_term_month': contract['contract_term_month'] ?? 0,
        'contract_credit_expiry_date': _calcExpiryDate(DateTime.now(), contract['contract_credit_effect_month']),
        'contract_ls_min_expiry_date': _calcExpiryDate(DateTime.now(), contract['contract_ls_min_effect_month'] ?? contract['contract_LS_min_effect_month']),
        'contract_games_expiry_date': _calcExpiryDate(DateTime.now(), contract['contract_games_effect_month']),
        'contract_ts_min_expiry_date': _calcExpiryDate(DateTime.now(), contract['contract_ts_min_effect_month'] ?? contract['contract_TS_min_effect_month']),
        'contract_term_month_expiry_date': termEndDate != null ? DateFormat('yyyy-MM-dd').format(termEndDate!) : null,
        'pro_id': selectedProId != null ? _safeParseInt(selectedProId) : null,
        'pro_name': selectedProName,
      };

      print('계약 히스토리 저장 중...');
      final historyResponse = await ApiService.addData(
        table: 'v3_contract_history',
        data: contractHistoryData,
      );

      if (historyResponse['success'] != true) {
        throw Exception('계약 히스토리 저장 실패');
      }

      // insertId를 정수로 변환 (문자열일 수 있음)
      final contractHistoryId = _safeParseInt(historyResponse['insertId']);
      print('계약 히스토리 저장 완료 - ID: $contractHistoryId');

      // 2. 포트원 결제 정보 저장
      final totalAmount = (contract['price'] ?? 0) as int;
      final orderName = '${contract['contract_name'] ?? '회원권'} - $memberName';
      
      // custom_data에 isTest 정보 저장
      final customData = isTest != null ? {'isTest': isTest} : null;
      
      final paymentSaveResult = await PortonePaymentService.savePaymentToDatabase(
        portonePaymentId: portonePaymentId,
        portoneTxId: portoneTxId,
        contractHistoryId: contractHistoryId,
        memberId: memberId,
        branchId: branchId,
        channelKey: channelKey ?? PortonePaymentService.defaultChannelKey,
        paymentAmount: totalAmount,
        paymentMethod: 'CARD',
        paymentProvider: 'TOSSPAYMENTS',
        orderName: orderName,
        paymentStatus: 'PAID',
        paymentRequestedAt: DateTime.now(),
        paymentPaidAt: DateTime.now(),
        customData: customData, // isTest 정보를 custom_data에 저장
      );

      if (paymentSaveResult['success'] != true) {
        debugPrint('❌ 포트원 결제 정보 저장 실패: ${paymentSaveResult['error']}');
        throw Exception('결제 정보 저장 실패: ${paymentSaveResult['error']}');
      } else {
        debugPrint('✅ 포트원 결제 정보 저장 완료');
      }
      
      // 3. DB에서 저장된 결제 정보를 조회하여 결제 완료 여부만 확인
      // (테스트 여부는 이미 채널 키로 판별 완료, DB는 결과 저장용)
      debugPrint('🔍 DB에서 저장된 결제 정보를 확인합니다...');
      final verificationResult = await _verifyPaymentFromDatabase(portonePaymentId);
      
      if (!verificationResult['isPaid']) {
        debugPrint('❌ DB에서 결제 정보를 확인할 수 없습니다. 회원권 부여를 중단합니다.');
        throw Exception('결제 정보를 확인할 수 없습니다: ${verificationResult['error']}');
      }
      
      debugPrint('✅ DB 확인 결과: 결제가 완료되었습니다. (payment_status: PAID)');

      // 4. 크레딧 적립 (v2_bills)
      final contractCredit = _safeParseInt(contract['contract_credit']);
      if (contractCredit > 0) {
        debugPrint('크레딧 적립 중: $contractCredit');
        final creditBillData = {
          'member_id': memberId,
          'branch_id': branchId,
          'bill_date': contractDate,
          'bill_type': '회원권적립',
          'bill_text': contract['contract_name'],
          'bill_totalamt': contractCredit,
          'bill_deduction': 0,
          'bill_netamt': contractCredit,
          'bill_timestamp': DateTime.now().toIso8601String(),
          'bill_balance_before': 0,
          'bill_balance_after': contractCredit,
          'bill_status': '결제완료',
          'contract_history_id': contractHistoryId,
          'contract_credit_expiry_date': contractHistoryData['contract_credit_expiry_date'],
        };

        final creditResponse = await ApiService.addData(
          table: 'v2_bills',
          data: creditBillData,
        );

        if (creditResponse['success'] == true) {
          debugPrint('크레딧 적립 완료');
          // bill_id를 contract_history에 업데이트
          await ApiService.updateData(
            table: 'v3_contract_history',
            data: {'bill_id': creditResponse['insertId']},
            where: [
              {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId}
            ],
          );
        }
      }

      // 5. 레슨권 처리 (v3_LS_countings만) - Supabase는 소문자로 반환
      final contractLS = _safeParseInt(contract['contract_ls_min'] ?? contract['contract_LS_min']);
      if (contractLS > 0) {
        debugPrint('레슨권 등록 중: $contractLS분');

        final effectMonth = _safeParseInt(contract['contract_ls_min_effect_month'] ?? contract['contract_LS_min_effect_month'], defaultValue: 12);
        final contractEndDate = DateTime(
          DateTime.now().year,
          DateTime.now().month + effectMonth,
          DateTime.now().day,
        );

        // v3_LS_countings 추가 (v2_LS_contracts 제외)
        final lsCountingData = {
          'LS_transaction_type': '레슨권 구매',
          'LS_date': contractDate,
          'member_id': memberId,
          'member_name': memberName,
          'member_type': widget.selectedMember?['member_type'] ?? '정회원',
          'LS_status': '결제완료',
          'LS_type': '일반',
          'LS_contract_id': null,
          'contract_history_id': contractHistoryId,
          'LS_id': null,
          'LS_contract_pro': null,
          'LS_balance_min_before': 0,
          'LS_net_min': contractLS,
          'LS_balance_min_after': contractLS,
          'LS_counting_source': 'v3_contract_history',
          'LS_set_id': null,
          'LS_expiry_date': DateFormat('yyyy-MM-dd').format(contractEndDate),
          'pro_id': selectedProId != null ? _safeParseInt(selectedProId) : null,
          'pro_name': selectedProName,
          'branch_id': branchId,
        };

        await ApiService.addData(
          table: 'v3_LS_countings',
          data: lsCountingData,
        );
        debugPrint('레슨권 카운팅 완료');
      }

      // 5. 타석시간 처리 (v2_bill_times) - Supabase는 소문자로 반환
      final contractTS = _safeParseInt(contract['contract_ts_min'] ?? contract['contract_TS_min']);
      if (contractTS > 0) {
        debugPrint('타석시간 등록 중: $contractTS분');

        final billTimesData = {
          'member_id': memberId,
          'bill_date': contractDate,
          'bill_type': '회원권등록',
          'bill_text': contract['contract_name'],
          'bill_min': contractTS,
          'bill_timestamp': DateTime.now().toIso8601String(),
          'bill_balance_min_before': 0,
          'bill_balance_min_after': contractTS,
          'reservation_id': null,
          'bill_status': '결제완료',
          'contract_history_id': contractHistoryId,
          'routine_id': null,
          'branch_id': branchId,
          'contract_ts_min_expiry_date': contractHistoryData['contract_ts_min_expiry_date'],
        };

        await ApiService.addData(
          table: 'v2_bill_times',
          data: billTimesData,
        );
        print('타석시간 등록 완료');
      }

      // 7. 스크린게임 처리 (v2_bill_games)
      final contractGames = _safeParseInt(contract['contract_games']);
      if (contractGames > 0) {
        print('스크린게임 등록 중: $contractGames회');

        final billGamesData = {
          'member_id': memberId,
          'bill_date': contractDate,
          'bill_type': '회원권등록',
          'bill_text': contract['contract_name'],
          'bill_games': contractGames,
          'bill_timestamp': DateTime.now().toIso8601String(),
          'bill_balance_game_before': 0,
          'bill_balance_game_after': contractGames,
          'reservation_id': null,
          'bill_status': '결제완료',
          'contract_history_id': contractHistoryId,
          'routine_id': null,
          'branch_id': branchId,
          'group_play_id': null,
          'group_members_numbers': null,
          'member_name': memberName,
          'non_member_name': null,
          'non_member_phone': null,
        };

        await ApiService.addData(
          table: 'v2_bill_games',
          data: billGamesData,
        );
        print('스크린게임 등록 완료');
      }

      // 8. 기간권 처리 (v2_bill_term)
      final contractTermMonth = _safeParseInt(contract['contract_term_month']);
      if (contractTermMonth > 0 && termStartDate != null && termEndDate != null) {
        print('기간권 등록 중: $contractTermMonth개월');

        final billTermData = {
          'member_id': memberId,
          'bill_date': contractDate,
          'bill_type': '회원권등록',
          'bill_text': contract['contract_name'],
          'bill_term_min': null,
          'bill_timestamp': DateTime.now().toIso8601String(),
          'reservation_id': null,
          'bill_status': '결제완료',
          'contract_history_id': contractHistoryId,
          'contract_term_month_expiry_date': DateFormat('yyyy-MM-dd').format(termEndDate!),
          'term_startdate': DateFormat('yyyy-MM-dd').format(termStartDate!),
          'term_enddate': DateFormat('yyyy-MM-dd').format(termEndDate!),
          'branch_id': branchId,
        };

        await ApiService.addData(
          table: 'v2_bill_term',
          data: billTermData,
        );
        print('기간권 등록 완료');
      }

      // 로딩 다이얼로그 닫기
      if (mounted && dialogContext != null) {
        Navigator.of(dialogContext!).pop();
      }

      // 성공 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text('결제가 완료되었습니다. 회원권이 등록되었습니다.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // 결제 페이지 닫기 (처리 완료 후)
      if (shouldClosePaymentPage && mounted) {
        Navigator.of(currentContext).pop(true); // 결제 페이지 닫기
        
        // isContentMode인 경우 콜백 호출, 아니면 페이지 닫기
        if (widget.isContentMode && widget.onComplete != null) {
          widget.onComplete!();
        } else {
          // 회원권 설정 페이지도 닫고 상위 화면으로 돌아가기
          if (mounted) {
            Navigator.of(currentContext).pop(true); // 회원권 설정 페이지 닫기
          }
        }
      }
    } catch (e) {
      // 로딩 다이얼로그 닫기
      if (mounted && dialogContext != null) {
        Navigator.of(dialogContext!).pop();
      }

      // 오류 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text('결제 처리 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }

      print('결제 처리 오류: $e');
      
      // 오류 발생 시 처리된 결제 ID에서 제거 (재시도 가능하도록)
      _processedPaymentIds.remove(portonePaymentId);
    }
  }

  // 결제 처리 및 DB 저장 (기존 함수 - 호환성 유지)
  Future<void> _processPayment() async {
    try {
      // 로딩 다이얼로그 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF3B82F6)),
                  SizedBox(height: 16),
                  Text(
                    '결제 처리 중...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      final contract = widget.contract;
      final branchId = ApiService.getCurrentBranchId();
      final contractDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // 회원 정보 (현재는 더미, 실제로는 selectedMember에서 가져와야 함)
      final memberId = widget.selectedMember?['member_id'] ?? 1;
      final memberName = widget.selectedMember?['member_name'] ?? '테스트회원';

      print('=== 회원권 등록 시작 ===');
      print('회원 ID: $memberId');
      print('계약 ID: ${contract['contract_id']}');
      print('계약명: ${contract['contract_name']}');

      // 1. v3_contract_history 저장
      final contractHistoryData = {
        'branch_id': branchId,
        'member_id': memberId,
        'member_name': memberName,
        'contract_id': contract['contract_id'],
        'contract_name': contract['contract_name'],
        'contract_type': widget.membershipType,
        'contract_date': contractDate,
        'contract_register': DateTime.now().toIso8601String(),
        'payment_type': '현금결제', // 임시로 현금결제 처리
        'contract_history_status': '활성',
        'price': contract['price'] ?? 0,
        'contract_credit': contract['contract_credit'] ?? 0,
        'contract_ls_min': contract['contract_ls_min'] ?? contract['contract_LS_min'] ?? 0,
        'contract_games': contract['contract_games'] ?? 0,
        'contract_ts_min': contract['contract_ts_min'] ?? contract['contract_TS_min'] ?? 0,
        'contract_term_month': contract['contract_term_month'] ?? 0,
        'contract_credit_expiry_date': _calcExpiryDate(DateTime.now(), contract['contract_credit_effect_month']),
        'contract_ls_min_expiry_date': _calcExpiryDate(DateTime.now(), contract['contract_ls_min_effect_month'] ?? contract['contract_LS_min_effect_month']),
        'contract_games_expiry_date': _calcExpiryDate(DateTime.now(), contract['contract_games_effect_month']),
        'contract_ts_min_expiry_date': _calcExpiryDate(DateTime.now(), contract['contract_ts_min_effect_month'] ?? contract['contract_TS_min_effect_month']),
        'contract_term_month_expiry_date': termEndDate != null ? DateFormat('yyyy-MM-dd').format(termEndDate!) : null,
        'pro_id': selectedProId != null ? _safeParseInt(selectedProId) : null,
        'pro_name': selectedProName,
      };

      print('계약 히스토리 저장 중...');
      final historyResponse = await ApiService.addData(
        table: 'v3_contract_history',
        data: contractHistoryData,
      );

      if (historyResponse['success'] != true) {
        throw Exception('계약 히스토리 저장 실패');
      }

      // insertId를 정수로 변환 (문자열일 수 있음)
      final contractHistoryId = _safeParseInt(historyResponse['insertId']);
      print('계약 히스토리 저장 완료 - ID: $contractHistoryId');

      // 2. 크레딧 적립 (v2_bills)
      final contractCredit = _safeParseInt(contract['contract_credit']);
      if (contractCredit > 0) {
        print('크레딧 적립 중: $contractCredit');
        final creditBillData = {
          'member_id': memberId,
          'branch_id': branchId,
          'bill_date': contractDate,
          'bill_type': '회원권적립',
          'bill_text': contract['contract_name'],
          'bill_totalamt': contractCredit,
          'bill_deduction': 0,
          'bill_netamt': contractCredit,
          'bill_timestamp': DateTime.now().toIso8601String(),
          'bill_balance_before': 0,
          'bill_balance_after': contractCredit,
          'bill_status': '결제완료',
          'contract_history_id': contractHistoryId,
          'contract_credit_expiry_date': contractHistoryData['contract_credit_expiry_date'],
        };

        final creditResponse = await ApiService.addData(
          table: 'v2_bills',
          data: creditBillData,
        );

        if (creditResponse['success'] == true) {
          print('크레딧 적립 완료');
          // bill_id를 contract_history에 업데이트
          await ApiService.updateData(
            table: 'v3_contract_history',
            data: {'bill_id': creditResponse['insertId']},
            where: [
              {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId}
            ],
          );
        }
      }

      // 3. 레슨권 처리 (v3_LS_countings만) - Supabase는 소문자로 반환
      final contractLS = _safeParseInt(contract['contract_ls_min'] ?? contract['contract_LS_min']);
      if (contractLS > 0) {
        print('레슨권 등록 중: $contractLS분');

        final effectMonth = _safeParseInt(contract['contract_ls_min_effect_month'] ?? contract['contract_LS_min_effect_month'], defaultValue: 12);
        final contractEndDate = DateTime(
          DateTime.now().year,
          DateTime.now().month + effectMonth,
          DateTime.now().day,
        );

        // v3_LS_countings 추가 (v2_LS_contracts 제외)
        final lsCountingData = {
          'LS_transaction_type': '레슨권 구매',
          'LS_date': contractDate,
          'member_id': memberId,
          'member_name': memberName,
          'member_type': widget.selectedMember?['member_type'] ?? '정회원',
          'LS_status': '결제완료',
          'LS_type': '일반',
          'LS_contract_id': null, // v2_LS_contracts를 사용하지 않으므로 null
          'contract_history_id': contractHistoryId,
          'LS_id': null,
          'LS_contract_pro': null,
          'LS_balance_min_before': 0,
          'LS_net_min': contractLS,
          'LS_balance_min_after': contractLS,
          'LS_counting_source': 'v3_contract_history',
          'LS_set_id': null,
          'LS_expiry_date': DateFormat('yyyy-MM-dd').format(contractEndDate),
          'pro_id': selectedProId != null ? _safeParseInt(selectedProId) : null,
          'pro_name': selectedProName,
          'branch_id': branchId,
        };

        await ApiService.addData(
          table: 'v3_LS_countings',
          data: lsCountingData,
        );
        print('레슨권 카운팅 완료');
      }

      // 4. 타석시간 처리 (v2_bill_times) - Supabase는 소문자로 반환
      final contractTS = _safeParseInt(contract['contract_ts_min'] ?? contract['contract_TS_min']);
      if (contractTS > 0) {
        print('타석시간 등록 중: $contractTS분');

        final billTimesData = {
          'member_id': memberId,
          'bill_date': contractDate,
          'bill_type': '회원권등록',
          'bill_text': contract['contract_name'],
          'bill_min': contractTS,
          'bill_timestamp': DateTime.now().toIso8601String(),
          'bill_balance_min_before': 0,
          'bill_balance_min_after': contractTS,
          'reservation_id': null,
          'bill_status': '결제완료',
          'contract_history_id': contractHistoryId,
          'routine_id': null,
          'branch_id': branchId,
          'contract_TS_min_expiry_date': contractHistoryData['contract_TS_min_expiry_date'],
        };

        await ApiService.addData(
          table: 'v2_bill_times',
          data: billTimesData,
        );
        print('타석시간 등록 완료');
      }

      // 5. 스크린게임 처리 (v2_bill_games)
      final contractGames = _safeParseInt(contract['contract_games']);
      if (contractGames > 0) {
        print('스크린게임 등록 중: $contractGames회');

        final billGamesData = {
          'member_id': memberId,
          'bill_date': contractDate,
          'bill_type': '회원권등록',
          'bill_text': contract['contract_name'],
          'bill_games': contractGames,
          'bill_timestamp': DateTime.now().toIso8601String(),
          'bill_balance_game_before': 0,
          'bill_balance_game_after': contractGames,
          'reservation_id': null,
          'bill_status': '결제완료',
          'contract_history_id': contractHistoryId,
          'routine_id': null,
          'branch_id': branchId,
          'group_play_id': null,
          'group_members_numbers': null,
          'member_name': memberName,
          'non_member_name': null,
          'non_member_phone': null,
        };

        await ApiService.addData(
          table: 'v2_bill_games',
          data: billGamesData,
        );
        print('스크린게임 등록 완료');
      }

      // 6. 기간권 처리 (v2_bill_term)
      final contractTermMonth = _safeParseInt(contract['contract_term_month']);
      if (contractTermMonth > 0 && termStartDate != null && termEndDate != null) {
        print('기간권 등록 중: $contractTermMonth개월');

        final billTermData = {
          'member_id': memberId,
          'bill_date': contractDate,
          'bill_type': '회원권등록',
          'bill_text': contract['contract_name'],
          'bill_term_min': null,
          'bill_timestamp': DateTime.now().toIso8601String(),
          'reservation_id': null,
          'bill_status': '결제완료',
          'contract_history_id': contractHistoryId,
          'contract_term_month_expiry_date': DateFormat('yyyy-MM-dd').format(termEndDate!),
          'term_startdate': DateFormat('yyyy-MM-dd').format(termStartDate!),
          'term_enddate': DateFormat('yyyy-MM-dd').format(termEndDate!),
          'branch_id': branchId,
        };

        await ApiService.addData(
          table: 'v2_bill_term',
          data: billTermData,
        );
        print('기간권 등록 완료');
      }

      print('=== 회원권 등록 완료 ===');

      // 로딩 다이얼로그 닫기
      Navigator.of(context).pop();

      // 성공 다이얼로그 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 64,
                  color: Color(0xFF10B981),
                ),
                SizedBox(height: 16),
                Text(
                  '회원권 등록 완료',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '회원권이 성공적으로 등록되었습니다',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  // 1. 다이얼로그 닫기
                  Navigator.of(context).pop();

                  // 2. 약간의 딜레이 후 페이지들 순차적으로 닫기
                  Future.delayed(Duration(milliseconds: 100), () {
                    try {
                      // contract_setup_page 닫기
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      print('첫 번째 pop 오류: $e');
                    }
                  });

                  Future.delayed(Duration(milliseconds: 200), () {
                    try {
                      // contract_list_page 닫기
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      print('두 번째 pop 오류: $e');
                    }
                  });

                  Future.delayed(Duration(milliseconds: 300), () {
                    try {
                      // membership_page 닫기
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      print('세 번째 pop 오류: $e');
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  '확인',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      );

    } catch (e) {
      print('회원권 등록 오류: $e');

      // 로딩 다이얼로그가 열려있으면 닫기
      Navigator.of(context).pop();

      // 오류 다이얼로그 표시
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Color(0xFFEF4444),
                ),
                SizedBox(height: 16),
                Text(
                  '등록 실패',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '회원권 등록 중 오류가 발생했습니다\n$e',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  '확인',
                  style: TextStyle(
                    color: Color(0xFF3B82F6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  // 유효기간 만료일 계산 함수
  String? _calcExpiryDate(DateTime base, dynamic month) {
    final m = _safeParseInt(month);
    if (m < 0) return null;
    if (m == 0) {
      return DateFormat('yyyy-MM-dd').format(base);
    }
    final expiry = DateTime(base.year, base.month + m, base.day).subtract(Duration(days: 1));
    return DateFormat('yyyy-MM-dd').format(expiry);
  }

  // 안전한 정수 변환
  int _safeParseInt(dynamic value, {int defaultValue = 0}) {
    try {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        return parsed ?? defaultValue;
      }
      return defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  // 안전한 문자열 변환
  String _safeToString(dynamic value, {String defaultValue = ''}) {
    try {
      if (value == null) return defaultValue;
      return value.toString();
    } catch (e) {
      return defaultValue;
    }
  }

  // 가격 포맷팅
  String _formatPrice(dynamic price) {
    final priceInt = _safeParseInt(price);
    final formatter = NumberFormat('#,###');
    return '${formatter.format(priceInt)}원';
  }

  // 설정 완료 여부 확인 - Supabase는 소문자로 반환
  bool _isSetupComplete() {
    final contractLS = _safeParseInt(widget.contract['contract_ls_min'] ?? widget.contract['contract_LS_min']);
    final contractTermMonth = _safeParseInt(widget.contract['contract_term_month']);

    // 레슨권이 있으면 프로 선택 필수
    if (contractLS > 0 && selectedProId == null) {
      return false;
    }

    // 기간권이 있으면 시작일 필수
    if (contractTermMonth > 0 && termStartDate == null) {
      return false;
    }

    return true;
  }

  // 서비스 칩 빌드
  Widget _buildServiceChip({
    required IconData icon,
    required Color iconColor,
    required String label,
    int? effectMonth,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          if (effectMonth != null && effectMonth > 0)
            Text(
              ' (${effectMonth}개월)',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat('#,###');
    final contract = widget.contract;
    final contractName = contract['contract_name'] ?? '';
    final price = contract['price'] ?? 0;

    // 서비스 정보 (Supabase는 소문자로 반환)
    final contractCredit = _safeParseInt(contract['contract_credit']);
    final contractLSMin = _safeParseInt(contract['contract_ls_min'] ?? contract['contract_LS_min']);
    final contractTSMin = _safeParseInt(contract['contract_ts_min'] ?? contract['contract_TS_min']);
    final contractGames = _safeParseInt(contract['contract_games']);
    final contractTermMonth = _safeParseInt(contract['contract_term_month']);

    // isContentMode인 경우 body만 반환
    if (widget.isContentMode) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 계약 정보 카드
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          contractName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Color(0xFFFFEDD5)),
                        ),
                        child: Text(
                          _formatPrice(price),
                          style: TextStyle(
                            color: Color(0xFFEA580C),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (contractCredit > 0)
                        _buildServiceChip(
                          icon: Icons.monetization_on,
                          iconColor: Colors.amber,
                          label: '크레딧 ${f.format(contractCredit)}원',
                          effectMonth: contract['contract_credit_effect_month'],
                        ),
                      if (contractLSMin > 0)
                        _buildServiceChip(
                          icon: Icons.school,
                          iconColor: Colors.blueAccent,
                          label: '레슨권 ${f.format(contractLSMin)}분',
                          effectMonth: contract['contract_LS_min_effect_month'],
                        ),
                      if (contractTSMin > 0)
                        _buildServiceChip(
                          icon: Icons.sports_golf,
                          iconColor: Colors.green,
                          label: '타석시간 ${f.format(contractTSMin)}분',
                          effectMonth: contract['contract_TS_min_effect_month'],
                        ),
                      if (contractGames > 0)
                        _buildServiceChip(
                          icon: Icons.sports_esports,
                          iconColor: Colors.purple,
                          label: '스크린게임 ${f.format(contractGames)}회',
                          effectMonth: contract['contract_games_effect_month'],
                        ),
                      if (contractTermMonth > 0)
                        _buildServiceChip(
                          icon: Icons.calendar_month,
                          iconColor: Colors.teal,
                          label: '기간권 ${f.format(contractTermMonth)}개월',
                          effectMonth: contract['contract_term_month_effect_month'],
                        ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // 프로 선택 섹션 (레슨권이 있을 때만)
            if (contractLSMin > 0) ...[
              Text(
                '담당 프로 선택',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              SizedBox(height: 12),
              GestureDetector(
                onTap: isLoadingPros ? null : _showProSelectionDialog,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selectedProId != null
                        ? Color(0xFFF0F9FF)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selectedProId != null
                          ? Color(0xFF0369A1)
                          : Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: selectedProId != null
                              ? Color(0xFF3B82F6)
                              : Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.person,
                          color: selectedProId != null
                              ? Colors.white
                              : Color(0xFF6B7280),
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          selectedProName ?? '프로를 선택해주세요',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: selectedProId != null
                                ? Color(0xFF0369A1)
                                : Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Color(0xFF9CA3AF),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
            ],

            // 기간권 시작일 선택 섹션 (기간권이 있을 때만)
            if (contractTermMonth > 0) ...[
              Text(
                '기간권 시작일',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              SizedBox(height: 12),
              GestureDetector(
                onTap: _selectTermStartDate,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 20,
                        color: Color(0xFF10B981),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          termStartDate != null
                              ? DateFormat('yyyy년 MM월 dd일').format(termStartDate!)
                              : '시작일을 선택해주세요',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: termStartDate != null
                                ? Color(0xFF374151)
                                : Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Color(0xFF9CA3AF),
                      ),
                    ],
                  ),
                ),
              ),
              if (termStartDate != null && termEndDate != null) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFF10B981).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.date_range,
                        size: 20,
                        color: Color(0xFF10B981),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '기간: ${DateFormat('yyyy.MM.dd').format(termStartDate!)} ~ ${DateFormat('yyyy.MM.dd').format(termEndDate!)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 24),
            ],

            // 요약 정보
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '선택 요약',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildSummaryRow('회원권 유형', widget.membershipType),
                  _buildSummaryRow('상품명', contractName),
                  _buildSummaryRow('결제 금액', _formatPrice(price)),
                  if (selectedProName != null)
                    _buildSummaryRow('담당 프로', selectedProName!),
                  if (termStartDate != null && termEndDate != null)
                    _buildSummaryRow(
                      '기간권',
                      '${DateFormat('yyyy.MM.dd').format(termStartDate!)} ~ ${DateFormat('yyyy.MM.dd').format(termEndDate!)}',
                    ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // 결제 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSetupComplete() ? _onPaymentButtonPressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Color(0xFFE5E7EB),
                  disabledForegroundColor: Color(0xFF9CA3AF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  '결제하기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            if (!_isSetupComplete()) ...[
              SizedBox(height: 12),
              Center(
                child: Text(
                  '필수 항목을 모두 선택해주세요',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],

            SizedBox(height: 30),

            // 판매자 정보 섹션
            if (branchInfo != null)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 첫 번째 줄: 판매자 정보
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '회원권 판매자',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                        Text(
                          '${branchInfo!['branch_name'] ?? ''} (사업자번호: ${branchInfo!['branch_business_reg_no'] ?? ''})',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),

                    // 두 번째 줄: 대표자 및 연락처 + 약관 버튼
                    Row(
                      children: [
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                                height: 1.5,
                              ),
                              children: [
                                TextSpan(
                                  text: '대표자: ',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                TextSpan(
                                  text: '${branchInfo!['branch_director_name'] ?? ''}',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                TextSpan(text: ', 연락처: ${branchInfo!['branch_phone'] ?? ''}'),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _showTermsDialog,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size(0, 28),
                            side: BorderSide(color: Color(0xFF3B82F6), width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(
                            '회원권 구매약관',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),

                    // 세 번째 줄: 면책 조항
                    Text(
                      '본 플랫폼은 통신판매중개자이며, 회원권 거래의 당사자가 아닙니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 16), // 마지막 여백
          ],
        ),
      );
    }
    
    // 기존 ContractSetupPage인 경우 Scaffold 전체 반환
    return Scaffold(
      backgroundColor: TabDesignService.backgroundColor,
      appBar: TabDesignService.buildAppBar(title: '회원권 설정'),
      bottomNavigationBar: TabDesignService.buildBottomNavigationBar(
        context: context,
        selectedIndex: 3, // 회원권 탭
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 계약 정보 카드
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          contractName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Color(0xFFFFEDD5)),
                        ),
                        child: Text(
                          _formatPrice(price),
                          style: TextStyle(
                            color: Color(0xFFEA580C),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 요약 정보 행
  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
