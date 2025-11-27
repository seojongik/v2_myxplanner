import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../services/program_reservation_classifier.dart';
import 'package:intl/intl.dart';

class CreditSearchPage extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const CreditSearchPage({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _CreditSearchPageState createState() => _CreditSearchPageState();
}

class _CreditSearchPageState extends State<CreditSearchPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('크레딧 조회'),
        backgroundColor: Color(0xFF00A86B),
        foregroundColor: Colors.white,
      ),
      body: CreditSearchContent(
        isAdminMode: widget.isAdminMode,
        selectedMember: widget.selectedMember,
        branchId: widget.branchId,
      ),
    );
  }
}

class CreditSearchContent extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const CreditSearchContent({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _CreditSearchContentState createState() => _CreditSearchContentState();
}

class _CreditSearchContentState extends State<CreditSearchContent> {
  bool _isLoading = true;
  bool _showExpired = false;
  List<Map<String, dynamic>> _contracts = [];
  Map<String, dynamic>? _selectedContract;
  List<Map<String, dynamic>> _creditHistory = [];

  @override
  void initState() {
    super.initState();
    _loadContracts();
  }

  Future<void> _loadContracts() async {
    setState(() => _isLoading = true);

    try {
      String? memberId;
      if (widget.isAdminMode) {
        memberId = widget.selectedMember?['member_id']?.toString();
      } else {
        memberId = ApiService.getCurrentUser()?['member_id']?.toString();
      }

      final branchId = widget.branchId ?? ApiService.getCurrentBranchId();

      print('=== 크레딧 조회 디버깅 시작 (v2_bills 중심) ===');
      print('memberId: $memberId');
      print('branchId: $branchId');
      print('showExpired: $_showExpired');

      if (memberId == null || branchId == null) {
        throw Exception('회원 정보가 없습니다');
      }

      // 1. v2_bills에서 회원의 모든 크레딧 거래 내역 조회
      print('\n=== STEP 1: v2_bills에서 모든 크레딧 거래 조회 ===');
      print('쿼리 조건: branch_id=$branchId, member_id=$memberId');

      final allBills = await ApiService.getData(
        table: 'v2_bills',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
        orderBy: [{'field': 'bill_id', 'direction': 'DESC'}],
      );

      print('v2_bills에서 조회된 전체 거래 수: ${allBills.length}');

      if (allBills.isEmpty) {
        print('WARNING: 해당 회원의 거래 내역이 전혀 없습니다.');
        _contracts = [];
        return;
      }

      // 2. contract_history_id별로 그룹화하여 최신 거래 추출
      print('\n=== STEP 2: contract_history_id별 그룹화 및 최신 거래 추출 ===');
      final Map<String, Map<String, dynamic>> contractMap = {};

      for (final bill in allBills) {
        final contractHistoryId = bill['contract_history_id']?.toString();
        if (contractHistoryId == null || contractHistoryId.isEmpty) {
          continue;
        }

        // 각 contract_history_id의 최신 거래만 저장 (이미 DESC 정렬되어 있으므로 첫 번째가 최신)
        if (!contractMap.containsKey(contractHistoryId)) {
          contractMap[contractHistoryId] = bill;
        }
      }

      print('그룹화된 contract_history_id 수: ${contractMap.length}');

      // 3. 각 계약의 유효성 판단 및 필터링
      print('\n=== STEP 3: 유효성 판단 및 필터링 ===');
      final contractList = <Map<String, dynamic>>[];

      for (final entry in contractMap.entries) {
        final contractHistoryId = entry.key;
        final latestBill = entry.value;

        print('\n--- contract_history_id: $contractHistoryId 처리 ---');

        final balance = int.tryParse(latestBill['bill_balance_after']?.toString() ?? '0') ?? 0;
        final expiryDateStr = latestBill['contract_credit_expiry_date']?.toString() ?? '';
        final billText = latestBill['bill_text']?.toString() ?? '';

        print('최신 거래 정보:');
        print('  - bill_id: ${latestBill['bill_id']}');
        print('  - bill_balance_after: $balance원');
        print('  - contract_credit_expiry_date: $expiryDateStr');
        print('  - bill_text: $billText');

        // 유효성 판단: 잔액 > 0 AND 만료일이 미래
        final expiryDate = DateTime.tryParse(expiryDateStr);
        final now = DateTime.now();
        final hasBalance = balance > 0;
        final notExpired = expiryDate?.isAfter(now) ?? false;
        final isValid = hasBalance && notExpired;

        print('유효성 판단:');
        print('  - 잔액 > 0: $hasBalance');
        print('  - 만료일 미래: $notExpired (만료일: $expiryDate, 현재: $now)');
        print('  - 최종 유효 여부: $isValid');

        // 만료된 계약 필터링
        if (!_showExpired && !isValid) {
          print('만료된 계약이고 showExpired=false이므로 건너뜀');
          continue;
        }

        // 4. 해당 계약의 전체 거래 건수 조회
        final billCount = allBills.where((b) =>
          b['contract_history_id']?.toString() == contractHistoryId
        ).length;

        print('전체 거래 건수: $billCount건');

        contractList.add({
          'contract_history_id': contractHistoryId,
          'bill_text': '', // 나중에 v3_contract_history에서 조회
          'contract_credit_expiry_date': expiryDateStr,
          'last_balance': balance.toString(),
          'bill_count': billCount,
          'is_valid': isValid,
        });

        print('✅ 계약 추가: contract_history_id=$contractHistoryId, 잔액: ${balance}원, 거래: $billCount건');
      }

      print('\n=== STEP 4: v3_contract_history에서 contract_name 조회 ===');

      if (contractList.isNotEmpty) {
        // 각 contract_history_id별로 계약 정보 조회
        for (final contract in contractList) {
          final contractHistoryId = contract['contract_history_id'];
          print('contract_history_id=$contractHistoryId 조회 중...');

          try {
            final contracts = await ApiService.getData(
              table: 'v3_contract_history',
              where: [
                {'field': 'branch_id', 'operator': '=', 'value': branchId},
                {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
              ],
              limit: 1,
            );

            if (contracts.isNotEmpty) {
              final contractData = contracts[0];
              final contractName = contractData['contract_name']?.toString() ?? '(알 수 없음)';
              final contractId = contractData['contract_id']?.toString();
              contract['bill_text'] = contractName;
              contract['contract_id'] = contractId;
              print('  → contract_name: $contractName, contract_id: $contractId');
            } else {
              contract['bill_text'] = '(알 수 없음)';
              print('  → 계약 정보 없음');
            }
          } catch (e) {
            print('  → 조회 실패: $e');
            contract['bill_text'] = '(알 수 없음)';
          }
        }
      }

      print('\n=== STEP 5: 프로그램 전용 상품 필터링 ===');
      print('필터링 전 계약 수: ${contractList.length}');

      final filteredContracts = await ProgramReservationClassifier.filterContracts(
        contracts: contractList,
        branchId: branchId,
        includeProgram: false,  // 프로그램 전용 상품 제외
      );

      print('필터링 후 계약 수: ${filteredContracts.length}');

      print('\n=== STEP 6: 최종 계약 목록 정리 ===');
      print('처리된 계약 수: ${filteredContracts.length}');

      _contracts = filteredContracts;

      // 만료일 기준으로 정렬
      print('만료일 기준으로 정렬 중...');
      _contracts.sort((a, b) {
        try {
          final dateA = DateTime.parse(b['contract_credit_expiry_date']);
          final dateB = DateTime.parse(a['contract_credit_expiry_date']);
          return dateA.compareTo(dateB);
        } catch (e) {
          print('정렬 중 날짜 파싱 에러: $e');
          return 0;
        }
      });

      print('최종 표시될 계약 목록:');
      for (int i = 0; i < _contracts.length; i++) {
        final c = _contracts[i];
        print('  $i: contract_history_id=${c['contract_history_id']}, ${c['bill_text']}, 잔액: ${c['last_balance']}원, 만료: ${c['contract_credit_expiry_date']}, 유효: ${c['is_valid']}');
      }

    } catch (e) {
      print('=== 에러 발생 ===');
      print('에러 메시지: $e');
      print('에러 타입: ${e.runtimeType}');
      print('에러 스택: ${StackTrace.current}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('크레딧 정보를 불러오는데 실패했습니다: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      print('=== 크레딧 조회 디버깅 종료 ===');
      print('최종 _contracts 길이: ${_contracts.length}');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCreditHistory(String contractHistoryId) async {
    setState(() => _isLoading = true);
    
    try {
      String? memberId;
      if (widget.isAdminMode) {
        memberId = widget.selectedMember?['member_id']?.toString();
      } else {
        memberId = ApiService.getCurrentUser()?['member_id']?.toString();
      }
      
      final branchId = widget.branchId ?? ApiService.getCurrentBranchId();
      
      if (memberId == null || branchId == null) {
        throw Exception('회원 정보가 없습니다');
      }

      _creditHistory = await ApiService.getData(
        table: 'v2_bills',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
        ],
        orderBy: [{'field': 'bill_id', 'direction': 'DESC'}],
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('크레딧 내역을 불러오는데 실패했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0원';
    final formatter = NumberFormat('#,###');
    return '${formatter.format(int.tryParse(amount.toString()) ?? 0)}원';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFF8F9FA),
      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A86B)),
              ),
            )
          : _selectedContract == null
              ? _buildContractList()
              : _buildCreditHistory(),
    );
  }

  Widget _buildContractList() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '크레딧 계약 목록',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              Row(
                children: [
                  Text(
                    '만료 포함',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                  Switch(
                    value: _showExpired,
                    onChanged: (value) {
                      setState(() => _showExpired = value);
                      _loadContracts();
                    },
                    activeColor: Color(0xFF00A86B),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _contracts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 64,
                        color: Color(0xFF00A86B).withOpacity(0.3),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '크레딧 계약이 없습니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _contracts.length,
                  itemBuilder: (context, index) {
                    final contract = _contracts[index];
                    return _buildContractTile(contract);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildContractTile(Map<String, dynamic> contract) {
    final isValid = contract['is_valid'] ?? false;
    final expiryDate = _formatDate(contract['contract_credit_expiry_date']);
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => _selectedContract = contract);
            _loadCreditHistory(contract['contract_history_id']);
          },
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isValid ? Color(0xFF00A86B).withOpacity(0.2) : Color(0xFFE0E0E0),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        contract['bill_text'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isValid ? Color(0xFF333333) : Color(0xFF999999),
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isValid ? Color(0xFF00A86B) : Color(0xFF999999),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isValid ? '유효' : '만료',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '잔액',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666666),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _formatCurrency(contract['last_balance']),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isValid ? Color(0xFF00A86B) : Color(0xFF999999),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '만료일',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF666666),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          expiryDate,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isValid ? Color(0xFF333333) : Color(0xFF999999),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '총 ${contract['bill_count']}건',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreditHistory() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: Color(0xFF00A86B)),
                onPressed: () {
                  setState(() {
                    _selectedContract = null;
                    _creditHistory.clear();
                  });
                },
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedContract?['bill_text'] ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    Text(
                      '만료일: ${_formatDate(_selectedContract?['contract_credit_expiry_date'])}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _creditHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 64,
                        color: Color(0xFF00A86B).withOpacity(0.3),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '크레딧 내역이 없습니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _creditHistory.length,
                  itemBuilder: (context, index) {
                    final history = _creditHistory[index];
                    return _buildHistoryTile(history);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> history) {
    final billType = history['bill_type'] ?? '';
    final billText = history['bill_text'] ?? '';
    final netAmount = int.tryParse(history['bill_netamt']?.toString() ?? '0') ?? 0;
    final balanceAfter = history['bill_balance_after'];
    final billDate = _formatDate(history['bill_date']);
    
    final isCredit = netAmount > 0;
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        elevation: 1,
        child: Container(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCredit 
                      ? Color(0xFF00A86B).withOpacity(0.1)
                      : Color(0xFFFF6B6B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isCredit ? Icons.add : Icons.remove,
                  color: isCredit ? Color(0xFF00A86B) : Color(0xFFFF6B6B),
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$billType | $billText',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF333333),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      billDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isCredit ? '+' : ''}${_formatCurrency(netAmount)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isCredit ? Color(0xFF00A86B) : Color(0xFFFF6B6B),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '잔액: ${_formatCurrency(balanceAfter)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666666),
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
}