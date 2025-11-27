import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../services/program_reservation_classifier.dart';
import 'package:intl/intl.dart';

class LessonSearchPage extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const LessonSearchPage({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _LessonSearchPageState createState() => _LessonSearchPageState();
}

class _LessonSearchPageState extends State<LessonSearchPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('레슨권 조회'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: LessonSearchContent(
        isAdminMode: widget.isAdminMode,
        selectedMember: widget.selectedMember,
        branchId: widget.branchId,
      ),
    );
  }
}

class LessonSearchContent extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const LessonSearchContent({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _LessonSearchContentState createState() => _LessonSearchContentState();
}

class _LessonSearchContentState extends State<LessonSearchContent> {
  bool _isLoading = true;
  bool _showExpired = false;
  List<Map<String, dynamic>> _contracts = [];
  Map<String, dynamic>? _selectedContract;
  List<Map<String, dynamic>> _lessonHistory = [];

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

      print('=== 레슨권 조회 디버깅 시작 (v3_LS_countings 중심) ===');
      print('isAdminMode: ${widget.isAdminMode}');
      print('selectedMember: ${widget.selectedMember}');
      print('memberId: $memberId');
      print('branchId: $branchId');
      print('showExpired: $_showExpired');

      if (memberId == null || branchId == null) {
        print('ERROR: 필수 정보 누락 - memberId: $memberId, branchId: $branchId');
        throw Exception('회원 정보가 없습니다');
      }

      // 1. v3_LS_countings에서 회원의 모든 레슨 거래 내역 조회
      print('\n=== STEP 1: v3_LS_countings에서 모든 레슨 거래 조회 ===');
      print('쿼리 조건: branch_id=$branchId, member_id=$memberId');

      final allCountings = await ApiService.getData(
        table: 'v3_LS_countings',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
        orderBy: [{'field': 'LS_counting_id', 'direction': 'DESC'}],
      );

      print('v3_LS_countings에서 조회된 전체 거래 수: ${allCountings.length}');

      if (allCountings.isEmpty) {
        print('WARNING: 해당 회원의 레슨 거래 내역이 전혀 없습니다.');
        _contracts = [];
        return;
      }

      // 2. contract_history_id별로 그룹화하여 최신 거래 추출
      print('\n=== STEP 2: contract_history_id별 그룹화 및 최신 거래 추출 ===');
      final Map<String, Map<String, dynamic>> contractMap = {};

      for (final counting in allCountings) {
        final contractHistoryId = counting['contract_history_id']?.toString();
        if (contractHistoryId == null || contractHistoryId.isEmpty) {
          continue;
        }

        // 각 contract_history_id의 최신 거래만 저장 (이미 DESC 정렬되어 있으므로 첫 번째가 최신)
        if (!contractMap.containsKey(contractHistoryId)) {
          contractMap[contractHistoryId] = counting;
        }
      }

      print('그룹화된 contract_history_id 수: ${contractMap.length}');

      // 3. 각 계약의 유효성 판단 및 필터링
      print('\n=== STEP 3: 유효성 판단 및 필터링 ===');
      final contractList = <Map<String, dynamic>>[];

      for (final entry in contractMap.entries) {
        final contractHistoryId = entry.key;
        final latestCounting = entry.value;

        print('\n--- contract_history_id: $contractHistoryId 처리 ---');

        final balance = int.tryParse(latestCounting['LS_balance_min_after']?.toString() ?? '0') ?? 0;
        final expiryDateStr = latestCounting['LS_expiry_date']?.toString() ?? '';
        final proName = latestCounting['pro_name']?.toString() ?? '';

        print('최신 거래 정보:');
        print('  - LS_counting_id: ${latestCounting['LS_counting_id']}');
        print('  - LS_balance_min_after: $balance분');
        print('  - LS_expiry_date: $expiryDateStr');
        print('  - pro_name: $proName');

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
        final countingCount = allCountings.where((c) =>
          c['contract_history_id']?.toString() == contractHistoryId
        ).length;

        print('전체 거래 건수: $countingCount건');

        contractList.add({
          'contract_history_id': contractHistoryId,
          'contract_name': '', // 나중에 v3_contract_history에서 조회
          'contract_LS_min_expiry_date': expiryDateStr,
          'last_balance': balance.toString(),
          'counting_count': countingCount,
          'is_valid': isValid,
          'pro_name': proName,
        });

        print('✅ 계약 추가: contract_history_id=$contractHistoryId, 잔액: ${balance}분, 거래: $countingCount건');
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
              contract['contract_name'] = contractName;
              contract['contract_id'] = contractId;
              print('  → contract_name: $contractName, contract_id: $contractId');
            } else {
              contract['contract_name'] = '(알 수 없음)';
              print('  → 계약 정보 없음');
            }
          } catch (e) {
            print('  → 조회 실패: $e');
            contract['contract_name'] = '(알 수 없음)';
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
          final dateA = DateTime.parse(b['contract_LS_min_expiry_date']);
          final dateB = DateTime.parse(a['contract_LS_min_expiry_date']);
          return dateA.compareTo(dateB);
        } catch (e) {
          print('정렬 중 날짜 파싱 에러: $e');
          return 0;
        }
      });

      print('최종 표시될 계약 목록:');
      for (int i = 0; i < _contracts.length; i++) {
        final c = _contracts[i];
        print('  $i: contract_history_id=${c['contract_history_id']}, ${c['contract_name']}, 잔액: ${c['last_balance']}분, 만료: ${c['contract_LS_min_expiry_date']}, 유효: ${c['is_valid']}, 강사: ${c['pro_name']}');
      }

    } catch (e) {
      print('=== 에러 발생 ===');
      print('에러 메시지: $e');
      print('에러 타입: ${e.runtimeType}');
      print('에러 스택: ${StackTrace.current}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('레슨권 정보를 불러오는데 실패했습니다: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      print('=== 레슨권 조회 디버깅 종료 ===');
      print('최종 _contracts 길이: ${_contracts.length}');
      print('_isLoading을 false로 설정');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLessonHistory(String contractHistoryId) async {
    setState(() => _isLoading = true);
    
    try {
      print('=== 레슨 내역 조회 시작 ===');
      print('contract_history_id: $contractHistoryId');
      
      String? memberId;
      if (widget.isAdminMode) {
        memberId = widget.selectedMember?['member_id']?.toString();
      } else {
        memberId = ApiService.getCurrentUser()?['member_id']?.toString();
      }
      
      final branchId = widget.branchId ?? ApiService.getCurrentBranchId();
      
      print('memberId: $memberId');
      print('branchId: $branchId');
      
      if (memberId == null || branchId == null) {
        print('ERROR: 필수 정보 누락');
        throw Exception('회원 정보가 없습니다');
      }

      print('\nv3_LS_countings 테이블에서 레슨 내역 조회 중...');
      print('쿼리 조건: branch_id=$branchId, member_id=$memberId, contract_history_id=$contractHistoryId');
      
      final allHistory = await ApiService.getData(
        table: 'v3_LS_countings',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
        ],
        orderBy: [{'field': 'LS_counting_id', 'direction': 'DESC'}],
      );
      
      // 예약취소 제외 필터링
      _lessonHistory = allHistory.where((history) {
        final status = history['LS_status']?.toString() ?? '';
        return status != '예약취소';
      }).toList();
      
      print('전체 조회된 내역 수: ${allHistory.length}건');
      print('예약취소 제외 후 내역 수: ${_lessonHistory.length}건');
      
      if (_lessonHistory.isNotEmpty) {
        print('\n처음 3개 내역:');
        for (int i = 0; i < _lessonHistory.length && i < 3; i++) {
          final history = _lessonHistory[i];
          print('내역 $i:');
          print('  - LS_counting_id: ${history['LS_counting_id']}');
          print('  - LS_transaction_type: ${history['LS_transaction_type']}');
          print('  - LS_date: ${history['LS_date']}');
          print('  - LS_status: ${history['LS_status']}');
          print('  - LS_net_min: ${history['LS_net_min']}');
          print('  - LS_balance_min_after: ${history['LS_balance_min_after']}');
          print('  - pro_name: ${history['pro_name']}');
        }
      } else {
        print('레슨 내역이 없습니다.');
      }
      
    } catch (e) {
      print('=== 레슨 내역 조회 에러 ===');
      print('에러 메시지: $e');
      print('에러 타입: ${e.runtimeType}');
      print('스택 트레이스: ${StackTrace.current}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('레슨 내역을 불러오는데 실패했습니다: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      print('=== 레슨 내역 조회 종료 ===');
      print('최종 _lessonHistory 길이: ${_lessonHistory.length}');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatMinutes(dynamic minutes) {
    if (minutes == null) return '0분';
    final mins = int.tryParse(minutes.toString()) ?? 0;
    return '${mins}분';
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
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            )
          : _selectedContract == null
              ? _buildContractList()
              : _buildLessonHistory(),
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
                '레슨권 계약 목록',
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
                    activeColor: Colors.orange,
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
                        Icons.school_outlined,
                        size: 64,
                        color: Colors.orange.withOpacity(0.3),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '레슨권 계약이 없습니다',
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
    final expiryDate = _formatDate(contract['contract_LS_min_expiry_date']);

    print('=== UI 렌더링: contract_history_id=${contract['contract_history_id']}, 계약명=${contract['contract_name']}, 잔액=${contract['last_balance']}분, 만료일=$expiryDate, 유효=$isValid ===');

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
            _loadLessonHistory(contract['contract_history_id']);
          },
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isValid ? Colors.orange.withOpacity(0.2) : Color(0xFFE0E0E0),
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
                        contract['contract_name'] ?? '',
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
                        color: isValid ? Colors.orange : Color(0xFF999999),
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
                            '잔여분',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666666),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _formatMinutes(contract['last_balance']),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isValid ? Colors.orange : Color(0xFF999999),
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
                        SizedBox(height: 2),
                        Text(
                          'ID: ${contract['contract_history_id']}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFFCCCCCC),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '총 ${contract['counting_count']}건',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF999999),
                      ),
                    ),
                    if (contract['pro_name'] != null && contract['pro_name'].toString().isNotEmpty)
                      Text(
                        '강사: ${contract['pro_name']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLessonHistory() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.orange),
                onPressed: () {
                  setState(() {
                    _selectedContract = null;
                    _lessonHistory.clear();
                  });
                },
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedContract?['contract_name'] ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    Text(
                      '만료일: ${_formatDate(_selectedContract?['contract_LS_min_expiry_date'])}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                      ),
                    ),
                    if (_selectedContract != null && 
                        _selectedContract!['pro_name'] != null && 
                        _selectedContract!['pro_name'].toString().isNotEmpty)
                      Text(
                        '담당 강사: ${_selectedContract!['pro_name']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _lessonHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 64,
                        color: Colors.orange.withOpacity(0.3),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '레슨 내역이 없습니다',
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
                  itemCount: _lessonHistory.length,
                  itemBuilder: (context, index) {
                    final history = _lessonHistory[index];
                    return _buildHistoryTile(history);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> history) {
    final transactionType = history['LS_transaction_type'] ?? '';
    final balanceBefore = int.tryParse(history['LS_balance_min_before']?.toString() ?? '0') ?? 0;
    final balanceAfter = int.tryParse(history['LS_balance_min_after']?.toString() ?? '0') ?? 0;
    final actualChange = balanceAfter - balanceBefore;
    final lessonDate = _formatDate(history['LS_date']);
    final lessonStatus = history['LS_status'] ?? '';
    final proName = history['pro_name'] ?? '';
    
    final isCredit = actualChange > 0;
    
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
                      ? Colors.orange.withOpacity(0.1)
                      : Color(0xFFFF6B6B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isCredit ? Icons.add : Icons.remove,
                  color: isCredit ? Colors.orange : Color(0xFFFF6B6B),
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$transactionType | $lessonStatus',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF333333),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      lessonDate,
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
                    '${isCredit ? '+' : '-'}${_formatMinutes(actualChange.abs())}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isCredit ? Colors.orange : Color(0xFFFF6B6B),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '잔여: ${_formatMinutes(balanceAfter)}',
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