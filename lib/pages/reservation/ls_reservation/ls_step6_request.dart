import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LsStep6Request extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;
  final DateTime? selectedDate;
  final String? selectedInstructor;
  final String? selectedTime;
  final int? selectedDuration;
  final dynamic selectedMembership;
  final Function(String) onRequestSubmitted;
  final String? requestText;
  final Map<String, dynamic>? lessonCountingData;
  final Map<String, Map<String, dynamic>> proInfoMap;
  final Map<String, Map<String, Map<String, dynamic>>> proScheduleMap;

  const LsStep6Request({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
    this.selectedDate,
    this.selectedInstructor,
    this.selectedTime,
    this.selectedDuration,
    this.selectedMembership,
    required this.onRequestSubmitted,
    this.requestText,
    this.lessonCountingData,
    required this.proInfoMap,
    required this.proScheduleMap,
  }) : super(key: key);

  @override
  _LsStep6RequestState createState() => _LsStep6RequestState();
}

class _LsStep6RequestState extends State<LsStep6Request> {
  final TextEditingController _requestController = TextEditingController();
  List<String> _selectedFocusAreas = []; // 복수 선택을 위해 List로 변경
  
  // 집중 분야 버튼 목록 (9개 - 3열 3행)
  final List<String> _focusAreas = [
    '드라이버', '아이언', '숏게임',
    '스윙템포', '스윙플레인', '임팩트',
    '게임운영', '스윙기초', '모름',
  ];

  @override
  void initState() {
    super.initState();
    _requestController.text = widget.requestText ?? '';
    
    // 전달받은 레슨 정보 출력
    if (widget.selectedMembership is Map<String, dynamic>) {
      final lessonInfo = widget.selectedMembership as Map<String, dynamic>;
      print('\n=== Step6에서 받은 레슨 정보 ===');
      print('pro_id: ${lessonInfo['pro_id']}');
      print('pro_name: ${lessonInfo['pro_name']}');
      print('LS_start_time: ${lessonInfo['LS_start_time']}');
      print('LS_net_min: ${lessonInfo['LS_net_min']}분');
      print('LS_end_time: ${lessonInfo['LS_end_time']}');
      print('LS_contract_id: ${lessonInfo['LS_contract_id']}');
      print('LS_counting_id: ${lessonInfo['LS_counting_id']}');
      print('LS_balance_min_before: ${lessonInfo['LS_balance_min_before']}');
      print('LS_balance_min_after: ${lessonInfo['LS_balance_min_after']}');
      print('LS_expiry_date: ${lessonInfo['LS_expiry_date']}');
      print('contract_name: ${lessonInfo['contract_name']}');
      print('===============================\n');
    }
  }

  void _onFocusAreaSelected(String focusArea) {
    setState(() {
      if (_selectedFocusAreas.contains(focusArea)) {
        _selectedFocusAreas.remove(focusArea); // 이미 선택된 경우 제거
      } else {
        _selectedFocusAreas.add(focusArea); // 새로 선택
      }
    });
    _updateRequestText();
  }

