import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../services/refund_service.dart';

/// 결제내역 조회 페이지
/// 포트원 결제 기록을 보여주고 환불 기능 제공
class PaymentHistorySearchPage extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const PaymentHistorySearchPage({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _PaymentHistorySearchPageState createState() => _PaymentHistorySearchPageState();
}

class _PaymentHistorySearchPageState extends State<PaymentHistorySearchPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('결제내역'),
        backgroundColor: const Color(0xFF9C27B0),
        foregroundColor: Colors.white,
      ),
      body: PaymentHistorySearchContent(
        isAdminMode: widget.isAdminMode,
        selectedMember: widget.selectedMember,
        branchId: widget.branchId,
      ),
    );
  }
}

/// 결제내역 콘텐츠 위젯 (탭에서 사용)
class PaymentHistorySearchContent extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const PaymentHistorySearchContent({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _PaymentHistorySearchContentState createState() => _PaymentHistorySearchContentState();
}

class _PaymentHistorySearchContentState extends State<PaymentHistorySearchContent> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _payments = [];
  Map<String, dynamic>? _selectedPayment;
  Map<String, dynamic>? _selectedContractHistory;
  
  // 환불 관련 상태
  bool _isCheckingRefund = false;
  bool _isRefundable = false;
  Map<String, dynamic>? _refundEligibility;

  final _numberFormat = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _loadPaymentHistory();
  }

  /// 결제 내역 로드 (contract_history 정보 포함)
  Future<void> _loadPaymentHistory() async {
    setState(() => _isLoading = true);

    try {
      final branchId = widget.branchId ?? ApiService.getCurrentBranchId();
      dynamic memberId;
      if (widget.isAdminMode) {
        memberId = widget.selectedMember?['member_id'];
      } else {
        memberId = ApiService.getCurrentUser()?['member_id'];
      }

      if (branchId == null || memberId == null) {
        setState(() {
          _payments = [];
          _isLoading = false;
        });
        return;
      }

      // v2_portone_payments 테이블에서 결제 내역 조회
      final payments = await ApiService.getData(
        table: 'v2_portone_payments',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
        orderBy: [
          {'field': 'created_at', 'direction': 'DESC'},
        ],
      );

      // 각 결제에 대해 contract_history 정보 추가
      for (var payment in payments) {
        final contractHistoryId = payment['contract_history_id'];
        if (contractHistoryId != null) {
          try {
            final contractHistory = await ApiService.getData(
              table: 'v3_contract_history',
              where: [
                {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
              ],
              limit: 1,
            );
            if (contractHistory.isNotEmpty) {
              payment['contract_history'] = contractHistory.first;
            }
          } catch (e) {
            print('contract_history 조회 오류: $e');
          }
        }
      }

      setState(() {
        _payments = payments;
        _isLoading = false;
      });
    } catch (e) {
      print('결제 내역 로드 오류: $e');
      setState(() {
        _payments = [];
        _isLoading = false;
      });
    }
  }

  /// 안전한 정수 변환
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

  /// 서비스 칩 빌드 (contract_list_page.dart와 동일)
  Widget _buildServiceChip({
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// 결제 상세 정보 로드 (contract_history 포함)
  Future<void> _loadPaymentDetail(Map<String, dynamic> payment) async {
    setState(() {
      _selectedPayment = payment;
      _selectedContractHistory = null;
      _isRefundable = false;
      _refundEligibility = null;
    });

    final contractHistoryId = payment['contract_history_id'];
    if (contractHistoryId == null) return;

    try {
      // v3_contract_history에서 계약 정보 조회
      final contractHistory = await ApiService.getData(
        table: 'v3_contract_history',
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
        ],
        limit: 1,
      );

      if (contractHistory.isNotEmpty) {
        setState(() {
          _selectedContractHistory = contractHistory.first;
        });

        // 환불 가능 여부 확인
        await _checkRefundEligibility(contractHistoryId);
      }
    } catch (e) {
      print('결제 상세 정보 로드 오류: $e');
    }
  }

  /// 환불 가능 여부 확인
  Future<void> _checkRefundEligibility(dynamic contractHistoryId) async {
    final branchId = widget.branchId ?? ApiService.getCurrentBranchId();
    dynamic memberId;
    if (widget.isAdminMode) {
      memberId = widget.selectedMember?['member_id'];
    } else {
      memberId = ApiService.getCurrentUser()?['member_id'];
    }

    if (branchId == null || memberId == null || contractHistoryId == null) {
      return;
    }

    setState(() => _isCheckingRefund = true);

    try {
      final result = await RefundService.checkRefundEligibility(
        branchId: branchId,
        memberId: memberId,
        contractHistoryId: contractHistoryId,
      );

      setState(() {
        _isCheckingRefund = false;
        _refundEligibility = result;
        _isRefundable = result['success'] == true &&
            result['has_portone_payment'] == true &&
            result['is_refundable'] == true;
      });

      print('환불 가능 여부: $_isRefundable - ${result['reason']}');
    } catch (e) {
      print('환불 가능 여부 확인 오류: $e');
      setState(() {
        _isCheckingRefund = false;
        _isRefundable = false;
        _refundEligibility = null;
      });
    }
  }

  /// 환불 처리 다이얼로그
  Future<void> _showRefundDialog() async {
    if (_selectedPayment == null || _refundEligibility == null) return;

    final paymentAmount = _refundEligibility!['payment_amount'] as int? ?? 0;
    final contractName = _selectedContractHistory?['contract_name'] ?? '회원권';
    final portonePaymentUid = _refundEligibility!['portone_payment_uid']?.toString() ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('결제취소 확인'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '다음 결제를 취소하시겠습니까?',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '상품명: $contractName',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '취소 금액: ${_numberFormat.format(paymentAmount)}원',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              '⚠️ 결제취소 시 해당 회원권의 모든 잔액이 0원으로 초기화됩니다.',
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('닫기'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('결제취소'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _processRefund(portonePaymentUid, paymentAmount);
    }
  }

  /// 환불 처리 실행
  Future<void> _processRefund(String paymentId, int amount) async {
    final branchId = widget.branchId ?? ApiService.getCurrentBranchId();
    dynamic memberId;
    if (widget.isAdminMode) {
      memberId = widget.selectedMember?['member_id'];
    } else {
      memberId = ApiService.getCurrentUser()?['member_id'];
    }
    final contractHistoryId = _selectedContractHistory?['contract_history_id'];

    if (branchId == null || memberId == null || contractHistoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('환불에 필요한 정보가 부족합니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('환불 처리 중...'),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await RefundService.processRefund(
        branchId: branchId,
        memberId: memberId,
        contractHistoryId: contractHistoryId,
        paymentId: paymentId,
      );

      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('환불이 완료되었습니다 (${_numberFormat.format(result['refunded_amount'] ?? amount)}원)'),
            backgroundColor: Colors.green,
          ),
        );

        // 상태 초기화 및 데이터 새로고침
        setState(() {
          _selectedPayment = null;
          _selectedContractHistory = null;
          _isRefundable = false;
          _refundEligibility = null;
        });
        _loadPaymentHistory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('환불 실패: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('환불 처리 오류: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 결제 상태 색상
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'PAID':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      case 'FAILED':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  /// 결제 상태 텍스트
  String _getStatusText(String? status) {
    switch (status) {
      case 'PAID':
        return '결제완료';
      case 'CANCELLED':
        return '취소됨';
      case 'FAILED':
        return '실패';
      case 'READY':
        return '대기중';
      default:
        return status ?? '알 수 없음';
    }
  }

  /// 날짜 포맷팅
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy.MM.dd HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    // 결제 상세 보기 모드
    if (_selectedPayment != null) {
      return _buildPaymentDetail();
    }

    // 결제 내역 목록
    return _buildPaymentList();
  }

  /// 결제 내역 목록 빌드
  Widget _buildPaymentList() {
    if (_payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              '결제 내역이 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPaymentHistory,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _payments.length,
        itemBuilder: (context, index) {
          final payment = _payments[index];
          return _buildPaymentCard(payment);
        },
      ),
    );
  }

  /// 결제 카드 빌드 (contract_list_page.dart UI와 통일)
  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final status = payment['payment_status'] as String?;
    final amount = payment['payment_amount'] as int? ?? 0;
    final orderName = payment['order_name'] as String? ?? '회원권';
    final paidAt = payment['payment_paid_at'] as String?;
    final channelKeyType = payment['channel_key_type'] as String? ?? '';
    final contractHistory = payment['contract_history'] as Map<String, dynamic>?;

    // 서비스 정보 추출 (contract_history에서)
    final contractCredit = _safeParseInt(contractHistory?['contract_credit']);
    final contractLSMin = _safeParseInt(contractHistory?['contract_ls_min'] ?? contractHistory?['contract_LS_min']);
    final contractTSMin = _safeParseInt(contractHistory?['contract_ts_min'] ?? contractHistory?['contract_TS_min']);
    final contractGames = _safeParseInt(contractHistory?['contract_games']);
    final contractTermMonth = _safeParseInt(contractHistory?['contract_term_month']);

    return GestureDetector(
      onTap: () => _loadPaymentDetail(payment),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단: 상품명 & 가격
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      orderName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0xFFFFEDD5)),
                    ),
                    child: Text(
                      '${_numberFormat.format(amount)}원',
                      style: TextStyle(
                        color: Color(0xFFEA580C),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              // 서비스 칩들 (contract_list_page.dart와 동일)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (contractCredit > 0)
                    _buildServiceChip(
                      icon: Icons.monetization_on,
                      iconColor: Colors.amber,
                      label: '크레딧 ${_numberFormat.format(contractCredit)}',
                    ),
                  if (contractLSMin > 0)
                    _buildServiceChip(
                      icon: Icons.school,
                      iconColor: Colors.blueAccent,
                      label: '레슨 ${_numberFormat.format(contractLSMin)}분',
                    ),
                  if (contractTSMin > 0)
                    _buildServiceChip(
                      icon: Icons.sports_golf,
                      iconColor: Colors.green,
                      label: '타석 ${_numberFormat.format(contractTSMin)}분',
                    ),
                  if (contractGames > 0)
                    _buildServiceChip(
                      icon: Icons.sports_esports,
                      iconColor: Colors.purple,
                      label: '게임 ${_numberFormat.format(contractGames)}회',
                    ),
                  if (contractTermMonth > 0)
                    _buildServiceChip(
                      icon: Icons.calendar_month,
                      iconColor: Colors.teal,
                      label: '기간권 ${contractTermMonth}개월',
                    ),
                ],
              ),

              // 서비스 칩이 하나도 없으면 기본 메시지
              if (contractCredit == 0 && contractLSMin == 0 && contractTSMin == 0 && contractGames == 0 && contractTermMonth == 0)
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    '서비스 정보 없음',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

              Divider(height: 24, color: Color(0xFFE2E8F0)),

              // 하단: 결제 상태 & 결제일
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _getStatusColor(status).withOpacity(0.5)),
                        ),
                        child: Text(
                          _getStatusText(status),
                          style: TextStyle(
                            color: _getStatusColor(status),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (channelKeyType == '테스트')
                        Container(
                          margin: EdgeInsets.only(left: 8),
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '테스트',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    _formatDate(paidAt),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
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

  /// 결제 수단 텍스트 (사용자 친화적)
  String _getPaymentMethodText(String? method) {
    switch (method?.toUpperCase()) {
      case 'CARD':
        return '카드';
      case 'TRANSFER':
        return '계좌이체';
      case 'VIRTUAL_ACCOUNT':
        return '가상계좌';
      case 'MOBILE':
        return '휴대폰';
      case 'EASY_PAY':
        return '간편결제';
      default:
        return method ?? '기타';
    }
  }

  /// 결제 상세 페이지 빌드
  Widget _buildPaymentDetail() {
    final payment = _selectedPayment!;
    final status = payment['payment_status'] as String?;
    final amount = payment['payment_amount'] as int? ?? 0;
    final orderName = payment['order_name'] as String? ?? '회원권';
    final paidAt = payment['payment_paid_at'] as String?;
    final paymentMethod = payment['payment_method'] as String? ?? '';
    final paymentUid = payment['portone_payment_uid'] as String? ?? '';

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 뒤로가기 버튼
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedPayment = null;
                _selectedContractHistory = null;
                _isRefundable = false;
                _refundEligibility = null;
              });
            },
            icon: Icon(Icons.arrow_back, size: 20),
            label: Text('목록으로'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: Color(0xFF9C27B0),
            ),
          ),
          SizedBox(height: 16),

          // 결제 정보 카드
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상품명
                Text(
                  orderName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 16),

                // 결제 금액
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '결제 금액',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '${_numberFormat.format(amount)}원',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9C27B0),
                      ),
                    ),
                  ],
                ),
                Divider(height: 32),

                // 상세 정보 (사용자에게 필요한 정보만 표시)
                _buildDetailRow('결제 상태', _getStatusText(status), _getStatusColor(status)),
                _buildDetailRow('결제 수단', _getPaymentMethodText(paymentMethod)),
                _buildDetailRow('결제 일시', _formatDate(paidAt)),
                if (paymentUid.isNotEmpty)
                  _buildDetailRow('거래번호', paymentUid, null, true),
              ],
            ),
          ),
          SizedBox(height: 16),

          // 회원권 정보 카드 (있는 경우)
          if (_selectedContractHistory != null) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '회원권 정보',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildContractInfo(),
                ],
              ),
            ),
            SizedBox(height: 24),
          ],

          // 환불 버튼
          if (_isCheckingRefund)
            Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_isRefundable && status == 'PAID')
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _showRefundDialog,
                  icon: Icon(Icons.cancel_outlined, size: 20),
                  label: Text(
                    '결제취소',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
          else if (status == 'CANCELLED')
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                  SizedBox(width: 8),
                  Text(
                    '이미 환불된 결제입니다',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else if (!_isRefundable && status == 'PAID')
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                '사용중인 회원권은 결제취소가 불가합니다.\n센터로 문의주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          // 하단 네비게이션 바 가림 방지 여백
          SizedBox(height: 100),
        ],
      ),
    );
  }

  /// 상세 정보 행 빌드
  Widget _buildDetailRow(String label, String value, [Color? valueColor, bool isSmall = false]) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isSmall ? 12 : 14,
                fontWeight: FontWeight.w500,
                color: valueColor ?? Color(0xFF1F2937),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  /// 회원권 정보 빌드
  Widget _buildContractInfo() {
    final contract = _selectedContractHistory!;
    final contractName = contract['contract_name'] as String? ?? '';
    final contractType = contract['contract_type'] as String? ?? '';
    final contractDate = contract['contract_date'] as String? ?? '';
    final contractStatus = contract['contract_history_status'] as String? ?? '';

    // 서비스 정보 (_safeParseInt로 안전하게 변환, 대소문자 fallback 처리)
    final credit = _safeParseInt(contract['contract_credit']);
    final lsMin = _safeParseInt(contract['contract_ls_min'] ?? contract['contract_LS_min']);
    final tsMin = _safeParseInt(contract['contract_ts_min'] ?? contract['contract_TS_min']);
    final games = _safeParseInt(contract['contract_games']);
    final termMonth = _safeParseInt(contract['contract_term_month']);

    // 구성상품 존재 여부 확인
    final hasServices = credit > 0 || lsMin > 0 || tsMin > 0 || games > 0 || termMonth > 0;

    // 각 상품별 사용 여부 (refundEligibility에서 가져옴)
    final creditUsed = _refundEligibility?['credit_used'] == true;
    final lessonUsed = _refundEligibility?['lesson_used'] == true;
    final timepassUsed = _refundEligibility?['timepass_used'] == true;
    final gameUsed = _refundEligibility?['game_used'] == true;
    final termUsed = _refundEligibility?['term_used'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 회원권 개요
        _buildDetailRow('상품명', contractName),
        _buildDetailRow('유형', contractType),
        _buildDetailRow('구매일', contractDate),
        _buildDetailRow('상태', contractStatus,
            contractStatus == '활성' ? Colors.green : Colors.grey),
        
        // 구분선 (구성상품이 있을 때만)
        if (hasServices)
          Divider(height: 24, color: Colors.grey[300]),
        
        // 구성상품 목록 (사용 여부 표시)
        if (credit > 0)
          _buildServiceRow('크레딧', '${_numberFormat.format(credit)}원', creditUsed),
        if (lsMin > 0)
          _buildServiceRow('레슨권', '${_numberFormat.format(lsMin)}분', lessonUsed),
        if (tsMin > 0)
          _buildServiceRow('타석시간', '${_numberFormat.format(tsMin)}분', timepassUsed),
        if (games > 0)
          _buildServiceRow('스크린게임', '${_numberFormat.format(games)}회', gameUsed),
        if (termMonth > 0)
          _buildServiceRow('기간권', '${termMonth}개월', termUsed),
      ],
    );
  }

  /// 서비스 행 빌드 (사용 여부 포함)
  Widget _buildServiceRow(String label, String value, bool isUsed) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F2937),
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isUsed ? Colors.red[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isUsed ? Colors.red[200]! : Colors.green[200]!,
                  ),
                ),
                child: Text(
                  isUsed ? '사용' : '미사용',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isUsed ? Colors.red[700] : Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

