import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/tab_design_service.dart';
import '../../services/tile_design_service.dart';
import 'contract_setup_page.dart';

// Scaffold 없는 콘텐츠 위젯 (MembershipPage에서 사용)
class ContractListPageContent extends StatefulWidget {
  final String membershipType;
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;
  final Function(Map<String, dynamic>) onContractSelected;

  const ContractListPageContent({
    Key? key,
    required this.membershipType,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
    required this.onContractSelected,
  }) : super(key: key);

  @override
  _ContractListPageContentState createState() => _ContractListPageContentState();
}

class _ContractListPageContentState extends State<ContractListPageContent> {
  List<Map<String, dynamic>> contracts = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadContracts();
  }

  // 계약 목록 로드
  Future<void> _loadContracts() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      print('계약 목록 로드 시작 - 회원권 유형: ${widget.membershipType}');

      // v2_contracts 테이블에서 현재 지점의 유효한 회원권 계약 조회
      final data = await ApiService.getData(
        table: 'v2_contracts',
        where: [
          {'field': 'contract_category', 'operator': '=', 'value': '회원권'},
          {'field': 'contract_status', 'operator': '=', 'value': '유효'},
          {'field': 'contract_type', 'operator': '=', 'value': widget.membershipType},
          {'field': 'branch_id', 'operator': '=', 'value': ApiService.getCurrentBranchId()},
        ],
        orderBy: [
          {'field': 'contract_id', 'direction': 'ASC'}
        ],
      );

      print('조회된 계약 수: ${data.length}개');

      setState(() {
        contracts = data;
        isLoading = false;
      });
    } catch (e) {
      print('계약 목록 로드 오류: $e');
      setState(() {
        errorMessage = '계약 목록을 불러오는데 실패했습니다.';
        isLoading = false;
      });
    }
  }

  // 계약 선택 시 콜백 호출
  void _onContractSelected(Map<String, dynamic> contract) {
    widget.onContractSelected(contract);
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

  // 가격 포맷팅
  String _formatPrice(dynamic price) {
    final priceInt = _safeParseInt(price);
    final formatter = NumberFormat('#,###');
    return '${formatter.format(priceInt)}원';
  }

  // 서비스 칩 빌드
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

  // 계약 타일 빌드
  Widget _buildContractTile(Map<String, dynamic> contract) {
    final f = NumberFormat('#,###');
    final contractName = contract['contract_name'] ?? '';
    final price = contract['price'] ?? 0;

    // 서비스 정보 추출 (Supabase는 소문자로 반환)
    final contractCredit = _safeParseInt(contract['contract_credit']);
    final contractLSMin = _safeParseInt(contract['contract_ls_min'] ?? contract['contract_LS_min']);
    final contractTSMin = _safeParseInt(contract['contract_ts_min'] ?? contract['contract_TS_min']);
    final contractGames = _safeParseInt(contract['contract_games']);
    final contractTermMonth = _safeParseInt(contract['contract_term_month']);

    return GestureDetector(
      onTap: () => _onContractSelected(contract),
      child: Container(
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
              // 상단: 계약 이름 및 가격
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      contractName,
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
                      _formatPrice(price),
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

              // 하단: 서비스 칩들
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (contractCredit > 0)
                    _buildServiceChip(
                      icon: Icons.monetization_on,
                      iconColor: Colors.amber,
                      label: '크레딧 ${f.format(contractCredit)}',
                    ),
                  if (contractLSMin > 0)
                    _buildServiceChip(
                      icon: Icons.school,
                      iconColor: Colors.blueAccent,
                      label: '레슨 ${f.format(contractLSMin)}분',
                    ),
                  if (contractTSMin > 0)
                    _buildServiceChip(
                      icon: Icons.sports_golf,
                      iconColor: Colors.green,
                      label: '타석 ${f.format(contractTSMin)}분',
                    ),
                  if (contractGames > 0)
                    _buildServiceChip(
                      icon: Icons.sports_esports,
                      iconColor: Colors.purple,
                      label: '게임 ${f.format(contractGames)}회',
                    ),
                  if (contractTermMonth > 0)
                    _buildServiceChip(
                      icon: Icons.calendar_month,
                      iconColor: Colors.teal,
                      label: '기간권 ${f.format(contractTermMonth)}개월',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: TileDesignService.buildLoading(
          title: '계약 로딩',
          message: '계약 목록을 불러오는 중...',
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: TileDesignService.buildError(
          errorMessage: errorMessage!,
          onRetry: _loadContracts,
        ),
      );
    }

    if (contracts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(height: 16),
            Text(
              '${widget.membershipType} 상품이 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: contracts.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: _buildContractTile(contracts[index]),
        );
      },
    );
  }
}

// 기존 ContractListPage (하위 호환성을 위해 유지, 하지만 사용하지 않음)
class ContractListPage extends StatefulWidget {
  final String membershipType;
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const ContractListPage({
    Key? key,
    required this.membershipType,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _ContractListPageState createState() => _ContractListPageState();
}

class _ContractListPageState extends State<ContractListPage> {
  @override
  Widget build(BuildContext context) {
    // 하위 호환성을 위해 ContractListPageContent를 사용
    return ContractListPageContent(
      membershipType: widget.membershipType,
      isAdminMode: widget.isAdminMode,
      selectedMember: widget.selectedMember,
      branchId: widget.branchId,
      onContractSelected: (contract) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ContractSetupPage(
              contract: contract,
              membershipType: widget.membershipType,
              isAdminMode: widget.isAdminMode,
              selectedMember: widget.selectedMember,
              branchId: widget.branchId,
            ),
          ),
        );
      },
    );
  }
}
