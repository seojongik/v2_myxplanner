import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../search/reservation_history/reservation_detail_dialog.dart';

class TodayReservationsWidget extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const TodayReservationsWidget({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _TodayReservationsWidgetState createState() => _TodayReservationsWidgetState();
}

class _TodayReservationsWidgetState extends State<TodayReservationsWidget> {
  List<Map<String, dynamic>> _todayReservations = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTodayReservations();
  }

  @override
  void didUpdateWidget(TodayReservationsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMember != widget.selectedMember) {
      _loadTodayReservations();
    }
  }

  Future<void> _loadTodayReservations() async {
    setState(() {
      _isLoading = true;
      _todayReservations = [];
    });

    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      List<Map<String, dynamic>> allReservations = [];
      
      // 회원 ID가 있을 때만 조회
      if (widget.selectedMember != null) {
        final memberId = widget.selectedMember!['member_id'];
        
        // 타석 예약 조회
        final tsReservations = await _getTsReservations(memberId, today);
        allReservations.addAll(tsReservations);
        
        // 레슨 예약 조회
        final lessonReservations = await _getLessonReservations(memberId, today);
        allReservations.addAll(lessonReservations);
      }
      
      // program_id로 그룹핑
      final groupedReservations = _groupProgramReservations(allReservations);
      
      // 시간순 정렬
      groupedReservations.sort((a, b) {
        final timeA = a['startTime'] ?? '';
        final timeB = b['startTime'] ?? '';
        return timeA.compareTo(timeB);
      });
      
      setState(() {
        _todayReservations = groupedReservations;
      });
    } catch (e) {
      print('Failed to load today reservations: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getTsReservations(dynamic memberId, String date) async {
    List<Map<String, dynamic>> whereConditions = [
      {'field': 'ts_date', 'operator': '=', 'value': date},
      {'field': 'member_id', 'operator': '=', 'value': memberId},
      {'field': 'ts_status', 'operator': '=', 'value': '결제완료'},
    ];
    
    final tsData = await ApiService.getData(
      table: 'v2_priced_TS',
      where: whereConditions,
      orderBy: [
        {'field': 'ts_start', 'direction': 'ASC'},
      ],
    );
    
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
      'isCancelled': item['ts_status'] == '예약취소',
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _getLessonReservations(dynamic memberId, String date) async {
    List<Map<String, dynamic>> whereConditions = [
      {'field': 'LS_date', 'operator': '=', 'value': date},
      {'field': 'member_id', 'operator': '=', 'value': memberId},
      {'field': 'LS_status', 'operator': 'IN', 'value': ['예약완료', '결제완료']},
    ];
    
    final lessonData = await ApiService.getData(
      table: 'v2_LS_orders',
      where: whereConditions,
      orderBy: [
        {'field': 'LS_start_time', 'direction': 'ASC'},
      ],
    );
    
    return lessonData.map((item) => {
      'type': '레슨',
      'date': item['LS_date'].toString(),
      'startTime': _formatTime(item['LS_start_time']),
      'endTime': _formatTime(item['LS_end_time']),
      'station': item['pro_name']?.toString() ?? '',
      'status': item['LS_status'] ?? '',
      'lessonOrderId': item['LS_order_id']?.toString() ?? '',
      'billId': item['bill_id']?.toString() ?? '',
      'billMinId': item['bill_min_id']?.toString() ?? '',
      'billGameId': item['bill_game_id']?.toString() ?? '',
      'programId': item['program_id']?.toString() ?? '',
      'programName': item['program_name']?.toString() ?? '',
      'memo': item['memo']?.toString() ?? '',
      'isCancelled': item['LS_status'] == '예약취소',
    }).toList();
  }

  List<Map<String, dynamic>> _groupProgramReservations(List<Map<String, dynamic>> reservations) {
    final Map<String, List<Map<String, dynamic>>> programGroups = {};
    final List<Map<String, dynamic>> result = [];
    
    // 프로그램별로 그룹핑
    for (final reservation in reservations) {
      final programId = reservation['programId']?.toString() ?? '';
      
      if (programId.isNotEmpty && programId != 'null') {
        if (!programGroups.containsKey(programId)) {
          programGroups[programId] = [];
        }
        programGroups[programId]!.add(reservation);
      } else {
        // 프로그램이 없는 개별 예약
        result.add(reservation);
      }
    }
    
    // 프로그램 그룹 처리
    for (final group in programGroups.values) {
      if (group.length == 1) {
        // 프로그램이지만 단일 예약인 경우
        result.add(group.first);
      } else {
        // 여러 예약이 묶인 프로그램
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

  String _formatTime(dynamic time) {
    if (time == null) return '';
    String timeStr = time.toString();
    
    // 이미 HH:mm:ss 형식인 경우
    if (timeStr.contains(':')) {
      return timeStr.split(':').take(2).join(':'); // HH:mm만 반환
    }
    
    // HHMM 형식인 경우
    if (timeStr.length == 4) {
      return '${timeStr.substring(0, 2)}:${timeStr.substring(2)}';
    }
    
    return timeStr;
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    
    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 24,
                color: const Color(0xFF00A86B),
              ),
              const SizedBox(width: 10),
              Text(
                '오늘의 예약',
                style: TextStyle(
                  fontSize: isSmallScreen ? 18.0 : 20.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              if (_todayReservations.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A86B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_todayReservations.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00A86B),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_todayReservations.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.event_available,
                    size: 36,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '오늘 예약이 없습니다',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          else
            ..._todayReservations.map((reservation) => _buildReservationTile(reservation)),
        ],
      ),
    );
  }

  Widget _buildReservationTile(Map<String, dynamic> reservation) {
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
                        // 오늘/취소 마크
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
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (BuildContext context) {
        return ReservationDetailDialog(
          reservation: reservation,
        );
      },
    ).then((_) {
      // 다이얼로그가 닫힐 때 예약 목록 새로고침
      _loadTodayReservations();
    });
  }
}