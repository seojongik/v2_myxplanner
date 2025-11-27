import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../services/program_reservation_classifier.dart';
import 'package:intl/intl.dart';

class GameSearchPage extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const GameSearchPage({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _GameSearchPageState createState() => _GameSearchPageState();
}

class _GameSearchPageState extends State<GameSearchPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('게임권 조회'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: GameSearchContent(
        isAdminMode: widget.isAdminMode,
        selectedMember: widget.selectedMember,
        branchId: widget.branchId,
      ),
    );
  }
}

class GameSearchContent extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const GameSearchContent({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _GameSearchContentState createState() => _GameSearchContentState();
}

class _GameSearchContentState extends State<GameSearchContent> {
  bool _isLoading = true;
  bool _showExpired = false;
  List<Map<String, dynamic>> _contracts = [];
  Map<String, dynamic>? _selectedContract;
  List<Map<String, dynamic>> _gameHistory = [];

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

      print('=== 게임권 조회 디버깅 시작 (v2_bill_games 중심) ===');
      print('memberId: $memberId');
      print('branchId: $branchId');
      print('showExpired: $_showExpired');

      if (memberId == null || branchId == null) {
        throw Exception('회원 정보가 없습니다');
      }

      // 1. v2_bill_games에서 회원의 모든 게임권 거래 내역 조회
      print('\n=== STEP 1: v2_bill_games에서 모든 게임권 거래 조회 ===');
      print('쿼리 조건: branch_id=$branchId, member_id=$memberId');

      final allBills = await ApiService.getData(
        table: 'v2_bill_games',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
        orderBy: [{'field': 'bill_game_id', 'direction': 'DESC'}],
      );

      print('v2_bill_games에서 조회된 전체 거래 수: ${allBills.length}');

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

        final balance = int.tryParse(latestBill['bill_balance_game_after']?.toString() ?? '0') ?? 0;
        final expiryDateStr = latestBill['contract_games_expiry_date']?.toString() ?? '';
        final billText = latestBill['bill_text']?.toString() ?? '';

        print('최신 거래 정보:');
        print('  - bill_game_id: ${latestBill['bill_game_id']}');
        print('  - bill_balance_game_after: ${balance}게임');
        print('  - contract_games_expiry_date: $expiryDateStr');
        print('  - bill_text: $billText');

        // 유효성 판단: 잔액 > 0 AND 만료일이 미래 (레슨권과 동일한 기준)
        bool isValid;
        if (expiryDateStr.isEmpty) {
          print('  - 만료일 없음 -> 만료');
          isValid = false; // 만료일이 없으면 만료로 간주
        } else {
          try {
            final expiryDate = DateTime.parse(expiryDateStr);
            final now = DateTime.now();
            final hasBalance = balance > 0;
            final notExpired = expiryDate.isAfter(now);
            isValid = hasBalance && notExpired;
            print('유효성 판단:');
            print('  - 잔액 > 0: $hasBalance');
            print('  - 만료일 미래: $notExpired (만료일: $expiryDateStr, 현재: $now)');
            print('  - 최종 유효 여부: $isValid');
          } catch (e) {
            print('  - 날짜 파싱 오류 -> 만료');
            isValid = false; // 파싱 오류시 만료로 간주
          }
        }

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
          'contract_games_expiry_date': expiryDateStr,
          'last_balance': balance.toString(),
          'bill_count': billCount,
          'is_valid': isValid,
        });

        print('✅ 계약 추가: contract_history_id=$contractHistoryId, 잔액: ${balance}게임, 거래: $billCount건');
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
          final dateA = DateTime.parse(b['contract_games_expiry_date']);
          final dateB = DateTime.parse(a['contract_games_expiry_date']);
          return dateA.compareTo(dateB);
        } catch (e) {
          print('정렬 중 날짜 파싱 에러: $e');
          return 0;
        }
      });

      print('최종 표시될 계약 목록:');
      for (int i = 0; i < _contracts.length; i++) {
        final c = _contracts[i];
        print('  $i: contract_history_id=${c['contract_history_id']}, ${c['bill_text']}, 잔액: ${c['last_balance']}게임, 만료: ${c['contract_games_expiry_date']}, 유효: ${c['is_valid']}');
      }

    } catch (e) {
      print('=== 에러 발생 ===');
      print('에러 메시지: $e');
      print('에러 타입: ${e.runtimeType}');
      print('에러 스택: ${StackTrace.current}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('게임권 정보를 불러오는데 실패했습니다: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      print('=== 게임권 조회 디버깅 종료 ===');
      print('최종 _contracts 길이: ${_contracts.length}');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGameHistory(String contractHistoryId) async {
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

      _gameHistory = await ApiService.getData(
        table: 'v2_bill_games',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
        ],
        orderBy: [{'field': 'bill_game_id', 'direction': 'DESC'}],
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('게임권 내역을 불러오는데 실패했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatGames(dynamic games) {
    if (games == null) return '0게임';
    final formatter = NumberFormat('#,###');
    return '${formatter.format(int.tryParse(games.toString()) ?? 0)}게임';
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

  bool _hasBalanceError(Map<String, dynamic> history) {
    final billGames = int.tryParse(history['bill_games']?.toString() ?? '0') ?? 0;
    final balanceBefore = int.tryParse(history['bill_balance_game_before']?.toString() ?? '0') ?? 0;
    final balanceAfter = int.tryParse(history['bill_balance_game_after']?.toString() ?? '0') ?? 0;
    final calculatedChange = balanceAfter - balanceBefore;

    // 잔액변화량의 절대값과 bill_games이 같아야 정상
    return calculatedChange.abs() != billGames;
  }

  int _getActualChange(Map<String, dynamic> history) {
    final balanceBefore = int.tryParse(history['bill_balance_game_before']?.toString() ?? '0') ?? 0;
    final balanceAfter = int.tryParse(history['bill_balance_game_after']?.toString() ?? '0') ?? 0;
    return balanceAfter - balanceBefore;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFF8F9FA),
      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
              ),
            )
          : _selectedContract == null
              ? _buildContractList()
              : _buildGameHistory(),
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
                '게임권 계약 목록',
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
                    activeColor: Colors.purple,
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
                        Icons.sports_esports,
                        size: 64,
                        color: Colors.purple.withOpacity(0.3),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '게임권 계약이 없습니다',
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
    final expiryDate = _formatDate(contract['contract_games_expiry_date']);

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
            _loadGameHistory(contract['contract_history_id']);
          },
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isValid ? Colors.purple.withOpacity(0.2) : Color(0xFFE0E0E0),
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
                        color: isValid ? Colors.purple : Color(0xFF999999),
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
                            '잔여게임',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666666),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _formatGames(contract['last_balance']),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isValid ? Colors.purple : Color(0xFF999999),
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

  Widget _buildGameHistory() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.purple),
                onPressed: () {
                  setState(() {
                    _selectedContract = null;
                    _gameHistory.clear();
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
                      '만료일: ${_formatDate(_selectedContract?['contract_games_expiry_date'])}',
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
          child: _gameHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 64,
                        color: Colors.purple.withOpacity(0.3),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '게임권 내역이 없습니다',
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
                  itemCount: _gameHistory.length,
                  itemBuilder: (context, index) {
                    final history = _gameHistory[index];
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
    final actualChange = _getActualChange(history);
    final balanceAfter = history['bill_balance_game_after'];
    final billDate = _formatDate(history['bill_date']);
    final hasError = _hasBalanceError(history);

    final isCredit = actualChange > 0;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        elevation: 1,
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: hasError ? BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
          ) : null,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: hasError
                      ? Colors.red.withOpacity(0.1)
                      : isCredit
                          ? Colors.purple.withOpacity(0.1)
                          : Color(0xFFFF6B6B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  hasError
                      ? Icons.error
                      : isCredit
                          ? Icons.add
                          : Icons.remove,
                  color: hasError
                      ? Colors.red
                      : isCredit
                          ? Colors.purple
                          : Color(0xFFFF6B6B),
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
                    Row(
                      children: [
                        Text(
                          billDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF999999),
                          ),
                        ),
                        if (hasError) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '잔액오류',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isCredit ? '+' : ''}${_formatGames(actualChange)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: hasError
                          ? Colors.red
                          : isCredit
                              ? Colors.purple
                              : Color(0xFFFF6B6B),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '잔여: ${_formatGames(balanceAfter)}',
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