import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../services/program_reservation_classifier.dart';
import 'package:intl/intl.dart';

class ProgramSearchPage extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const ProgramSearchPage({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _ProgramSearchPageState createState() => _ProgramSearchPageState();
}

class _ProgramSearchPageState extends State<ProgramSearchPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('프로그램 조회'),
        backgroundColor: Color(0xFFFF5722),
        foregroundColor: Colors.white,
      ),
      body: ProgramSearchContent(
        isAdminMode: widget.isAdminMode,
        selectedMember: widget.selectedMember,
        branchId: widget.branchId,
      ),
    );
  }
}

class ProgramSearchContent extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const ProgramSearchContent({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _ProgramSearchContentState createState() => _ProgramSearchContentState();
}

class _ProgramSearchContentState extends State<ProgramSearchContent> {
  bool _isLoading = true;
  bool _showExpired = false;
  List<Map<String, dynamic>> _contracts = [];
  Map<String, dynamic>? _selectedContract;
  List<Map<String, dynamic>> _programHistory = [];
  Map<String, List<Map<String, dynamic>>> _groupedHistory = {};

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
      
      print('=== 프로그램 조회 디버깅 시작 ===');
      print('memberId: $memberId');
      print('branchId: $branchId');
      print('showExpired: $_showExpired');
      
      if (memberId == null || branchId == null) {
        throw Exception('회원 정보가 없습니다');
      }

      // 1. v3_contract_history에서 모든 계약 조회
      print('\n=== STEP 1: v3_contract_history에서 모든 계약 조회 ===');
      final allContracts = await ApiService.getData(
        table: 'v3_contract_history',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
        orderBy: [{'field': 'contract_history_id', 'direction': 'DESC'}],
      );
      
      print('전체 계약 수: ${allContracts.length}');

      // 2. 프로그램 전용 계약만 필터링
      print('\n=== STEP 2: 프로그램 전용 계약 필터링 ===');
      final programContracts = await ProgramReservationClassifier.filterContracts(
        contracts: allContracts,
        branchId: branchId,
        includeProgram: true,   // 프로그램 전용 상품만 포함
        includeGeneral: false,  // 일반 상품 제외
      );

      print('프로그램 전용 계약 수: ${programContracts.length}');

      if (programContracts.isNotEmpty) {
        final contractList = <Map<String, dynamic>>[];
        
        for (final contract in programContracts) {
          final contractHistoryId = contract['contract_history_id']?.toString();
          if (contractHistoryId == null) continue;

          print('\n--- 계약 처리: ${contract['contract_name']} (ID: $contractHistoryId) ---');

          // 시간권 잔액 조회 (v2_bill_times)
          String timeBalance = '0';
          String timeExpiryDate = '';
          try {
            final timeBills = await ApiService.getData(
              table: 'v2_bill_times',
              where: [
                {'field': 'branch_id', 'operator': '=', 'value': branchId},
                {'field': 'member_id', 'operator': '=', 'value': memberId},
                {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
                {'field': 'bill_status', 'operator': '=', 'value': '결제완료'},
              ],
              orderBy: [{'field': 'bill_min_id', 'direction': 'DESC'}],
              limit: 1,
            );
            
            if (timeBills.isNotEmpty) {
              timeBalance = timeBills[0]['bill_balance_min_after']?.toString() ?? '0';
              timeExpiryDate = timeBills[0]['contract_TS_min_expiry_date'] ?? '';
              print('시간권 잔액: ${timeBalance}분, 만료일: $timeExpiryDate');
            }
          } catch (e) {
            print('시간권 잔액 조회 실패: $e');
          }

          // 레슨권 잔액 조회 (v3_LS_countings)
          String lessonBalance = '0';
          String lessonExpiryDate = '';
          try {
            final lessonCountings = await ApiService.getData(
              table: 'v3_LS_countings',
              where: [
                {'field': 'branch_id', 'operator': '=', 'value': branchId},
                {'field': 'member_id', 'operator': '=', 'value': memberId},
                {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
              ],
              orderBy: [{'field': 'LS_counting_id', 'direction': 'DESC'}],
              limit: 1,
            );
            
            if (lessonCountings.isNotEmpty) {
              lessonBalance = lessonCountings[0]['LS_balance_min_after']?.toString() ?? '0';
              lessonExpiryDate = lessonCountings[0]['LS_expiry_date'] ?? '';
              print('레슨권 잔액: ${lessonBalance}분, 만료일: $lessonExpiryDate');
            }
          } catch (e) {
            print('레슨권 잔액 조회 실패: $e');
          }

          // 만료일 확인 (둘 중 더 늦은 만료일 사용)
          DateTime? timeExpiry = DateTime.tryParse(timeExpiryDate);
          DateTime? lessonExpiry = DateTime.tryParse(lessonExpiryDate);
          
          DateTime? latestExpiry;
          String latestExpiryStr = '';
          
          if (timeExpiry != null && lessonExpiry != null) {
            latestExpiry = timeExpiry.isAfter(lessonExpiry) ? timeExpiry : lessonExpiry;
            latestExpiryStr = timeExpiry.isAfter(lessonExpiry) ? timeExpiryDate : lessonExpiryDate;
          } else if (timeExpiry != null) {
            latestExpiry = timeExpiry;
            latestExpiryStr = timeExpiryDate;
          } else if (lessonExpiry != null) {
            latestExpiry = lessonExpiry;
            latestExpiryStr = lessonExpiryDate;
          }

          final now = DateTime.now();
          final isValid = latestExpiry?.isAfter(now) ?? false;
          
          if (!_showExpired && !isValid) {
            print('만료된 계약이고 showExpired=false이므로 건너뜀');
            continue;
          }

          contractList.add({
            'contract_history_id': contractHistoryId,
            'contract_name': contract['contract_name'] ?? '',
            'time_balance': timeBalance,
            'lesson_balance': lessonBalance,
            'expiry_date': latestExpiryStr,
            'is_valid': isValid,
          });

          print('✅ 프로그램 계약 추가: ${contract['contract_name']}, 시간권: ${timeBalance}분, 레슨권: ${lessonBalance}분');
        }
        
        _contracts = contractList;
        _contracts.sort((a, b) {
          try {
            return DateTime.parse(b['expiry_date'])
                .compareTo(DateTime.parse(a['expiry_date']));
          } catch (e) {
            return 0;
          }
        });

        print('최종 프로그램 계약 수: ${_contracts.length}');
      } else {
        print('프로그램 전용 계약이 없습니다.');
        _contracts = [];
      }
    } catch (e) {
      print('에러 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('프로그램 정보를 불러오는데 실패했습니다: $e')),
        );
      }
    } finally {
      print('=== 프로그램 조회 디버깅 종료 ===');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProgramHistory(String contractHistoryId) async {
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

      print('=== 프로그램 내역 조회 시작 ===');
      print('선택된 contract_history_id: $contractHistoryId');
      print('회원의 모든 프로그램 관련 내역을 조회합니다.');

      // 시간권과 레슨권 내역을 모두 가져와서 합치기
      final List<Map<String, dynamic>> allHistory = [];
      final Map<String, Map<String, dynamic>> contractRegistrations = {};

      // 시간권 내역 조회 - 선택된 계약만 조회
      print('시간권 내역 조회 중...');
      final timeHistory = await ApiService.getData(
        table: 'v2_bill_times',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          {'field': 'bill_status', 'operator': '=', 'value': '결제완료'},
        ],
        orderBy: [{'field': 'bill_min_id', 'direction': 'DESC'}],
      );

      print('시간권 내역 수: ${timeHistory.length}');
      for (final history in timeHistory) {
        final reservationId = history['reservation_id']?.toString() ?? '';
        final billType = history['bill_type']?.toString() ?? '';
        final billDate = history['bill_date']?.toString() ?? '';
        final billText = history['bill_text']?.toString() ?? '';

        if (billType == '회원권등록') {
          // 회원권 등록은 별도로 저장 (날짜를 키로 사용)
          final dateKey = billDate.substring(0, 10); // YYYY-MM-DD 형식
          if (!contractRegistrations.containsKey(dateKey)) {
            contractRegistrations[dateKey] = {
              'date': billDate,
              'time_data': null,
              'lesson_data': null,
              'bill_text': billText,
            };
          }
          contractRegistrations[dateKey]!['time_data'] = history;
          contractRegistrations[dateKey]!['bill_text'] = billText;
        } else if (reservationId.isNotEmpty) {
          // reservation_id에서 program_id 추출: "251119_1_1330_1/1" -> "251119_1_1330"
          String programId = reservationId;
          final lastUnderscoreIndex = reservationId.lastIndexOf('_');
          if (lastUnderscoreIndex > 0 && reservationId.contains('/')) {
            programId = reservationId.substring(0, lastUnderscoreIndex);
            print('  시간권: reservation_id "$reservationId" -> program_id "$programId"');
          }

          // 프로그램 예약 - program_id 추출, 표시용 bill_text 저장
          allHistory.add({
            ...history,
            'program_id': programId,      // 그룹화용 ID (추출된 program_id)
            'display_name': billText,     // UI 표시용 텍스트
            'type': 'time',
            'amount': history['bill_min'],
            'balance_after': history['bill_balance_min_after'],
            'date': history['bill_date'],
            'text': billText,
            'status': history['bill_status'],
          });
        }
      }

      // 레슨권 내역 조회 - 선택된 계약만 조회
      print('레슨권 내역 조회 중...');
      final lessonHistory = await ApiService.getData(
        table: 'v3_LS_countings',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
        ],
        orderBy: [{'field': 'LS_counting_id', 'direction': 'DESC'}],
      );

      print('레슨권 내역 수: ${lessonHistory.length}');
      for (final history in lessonHistory) {
        final lsStatus = history['LS_status']?.toString() ?? '';
        final programId = history['program_id']?.toString() ?? '';
        final transactionType = history['LS_transaction_type']?.toString() ?? '';
        final lessonDate = history['LS_date']?.toString() ?? '';
        final lsCountingId = history['LS_counting_id']?.toString() ?? '';
        
        print('레슨 내역 처리: ID=$lsCountingId, Type=$transactionType, ProgramID=$programId, Status=$lsStatus');
        
        if (lsStatus == '예약취소') {
          print('  -> 예약취소 건너뜀');
          continue;
        }
        
        if (transactionType == '레슨권 구매') {
          // 레슨권 구매는 회원권 등록과 같은 날짜로 묶기
          final dateKey = lessonDate.substring(0, 10);
          if (!contractRegistrations.containsKey(dateKey)) {
            contractRegistrations[dateKey] = {
              'date': lessonDate,
              'time_data': null,
              'lesson_data': null,
              'bill_text': '',
            };
          }
          contractRegistrations[dateKey]!['lesson_data'] = history;
          print('  -> 계약등록으로 분류');
        } else if (programId.isNotEmpty) {
          // 프로그램에서 레슨 사용 - program_id는 그대로, 표시명은 시간권에서 가져오기
          String displayName = '';
          for (final h in allHistory) {
            if (h['program_id'] == programId && h['type'] == 'time') {
              displayName = h['display_name'] ?? '';
              break;
            }
          }
          
          allHistory.add({
            ...history,
            'program_id': programId,  // 그룹화용 ID (변경 없음)
            'display_name': displayName,  // UI 표시용 텍스트
            'type': 'lesson',
            'amount': history['LS_net_min'],
            'balance_after': history['LS_balance_min_after'],
            'date': history['LS_date'],
            'text': '${history['LS_transaction_type']} | ${history['pro_name']}',
            'status': history['LS_status'],
          });
          print('  -> 프로그램 $programId로 분류 (표시명: $displayName)');
        } else {
          // 일반 레슨 예약
          allHistory.add({
            ...history,
            'program_id': '일반레슨',
            'type': 'lesson',
            'amount': history['LS_net_min'],
            'balance_after': history['LS_balance_min_after'],
            'date': history['LS_date'],
            'text': '${history['LS_transaction_type']} | ${history['pro_name']}',
            'status': history['LS_status'],
          });
          print('  -> 일반레슨으로 분류');
        }
      }

      // 계약 등록 내역을 allHistory에 추가
      for (final registration in contractRegistrations.values) {
        final timeData = registration['time_data'];
        final lessonData = registration['lesson_data'];
        final date = registration['date'];
        final billText = registration['bill_text'] ?? '';
        
        // 계약 등록은 하나의 그룹으로 묶어서 추가 - bill_text를 그룹명으로 사용
        final groupId = billText.isNotEmpty ? billText : '계약등록';
        
        if (timeData != null) {
          allHistory.add({
            ...timeData,
            'program_id': groupId,
            'type': 'time',
            'amount': timeData['bill_min'],
            'balance_after': timeData['bill_balance_min_after'],
            'date': date,
            'text': '시간권: ${timeData['bill_min']}분',
            'status': timeData['bill_status'],
            'is_registration': true,
          });
        }
        
        if (lessonData != null) {
          allHistory.add({
            ...lessonData,
            'program_id': groupId,
            'type': 'lesson',
            'amount': lessonData['LS_net_min'],
            'balance_after': lessonData['LS_balance_min_after'],
            'date': date,
            'text': '레슨권: ${lessonData['LS_net_min']}분',
            'status': lessonData['LS_status'],
            'is_registration': true,
          });
        }
      }

      print('전체 프로그램 내역 수: ${allHistory.length}');

      // program_id별로 그룹화
      _groupedHistory.clear();
      for (final history in allHistory) {
        final programId = history['program_id']?.toString() ?? '';
        if (programId.isNotEmpty) {
          if (!_groupedHistory.containsKey(programId)) {
            _groupedHistory[programId] = [];
          }
          _groupedHistory[programId]!.add(history);
        }
      }

      // 각 그룹 내에서 날짜 및 ID 순으로 정렬
      _groupedHistory.forEach((key, value) {
        value.sort((a, b) {
          // 1. 날짜 비교 (최근 날짜가 먼저)
          final dateCompare = b['date'].compareTo(a['date']);
          if (dateCompare != 0) return dateCompare;

          // 2. 같은 날짜면 ID로 비교 (큰 ID가 먼저 = 더 최근 거래)
          final aId = int.tryParse(
            a['LS_counting_id']?.toString() ??
            a['bill_min_id']?.toString() ??
            '0'
          ) ?? 0;
          final bId = int.tryParse(
            b['LS_counting_id']?.toString() ??
            b['bill_min_id']?.toString() ??
            '0'
          ) ?? 0;
          return bId.compareTo(aId);
        });
      });

      _programHistory = allHistory;
      
      print('program_id별 그룹 수: ${_groupedHistory.length}');
      _groupedHistory.forEach((programId, histories) {
        print('$programId: ${histories.length}건');
      });
      
    } catch (e) {
      print('프로그램 내역 조회 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('프로그램 내역을 불러오는데 실패했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(dynamic minutes) {
    if (minutes == null) return '0분';
    final formatter = NumberFormat('#,###');
    return '${formatter.format(int.tryParse(minutes.toString()) ?? 0)}분';
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

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MM-dd HH:mm').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFF8F9FA),
      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5722)),
              ),
            )
          : _selectedContract == null
              ? _buildContractList()
              : _buildProgramHistory(),
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
                '프로그램 계약 목록',
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
                    activeColor: Color(0xFFFF5722),
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
                        color: Color(0xFFFF5722).withOpacity(0.3),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '프로그램 계약이 없습니다',
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
    final expiryDate = _formatDate(contract['expiry_date']);
    
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
            _loadProgramHistory(contract['contract_history_id']);
          },
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isValid ? Color(0xFFFF5722).withOpacity(0.2) : Color(0xFFE0E0E0),
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
                        color: isValid ? Color(0xFFFF5722) : Color(0xFF999999),
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
                            '시간권 잔액',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666666),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _formatTime(contract['time_balance']),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isValid ? Color(0xFF9C27B0) : Color(0xFF999999),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '레슨권 잔액',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666666),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _formatTime(contract['lesson_balance']),
                            style: TextStyle(
                              fontSize: 16,
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
                      ],
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

  Widget _buildProgramHistory() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: Color(0xFFFF5722)),
                onPressed: () {
                  setState(() {
                    _selectedContract = null;
                    _programHistory.clear();
                    _groupedHistory.clear();
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
                      '프로그램별 예약내역 (${_groupedHistory.length}개 프로그램)',
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
          child: _groupedHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 64,
                        color: Color(0xFFFF5722).withOpacity(0.3),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '프로그램 예약내역이 없습니다',
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
                  itemCount: _groupedHistory.keys.length,
                  itemBuilder: (context, index) {
                    final programId = _groupedHistory.keys.elementAt(index);
                    final histories = _groupedHistory[programId]!;
                    return _buildProgramGroupTile(programId, histories);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProgramGroupTile(String programId, List<Map<String, dynamic>> histories) {
    // 계약 등록 여부 확인
    final isRegistration = histories.any((h) => h['is_registration'] == true);
    
    final totalTimeUsed = histories
        .where((h) => h['type'] == 'time')
        .map((h) => int.tryParse(h['amount']?.toString() ?? '0') ?? 0)
        .fold(0, (a, b) => a + b);
    
    final totalLessonUsed = histories
        .where((h) => h['type'] == 'lesson')
        .map((h) => int.tryParse(h['amount']?.toString() ?? '0') ?? 0)
        .fold(0, (a, b) => a + b);

    // 최종 잔액 찾기 (가장 최근 거래의 balance_after)
    int? finalTimeBalance;
    int? finalLessonBalance;
    
    // 시간권 최종 잔액
    final timeHistories = histories.where((h) => h['type'] == 'time').toList();
    if (timeHistories.isNotEmpty) {
      finalTimeBalance = int.tryParse(timeHistories.first['balance_after']?.toString() ?? '0');
    }
    
    // 레슨권 최종 잔액
    final lessonHistories = histories.where((h) => h['type'] == 'lesson').toList();
    if (lessonHistories.isNotEmpty) {
      finalLessonBalance = int.tryParse(lessonHistories.first['balance_after']?.toString() ?? '0');
    }

    // 가장 최근 날짜 찾기
    final latestDate = histories.first['date'] ?? '';
    
    // display_name 찾기 (프로그램의 경우)
    String displayName = programId;  // 기본값
    if (histories.isNotEmpty && histories.first['display_name'] != null) {
      displayName = histories.first['display_name'] ?? programId;
    }
    
    // 프로그램 타입에 따른 아이콘과 색상 결정
    IconData icon;
    Color color;
    
    if (programId == '일반레슨') {
      icon = Icons.school;
      color = Colors.orange;
      displayName = '일반 레슨';
    } else if (isRegistration) {
      // 계약 등록인 경우
      icon = Icons.card_membership;
      color = Color(0xFF00A86B);
      // displayName은 이미 bill_text(programId)로 설정됨
    } else {
      icon = Icons.sports_golf;
      color = Color(0xFFFF5722);
      // displayName은 이미 display_name으로 설정됨
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        child: ExpansionTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              SizedBox(height: 4),
              Text(
                _formatDate(latestDate),
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4),
              Row(
                children: [
                  if (totalTimeUsed > 0)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      margin: EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Color(0xFF9C27B0).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isRegistration ? '적립 ${_formatTime(totalTimeUsed)}' : '사용 ${_formatTime(totalTimeUsed)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9C27B0),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (totalLessonUsed > 0)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isRegistration ? '적립 ${_formatTime(totalLessonUsed)}' : '사용 ${_formatTime(totalLessonUsed)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 6),
              Row(
                children: [
                  if (finalTimeBalance != null)
                    Expanded(
                      child: Text(
                        '시간권 잔액: ${_formatTime(finalTimeBalance)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF9C27B0),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (finalLessonBalance != null)
                    Expanded(
                      child: Text(
                        '레슨권 잔액: ${_formatTime(finalLessonBalance)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          children: histories.map((history) => _buildHistoryTile(history)).toList(),
        ),
      ),
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> history) {
    final type = history['type'] ?? '';
    final amount = int.tryParse(history['amount']?.toString() ?? '0') ?? 0;
    final balanceAfter = history['balance_after'];
    final text = history['text'] ?? '';
    final isRegistration = history['is_registration'] == true;
    
    final isTime = type == 'time';
    final isPositive = isRegistration;  // 계약등록(적립)만 플러스, 나머지는 마이너스
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isTime 
                      ? Color(0xFF9C27B0).withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  isTime ? Icons.access_time : Icons.school,
                  color: isTime ? Color(0xFF9C27B0) : Colors.orange,
                  size: 18,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isPositive ? '+' : '-'}${_formatTime(amount.abs())}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isPositive 
                          ? (isTime ? Color(0xFF9C27B0) : Colors.orange)
                          : Color(0xFFFF6B6B),
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '잔여: ${_formatTime(balanceAfter)}',
                    style: TextStyle(
                      fontSize: 11,
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