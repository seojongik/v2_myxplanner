import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../services/program_reservation_classifier.dart';

class MembershipSearchPage extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const MembershipSearchPage({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _MembershipSearchPageState createState() => _MembershipSearchPageState();
}

class _MembershipSearchPageState extends State<MembershipSearchPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회원권 조회'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      body: MembershipSearchContent(
        isAdminMode: widget.isAdminMode,
        selectedMember: widget.selectedMember,
        branchId: widget.branchId,
      ),
    );
  }
}

class MembershipSearchContent extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const MembershipSearchContent({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _MembershipSearchContentState createState() => _MembershipSearchContentState();
}

class _MembershipSearchContentState extends State<MembershipSearchContent> {
  bool _isLoading = false;
  bool _showExpiredMemberships = false;

  // 각 회원권 타입별 계약 목록 (유효한 것)
  List<Map<String, dynamic>> _creditContracts = [];
  List<Map<String, dynamic>> _lessonContracts = [];
  List<Map<String, dynamic>> _timePassContracts = [];
  List<Map<String, dynamic>> _periodPassContracts = [];
  List<Map<String, dynamic>> _gameContracts = [];
  List<Map<String, dynamic>> _programContracts = [];

  // 각 회원권 타입별 계약 목록 (만료된 것)
  List<Map<String, dynamic>> _expiredCreditContracts = [];
  List<Map<String, dynamic>> _expiredLessonContracts = [];
  List<Map<String, dynamic>> _expiredTimePassContracts = [];
  List<Map<String, dynamic>> _expiredPeriodPassContracts = [];
  List<Map<String, dynamic>> _expiredGameContracts = [];
  List<Map<String, dynamic>> _expiredProgramContracts = [];

  // 선택된 계약 및 거래 내역
  Map<String, dynamic>? _selectedContract;
  List<Map<String, dynamic>> _transactionHistory = [];

  @override
  void initState() {
    super.initState();
    _loadAllContracts();
  }

  Future<void> _loadAllContracts() async {
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

      // 병렬로 모든 회원권 타입 조회
      await Future.wait([
        _loadCreditContracts(memberId, branchId),
        _loadLessonContracts(memberId, branchId),
        _loadTimePassContracts(memberId, branchId),
        _loadPeriodPassContracts(memberId, branchId),
        _loadGameContracts(memberId, branchId),
        _loadProgramContracts(memberId, branchId),
      ]);
    } catch (e) {
      print('회원권 조회 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('회원권 정보를 불러오는데 실패했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCreditContracts(String memberId, String branchId) async {
    try {
      final allBills = await ApiService.getData(
        table: 'v2_bills',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
        orderBy: [{'field': 'bill_id', 'direction': 'DESC'}],
      );

      final Map<String, Map<String, dynamic>> contractMap = {};
      for (final bill in allBills) {
        final contractHistoryId = bill['contract_history_id']?.toString();
        if (contractHistoryId == null || contractHistoryId.isEmpty) continue;
        if (!contractMap.containsKey(contractHistoryId)) {
          contractMap[contractHistoryId] = bill;
        }
      }

      final contractList = <Map<String, dynamic>>[];
      for (final entry in contractMap.entries) {
        final contractHistoryId = entry.key;
        final latestBill = entry.value;
        final balance = int.tryParse(latestBill['bill_balance_after']?.toString() ?? '0') ?? 0;
        final expiryDateStr = latestBill['contract_credit_expiry_date']?.toString() ?? '';

        final expiryDate = DateTime.tryParse(expiryDateStr);
        final now = DateTime.now();
        final hasBalance = balance > 0;
        final notExpired = expiryDate?.isAfter(now) ?? false;
        final isValid = hasBalance && notExpired;

        final contracts = await ApiService.getData(
          table: 'v3_contract_history',
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          ],
          limit: 1,
        );

        String contractName = '(알 수 없음)';
        String? contractId;
        if (contracts.isNotEmpty) {
          contractName = contracts[0]['contract_name']?.toString() ?? '(알 수 없음)';
          contractId = contracts[0]['contract_id']?.toString();
        }

        contractList.add({
          'type': 'credit',
          'contract_history_id': contractHistoryId,
          'contract_id': contractId,
          'contract_name': contractName,
          'expiry_date': expiryDateStr,
          'balance': balance.toString(),
          'balance_unit': '원',
          'is_valid': isValid,
        });
      }

      final filteredContracts = await ProgramReservationClassifier.filterContracts(
        contracts: contractList,
        branchId: branchId,
        includeProgram: false,
      );

      // 유효한 것과 만료된 것 분리
      final validContracts = <Map<String, dynamic>>[];
      final expiredContracts = <Map<String, dynamic>>[];

      for (final contract in filteredContracts) {
        if (contract['is_valid'] == true) {
          validContracts.add(contract);
        } else {
          expiredContracts.add(contract);
        }
      }

      validContracts.sort((a, b) {
        try {
          return DateTime.parse(b['expiry_date']).compareTo(DateTime.parse(a['expiry_date']));
        } catch (e) {
          return 0;
        }
      });

      expiredContracts.sort((a, b) {
        try {
          return DateTime.parse(b['expiry_date']).compareTo(DateTime.parse(a['expiry_date']));
        } catch (e) {
          return 0;
        }
      });

      _creditContracts = validContracts;
      _expiredCreditContracts = expiredContracts;
    } catch (e) {
      print('크레딧 조회 오류: $e');
      _creditContracts = [];
      _expiredCreditContracts = [];
    }
  }

  Future<void> _loadLessonContracts(String memberId, String branchId) async {
    try {
      final allCountings = await ApiService.getData(
        table: 'v3_LS_countings',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
        orderBy: [{'field': 'LS_counting_id', 'direction': 'DESC'}],
      );

      final Map<String, Map<String, dynamic>> contractMap = {};
      for (final counting in allCountings) {
        final contractHistoryId = counting['contract_history_id']?.toString();
        if (contractHistoryId == null || contractHistoryId.isEmpty) continue;
        if (!contractMap.containsKey(contractHistoryId)) {
          contractMap[contractHistoryId] = counting;
        }
      }

      final contractList = <Map<String, dynamic>>[];
      for (final entry in contractMap.entries) {
        final contractHistoryId = entry.key;
        final latestCounting = entry.value;
        final balance = int.tryParse(latestCounting['LS_balance_min_after']?.toString() ?? '0') ?? 0;
        final expiryDateStr = latestCounting['LS_expiry_date']?.toString() ?? '';
        final proName = latestCounting['pro_name']?.toString() ?? '';

        final expiryDate = DateTime.tryParse(expiryDateStr);
        final now = DateTime.now();
        final hasBalance = balance > 0;
        final notExpired = expiryDate?.isAfter(now) ?? false;
        final isValid = hasBalance && notExpired;

        final contracts = await ApiService.getData(
          table: 'v3_contract_history',
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          ],
          limit: 1,
        );

        String contractName = '(알 수 없음)';
        String? contractId;
        if (contracts.isNotEmpty) {
          contractName = contracts[0]['contract_name']?.toString() ?? '(알 수 없음)';
          contractId = contracts[0]['contract_id']?.toString();
        }

        contractList.add({
          'type': 'lesson',
          'contract_history_id': contractHistoryId,
          'contract_id': contractId,
          'contract_name': contractName,
          'expiry_date': expiryDateStr,
          'balance': balance.toString(),
          'balance_unit': '분',
          'pro_name': proName,
          'is_valid': isValid,
        });
      }

      final filteredContracts = await ProgramReservationClassifier.filterContracts(
        contracts: contractList,
        branchId: branchId,
        includeProgram: false,
      );

      // 유효한 것과 만료된 것 분리
      final validContracts = <Map<String, dynamic>>[];
      final expiredContracts = <Map<String, dynamic>>[];

      for (final contract in filteredContracts) {
        if (contract['is_valid'] == true) {
          validContracts.add(contract);
        } else {
          expiredContracts.add(contract);
        }
      }

      validContracts.sort((a, b) {
        try {
          return DateTime.parse(b['expiry_date']).compareTo(DateTime.parse(a['expiry_date']));
        } catch (e) {
          return 0;
        }
      });

      expiredContracts.sort((a, b) {
        try {
          return DateTime.parse(b['expiry_date']).compareTo(DateTime.parse(a['expiry_date']));
        } catch (e) {
          return 0;
        }
      });

      _lessonContracts = validContracts;
      _expiredLessonContracts = expiredContracts;
    } catch (e) {
      print('레슨권 조회 오류: $e');
      _lessonContracts = [];
      _expiredLessonContracts = [];
    }
  }

  Future<void> _loadTimePassContracts(String memberId, String branchId) async {
    try {
      final allBills = await ApiService.getData(
        table: 'v2_bill_times',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
        orderBy: [{'field': 'bill_min_id', 'direction': 'DESC'}],
      );

      final Map<String, Map<String, dynamic>> contractMap = {};
      for (final bill in allBills) {
        final contractHistoryId = bill['contract_history_id']?.toString();
        if (contractHistoryId == null || contractHistoryId.isEmpty) continue;
        if (!contractMap.containsKey(contractHistoryId)) {
          contractMap[contractHistoryId] = bill;
        }
      }

      final contractList = <Map<String, dynamic>>[];
      for (final entry in contractMap.entries) {
        final contractHistoryId = entry.key;
        final latestBill = entry.value;
        final balance = int.tryParse(latestBill['bill_balance_min_after']?.toString() ?? '0') ?? 0;
        // Supabase는 소문자로 반환
        final expiryDateStr = (latestBill['contract_ts_min_expiry_date'] ?? latestBill['contract_TS_min_expiry_date'])?.toString() ?? '';

        final expiryDate = DateTime.tryParse(expiryDateStr);
        final now = DateTime.now();
        final hasBalance = balance > 0;
        final notExpired = expiryDate?.isAfter(now) ?? false;
        final isValid = hasBalance && notExpired;

        final contracts = await ApiService.getData(
          table: 'v3_contract_history',
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          ],
          limit: 1,
        );

        String contractName = '(알 수 없음)';
        String? contractId;
        if (contracts.isNotEmpty) {
          contractName = contracts[0]['contract_name']?.toString() ?? '(알 수 없음)';
          contractId = contracts[0]['contract_id']?.toString();
        }

        contractList.add({
          'type': 'time_pass',
          'contract_history_id': contractHistoryId,
          'contract_id': contractId,
          'contract_name': contractName,
          'expiry_date': expiryDateStr,
          'balance': balance.toString(),
          'balance_unit': '분',
          'is_valid': isValid,
        });
      }

      final filteredContracts = await ProgramReservationClassifier.filterContracts(
        contracts: contractList,
        branchId: branchId,
        includeProgram: false,
      );

      // 유효한 것과 만료된 것 분리
      final validContracts = <Map<String, dynamic>>[];
      final expiredContracts = <Map<String, dynamic>>[];

      for (final contract in filteredContracts) {
        if (contract['is_valid'] == true) {
          validContracts.add(contract);
        } else {
          expiredContracts.add(contract);
        }
      }

      validContracts.sort((a, b) {
        try {
          return DateTime.parse(b['expiry_date']).compareTo(DateTime.parse(a['expiry_date']));
        } catch (e) {
          return 0;
        }
      });

      expiredContracts.sort((a, b) {
        try {
          return DateTime.parse(b['expiry_date']).compareTo(DateTime.parse(a['expiry_date']));
        } catch (e) {
          return 0;
        }
      });

      _timePassContracts = validContracts;
      _expiredTimePassContracts = expiredContracts;
    } catch (e) {
      print('시간권 조회 오류: $e');
      _timePassContracts = [];
      _expiredTimePassContracts = [];
    }
  }

  Future<void> _loadPeriodPassContracts(String memberId, String branchId) async {
    try {
      final allBills = await ApiService.getData(
        table: 'v2_bill_term',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
        orderBy: [{'field': 'bill_term_id', 'direction': 'DESC'}],
      );

      final Map<String, Map<String, dynamic>> contractMap = {};
      for (final bill in allBills) {
        final contractHistoryId = bill['contract_history_id']?.toString();
        if (contractHistoryId == null || contractHistoryId.isEmpty) continue;
        if (!contractMap.containsKey(contractHistoryId)) {
          contractMap[contractHistoryId] = bill;
        }
      }

      final contractList = <Map<String, dynamic>>[];
      for (final entry in contractMap.entries) {
        final contractHistoryId = entry.key;
        final latestBill = entry.value;
        final startDateStr = latestBill['term_startdate']?.toString() ?? '';
        final endDateStr = latestBill['term_enddate']?.toString() ?? '';
        final expiryDateStr = latestBill['contract_term_month_expiry_date']?.toString() ?? '';

        bool isValid;
        if (expiryDateStr.isEmpty) {
          isValid = true;
        } else {
          try {
            final expiryDate = DateTime.parse(expiryDateStr);
            final now = DateTime.now();
            isValid = expiryDate.isAfter(now);
          } catch (e) {
            isValid = true;
          }
        }

        final contracts = await ApiService.getData(
          table: 'v3_contract_history',
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          ],
          limit: 1,
        );

        String contractName = '(알 수 없음)';
        String? contractId;
        if (contracts.isNotEmpty) {
          contractName = contracts[0]['contract_name']?.toString() ?? '(알 수 없음)';
          contractId = contracts[0]['contract_id']?.toString();
        }

        contractList.add({
          'type': 'period_pass',
          'contract_history_id': contractHistoryId,
          'contract_id': contractId,
          'contract_name': contractName,
          'expiry_date': expiryDateStr.isNotEmpty ? expiryDateStr : endDateStr,
          'start_date': startDateStr,
          'end_date': endDateStr,
          'is_valid': isValid,
        });
      }

      final filteredContracts = await ProgramReservationClassifier.filterContracts(
        contracts: contractList,
        branchId: branchId,
        includeProgram: false,
      );

      // 유효한 것과 만료된 것 분리
      final validContracts = <Map<String, dynamic>>[];
      final expiredContracts = <Map<String, dynamic>>[];

      for (final contract in filteredContracts) {
        if (contract['is_valid'] == true) {
          validContracts.add(contract);
        } else {
          expiredContracts.add(contract);
        }
      }

      validContracts.sort((a, b) {
        try {
          final dateAStr = b['expiry_date']?.toString() ?? '';
          final dateBStr = a['expiry_date']?.toString() ?? '';
          if (dateAStr.isEmpty && dateBStr.isEmpty) return 0;
          if (dateAStr.isEmpty) return 1;
          if (dateBStr.isEmpty) return -1;
          return DateTime.parse(dateAStr).compareTo(DateTime.parse(dateBStr));
        } catch (e) {
          return 0;
        }
      });

      expiredContracts.sort((a, b) {
        try {
          final dateAStr = b['expiry_date']?.toString() ?? '';
          final dateBStr = a['expiry_date']?.toString() ?? '';
          if (dateAStr.isEmpty && dateBStr.isEmpty) return 0;
          if (dateAStr.isEmpty) return 1;
          if (dateBStr.isEmpty) return -1;
          return DateTime.parse(dateAStr).compareTo(DateTime.parse(dateBStr));
        } catch (e) {
          return 0;
        }
      });

      _periodPassContracts = validContracts;
      _expiredPeriodPassContracts = expiredContracts;
    } catch (e) {
      print('기간권 조회 오류: $e');
      _periodPassContracts = [];
      _expiredPeriodPassContracts = [];
    }
  }

  Future<void> _loadGameContracts(String memberId, String branchId) async {
    try {
      final allBills = await ApiService.getData(
        table: 'v2_bill_games',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
        orderBy: [{'field': 'bill_game_id', 'direction': 'DESC'}],
      );

      final Map<String, Map<String, dynamic>> contractMap = {};
      for (final bill in allBills) {
        final contractHistoryId = bill['contract_history_id']?.toString();
        if (contractHistoryId == null || contractHistoryId.isEmpty) continue;
        if (!contractMap.containsKey(contractHistoryId)) {
          contractMap[contractHistoryId] = bill;
        }
      }

      final contractList = <Map<String, dynamic>>[];
      for (final entry in contractMap.entries) {
        final contractHistoryId = entry.key;
        final latestBill = entry.value;
        final balance = int.tryParse(latestBill['bill_balance_game_after']?.toString() ?? '0') ?? 0;
        final expiryDateStr = latestBill['contract_games_expiry_date']?.toString() ?? '';

        bool isValid;
        if (expiryDateStr.isEmpty) {
          isValid = false;
        } else {
          try {
            final expiryDate = DateTime.parse(expiryDateStr);
            final now = DateTime.now();
            final hasBalance = balance > 0;
            final notExpired = expiryDate.isAfter(now);
            isValid = hasBalance && notExpired;
          } catch (e) {
            isValid = false;
          }
        }

        final contracts = await ApiService.getData(
          table: 'v3_contract_history',
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          ],
          limit: 1,
        );

        String contractName = '(알 수 없음)';
        String? contractId;
        if (contracts.isNotEmpty) {
          contractName = contracts[0]['contract_name']?.toString() ?? '(알 수 없음)';
          contractId = contracts[0]['contract_id']?.toString();
        }

        contractList.add({
          'type': 'game',
          'contract_history_id': contractHistoryId,
          'contract_id': contractId,
          'contract_name': contractName,
          'expiry_date': expiryDateStr,
          'balance': balance.toString(),
          'balance_unit': '게임',
          'is_valid': isValid,
        });
      }

      final filteredContracts = await ProgramReservationClassifier.filterContracts(
        contracts: contractList,
        branchId: branchId,
        includeProgram: false,
      );

      // 유효한 것과 만료된 것 분리
      final validContracts = <Map<String, dynamic>>[];
      final expiredContracts = <Map<String, dynamic>>[];

      for (final contract in filteredContracts) {
        if (contract['is_valid'] == true) {
          validContracts.add(contract);
        } else {
          expiredContracts.add(contract);
        }
      }

      validContracts.sort((a, b) {
        try {
          return DateTime.parse(b['expiry_date']).compareTo(DateTime.parse(a['expiry_date']));
        } catch (e) {
          return 0;
        }
      });

      expiredContracts.sort((a, b) {
        try {
          return DateTime.parse(b['expiry_date']).compareTo(DateTime.parse(a['expiry_date']));
        } catch (e) {
          return 0;
        }
      });

      _gameContracts = validContracts;
      _expiredGameContracts = expiredContracts;
    } catch (e) {
      print('게임권 조회 오류: $e');
      _gameContracts = [];
      _expiredGameContracts = [];
    }
  }

  Future<void> _loadProgramContracts(String memberId, String branchId) async {
    try {
      final allContracts = await ApiService.getData(
        table: 'v3_contract_history',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
        orderBy: [{'field': 'contract_history_id', 'direction': 'DESC'}],
      );

      final programContracts = await ProgramReservationClassifier.filterContracts(
        contracts: allContracts,
        branchId: branchId,
        includeProgram: true,
        includeGeneral: false,
      );

      final contractList = <Map<String, dynamic>>[];
      for (final contract in programContracts) {
        final contractHistoryId = contract['contract_history_id']?.toString();
        if (contractHistoryId == null) continue;

        // 시간권 잔액 조회
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
            // Supabase는 소문자로 반환
            timeExpiryDate = timeBills[0]['contract_ts_min_expiry_date'] ?? timeBills[0]['contract_TS_min_expiry_date'] ?? '';
          }
        } catch (e) {
          print('시간권 잔액 조회 실패: $e');
        }

        // 레슨권 잔액 조회
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

        contractList.add({
          'type': 'program',
          'contract_history_id': contractHistoryId,
          'contract_name': contract['contract_name'] ?? '',
          'expiry_date': latestExpiryStr,
          'time_balance': timeBalance,
          'lesson_balance': lessonBalance,
          'is_valid': isValid,
        });
      }

      // 유효한 것과 만료된 것 분리
      final validContracts = <Map<String, dynamic>>[];
      final expiredContracts = <Map<String, dynamic>>[];

      for (final contract in contractList) {
        if (contract['is_valid'] == true) {
          validContracts.add(contract);
        } else {
          expiredContracts.add(contract);
        }
      }

      validContracts.sort((a, b) {
        try {
          return DateTime.parse(b['expiry_date']).compareTo(DateTime.parse(a['expiry_date']));
        } catch (e) {
          return 0;
        }
      });

      expiredContracts.sort((a, b) {
        try {
          return DateTime.parse(b['expiry_date']).compareTo(DateTime.parse(a['expiry_date']));
        } catch (e) {
          return 0;
        }
      });

      _programContracts = validContracts;
      _expiredProgramContracts = expiredContracts;
    } catch (e) {
      print('프로그램 조회 오류: $e');
      _programContracts = [];
      _expiredProgramContracts = [];
    }
  }

  // 거래 내역 조회 함수들
  Future<void> _loadTransactionHistory(Map<String, dynamic> contract) async {
    setState(() {
      _isLoading = true;
      _selectedContract = contract;
      _transactionHistory = [];
    });

    try {
      final type = contract['type'];
      final contractHistoryId = contract['contract_history_id']?.toString();

      if (contractHistoryId == null) {
        throw Exception('계약 ID가 없습니다');
      }

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

      switch (type) {
        case 'credit':
          await _loadCreditHistory(contractHistoryId, memberId, branchId);
          break;
        case 'lesson':
          await _loadLessonHistory(contractHistoryId, memberId, branchId);
          break;
        case 'time_pass':
          await _loadTimePassHistory(contractHistoryId, memberId, branchId);
          break;
        case 'period_pass':
          await _loadPeriodHistory(contractHistoryId, memberId, branchId);
          break;
        case 'game':
          await _loadGameHistory(contractHistoryId, memberId, branchId);
          break;
        case 'program':
          await _loadProgramHistory(contractHistoryId, memberId, branchId);
          break;
      }
    } catch (e) {
      print('거래 내역 조회 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('거래 내역을 불러오는데 실패했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCreditHistory(String contractHistoryId, String memberId, String branchId) async {
    final history = await ApiService.getData(
      table: 'v2_bills',
      where: [
        {'field': 'branch_id', 'operator': '=', 'value': branchId},
        {'field': 'member_id', 'operator': '=', 'value': memberId},
        {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
      ],
      orderBy: [{'field': 'bill_id', 'direction': 'DESC'}],
    );
    _transactionHistory = history;
  }

  Future<void> _loadLessonHistory(String contractHistoryId, String memberId, String branchId) async {
    final allHistory = await ApiService.getData(
      table: 'v3_LS_countings',
      where: [
        {'field': 'branch_id', 'operator': '=', 'value': branchId},
        {'field': 'member_id', 'operator': '=', 'value': memberId},
        {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
      ],
      orderBy: [{'field': 'LS_counting_id', 'direction': 'DESC'}],
    );

    // 예약취소 제외
    _transactionHistory = allHistory.where((history) {
      final status = history['LS_status']?.toString() ?? '';
      return status != '예약취소';
    }).toList();
  }

  Future<void> _loadTimePassHistory(String contractHistoryId, String memberId, String branchId) async {
    final history = await ApiService.getData(
      table: 'v2_bill_times',
      where: [
        {'field': 'branch_id', 'operator': '=', 'value': branchId},
        {'field': 'member_id', 'operator': '=', 'value': memberId},
        {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
      ],
      orderBy: [{'field': 'bill_min_id', 'direction': 'DESC'}],
    );
    _transactionHistory = history;
  }

  Future<void> _loadPeriodHistory(String contractHistoryId, String memberId, String branchId) async {
    final history = await ApiService.getData(
      table: 'v2_bill_term',
      where: [
        {'field': 'branch_id', 'operator': '=', 'value': branchId},
        {'field': 'member_id', 'operator': '=', 'value': memberId},
        {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
      ],
      orderBy: [{'field': 'bill_term_id', 'direction': 'DESC'}],
    );
    _transactionHistory = history;
  }

  Future<void> _loadGameHistory(String contractHistoryId, String memberId, String branchId) async {
    final history = await ApiService.getData(
      table: 'v2_bill_games',
      where: [
        {'field': 'branch_id', 'operator': '=', 'value': branchId},
        {'field': 'member_id', 'operator': '=', 'value': memberId},
        {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
      ],
      orderBy: [{'field': 'bill_game_id', 'direction': 'DESC'}],
    );
    _transactionHistory = history;
  }

  Future<void> _loadProgramHistory(String contractHistoryId, String memberId, String branchId) async {
    // 프로그램은 시간권과 레슨권 내역을 모두 가져와서 합치기
    final List<Map<String, dynamic>> allHistory = [];

    // 시간권 내역
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

    for (final history in timeHistory) {
      allHistory.add({
        ...history,
        'type': 'time',
        'date': history['bill_date'],
      });
    }

    // 레슨권 내역
    final lessonHistory = await ApiService.getData(
      table: 'v3_LS_countings',
      where: [
        {'field': 'branch_id', 'operator': '=', 'value': branchId},
        {'field': 'member_id', 'operator': '=', 'value': memberId},
        {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
      ],
      orderBy: [{'field': 'LS_counting_id', 'direction': 'DESC'}],
    );

    for (final history in lessonHistory) {
      final lsStatus = history['LS_status']?.toString() ?? '';
      if (lsStatus == '예약취소') continue;

      allHistory.add({
        ...history,
        'type': 'lesson',
        'date': history['LS_date'],
      });
    }

    // 날짜 순으로 정렬
    allHistory.sort((a, b) {
      try {
        final dateA = DateTime.parse(a['date']?.toString() ?? '');
        final dateB = DateTime.parse(b['date']?.toString() ?? '');
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0;
      }
    });

    _transactionHistory = allHistory;
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0';
    final formatter = NumberFormat('#,###');
    return formatter.format(int.tryParse(amount.toString()) ?? 0);
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

  Map<String, dynamic> _getMembershipTypeInfo(String type) {
    switch (type) {
      case 'credit':
        return {
          'name': '크레딧',
          'color': const Color(0xFFFF8C00),
          'icon': Icons.account_balance_wallet,
        };
      case 'lesson':
        return {
          'name': '레슨권',
          'color': const Color(0xFF6B73FF),
          'icon': Icons.school,
        };
      case 'time_pass':
        return {
          'name': '시간권',
          'color': const Color(0xFF9C27B0),
          'icon': Icons.access_time,
        };
      case 'period_pass':
        return {
          'name': '기간권',
          'color': const Color(0xFF4CAF50),
          'icon': Icons.date_range,
        };
      case 'game':
        return {
          'name': '게임권',
          'color': const Color(0xFFF44336),
          'icon': Icons.sports_esports,
        };
      case 'program':
        return {
          'name': '프로그램',
          'color': const Color(0xFFFF5722),
          'icon': Icons.school_outlined,
        };
      default:
        return {
          'name': '알 수 없음',
          'color': Colors.grey,
          'icon': Icons.help_outline,
        };
    }
  }

  void _onContractTileTap(Map<String, dynamic> contract) {
    _loadTransactionHistory(contract);
  }

  @override
  Widget build(BuildContext context) {
    // 거래 내역 조회 중
    if (_isLoading && _selectedContract != null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
        ),
      );
    }

    // 거래 내역 표시
    if (_selectedContract != null) {
      return _buildTransactionHistory();
    }

    // 계약 목록 로딩 중
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
        ),
      );
    }

    // 계약 목록 표시
    final hasValidMemberships = _creditContracts.isNotEmpty ||
        _lessonContracts.isNotEmpty ||
        _timePassContracts.isNotEmpty ||
        _periodPassContracts.isNotEmpty ||
        _gameContracts.isNotEmpty ||
        _programContracts.isNotEmpty;

    return Container(
      color: Colors.grey[50],
      child: CustomScrollView(
        slivers: [
          // 유효한 회원권 섹션
          if (hasValidMemberships) ...[
            _buildMembershipSection('credit', _creditContracts),
            _buildMembershipSection('lesson', _lessonContracts),
            _buildMembershipSection('time_pass', _timePassContracts),
            _buildMembershipSection('period_pass', _periodPassContracts),
            _buildMembershipSection('game', _gameContracts),
            _buildMembershipSection('program', _programContracts),
          ] else ...[
            // 유효한 회원권이 없을 때 빈 상태 메시지
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.card_membership,
                      size: 48,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '유효한 회원권이 없습니다',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 만료된 회원권 토글 섹션
          _buildExpiredMembershipToggle(),

          // 하단 여백
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipSection(String type, List<Map<String, dynamic>> contracts) {
    if (contracts.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    final typeInfo = _getMembershipTypeInfo(type);

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: typeInfo['color'],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  typeInfo['icon'],
                  size: 20,
                  color: typeInfo['color'],
                ),
                const SizedBox(width: 6),
                Text(
                  typeInfo['name'],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[900],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (typeInfo['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${contracts.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: typeInfo['color'],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 계약 타일들
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: contracts.map((contract) => _buildContractTile(contract, showTypeBadge: true)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredMembershipToggle() {
    // 모든 만료된 회원권 개수 계산
    final totalExpired = _expiredCreditContracts.length +
        _expiredLessonContracts.length +
        _expiredTimePassContracts.length +
        _expiredPeriodPassContracts.length +
        _expiredGameContracts.length +
        _expiredProgramContracts.length;

    return SliverToBoxAdapter(
      child: Column(
        children: [
          // 만료된 회원권 토글 헤더
          GestureDetector(
            onTap: () {
              setState(() {
                _showExpiredMemberships = !_showExpiredMemberships;
              });
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '만료된 회원권',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[700],
                    ),
                  ),
                  if (totalExpired > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$totalExpired',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Icon(
                    _showExpiredMemberships ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // 만료된 회원권 내용
          if (_showExpiredMemberships) ...[
            if (totalExpired > 0) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    ..._expiredCreditContracts.map((contract) => _buildContractTile(contract, showTypeBadge: true)),
                    ..._expiredLessonContracts.map((contract) => _buildContractTile(contract, showTypeBadge: true)),
                    ..._expiredTimePassContracts.map((contract) => _buildContractTile(contract, showTypeBadge: true)),
                    ..._expiredPeriodPassContracts.map((contract) => _buildContractTile(contract, showTypeBadge: true)),
                    ..._expiredGameContracts.map((contract) => _buildContractTile(contract, showTypeBadge: true)),
                    ..._expiredProgramContracts.map((contract) => _buildContractTile(contract, showTypeBadge: true)),
                  ],
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    '만료된 회원권이 없습니다',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildContractTile(Map<String, dynamic> contract, {required bool showTypeBadge}) {
    final isValid = contract['is_valid'] ?? false;
    final expiryDate = _formatDate(contract['expiry_date']);
    final type = contract['type'];
    final typeInfo = _getMembershipTypeInfo(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _onContractTileTap(contract),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 아이콘
                Container(
                  width: 64,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: (typeInfo['color'] as Color).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (typeInfo['color'] as Color).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        typeInfo['icon'],
                        size: 24,
                        color: isValid ? typeInfo['color'] : Colors.grey[400],
                      ),
                      const SizedBox(height: 4),
                      if (showTypeBadge)
                        Text(
                          typeInfo['name'],
                          style: TextStyle(
                            fontSize: 10,
                            color: isValid ? typeInfo['color'] : Colors.grey[400],
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // 내용
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 계약명 & 상태 뱃지
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              contract['contract_name'] ?? '',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isValid ? Colors.grey[900] : Colors.grey[400],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isValid ? (typeInfo['color'] as Color).withOpacity(0.1) : Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isValid ? (typeInfo['color'] as Color).withOpacity(0.3) : Colors.grey[400]!,
                              ),
                            ),
                            child: Text(
                              isValid ? '유효' : '만료',
                              style: TextStyle(
                                fontSize: 11,
                                color: isValid ? typeInfo['color'] : Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 잔액 정보
                      if (type == 'program') ...[
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '시간권: ${_formatCurrency(contract['time_balance'])}분',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.school, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '레슨권: ${_formatCurrency(contract['lesson_balance'])}분',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ] else if (type == 'period_pass') ...[
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '${_formatDate(contract['start_date'])} ~ ${_formatDate(contract['end_date'])}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ] else if (contract['balance'] != null) ...[
                        Row(
                          children: [
                            Icon(Icons.account_balance_wallet, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '잔액: ${_formatCurrency(contract['balance'])}${contract['balance_unit']}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 4),

                      // 만료일 & 레슨권 강사명
                      Row(
                        children: [
                          Icon(Icons.event_available, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '만료일: ${expiryDate.isNotEmpty ? expiryDate : '-'}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          // 레슨권인 경우 강사명 우측 정렬
                          if (type == 'lesson' && contract['pro_name'] != null && contract['pro_name'].toString().isNotEmpty) ...[
                            const Spacer(),
                            Icon(Icons.person, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '프로: ${contract['pro_name']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: typeInfo['color'],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 거래 내역 표시
  Widget _buildTransactionHistory() {
    final typeInfo = _getMembershipTypeInfo(_selectedContract!['type']);
    final type = _selectedContract!['type'];

    return Container(
      color: const Color(0xFFF8F9FA),
      child: Column(
        children: [
          // 헤더 (뒤로가기 + 계약 정보)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: typeInfo['color']),
                  onPressed: () {
                    setState(() {
                      _selectedContract = null;
                      _transactionHistory.clear();
                    });
                  },
                ),
                const SizedBox(width: 8),
                Icon(typeInfo['icon'], size: 20, color: typeInfo['color']),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedContract!['contract_name'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${typeInfo['name']} • 총 ${_transactionHistory.length}건',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 거래 내역 리스트
          Expanded(
            child: _transactionHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: (typeInfo['color'] as Color).withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '거래 내역이 없습니다',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _transactionHistory.length,
                    itemBuilder: (context, index) {
                      final history = _transactionHistory[index];
                      return _buildTransactionTile(history, type);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // 거래 내역 타일 (타입별 분기)
  Widget _buildTransactionTile(Map<String, dynamic> history, String type) {
    switch (type) {
      case 'credit':
        return _buildCreditTile(history);
      case 'lesson':
        return _buildLessonTile(history);
      case 'time_pass':
        return _buildTimePassTile(history);
      case 'period_pass':
        return _buildPeriodTile(history);
      case 'game':
        return _buildGameTile(history);
      case 'program':
        return _buildProgramTile(history);
      default:
        return const SizedBox.shrink();
    }
  }

  // 크레딧 거래 타일
  Widget _buildCreditTile(Map<String, dynamic> history) {
    final billType = history['bill_type'] ?? '';
    final billText = history['bill_text'] ?? '';
    final balanceBefore = int.tryParse(history['bill_balance_before']?.toString() ?? '0') ?? 0;
    final balanceAfter = int.tryParse(history['bill_balance_after']?.toString() ?? '0') ?? 0;
    final actualChange = balanceAfter - balanceBefore;
    final billDate = _formatDate(history['bill_date']);
    final isCredit = actualChange > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCredit ? const Color(0xFF37474F).withOpacity(0.1) : const Color(0xFF78909C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isCredit ? Icons.add : Icons.remove,
                color: isCredit ? const Color(0xFF37474F) : const Color(0xFF78909C),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$billType | $billText',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    billDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isCredit ? '+' : ''}${_formatCurrency(actualChange)}원',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCredit ? const Color(0xFF37474F) : const Color(0xFF78909C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '잔여: ${_formatCurrency(balanceAfter)}원',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 레슨권 거래 타일
  Widget _buildLessonTile(Map<String, dynamic> history) {
    final transactionType = history['LS_transaction_type'] ?? '';
    final proName = history['pro_name'] ?? '';
    final netMin = int.tryParse(history['LS_net_min']?.toString() ?? '0') ?? 0;
    final balanceAfter = history['LS_balance_min_after'];
    final date = _formatDate(history['LS_date']);
    final isCredit = netMin > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCredit ? const Color(0xFF37474F).withOpacity(0.1) : const Color(0xFF78909C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isCredit ? Icons.add : Icons.remove,
                color: isCredit ? const Color(0xFF37474F) : const Color(0xFF78909C),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$transactionType | $proName',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isCredit ? '+' : ''}${_formatCurrency(netMin)}분',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCredit ? const Color(0xFF37474F) : const Color(0xFF78909C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '잔여: ${_formatCurrency(balanceAfter)}분',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 시간권 거래 타일
  Widget _buildTimePassTile(Map<String, dynamic> history) {
    final billType = history['bill_type'] ?? '';
    final billText = history['bill_text'] ?? '';
    final balanceBefore = int.tryParse(history['bill_balance_min_before']?.toString() ?? '0') ?? 0;
    final balanceAfter = int.tryParse(history['bill_balance_min_after']?.toString() ?? '0') ?? 0;
    final actualChange = balanceAfter - balanceBefore;
    final billDate = _formatDate(history['bill_date']);
    final isCredit = actualChange > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCredit ? const Color(0xFF37474F).withOpacity(0.1) : const Color(0xFF78909C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isCredit ? Icons.add : Icons.remove,
                color: isCredit ? const Color(0xFF37474F) : const Color(0xFF78909C),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$billType | $billText',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    billDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isCredit ? '+' : ''}${_formatCurrency(actualChange)}분',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCredit ? const Color(0xFF37474F) : const Color(0xFF78909C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '잔여: ${_formatCurrency(balanceAfter)}분',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 기간권 거래 타일
  Widget _buildPeriodTile(Map<String, dynamic> history) {
    final billType = history['bill_type'] ?? '';
    final billText = history['bill_text'] ?? '';
    final startDate = _formatDate(history['term_startdate']);
    final endDate = _formatDate(history['term_enddate']);
    final billDate = _formatDate(history['bill_date']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF37474F).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.date_range,
                color: Color(0xFF37474F),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$billType | $billText',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    billDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  startDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  '~',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  endDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 게임권 거래 타일
  Widget _buildGameTile(Map<String, dynamic> history) {
    final billType = history['bill_type'] ?? '';
    final billText = history['bill_text'] ?? '';
    final balanceBefore = int.tryParse(history['bill_balance_game_before']?.toString() ?? '0') ?? 0;
    final balanceAfter = int.tryParse(history['bill_balance_game_after']?.toString() ?? '0') ?? 0;
    final actualChange = balanceAfter - balanceBefore;
    final billDate = _formatDate(history['bill_date']);
    final isCredit = actualChange > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCredit ? const Color(0xFF37474F).withOpacity(0.1) : const Color(0xFF78909C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isCredit ? Icons.add : Icons.remove,
                color: isCredit ? const Color(0xFF37474F) : const Color(0xFF78909C),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$billType | $billText',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    billDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isCredit ? '+' : ''}${_formatCurrency(actualChange)}게임',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCredit ? const Color(0xFF37474F) : const Color(0xFF78909C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '잔여: ${_formatCurrency(balanceAfter)}게임',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 프로그램 거래 타일
  Widget _buildProgramTile(Map<String, dynamic> history) {
    final historyType = history['type'];

    if (historyType == 'time') {
      final billType = history['bill_type'] ?? '';
      final billText = history['bill_text'] ?? '';
      final balanceBefore = int.tryParse(history['bill_balance_min_before']?.toString() ?? '0') ?? 0;
      final balanceAfter = int.tryParse(history['bill_balance_min_after']?.toString() ?? '0') ?? 0;
      final actualChange = balanceAfter - balanceBefore;
      final billDate = _formatDate(history['bill_date']);
      final isCredit = actualChange > 0;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCredit ? const Color(0xFF37474F).withOpacity(0.1) : const Color(0xFF78909C).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.access_time,
                  color: isCredit ? const Color(0xFF37474F) : const Color(0xFF78909C),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF37474F).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '시간권',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF37474F),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$billType | $billText',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[900],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      billDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isCredit ? '+' : ''}${_formatCurrency(actualChange)}분',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isCredit ? const Color(0xFF37474F) : const Color(0xFF78909C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '잔여: ${_formatCurrency(balanceAfter)}분',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      // lesson
      final transactionType = history['LS_transaction_type'] ?? '';
      final proName = history['pro_name'] ?? '';
      final netMin = int.tryParse(history['LS_net_min']?.toString() ?? '0') ?? 0;
      final balanceAfter = history['LS_balance_min_after'];
      final date = _formatDate(history['LS_date']);
      final isCredit = netMin > 0;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCredit ? const Color(0xFF37474F).withOpacity(0.1) : const Color(0xFF78909C).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.school,
                  color: isCredit ? const Color(0xFF37474F) : const Color(0xFF78909C),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF37474F).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '레슨권',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF37474F),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$transactionType | $proName',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[900],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isCredit ? '+' : ''}${_formatCurrency(netMin)}분',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isCredit ? const Color(0xFF37474F) : const Color(0xFF78909C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '잔여: ${_formatCurrency(balanceAfter)}분',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }
}
