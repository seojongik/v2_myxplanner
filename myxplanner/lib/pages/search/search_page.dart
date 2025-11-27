import 'package:flutter/material.dart';
import '../../services/tab_design_service.dart';
import '../../services/api_service.dart';
import '../../services/program_reservation_classifier.dart';
import 'reservation_history/reservation_history_search_page.dart';
import 'coupon/coupon_search_page.dart';
import 'membership/membership_search_page.dart';

class SearchPage extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const SearchPage({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool _isLoading = true;
  
  final List<Map<String, dynamic>> allTabs = [
    {
      'title': '예약내역',
      'type': 'reservation_history',
      'icon': Icons.history,
      'color': Color(0xFF00A86B),
      'alwaysShow': true, // 예약내역은 항상 표시
    },
    {
      'title': '쿠폰',
      'type': 'coupon',
      'icon': Icons.local_offer,
      'color': Color(0xFFE91E63),
      'alwaysShow': true, // 쿠폰은 항상 표시
    },
    {
      'title': '회원권',
      'type': 'membership',
      'icon': Icons.card_membership,
      'color': Color(0xFF2196F3),
      'tables': ['v2_bills', 'v3_LS_countings', 'v2_bill_times', 'v2_bill_term', 'v2_bill_games'], // 여러 테이블 확인
    },
  ];

  List<Map<String, dynamic>> visibleTabs = [];

  @override
  void initState() {
    super.initState();
    _checkTabsAvailability();
  }

  Future<void> _checkTabsAvailability() async {
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
        // 회원 정보가 없으면 모든 탭 표시
        visibleTabs = allTabs;
        _tabController = TabController(length: visibleTabs.length, vsync: this);
        setState(() => _isLoading = false);
        return;
      }

      // 각 탭의 계약 존재 여부 확인
      List<Map<String, dynamic>> tabsToShow = [];

      for (final tab in allTabs) {
        // 예약내역은 항상 표시
        if (tab['alwaysShow'] == true) {
          tabsToShow.add(tab);
          continue;
        }

        // 계약이 있는지 확인
        final hasContracts = await _checkTabHasContracts(
          tab['type'],
          tab['table'],
          memberId,
          branchId,
        );

        if (hasContracts) {
          tabsToShow.add(tab);
        }
      }

      visibleTabs = tabsToShow;
      _tabController = TabController(length: visibleTabs.length, vsync: this);
    } catch (e) {
      print('탭 가용성 확인 오류: $e');
      // 오류 발생 시 모든 탭 표시
      visibleTabs = allTabs;
      _tabController = TabController(length: visibleTabs.length, vsync: this);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _checkTabHasContracts(
    String tabType,
    String? table,
    String memberId,
    String branchId,
  ) async {
    // 회원권 탭은 여러 테이블 확인
    if (tabType == 'membership') {
      return await _checkMembershipContracts(memberId, branchId);
    }

    // 프로그램 탭은 별도 로직으로 확인 (현재는 사용 안 함)
    if (tabType == 'program') {
      return await _checkProgramContracts(memberId, branchId);
    }

    if (table == null) return true;

    try {
      final data = await ApiService.getData(
        table: table,
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
        limit: 1, // 하나만 확인하면 됨
      );

      // contract_history_id가 null이 아닌 데이터가 있는지 확인
      for (final item in data) {
        final contractHistoryId = item['contract_history_id'];
        if (contractHistoryId != null) {
          return true; // 계약이 있음
        }
      }

      return false; // 계약이 없음
    } catch (e) {
      print('$tabType 탭 확인 오류: $e');
      return true; // 오류 발생 시 표시
    }
  }

  Future<bool> _checkMembershipContracts(String memberId, String branchId) async {
    try {
      // 여러 테이블에서 계약 확인: 하나라도 있으면 true
      final tables = ['v2_bills', 'v3_LS_countings', 'v2_bill_times', 'v2_bill_term', 'v2_bill_games'];

      for (final table in tables) {
        final data = await ApiService.getData(
          table: table,
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'member_id', 'operator': '=', 'value': memberId},
          ],
          limit: 1,
        );

        // contract_history_id가 null이 아닌 데이터가 있는지 확인
        for (final item in data) {
          final contractHistoryId = item['contract_history_id'];
          if (contractHistoryId != null) {
            return true; // 하나라도 계약이 있음
          }
        }
      }

      // 프로그램 계약도 확인
      final hasProgramContracts = await _checkProgramContracts(memberId, branchId);
      if (hasProgramContracts) {
        return true;
      }

      return false; // 모든 테이블에 계약 없음
    } catch (e) {
      print('회원권 탭 확인 오류: $e');
      return true; // 오류 발생 시 표시
    }
  }

  Future<bool> _checkProgramContracts(String memberId, String branchId) async {
    try {
      // 1. v3_contract_history에서 회원의 계약 조회
      final contracts = await ApiService.getData(
        table: 'v3_contract_history',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
      );

      if (contracts.isEmpty) {
        return false; // 계약이 없음
      }

      // 2. 각 계약의 contract_id로 v2_contracts에서 program_reservation_availability 확인
      for (final contract in contracts) {
        final contractId = contract['contract_id']?.toString();
        if (contractId == null) continue;

        final contractDetails = await ApiService.getData(
          table: 'v2_contracts',
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'contract_id', 'operator': '=', 'value': contractId},
          ],
          limit: 1,
        );

        if (contractDetails.isNotEmpty) {
          final programAvailability = contractDetails[0]['program_reservation_availability']?.toString() ?? '';
          // null, 빈칸, '0'이 아닌 값이 있으면 프로그램 계약
          if (programAvailability.isNotEmpty && programAvailability != '0') {
            return true; // 프로그램 계약 발견
          }
        }
      }

      return false; // 프로그램 계약 없음
    } catch (e) {
      print('프로그램 탭 확인 오류: $e');
      return false; // 오류 발생 시 숨김
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  // 각 탭에 해당하는 위젯 생성
  Widget _buildTabContent(Map<String, dynamic> tab) {
    final String type = tab['type'];

    switch (type) {
      case 'reservation_history':
        return ReservationHistorySearchContent(
          isAdminMode: widget.isAdminMode,
          selectedMember: widget.selectedMember,
          branchId: widget.branchId,
        );

      case 'coupon':
        return CouponSearchContent(
          isAdminMode: widget.isAdminMode,
          selectedMember: widget.selectedMember,
          branchId: widget.branchId,
        );

      case 'membership':
        return MembershipSearchContent(
          isAdminMode: widget.isAdminMode,
          selectedMember: widget.selectedMember,
          branchId: widget.branchId,
        );

      default:
        return Container(
          child: Center(
            child: Text('알 수 없는 탭입니다.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _tabController == null) {
      return Scaffold(
        backgroundColor: TabDesignService.backgroundColor,
        appBar: TabDesignService.buildAppBar(
          title: '조회하기',
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: TabDesignService.backgroundColor,
      appBar: TabDesignService.buildAppBar(
        title: '조회하기',
        bottom: TabDesignService.buildUnderlineTabBar(
          controller: _tabController!,
          tabs: visibleTabs,
        ),
      ),
      body: TabBarView(
        controller: _tabController!,
        children: visibleTabs.map((tab) => _buildTabContent(tab)).toList(),
      ),
    );
  }
} 