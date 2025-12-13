import 'package:flutter/material.dart';
import '/services/api_service.dart';
import '/services/supabase_adapter.dart';
import '/constants/font_sizes.dart';

// 읽기 전용 회원권 상세 뷰어
class ContractViewerDialog extends StatefulWidget {
  final int contractHistoryId;

  const ContractViewerDialog({
    Key? key,
    required this.contractHistoryId,
  }) : super(key: key);

  @override
  State<ContractViewerDialog> createState() => _ContractViewerDialogState();
}

// 타임라인 세션 데이터 클래스
class TimelineSession {
  String type; // 'lesson' or 'break'
  int duration;
  
  TimelineSession({required this.type, required this.duration});
}

class _ContractViewerDialogState extends State<ContractViewerDialog> {
  Map<String, dynamic>? contractData;
  Map<String, dynamic>? programData;
  bool isLoading = true;
  bool isLoadingProgram = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadContractData();
  }

  Future<void> _loadContractData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // 1. contract_history_id로 contract_id 조회
      final historyData = await ApiService.getDataList(
        table: 'v3_contract_history',
        where: [
          {
            'field': 'contract_history_id',
            'operator': '=',
            'value': widget.contractHistoryId,
          },
          {
            'field': 'branch_id',
            'operator': '=',
            'value': ApiService.getCurrentBranchId(),
          }
        ],
        limit: 1,
      );

      if (historyData.isEmpty) {
        throw Exception('계약 이력을 찾을 수 없습니다');
      }

      final contractId = historyData[0]['contract_id'];

      // 2. contract_id로 회원권 상세 정보 조회
      final contracts = await ApiService.getDataList(
        table: 'v2_contracts',
        fields: [
          'contract_id', 'contract_type', 'contract_name', 'contract_credit',
          'contract_LS_min', 'contract_games', 'contract_TS_min', 'contract_term_month',
          'contract_status', 'price', 'effect_month', 'sell_by_credit_price',
          'contract_category', 'LS_type', 'branch_id', 'available_days',
          'available_start_time', 'available_end_time', 'contract_credit_effect_month',
          'contract_LS_min_effect_month', 'contract_games_effect_month',
          'contract_TS_min_effect_month', 'contract_term_month_effect_month',
          'available_ts_id', 'program_reservation_availability', 'max_min_reservation_ahead',
          'coupon_issue_available', 'coupon_use_available', 'max_ts_use_min',
          'max_use_per_day', 'max_ls_min_session', 'max_ls_per_day', 'prohibited_ts_id', 'prohibited_TS_id'
        ],
        where: [
          {
            'field': 'contract_id',
            'operator': '=',
            'value': contractId,
          },
          {
            'field': 'branch_id',
            'operator': '=',
            'value': ApiService.getCurrentBranchId(),
          }
        ],
        limit: 1,
      );

      if (contracts.isEmpty) {
        throw Exception('회원권 정보를 찾을 수 없습니다');
      }

      setState(() {
        contractData = contracts[0];
        isLoading = false;
      });
      
      // 프로그램 정보가 있으면 로드
      final programId = contracts[0]['program_reservation_availability']?.toString();
      if (programId != null && programId.isNotEmpty && programId != 'null') {
        await _loadProgramData(programId);
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // 프로그램 데이터 로드
  Future<void> _loadProgramData(String programId) async {
    try {
      setState(() {
        isLoadingProgram = true;
      });

      // programId로 프로그램 이름 조회
      String? programName;
      try {
        final programNameData = await SupabaseAdapter.getData(
          table: 'v2_base_option_setting',
          where: [
            {'field': 'category', 'operator': '=', 'value': '특수타석예약'},
            {'field': 'field_name', 'operator': '=', 'value': 'program_id'},
            {'field': 'option_value', 'operator': '=', 'value': programId},
          ],
          limit: 1,
        );
        
        if (programNameData.isNotEmpty) {
          programName = programNameData[0]['table_name']?.toString();
        }
      } catch (e) {
        print('프로그램 이름 조회 오류: $e');
      }

      // 프로그램 이름이 없으면 programId를 그대로 사용
      final searchName = programName ?? programId;

      // v2_base_option_setting 테이블에서 조회
      final result = await SupabaseAdapter.getData(
        table: 'v2_base_option_setting',
        where: [
          {'field': 'category', 'operator': '=', 'value': '특수타석예약'},
          {'field': 'table_name', 'operator': '=', 'value': searchName},
        ],
        orderBy: [
          {'field': 'field_name', 'direction': 'ASC'}
        ],
      );

      // 프로그램 데이터 분석
      final analyzedData = _analyzeProgramData(result);
      
      print('🔍 [Program] programId: $programId, programName: $programName, searchName: $searchName');
      print('🔍 [Program] 조회된 데이터 수: ${result.length}');
      print('🔍 [Program] 분석된 데이터: $analyzedData');
      print('🔍 [Program] 타임라인 세션 수: ${analyzedData['timeline'].length}');

      setState(() {
        programData = analyzedData;
        isLoadingProgram = false;
      });
    } catch (e) {
      print('프로그램 데이터 로드 오류: $e');
      setState(() {
        isLoadingProgram = false;
      });
    }
  }

  // 프로그램 데이터 분석
  Map<String, dynamic> _analyzeProgramData(List<Map<String, dynamic>> settings) {
    int tsMin = 0;
    List<Map<String, dynamic>> timelineSessions = [];
    int minPlayerNo = 0;
    int maxPlayerNo = 0;
    String status = '유효';
    
    for (var setting in settings) {
      final fieldName = setting['field_name'] ?? '';
      final optionValue = setting['option_value'] ?? '';
      final settingStatus = setting['setting_status'] ?? '';
      
      if (settingStatus != '유효') {
        status = settingStatus;
      }
      
      switch (fieldName) {
        case 'ts_min':
          tsMin = int.tryParse(optionValue) ?? 0;
          break;
        case 'min_player_no':
          minPlayerNo = int.tryParse(optionValue) ?? 0;
          break;
        case 'max_player_no':
          maxPlayerNo = int.tryParse(optionValue) ?? 0;
          break;
        default:
          // ls_min(1), ls_break_min(2) 형식의 필드명 처리
          RegExp regExp = RegExp(r'^(ls_min|ls_break_min)\((\d+)\)$');
          Match? match = regExp.firstMatch(fieldName);
          if (match != null) {
            String sessionType = match.group(1)!;
            int order = int.tryParse(match.group(2)!) ?? 0;
            int duration = int.tryParse(optionValue) ?? 0;
            
            timelineSessions.add({
              'type': sessionType == 'ls_min' ? 'lesson' : 'break',
              'duration': duration,
              'order': order,
            });
          }
          break;
      }
    }
    
    // 순서대로 정렬
    timelineSessions.sort((a, b) => a['order'].compareTo(b['order']));
    
    // TimelineSession 객체 리스트로 변환
    List<TimelineSession> timeline = timelineSessions.map((session) => 
      TimelineSession(
        type: session['type'],
        duration: session['duration'],
      )
    ).toList();
    
    return {
      'ts_min': tsMin,
      'timeline': timeline,
      'total_lesson_time': timeline.where((s) => s.type == 'lesson').fold<int>(0, (a, b) => a + b.duration),
      'total_break_time': timeline.where((s) => s.type == 'break').fold<int>(0, (a, b) => a + b.duration),
      'lesson_count': timeline.where((s) => s.type == 'lesson').length,
      'min_player_no': minPlayerNo,
      'max_player_no': maxPlayerNo,
      'status': status,
    };
  }

  // 타임라인 미리보기 위젯
  Widget _buildTimelinePreview(List<TimelineSession> timeline) {
    if (timeline.isEmpty) return Container();
    
    int totalDuration = timeline.fold<int>(0, (a, b) => a + b.duration);
    
    return Container(
      height: 40,
      child: Row(
        children: timeline.map((session) {
          double width = (session.duration / totalDuration) * 400; // 최대 400px
          return Container(
            width: width < 40 ? 40 : width, // 최소 너비 40px
            height: 40,
            margin: EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: session.type == 'lesson' ? Color(0xFF3B82F6) : Color(0xFF9CA3AF),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                '${session.duration}분',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 요약 칩 위젯
  Widget _buildSummaryChip(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0원';
    final int priceInt = price is int ? price : int.tryParse(price.toString()) ?? 0;
    final formatted = priceInt.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$formatted원';
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case '패키지':
        return Color(0xFF6366F1);
      case '선불크레딧':
        return Color(0xFF10B981);
      case '레슨권':
        return Color(0xFFF59E0B);
      case '시간권':
        return Color(0xFFEF4444);
      case '기간권':
        return Color(0xFF8B5CF6);
      default:
        return Color(0xFF64748B);
    }
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTextStyles.cardBody.copyWith(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.cardBody.copyWith(
                color: valueColor ?? Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Color(0xFF64748B),
                ),
                SizedBox(width: 8),
                Text(
                  title,
                  style: AppTextStyles.cardBody.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 600,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.card_membership,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '회원권 상세 정보',
                          style: AppTextStyles.titleH3.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (contractData != null)
                          Text(
                            contractData!['contract_name'] ?? '',
                            style: AppTextStyles.cardBody.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            // 본문
            Expanded(
              child: isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Color(0xFF3B82F6),
                          ),
                          SizedBox(height: 16),
                          Text(
                            '회원권 정보를 불러오는 중...',
                            style: AppTextStyles.cardBody.copyWith(
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    )
                  : errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Color(0xFFDC2626),
                              ),
                              SizedBox(height: 16),
                              Text(
                                '오류가 발생했습니다',
                                style: AppTextStyles.cardBody.copyWith(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                errorMessage!,
                                style: AppTextStyles.cardMeta.copyWith(
                                  color: Color(0xFF94A3B8),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 기본 정보
                              _buildSection(
                                '기본 정보',
                                [
                                  _buildInfoRow('회원권 ID', contractData!['contract_id'] ?? '-'),
                                  _buildInfoRow(
                                    '회원권 유형',
                                    contractData!['contract_type'] ?? '-',
                                    valueColor: _getTypeColor(contractData!['contract_type']),
                                  ),
                                  _buildInfoRow('회원권 이름', contractData!['contract_name'] ?? '-'),
                                  _buildInfoRow(
                                    '판매 가격',
                                    _formatPrice(contractData!['price']),
                                    valueColor: Color(0xFF059669),
                                  ),
                                  _buildInfoRow(
                                    '상태',
                                    contractData!['contract_status'] ?? '유효',
                                    valueColor: contractData!['contract_status'] == '유효'
                                        ? Color(0xFF059669)
                                        : Color(0xFFDC2626),
                                  ),
                                ],
                              ),

                              // 제공 혜택
                              if (_hasAnyBenefit()) ...[
                                _buildSection(
                                  '제공 혜택',
                                  [
                                    if ((contractData!['contract_credit'] ?? 0) > 0)
                                      _buildInfoRow(
                                        '선불크레딧',
                                        _formatPrice(contractData!['contract_credit']),
                                        valueColor: Color(0xFFFFA500),
                                      ),
                                    if ((contractData!['contract_LS_min'] ?? 0) > 0)
                                      _buildInfoRow(
                                        '레슨권',
                                        '${contractData!['contract_LS_min']}분',
                                        valueColor: Color(0xFF2563EB),
                                      ),
                                    if ((contractData!['contract_games'] ?? 0) > 0)
                                      _buildInfoRow(
                                        '스크린게임',
                                        '${contractData!['contract_games']}회',
                                        valueColor: Color(0xFF8B5CF6),
                                      ),
                                    if ((contractData!['contract_TS_min'] ?? 0) > 0)
                                      _buildInfoRow(
                                        '타석시간',
                                        '${contractData!['contract_TS_min']}분',
                                        valueColor: Color(0xFF10B981),
                                      ),
                                    if ((contractData!['contract_term_month'] ?? 0) > 0)
                                      _buildInfoRow(
                                        '기간권',
                                        '${contractData!['contract_term_month']}개월',
                                        valueColor: Color(0xFF0D9488),
                                      ),
                                  ],
                                ),
                              ],

                              // 유효기간 정보
                              _buildSection(
                                '유효기간 정보',
                                [
                                  _buildInfoRow(
                                    '회원권 유효기간',
                                    contractData!['effect_month'] != null
                                        ? '${contractData!['effect_month']}개월'
                                        : '무제한',
                                  ),
                                  if (contractData!['contract_credit_effect_month'] != null &&
                                      contractData!['contract_credit_effect_month'] > 0)
                                    _buildInfoRow(
                                      '크레딧 유효기간',
                                      '${contractData!['contract_credit_effect_month']}개월',
                                    ),
                                  if (contractData!['contract_LS_min_effect_month'] != null &&
                                      contractData!['contract_LS_min_effect_month'] > 0)
                                    _buildInfoRow(
                                      '레슨 유효기간',
                                      '${contractData!['contract_LS_min_effect_month']}개월',
                                    ),
                                  if (contractData!['contract_games_effect_month'] != null &&
                                      contractData!['contract_games_effect_month'] > 0)
                                    _buildInfoRow(
                                      '게임 유효기간',
                                      '${contractData!['contract_games_effect_month']}개월',
                                    ),
                                  if (contractData!['contract_TS_min_effect_month'] != null &&
                                      contractData!['contract_TS_min_effect_month'] > 0)
                                    _buildInfoRow(
                                      '타석시간 유효기간',
                                      '${contractData!['contract_TS_min_effect_month']}개월',
                                    ),
                                ],
                              ),

                              // 이용 제한
                              _buildSection(
                                '이용 제한',
                                [
                                  _buildInfoRow(
                                    '이용가능 요일',
                                    _formatAvailableDays(contractData!['available_days']),
                                  ),
                                  _buildInfoRow(
                                    '이용가능 시간',
                                    _formatAvailableTime(
                                      contractData!['available_start_time'],
                                      contractData!['available_end_time'],
                                    ),
                                  ),
                                  _buildInfoRow(
                                    '선택가능 타석제한',
                                    () {
                                      // PostgreSQL은 소문자로 변환하지만, 실제 데이터는 prohibited_TS_id로 들어올 수 있음
                                      final prohibitedTsId = contractData!['prohibited_ts_id'] ?? contractData!['prohibited_TS_id'];
                                      
                                      if (prohibitedTsId == null) {
                                        return '전체 타석 선택가능';
                                      }
                                      
                                      final prohibitedTsIdStr = prohibitedTsId.toString().trim();
                                      
                                      if (prohibitedTsIdStr.isEmpty || prohibitedTsIdStr == 'null' || prohibitedTsIdStr == 'NULL') {
                                        return '전체 타석 선택가능';
                                      }
                                      
                                      final tsIds = prohibitedTsIdStr.split(',').map((id) => id.trim()).where((id) => id.isNotEmpty).toList();
                                      
                                      if (tsIds.isEmpty) {
                                        return '전체 타석 선택가능';
                                      }
                                      
                                      return '${tsIds.join(', ')}번 제한';
                                    }(),
                                  ),
                                ],
                              ),

                              // 기타 설정
                              _buildSection(
                                '기타 설정',
                                [
                                  _buildInfoRow(
                                    '선불크레딧 결제',
                                    (contractData!['sell_by_credit_price'] ?? 0) > 0
                                        ? '허용 (${_formatPrice(contractData!['sell_by_credit_price'])})'
                                        : '불허용',
                                  ),
                                ],
                              ),

                              // 프로그램 상세 정보
                              if (contractData!['program_reservation_availability'] != null &&
                                  contractData!['program_reservation_availability'].toString().isNotEmpty &&
                                  contractData!['program_reservation_availability'].toString() != 'null') ...[
                                if (isLoadingProgram)
                                  Container(
                                    padding: EdgeInsets.all(24),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          CircularProgressIndicator(
                                            color: Color(0xFF6366F1),
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            '프로그램 정보를 불러오는 중...',
                                            style: AppTextStyles.cardBody.copyWith(
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else if (programData != null) ...[
                                  // 기본 정보
                                  _buildSection(
                                    '프로그램 기본 정보',
                                    [
                                      _buildInfoRow('프로그램 ID', contractData!['program_reservation_availability'].toString()),
                                      _buildInfoRow('프로그램시간', '${programData!['ts_min']}분'),
                                      _buildInfoRow('최소인원', '${programData!['min_player_no']}명'),
                                      _buildInfoRow('최대인원', '${programData!['max_player_no']}명'),
                                      _buildInfoRow(
                                        '상태',
                                        programData!['status'],
                                        valueColor: programData!['status'] == '유효'
                                            ? Color(0xFF059669)
                                            : Color(0xFFDC2626),
                                      ),
                                    ],
                                  ),

                                  // 타임라인 미리보기
                                  if (programData!['timeline'].isNotEmpty) ...[
                                    _buildSection(
                                      '타임라인 미리보기',
                                      [
                                        _buildTimelinePreview(programData!['timeline']),
                                        SizedBox(height: 12),
                                        Row(
                                          children: [
                                            _buildSummaryChip('레슨', '${programData!['total_lesson_time']}분', Color(0xFF3B82F6)),
                                            SizedBox(width: 6),
                                            _buildSummaryChip('자체연습', '${programData!['total_break_time']}분', Color(0xFF9CA3AF)),
                                            SizedBox(width: 6),
                                            _buildSummaryChip('총시간', '${programData!['ts_min']}분', Color(0xFF6366F1)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ],
                            ],
                          ),
                        ),
            ),
            // 하단 버튼
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF64748B),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      '닫기',
                      style: AppTextStyles.button.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasAnyBenefit() {
    return (contractData!['contract_credit'] ?? 0) > 0 ||
        (contractData!['contract_LS_min'] ?? 0) > 0 ||
        (contractData!['contract_games'] ?? 0) > 0 ||
        (contractData!['contract_TS_min'] ?? 0) > 0 ||
        (contractData!['contract_term_month'] ?? 0) > 0;
  }

  String _formatAvailableDays(dynamic days) {
    if (days == null || days.toString().isEmpty || days.toString() == '전체') {
      return '전체 요일';
    }
    
    final daysList = days.toString().split(',');
    final weekdays = ['월', '화', '수', '목', '금'];
    final weekends = ['토', '일'];
    
    final hasAllWeekdays = weekdays.every((day) => daysList.contains(day));
    final hasAllWeekends = weekends.every((day) => daysList.contains(day));
    final hasHoliday = daysList.contains('공휴일');
    
    if (hasAllWeekdays && hasAllWeekends && hasHoliday) {
      return '전체 요일';
    } else if (hasAllWeekdays && !hasAllWeekends && !hasHoliday) {
      return '평일';
    } else if (!hasAllWeekdays && hasAllWeekends && !hasHoliday) {
      return '주말';
    } else if (!hasAllWeekdays && hasAllWeekends && hasHoliday) {
      return '주말 및 공휴일';
    }
    
    return days.toString();
  }

  String _formatAvailableTime(dynamic startTime, dynamic endTime) {
    if (startTime == null || endTime == null || 
        startTime.toString().isEmpty || endTime.toString().isEmpty) {
      return '전체 시간';
    }
    
    String start = startTime.toString();
    String end = endTime.toString();
    
    // 초 단위 제거
    if (start.length > 5) start = start.substring(0, 5);
    if (end.length > 5) end = end.substring(0, 5);
    
    if (start == '00:00' && end == '00:00') {
      return '전체 시간';
    }
    
    return '$start ~ $end';
  }
}