  void _updateRequestText() {
    String fullRequest = '';
    
    // 선택된 집중 분야들이 있으면 추가
    if (_selectedFocusAreas.isNotEmpty) {
      fullRequest += '집중 분야: ${_selectedFocusAreas.join(', ')}';
    }
    
    // 추가 요청사항이 있으면 추가
    String additionalRequest = _requestController.text.trim();
    if (additionalRequest.isNotEmpty) {
      if (fullRequest.isNotEmpty) {
        fullRequest += '\n추가 요청사항: $additionalRequest';
      } else {
        fullRequest = additionalRequest;
      }
    }
    
    widget.onRequestSubmitted(fullRequest);
    
    // LS_request 형식으로 출력
    if (fullRequest.isNotEmpty) {
      String lsRequest = '';
      
      // 집중 분야들을 쉼표로 연결
      if (_selectedFocusAreas.isNotEmpty) {
        lsRequest += _selectedFocusAreas.join(',');
      }
      
      // 추가 요청사항을 /로 구분하여 추가
      if (additionalRequest.isNotEmpty) {
        if (lsRequest.isNotEmpty) {
          lsRequest += '/$additionalRequest';
        } else {
          lsRequest = additionalRequest;
        }
      }
      
      // 레슨 정보와 함께 출력
      if (widget.selectedMembership is Map<String, dynamic>) {
        final lessonInfo = widget.selectedMembership as Map<String, dynamic>;
        print('\n=== Step6에서 받은 레슨 정보 ===');
        print('pro_id: ${lessonInfo['pro_id']}');
        print('pro_name: ${lessonInfo['pro_name']}');
        print('LS_start_time: ${lessonInfo['LS_start_time']}');
        print('LS_net_min: ${lessonInfo['LS_net_min']}분');
        print('LS_end_time: ${lessonInfo['LS_end_time']}');
        print('LS_contract_id: ${lessonInfo['LS_contract_id']}');
        print('LS_counting_id: ${lessonInfo['LS_counting_id']}');
        print('LS_balance_min_before: ${lessonInfo['LS_balance_min_before']}');
        print('LS_balance_min_after: ${lessonInfo['LS_balance_min_after']}');
        print('LS_expiry_date: ${lessonInfo['LS_expiry_date']}');
        print('contract_name: ${lessonInfo['contract_name']}');
        print('LS_request: $lsRequest');
        print('===============================\n');
      }
    }
  }

  Widget _buildLessonInfoCard() {
    if (widget.selectedMembership is! Map<String, dynamic>) {
      return SizedBox.shrink();
    }

    final lessonInfo = widget.selectedMembership as Map<String, dynamic>;
    final dateStr = widget.selectedDate != null 
        ? DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(widget.selectedDate!)
        : '';

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '레슨 예약 정보',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: 12),
          _buildInfoRow('날짜', dateStr, Icons.calendar_today),
          _buildInfoRow('강사', '${lessonInfo['pro_name']} 프로', Icons.person),
          _buildInfoRow('시간', '${lessonInfo['LS_start_time']} ~ ${lessonInfo['LS_end_time']}', Icons.access_time),
          _buildInfoRow('레슨시간', '${lessonInfo['LS_net_min']}분', Icons.timer),
          _buildInfoRow('계약', '${lessonInfo['contract_name']}', Icons.description),
          _buildInfoRow('사용 후 잔여', '${lessonInfo['LS_balance_min_after']}분', Icons.hourglass_bottom),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Color(0xFF6B7280),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusAreaButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '이번 레슨에서 집중하고 싶은 분야를 선택해주세요.',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        SizedBox(height: 16),
        
        // 3열 3행 버튼 배치
        for (int row = 0; row < 3; row++)
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                for (int col = 0; col < 3; col++) ...[
                  Expanded(
                    child: _buildFocusButton(_focusAreas[row * 3 + col]),
                  ),
                  if (col < 2) SizedBox(width: 8),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFocusButton(String focusArea) {
    final isSelected = _selectedFocusAreas.contains(focusArea);
    
    return GestureDetector(
      onTap: () => _onFocusAreaSelected(focusArea),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF10B981) : Colors.white,
          border: Border.all(
            color: isSelected ? Color(0xFF10B981) : Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Color(0xFF10B981).withOpacity(0.2),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
          ],
        ),
        child: Text(
          focusArea,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Color(0xFF374151),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 집중 분야 선택 버튼들
          _buildFocusAreaButtons(),
          
          SizedBox(height: 24),
          
          // 추가 요청사항 입력
          Text(
            '추가 요청사항',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _requestController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '예: 백스윙 자세를 중점적으로 봐주세요',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
                hintStyle: TextStyle(
                  color: Color(0xFF9CA3AF),
                ),
              ),
              onChanged: (value) {
                _updateRequestText();
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _requestController.dispose();
    super.dispose();
  }
} 