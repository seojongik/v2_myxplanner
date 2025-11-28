import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import 'reservation_detail_dialog.dart';

class ReservationHistorySearchPage extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const ReservationHistorySearchPage({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _ReservationHistorySearchPageState createState() => _ReservationHistorySearchPageState();
}

class _ReservationHistorySearchPageState extends State<ReservationHistorySearchPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('예약내역 조회'),
        backgroundColor: const Color(0xFF00A86B),
        foregroundColor: Colors.white,
      ),
      body: ReservationHistorySearchContent(
        isAdminMode: widget.isAdminMode,
        selectedMember: widget.selectedMember,
        branchId: widget.branchId,
      ),
    );
  }
}

class ReservationHistorySearchContent extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const ReservationHistorySearchContent({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _ReservationHistorySearchContentState createState() => _ReservationHistorySearchContentState();
}

class _ReservationHistorySearchContentState extends State<ReservationHistorySearchContent> {
  // Search filters
  String? _selectedMemberId;
  bool _showCancelled = false;

  // Data
  List<Map<String, dynamic>> _futureReservations = [];
  List<Map<String, dynamic>> _pastReservations = [];
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = false;
  bool _isPastLoading = false;
  bool _showPastReservations = false;
  int _pastOffset = 0;
  final int _pastPageSize = 10;

  @override
  void initState() {
    super.initState();
    
    // 선택된 회원이 있으면 자동 설정하고 검색
    if (widget.selectedMember != null) {
      _selectedMemberId = widget.selectedMember!['member_id'].toString();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadFutureReservations();
      });
    } else if (widget.isAdminMode) {
      // 관리자 모드에서만 회원 목록 로드
      _loadMembers();
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

  Future<void> _loadFutureReservations() async {
    print('\n🚀 [메인] _loadFutureReservations 시작');

    setState(() {
      _isLoading = true;
      _futureReservations = [];
    });

    try {
      List<Map<String, dynamic>> allReservations = [];

      print('📋 타석 예약 조회 중...');
      final tsReservations = await _getFutureReservations('ts');
      print('✅ 타석 예약 ${tsReservations.length}건 받음');
      allReservations.addAll(tsReservations);

      print('📋 레슨 예약 조회 중...');
      final lessonReservations = await _getFutureReservations('lesson');
      print('✅ 레슨 예약 ${lessonReservations.length}건 받음');
      allReservations.addAll(lessonReservations);

      print('📦 전체 예약 데이터: ${allReservations.length}건');

      // program_id로 그룹핑 (타석과 레슨 모두)
      final groupedReservations = _groupProgramReservations(allReservations);
      print('🔄 그룹핑 후: ${groupedReservations.length}건');

      groupedReservations.sort((a, b) {
        final dateTimeA = DateTime.parse('${a['date']} ${a['startTime']}:00');
        final dateTimeB = DateTime.parse('${b['date']} ${b['startTime']}:00');
        return dateTimeA.compareTo(dateTimeB); // 미래 예약은 가까운 순
      });

      setState(() {
        _futureReservations = groupedReservations;
      });

      print('✅ [메인] 미래 예약 로딩 완료: ${_futureReservations.length}건\n');
    } catch (e) {
      print('❌ [메인] 예약 조회 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('예약 조회 실패: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPastReservations({bool loadMore = false}) async {
    print('\n🚀 [과거예약메인] _loadPastReservations 시작 (더보기: $loadMore)');

    setState(() {
      _isPastLoading = true;
    });

    try {
      List<Map<String, dynamic>> allReservations = [];

      print('📋 과거 타석 예약 조회 중...');
      final tsReservations = await _getPastReservations('ts', loadMore ? _pastOffset : 0);
      print('✅ 과거 타석 예약 ${tsReservations.length}건 받음');
      allReservations.addAll(tsReservations);

      print('📋 과거 레슨 예약 조회 중...');
      final lessonReservations = await _getPastReservations('lesson', loadMore ? _pastOffset : 0);
      print('✅ 과거 레슨 예약 ${lessonReservations.length}건 받음');
      allReservations.addAll(lessonReservations);

      print('📦 전체 과거 예약 데이터: ${allReservations.length}건');

      final groupedReservations = _groupProgramReservations(allReservations);
      print('🔄 그룹핑 후: ${groupedReservations.length}건');

      groupedReservations.sort((a, b) {
        final dateTimeA = DateTime.parse('${a['date']} ${a['startTime']}:00');
        final dateTimeB = DateTime.parse('${b['date']} ${b['startTime']}:00');
        return dateTimeB.compareTo(dateTimeA); // 과거 예약은 최신순
      });

      setState(() {
        if (loadMore) {
          _pastReservations.addAll(groupedReservations);
          print('📝 기존 과거 예약에 추가: 총 ${_pastReservations.length}건');
        } else {
          _pastReservations = groupedReservations;
          print('📝 과거 예약 새로 설정: ${_pastReservations.length}건');
        }
        _pastOffset += _pastPageSize;
        print('📄 다음 오프셋: $_pastOffset');
      });

      print('✅ [과거예약메인] 과거 예약 로딩 완료\n');
    } catch (e) {
      print('❌ [과거예약메인] 과거 예약 조회 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('과거 예약 조회 실패: $e')),
        );
      }
    } finally {
      setState(() {
        _isPastLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _groupProgramReservations(List<Map<String, dynamic>> reservations) {
    final Map<String, List<Map<String, dynamic>>> programGroups = {};
    final List<Map<String, dynamic>> result = [];
    
    // program_id가 있는 예약들을 그룹핑
    for (final reservation in reservations) {
      if (reservation['programId'] != null && reservation['programId'].toString().isNotEmpty) {
        final programId = reservation['programId'].toString();
        if (!programGroups.containsKey(programId)) {
          programGroups[programId] = [];
        }
        programGroups[programId]!.add(reservation);
      } else {
        // program_id가 없는 일반 예약은 그대로 추가
        result.add(reservation);
      }
    }
    
    // 프로그램 예약들을 하나의 타일로 생성
    for (final group in programGroups.values) {
      if (group.isNotEmpty) {
        // 타석 예약을 찾아서 기준 시간으로 사용
        final tsReservation = group.firstWhere(
          (r) => r['type'] == '타석',
          orElse: () => group.first,
        );
        
        final lessonReservations = group.where((r) => r['type'] == '레슨').toList();
        final tsReservations = group.where((r) => r['type'] == '타석').toList();
        
        result.add({
          ...tsReservation,
          'type': '프로그램',
          'isProgramReservation': true,
          'programId': group.first['programId'],
          'programName': _getProgramName(group),
          'tsCount': tsReservations.length,
          'lessonCount': lessonReservations.length,
          'totalItems': group.length,
          'programDetails': {
            'tsReservations': tsReservations,
            'lessonReservations': lessonReservations,
          },
          'station': _buildProgramStationInfo(tsReservations, lessonReservations),
        });
      }
    }
    
    return result;
  }
  
  String _buildProgramStationInfo(List<Map<String, dynamic>> tsReservations, List<Map<String, dynamic>> lessonReservations) {
    final stations = <String>[];

    if (tsReservations.isNotEmpty) {
      stations.add('${tsReservations.first['station']}번 타석');
    }

    if (lessonReservations.isNotEmpty) {
      final proNames = lessonReservations.map((r) => r['station']).toSet();
      for (final proName in proNames) {
        stations.add('$proName 프로');
      }
    }

    return stations.join(' + ');
  }

  String _getProgramName(List<Map<String, dynamic>> group) {
    for (final reservation in group) {
      if (reservation['type'] == '타석' &&
          reservation['programName'] != null &&
          reservation['programName'].toString().isNotEmpty) {
        return reservation['programName'].toString();
      }
    }

    for (final reservation in group) {
      if (reservation['programName'] != null &&
          reservation['programName'].toString().isNotEmpty) {
        return reservation['programName'].toString();
      }
    }

    return '프로그램';
  }

  Future<List<Map<String, dynamic>>> _getFutureReservations(String type) async {
    List<Map<String, dynamic>> whereConditions = [];
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    print('🔍 [예약조회] _getFutureReservations 시작');
    print('📅 오늘 날짜: $today');
    print('📋 조회 타입: $type');
    print('👤 선택된 회원 ID: $_selectedMemberId');
    print('🚫 취소 포함: $_showCancelled');

    if (type == 'ts') {
      whereConditions.add({
        'field': 'ts_date',
        'operator': '>=',
        'value': today,
      });

      if (_selectedMemberId != null && _selectedMemberId!.isNotEmpty) {
        whereConditions.add({
          'field': 'member_id',
          'operator': '=',
          'value': int.parse(_selectedMemberId!),
        });
      }

      // 상태 조건: 결제완료만 또는 취소 포함
      if (_showCancelled) {
        whereConditions.add({
          'field': 'ts_status',
          'operator': 'IN',
          'value': ['결제완료', '취소', '예약취소'],  // 예약취소도 포함
        });
      } else {
        whereConditions.add({
          'field': 'ts_status',
          'operator': '=',
          'value': '결제완료',
        });
      }

      print('🔎 [타석] WHERE 조건: $whereConditions');

      final tsData = await ApiService.getData(
        table: 'v2_priced_TS',
        where: whereConditions,
        orderBy: [
          {'field': 'ts_date', 'direction': 'ASC'},
          {'field': 'ts_start', 'direction': 'ASC'},
        ],
      );

      print('✅ [타석] 조회 결과: ${tsData.length}건');
      if (tsData.isNotEmpty) {
        print('📊 [타석] 첫번째 데이터: ${tsData.first}');
      }

      return tsData.map((item) => {
        'type': '타석',
        'date': item['ts_date'].toString(),
        'startTime': _formatTime(item['ts_start']),
        'endTime': _formatTime(item['ts_end']),
        'station': item['ts_id']?.toString() ?? '',
        'status': item['ts_status'] ?? '',
        'amount': item['net_amt'] ?? 0,
        'reservationId': item['reservation_id']?.toString() ?? '',
        'billId': item['bill_id']?.toString() ?? '',
        'billMinId': item['bill_min_id']?.toString() ?? '',
        'billGameId': item['bill_game_id']?.toString() ?? '',
        'programId': item['program_id']?.toString() ?? '',
        'programName': item['program_name']?.toString() ?? '',
        'memo': item['memo']?.toString() ?? '',
        'isCancelled': item['ts_status'] == '취소' || item['ts_status'] == '예약취소',
      }).toList();
    } else {
      whereConditions.add({
        'field': 'LS_date',
        'operator': '>=',
        'value': today,
      });

      if (_selectedMemberId != null && _selectedMemberId!.isNotEmpty) {
        whereConditions.add({
          'field': 'member_id',
          'operator': '=',
          'value': int.parse(_selectedMemberId!),
        });
      }

      if (_showCancelled) {
        whereConditions.add({
          'field': 'LS_status',
          'operator': 'IN',
          'value': ['결제완료', '취소', '예약취소'],  // 예약취소도 포함
        });
      } else {
        whereConditions.add({
          'field': 'LS_status',
          'operator': '=',
          'value': '결제완료',
        });
      }

      print('🔎 [레슨] WHERE 조건: $whereConditions');

      final lessonData = await ApiService.getData(
        table: 'v2_LS_orders',
        where: whereConditions,
        orderBy: [
          {'field': 'LS_date', 'direction': 'ASC'},
          {'field': 'LS_start_time', 'direction': 'ASC'},
        ],
      );

      print('✅ [레슨] 조회 결과: ${lessonData.length}건');
      if (lessonData.isNotEmpty) {
        print('📊 [레슨] 첫번째 데이터: ${lessonData.first}');
      }

      return lessonData.map((item) => {
        'type': '레슨',
        'date': item['LS_date'].toString(),
        'startTime': _formatTime(item['LS_start_time']),
        'endTime': _formatTime(item['LS_end_time']),
        'station': item['pro_name'] ?? '',
        'status': item['LS_status'] ?? '',
        'programId': item['program_id'],
        'memberName': item['member_name'] ?? '',
        'reservationId': item['LS_orders_id']?.toString() ?? '',
        'lessonOrderId': item['LS_order_id']?.toString() ?? '',
        'billId': item['bill_id']?.toString() ?? '',
        'billMinId': item['bill_min_id']?.toString() ?? '',
        'billGameId': item['bill_game_id']?.toString() ?? '',
        'programName': item['program_name']?.toString() ?? '',
        'memo': item['memo']?.toString() ?? '',
        'isCancelled': item['LS_status'] == '취소' || item['LS_status'] == '예약취소',
      }).toList();
    }
  }

  Future<List<Map<String, dynamic>>> _getPastReservations(String type, int offset) async {
    List<Map<String, dynamic>> whereConditions = [];
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    print('🔍 [과거예약] _getPastReservations 시작');
    print('📅 오늘 날짜: $today');
    print('📋 조회 타입: $type');
    print('👤 선택된 회원 ID: $_selectedMemberId');
    print('📄 페이지 오프셋: $offset, 페이지 크기: $_pastPageSize');

    if (type == 'ts') {
      whereConditions.add({
        'field': 'ts_date',
        'operator': '<',
        'value': today,
      });

      if (_selectedMemberId != null && _selectedMemberId!.isNotEmpty) {
        whereConditions.add({
          'field': 'member_id',
          'operator': '=',
          'value': int.parse(_selectedMemberId!),
        });
      }

      if (_showCancelled) {
        whereConditions.add({
          'field': 'ts_status',
          'operator': 'IN',
          'value': ['결제완료', '취소', '예약취소'],  // 예약취소도 포함
        });
      } else {
        whereConditions.add({
          'field': 'ts_status',
          'operator': '=',
          'value': '결제완료',
        });
      }

      print('🔎 [과거타석] WHERE 조건: $whereConditions');

      final tsData = await ApiService.getData(
        table: 'v2_priced_TS',
        where: whereConditions,
        orderBy: [
          {'field': 'ts_date', 'direction': 'DESC'},
          {'field': 'ts_start', 'direction': 'DESC'},
        ],
        limit: _pastPageSize,
        offset: offset,
      );

      print('✅ [과거타석] 조회 결과: ${tsData.length}건');
      if (tsData.isNotEmpty) {
        print('📊 [과거타석] 첫번째 데이터: ${tsData.first}');
      }

      return tsData.map((item) => {
        'type': '타석',
        'date': item['ts_date'].toString(),
        'startTime': _formatTime(item['ts_start']),
        'endTime': _formatTime(item['ts_end']),
        'station': item['ts_id']?.toString() ?? '',
        'status': item['ts_status'] ?? '',
        'amount': item['net_amt'] ?? 0,
        'reservationId': item['reservation_id']?.toString() ?? '',
        'billId': item['bill_id']?.toString() ?? '',
        'billMinId': item['bill_min_id']?.toString() ?? '',
        'billGameId': item['bill_game_id']?.toString() ?? '',
        'programId': item['program_id']?.toString() ?? '',
        'programName': item['program_name']?.toString() ?? '',
        'memo': item['memo']?.toString() ?? '',
        'isCancelled': item['ts_status'] == '취소' || item['ts_status'] == '예약취소',
      }).toList();
    } else {
      whereConditions.add({
        'field': 'LS_date',
        'operator': '<',
        'value': today,
      });

      if (_selectedMemberId != null && _selectedMemberId!.isNotEmpty) {
        whereConditions.add({
          'field': 'member_id',
          'operator': '=',
          'value': int.parse(_selectedMemberId!),
        });
      }

      if (_showCancelled) {
        whereConditions.add({
          'field': 'LS_status',
          'operator': 'IN',
          'value': ['결제완료', '취소', '예약취소'],  // 예약취소도 포함
        });
      } else {
        whereConditions.add({
          'field': 'LS_status',
          'operator': '=',
          'value': '결제완료',
        });
      }

      print('🔎 [과거레슨] WHERE 조건: $whereConditions');

      final lessonData = await ApiService.getData(
        table: 'v2_LS_orders',
        where: whereConditions,
        orderBy: [
          {'field': 'LS_date', 'direction': 'DESC'},
          {'field': 'LS_start_time', 'direction': 'DESC'},
        ],
        limit: _pastPageSize,
        offset: offset,
      );

      print('✅ [과거레슨] 조회 결과: ${lessonData.length}건');
      if (lessonData.isNotEmpty) {
        print('📊 [과거레슨] 첫번째 데이터: ${lessonData.first}');
      }

      return lessonData.map((item) => {
        'type': '레슨',
        'date': item['LS_date'].toString(),
        'startTime': _formatTime(item['LS_start_time']),
        'endTime': _formatTime(item['LS_end_time']),
        'station': item['pro_name'] ?? '',
        'status': item['LS_status'] ?? '',
        'programId': item['program_id'],
        'memberName': item['member_name'] ?? '',
        'reservationId': item['LS_orders_id']?.toString() ?? '',
        'lessonOrderId': item['LS_order_id']?.toString() ?? '',
        'billId': item['bill_id']?.toString() ?? '',
        'billMinId': item['bill_min_id']?.toString() ?? '',
        'billGameId': item['bill_game_id']?.toString() ?? '',
        'programName': item['program_name']?.toString() ?? '',
        'memo': item['memo']?.toString() ?? '',
        'isCancelled': item['LS_status'] == '취소' || item['LS_status'] == '예약취소',
      }).toList();
    }
  }

  String _formatTime(dynamic timeValue) {
    if (timeValue == null) return '';
    
    String timeStr = timeValue.toString();
    
    // 이미 HH:mm 또는 HH:mm:ss 형태인 경우
    if (timeStr.contains(':')) {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      }
    }
    
    // Duration 객체인 경우 (예: 32400초 = 09:00:00)
    if (timeStr.contains('.') && timeStr.contains(':')) {
      // Duration 문자열에서 시간 부분만 추출
      final match = RegExp(r'(\d+):(\d+):(\d+)').firstMatch(timeStr);
      if (match != null) {
        final hour = int.tryParse(match.group(1)!) ?? 0;
        final minute = int.tryParse(match.group(2)!) ?? 0;
        return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      }
    }
    
    return timeStr;
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

        Expanded(child: _buildReservationList()),
      ],
    );
  }

  Widget _buildCancelledToggle() {
    return Row(
      children: [
        Text(
          '취소 포함',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
          ),
        ),
        Switch(
          value: _showCancelled,
          onChanged: (value) {
            setState(() {
              _showCancelled = value;
              _pastOffset = 0;
              _pastReservations.clear();
            });
            _loadFutureReservations();
            if (_showPastReservations) {
              _loadPastReservations();
            }
          },
          activeColor: const Color(0xFF00A86B),
        ),
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

  Widget _buildReservationList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: Colors.grey[50],
      child: CustomScrollView(
        slivers: [
          // 미래 예약
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A86B),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '다가오는 예약',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[900],
                    ),
                  ),
                  if (_futureReservations.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A86B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_futureReservations.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF00A86B),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  _buildCancelledToggle(),
                ],
              ),
            ),
          ),
          if (_futureReservations.isNotEmpty) ...[
            ..._buildGroupedReservationSlivers(_futureReservations, true),
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
                      Icons.event_available,
                      size: 48,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '다가오는 예약이 없습니다',
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

          // 지난 예약 토글
          SliverToBoxAdapter(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showPastReservations = !_showPastReservations;
                  if (!_showPastReservations) {
                    _pastReservations.clear();
                    _pastOffset = 0;
                  }
                });
                if (_showPastReservations && _pastReservations.isEmpty) {
                  _loadPastReservations();
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
                      '지난 예약',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _showPastReservations ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 지난 예약 내용
          if (_showPastReservations) ...[
            if (_isPastLoading && _pastReservations.isEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ] else if (_pastReservations.isNotEmpty) ...[
              ..._buildGroupedReservationSlivers(_pastReservations, false),
              // 더보기 버튼 - 더 불러올 데이터가 있을 때만 표시
              if (_pastReservations.length >= _pastPageSize && _pastReservations.length % _pastPageSize == 0) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: _isPastLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: () => _loadPastReservations(loadMore: true),
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
                      '지난 예약이 없습니다',
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

  Widget _buildCompactReservationCard(Map<String, dynamic> reservation) {
    final isLessonType = reservation['type'] == '레슨';
    final date = DateTime.parse(reservation['date']);
    final dateStr = DateFormat('M월 d일').format(date);
    final dayOfWeek = DateFormat('EEEE', 'ko').format(date);
    final isToday = DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isCancelled = reservation['status'] == '취소' || reservation['status'] == '예약취소';
    
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // 날짜 사이드바
              Container(
                width: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isCancelled 
                      ? [Colors.grey[400]!, Colors.grey[600]!]
                      : isToday 
                        ? [const Color(0xFF00A86B), const Color(0xFF00875A)]
                        : isLessonType
                          ? [Colors.orange[400]!, Colors.orange[600]!]
                          : [Colors.blue[400]!, Colors.blue[600]!],
                  ),
                ),
              ),
              
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // 날짜와 시간
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isCancelled ? Colors.grey[400] : Colors.grey[800],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                dayOfWeek,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isCancelled ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                              if (isToday) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00A86B).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '오늘',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF00A86B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: isCancelled ? Colors.grey[400] : const Color(0xFF00A86B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${reservation['startTime']} - ${reservation['endTime']}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isCancelled ? Colors.grey[400] : Colors.grey[900],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      const Spacer(),
                      
                      // 타석/프로 정보
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isLessonType ? Icons.school : Icons.sports_golf,
                                size: 16,
                                color: isCancelled 
                                  ? Colors.grey[400] 
                                  : isLessonType ? Colors.orange[600] : Colors.blue[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isLessonType 
                                  ? '${reservation['station']} 프로' 
                                  : '${reservation['station']}번 타석',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isCancelled 
                                    ? Colors.grey[400] 
                                    : isLessonType ? Colors.orange[600] : Colors.blue[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (reservation['isGrouped'] == true) ...[
                            Text(
                              '${reservation['groupCount']}명 그룹',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ] else if (!isLessonType && reservation['amount'] > 0) ...[
                            Text(
                              '${NumberFormat('#,###').format(reservation['amount'])}원',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isCancelled ? Colors.grey[400] : Colors.grey[700],
                              ),
                            ),
                          ],
                        ],
                      ),
                      
                      if (isCancelled) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Text(
                            '취소됨',
                            style: TextStyle(
                              color: Colors.red[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedReservationSlivers(List<Map<String, dynamic>> reservations, bool isFuture) {
    final groupedByDate = <String, List<Map<String, dynamic>>>{};
    
    // 날짜별로 그룹핑
    for (final reservation in reservations) {
      final date = reservation['date'].toString();
      if (!groupedByDate.containsKey(date)) {
        groupedByDate[date] = [];
      }
      groupedByDate[date]!.add(reservation);
    }
    
    final slivers = <Widget>[];
    
    groupedByDate.forEach((date, dateReservations) {
      final parsedDate = DateTime.parse(date);
      final dateStr = DateFormat('M월 d일').format(parsedDate);
      final dayOfWeek = DateFormat('EEEE', 'ko').format(parsedDate);
      final isToday = DateFormat('yyyy-MM-dd').format(parsedDate) == DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // 날짜 헤더
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  dayOfWeek,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A86B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '오늘',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF00A86B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
      
      // 해당 날짜의 예약들
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildSimpleReservationCard(dateReservations[index], !isFuture),
              childCount: dateReservations.length,
            ),
          ),
        ),
      );
    });
    
    return slivers;
  }

  Widget _buildSimpleReservationCard(Map<String, dynamic> reservation, bool isPast) {
    final bool isLessonType = reservation['type'] == '레슨';
    final bool isProgramType = reservation['type'] == '프로그램';
    final bool isCancelled = reservation['isCancelled'] ?? false;
    final String dateStr = DateFormat('MM.dd').format(DateTime.parse(reservation['date']));
    final String dayOfWeek = DateFormat('EEE', 'ko').format(DateTime.parse(reservation['date']));
    final bool isToday = reservation['date'] == DateFormat('yyyy-MM-dd').format(DateTime.now());

    return GestureDetector(
      onTap: () {
        if (!isCancelled) {
          _showReservationDetail(reservation);
        }
      },
      child: Container(
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
              // 타입 아이콘과 텍스트
              Container(
                width: 56,
                padding: EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isCancelled
                    ? Colors.grey[100]
                    : isProgramType
                      ? Colors.indigo.withOpacity(0.08)
                      : isLessonType
                        ? Colors.teal.withOpacity(0.08)
                        : Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCancelled
                      ? Colors.grey.withOpacity(0.2)
                      : isProgramType
                        ? Colors.indigo.withOpacity(0.2)
                        : isLessonType
                          ? Colors.teal.withOpacity(0.2)
                          : Colors.blue.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isProgramType
                        ? Icons.card_giftcard
                        : isLessonType
                          ? Icons.school
                          : Icons.sports_golf,
                      size: 24,
                      color: isCancelled
                        ? Colors.grey[400]
                        : isProgramType
                          ? Colors.indigo[600]
                          : isLessonType
                            ? Colors.teal[600]
                            : Colors.blue[600],
                    ),
                    SizedBox(height: 4),
                    Text(
                      isProgramType
                        ? '프로그램'
                        : isLessonType
                          ? '레슨'
                          : '타석',
                      style: TextStyle(
                        fontSize: 11,
                        color: isCancelled
                          ? Colors.grey[400]
                          : isProgramType
                            ? Colors.indigo[600]
                            : isLessonType
                              ? Colors.teal[600]
                              : Colors.blue[600],
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
                    // 타석/프로/프로그램 정보와 상태 마크
                    Row(
                      children: [
                        Icon(
                          isProgramType
                            ? Icons.card_giftcard
                            : isLessonType
                              ? Icons.school
                              : Icons.sports_golf,
                          size: 16,
                          color: isCancelled
                            ? Colors.grey[400]
                            : isProgramType
                              ? Colors.indigo[500]
                              : isLessonType
                                ? Colors.teal[500]
                                : Colors.blue[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isProgramType
                            ? reservation['programName']
                            : isLessonType
                              ? '${reservation['station']} 프로'
                              : '${reservation['station']}번 타석',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isCancelled
                              ? Colors.grey[400]
                              : isProgramType
                                ? Colors.indigo[600]
                                : isLessonType
                                  ? Colors.teal[600]
                                  : Colors.blue[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 오늘/완료/취소 마크
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
                        ] else if (isToday) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00A86B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF00A86B).withOpacity(0.3)),
                            ),
                            child: const Text(
                              '오늘',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF00A86B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ] else if (isPast) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey[400]!),
                            ),
                            child: Text(
                              '완료',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 시간
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: isCancelled ? Colors.grey[400] : const Color(0xFF00A86B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${reservation['startTime']} - ${reservation['endTime']}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isCancelled ? Colors.grey[400] : Colors.grey[900],
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
      ),
    );
  }

  void _showReservationDetail(Map<String, dynamic> reservation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: false,
      builder: (context) => ReservationDetailDialog(reservation: reservation),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '예약완료':
        return Colors.blue;
      case '결제완료':
        return Colors.green;
      case '취소':
      case '예약취소':
        return Colors.red;
      case '노쇼':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}