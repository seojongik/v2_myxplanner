import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';

class CouponSearchPage extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const CouponSearchPage({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _CouponSearchPageState createState() => _CouponSearchPageState();
}

class _CouponSearchPageState extends State<CouponSearchPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('쿠폰 조회'),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
      ),
      body: CouponSearchContent(
        isAdminMode: widget.isAdminMode,
        selectedMember: widget.selectedMember,
        branchId: widget.branchId,
      ),
    );
  }
}

class CouponSearchContent extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const CouponSearchContent({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _CouponSearchContentState createState() => _CouponSearchContentState();
}

class _CouponSearchContentState extends State<CouponSearchContent> {
  // Search filters
  String? _selectedMemberId;

  // Data
  List<Map<String, dynamic>> _unusedCoupons = [];
  List<Map<String, dynamic>> _usedCoupons = [];
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = false;
  bool _isUsedLoading = false;
  bool _showUsedCoupons = false;
  int _usedOffset = 0;
  final int _usedPageSize = 10;

  @override
  void initState() {
    super.initState();

    // 선택된 회원이 있으면 자동 설정하고 검색
    if (widget.selectedMember != null) {
      _selectedMemberId = widget.selectedMember!['member_id'].toString();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadUnusedCoupons();
      });
    } else if (widget.isAdminMode) {
      // 관리자 모드에서만 회원 목록 로드
      _loadMembers();
    } else {
      // 일반 모드에서는 현재 로그인한 사용자의 쿠폰 자동 로드
      final currentUser = ApiService.getCurrentUser();
      if (currentUser != null) {
        _selectedMemberId = currentUser['member_id'].toString();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadUnusedCoupons();
        });
      }
    }
  }

  Future<void> _loadMembers() async {
    try {
      final members = await ApiService.getMembers();
      final currentBranchId = ApiService.getCurrentBranchId();

      // 현재 브랜치의 회원만 필터링
      final filteredMembers = members.where((member) {
        return member['branch_id'] == currentBranchId;
      }).toList();

      setState(() {
        _members = filteredMembers;
      });
    } catch (e) {
      print('Failed to load members: $e');
    }
  }

  Future<void> _loadUnusedCoupons() async {
    print('\n🚀 [쿠폰메인] _loadUnusedCoupons 시작');

    setState(() {
      _isLoading = true;
      _unusedCoupons = [];
    });

    try {
      List<Map<String, dynamic>> whereConditions = [];

      if (_selectedMemberId != null && _selectedMemberId!.isNotEmpty) {
        whereConditions.add({
          'field': 'member_id',
          'operator': '=',
          'value': int.parse(_selectedMemberId!),
        });
      }

      // 상태 조건: 미사용만 조회
      whereConditions.add({
        'field': 'coupon_status',
        'operator': '=',
        'value': '미사용',
      });

      print('🔎 [쿠폰] WHERE 조건: $whereConditions');

      final coupons = await ApiService.getData(
        table: 'v2_discount_coupon',
        where: whereConditions,
        orderBy: [
          {'field': 'coupon_expiry_date', 'direction': 'ASC'},
          {'field': 'coupon_issue_date', 'direction': 'DESC'},
        ],
      );

      print('✅ [쿠폰] 조회 결과: ${coupons.length}건');

      setState(() {
        _unusedCoupons = coupons;
      });

      print('✅ [쿠폰메인] 미사용 쿠폰 로딩 완료: ${_unusedCoupons.length}건\n');
    } catch (e) {
      print('❌ [쿠폰메인] 쿠폰 조회 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('쿠폰 조회 실패: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUsedCoupons({bool loadMore = false}) async {
    print('\n🚀 [사용쿠폰메인] _loadUsedCoupons 시작 (더보기: $loadMore)');

    setState(() {
      _isUsedLoading = true;
    });

    try {
      List<Map<String, dynamic>> whereConditions = [];

      if (_selectedMemberId != null && _selectedMemberId!.isNotEmpty) {
        whereConditions.add({
          'field': 'member_id',
          'operator': '=',
          'value': int.parse(_selectedMemberId!),
        });
      }

      whereConditions.add({
        'field': 'coupon_status',
        'operator': '=',
        'value': '사용',
      });

      print('🔎 [사용쿠폰] WHERE 조건: $whereConditions');

      final coupons = await ApiService.getData(
        table: 'v2_discount_coupon',
        where: whereConditions,
        orderBy: [
          {'field': 'coupon_use_timestamp', 'direction': 'DESC'},
        ],
        limit: _usedPageSize,
        offset: loadMore ? _usedOffset : 0,
      );

      print('✅ [사용쿠폰] 조회 결과: ${coupons.length}건');

      setState(() {
        if (loadMore) {
          _usedCoupons.addAll(coupons);
          print('📝 기존 사용쿠폰에 추가: 총 ${_usedCoupons.length}건');
        } else {
          _usedCoupons = coupons;
          print('📝 사용쿠폰 새로 설정: ${_usedCoupons.length}건');
        }
        _usedOffset += _usedPageSize;
        print('📄 다음 오프셋: $_usedOffset');
      });

      print('✅ [사용쿠폰메인] 사용쿠폰 로딩 완료\n');
    } catch (e) {
      print('❌ [사용쿠폰메인] 사용쿠폰 조회 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사용쿠폰 조회 실패: $e')),
        );
      }
    } finally {
      setState(() {
        _isUsedLoading = false;
      });
    }
  }

  String _formatDiscountInfo(Map<String, dynamic> coupon) {
    final couponType = coupon['coupon_type']?.toString() ?? '';
    final discountRatio = int.tryParse(coupon['discount_ratio']?.toString() ?? '0') ?? 0;
    final discountAmt = int.tryParse(coupon['discount_amt']?.toString() ?? '0') ?? 0;

    if (couponType == '정률권' && discountRatio > 0) {
      return '정률권($discountRatio%)';
    } else if (couponType == '정액권' && discountAmt > 0) {
      return '정액권(${NumberFormat('#,###').format(discountAmt)}원)';
    }
    return couponType;
  }

  String? _parseUsedDate(String? reservationId) {
    if (reservationId == null || reservationId.isEmpty) return null;

    // reservation_id_used 형식: 250831_2_1010 (첫 6자리가 yymmdd)
    if (reservationId.length >= 6) {
      final dateStr = reservationId.substring(0, 6);
      try {
        final year = int.parse('20${dateStr.substring(0, 2)}');
        final month = int.parse(dateStr.substring(2, 4));
        final day = int.parse(dateStr.substring(4, 6));
        final date = DateTime(year, month, day);
        return DateFormat('yyyy-MM-dd').format(date);
      } catch (e) {
        print('날짜 파싱 오류: $e');
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 관리자 모드에서만 회원 드롭다운 표시
        if (widget.isAdminMode && widget.selectedMember == null)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: _buildMemberDropdown(),
          ),

        Expanded(child: _buildCouponList()),
      ],
    );
  }


  Widget _buildMemberDropdown() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: '회원 선택',
        border: OutlineInputBorder(),
      ),
      value: _selectedMemberId,
      items: [
        const DropdownMenuItem(
          value: null,
          child: Text('전체 회원'),
        ),
        ..._members.map((member) => DropdownMenuItem(
          value: member['member_id'].toString(),
          child: Text('${member['name']} (${member['member_id']})'),
        )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedMemberId = value;
        });
      },
    );
  }

  Widget _buildCouponList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: Colors.grey[50],
      child: CustomScrollView(
        slivers: [
          // 미사용 쿠폰
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE91E63),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '사용 가능한 쿠폰',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[900],
                    ),
                  ),
                  if (_unusedCoupons.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE91E63).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_unusedCoupons.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE91E63),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_unusedCoupons.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildCouponCard(_unusedCoupons[index], false),
                  childCount: _unusedCoupons.length,
                ),
              ),
            ),
          ] else if (!_isLoading) ...[
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
                      Icons.local_offer,
                      size: 48,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '사용 가능한 쿠폰이 없습니다',
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

          // 사용한 쿠폰 토글
          SliverToBoxAdapter(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showUsedCoupons = !_showUsedCoupons;
                  if (!_showUsedCoupons) {
                    _usedCoupons.clear();
                    _usedOffset = 0;
                  }
                });
                if (_showUsedCoupons && _usedCoupons.isEmpty) {
                  _loadUsedCoupons();
                }
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
                      '사용한 쿠폰',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _showUsedCoupons ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 사용한 쿠폰 내용
          if (_showUsedCoupons) ...[
            if (_isUsedLoading && _usedCoupons.isEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ] else if (_usedCoupons.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildCouponCard(_usedCoupons[index], true),
                    childCount: _usedCoupons.length,
                  ),
                ),
              ),
              // 더보기 버튼
              if (_usedCoupons.length >= _usedPageSize && _usedCoupons.length % _usedPageSize == 0) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: _isUsedLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: () => _loadUsedCoupons(loadMore: true),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              backgroundColor: Colors.grey[200],
                            ),
                            child: Text(
                              '더보기',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                    ),
                  ),
                ),
              ],
            ] else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Text(
                      '사용한 쿠폰이 없습니다',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],

          // 하단 여백
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponCard(Map<String, dynamic> coupon, bool isUsed) {
    final isCancelled = coupon['coupon_status'] == '취소';
    final expiryDate = coupon['coupon_expiry_date']?.toString();
    final issueDate = coupon['coupon_issue_date']?.toString();
    final description = coupon['coupon_description'] ?? '';
    final discountInfo = _formatDiscountInfo(coupon);
    final isMultipleUse = coupon['multiple_coupon_use'] == '가능';
    final usedReservationId = coupon['reservation_id_used']?.toString();
    final usedDate = _parseUsedDate(usedReservationId);

    // 만료일 체크
    DateTime? expiryDateTime;
    bool isExpiringSoon = false;
    bool isExpired = false;
    int daysUntilExpiry = 0;

    if (expiryDate != null) {
      try {
        expiryDateTime = DateTime.parse(expiryDate);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final expiry = DateTime(expiryDateTime.year, expiryDateTime.month, expiryDateTime.day);
        daysUntilExpiry = expiry.difference(today).inDays;

        if (daysUntilExpiry < 0) {
          isExpired = true;
        } else if (daysUntilExpiry <= 7) {
          isExpiringSoon = true;
        }
      } catch (e) {
        print('만료일 파싱 오류: $e');
      }
    }

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 쿠폰 타입 아이콘
            Container(
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isCancelled
                  ? Colors.grey[100]
                  : isUsed
                    ? Colors.grey.withOpacity(0.08)
                    : const Color(0xFFE91E63).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCancelled
                    ? Colors.grey.withOpacity(0.2)
                    : isUsed
                      ? Colors.grey.withOpacity(0.2)
                      : const Color(0xFFE91E63).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_offer,
                    size: 24,
                    color: isCancelled
                      ? Colors.grey[400]
                      : isUsed
                        ? Colors.grey[600]
                        : const Color(0xFFE91E63),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    discountInfo,
                    style: TextStyle(
                      fontSize: 10,
                      color: isCancelled
                        ? Colors.grey[400]
                        : isUsed
                          ? Colors.grey[600]
                          : const Color(0xFFE91E63),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 쿠폰 설명
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          description,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isCancelled ? Colors.grey[400] : Colors.grey[900],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 상태 마크
                      if (isCancelled) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.red[300]!),
                          ),
                          child: Text(
                            '취소',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ] else if (isUsed) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey[400]!),
                          ),
                          child: Text(
                            '사용완료',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ] else if (isExpired) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.red[300]!),
                          ),
                          child: Text(
                            '만료',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ] else if (isExpiringSoon) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange[300]!),
                          ),
                          child: Text(
                            'D-$daysUntilExpiry',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 발급일자와 유효기간
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: isCancelled ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '발급: ${issueDate != null ? DateFormat('yy.MM.dd').format(DateTime.parse(issueDate)) : '-'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isCancelled ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.event_available,
                        size: 14,
                        color: isCancelled
                          ? Colors.grey[400]
                          : isExpired || isExpiringSoon
                            ? Colors.orange[600]
                            : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '~${expiryDate != null ? DateFormat('yy.MM.dd').format(DateTime.parse(expiryDate)) : '-'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isCancelled
                            ? Colors.grey[400]
                            : isExpired || isExpiringSoon
                              ? Colors.orange[700]
                              : Colors.grey[600],
                          fontWeight: isExpiringSoon || isExpired ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),

                  // 사용일자 (사용한 쿠폰인 경우)
                  if (isUsed && usedDate != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '사용: ${DateFormat('yy.MM.dd').format(DateTime.parse(usedDate))}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],

                  // 중복사용 가능 태그
                  if (isMultipleUse && !isUsed) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Text(
                        '중복사용 가능',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
