import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import 'sp_integrated_availability_service.dart';

class SpStep4SelectTs extends StatefulWidget {
  final Function(String) onTsSelected;
  final DateTime? selectedDate;
  final int? selectedProId;
  final String? selectedProName;
  final String? selectedTime;
  final List<Map<String, dynamic>>? availableTsList;
  final Map<String, dynamic> specialSettings;
  final Map<String, dynamic>? selectedMember;

  const SpStep4SelectTs({
    Key? key,
    required this.onTsSelected,
    this.selectedDate,
    this.selectedProId,
    this.selectedProName,
    this.selectedTime,
    this.availableTsList,
    required this.specialSettings,
    this.selectedMember,
  }) : super(key: key);

  @override
  State<SpStep4SelectTs> createState() => _SpStep4SelectTsState();
}

class _SpStep4SelectTsState extends State<SpStep4SelectTs> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allTsInfoList = [];
  List<Map<String, dynamic>> _availableTsOptions = [];
  Set<String> _availableTsIds = {};
  String? _selectedTsId;
  String _memberType = '';

  @override
  void initState() {
    super.initState();
    _debugPrintAllInfo();
    _loadTsInfoAndSetAvailability();
  }

  @override
  void didUpdateWidget(SpStep4SelectTs oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 가용 타석 정보가 변경된 경우 UI 업데이트
    if (widget.availableTsList != oldWidget.availableTsList) {
      print('');
      print('🔄 Step4 위젯 업데이트됨 - 가용 타석 정보 변경');
      print('이전 타석 수: ${oldWidget.availableTsList?.length ?? 0}');
      print('새로운 타석 수: ${widget.availableTsList?.length ?? 0}');
      print('');
      
      _loadTsInfoAndSetAvailability();
    }
  }

  void _debugPrintAllInfo() {
    print('');
    print('═══════════════════════════════════════════════════════════');
    print('STEP4 (타석 선택) 디버깅 정보');
    print('═══════════════════════════════════════════════════════════');

    // 기본 정보
    final branchId = ApiService.getCurrentBranchId();
    final currentUser = widget.selectedMember ?? ApiService.getCurrentUser();
    final memberId = currentUser?['member_id']?.toString();

    print('branch_id: $branchId (ApiService.getCurrentBranchId())');
    print('member_id: $memberId');
    
    // 이전 단계에서 전달받은 정보
    print('');
    print('이전 단계에서 전달받은 정보:');
    print('selectedDate: ${widget.selectedDate != null ? widget.selectedDate.toString() : 'null'}');
    print('selectedProId: ${widget.selectedProId ?? 'null'}');
    print('selectedProName: ${widget.selectedProName ?? 'null'}');
    print('selectedTime: ${widget.selectedTime ?? 'null'}');
    
    // 저장된 설정 변수들
    print('');
    print('저장된 설정 변수들:');
    widget.specialSettings.forEach((key, value) {
      print('$key = $value');
    });
    
    print('═══════════════════════════════════════════════════════════');
    print('');
  }

  Future<void> _loadTsInfoAndSetAvailability() async {
    print('');
    print('🔄 타석 정보 로드 및 가용성 설정 시작');
    
    try {
      setState(() {
        _isLoading = true;
        _allTsInfoList = [];
        _availableTsOptions = [];
        _availableTsIds = {};
        _selectedTsId = null;
      });
      
      print('✅ 1단계: 로딩 상태 설정 완료');
      
      // 1. 전체 타석 정보 조회 (상태 포함)
      final allTsInfo = await ApiService.getTsInfoWithBuffer();
      print('✅ 2단계: 전체 타석 정보 조회 완료 (${allTsInfo.length}개)');
      
      // 2. 전달받은 가용 타석 정보 사용
      Set<String> availableTsIds = {};
      if (widget.availableTsList != null) {
        for (final tsInfo in widget.availableTsList!) {
          final tsId = tsInfo['ts_id']?.toString();
          if (tsId != null) {
            availableTsIds.add(tsId);
          }
        }
      }
      
      print('✅ 3단계: 가용 타석 ID 설정 완료');
      print('   가용한 타석 ID: ${availableTsIds.toList()}');
      
      // 3. 회원 타입 조회 (member_type_prohibited 체크용)
      final currentUser = widget.selectedMember ?? ApiService.getCurrentUser();
      final memberId = currentUser?['member_id']?.toString();
      String memberType = '';
      
      if (memberId != null) {
        try {
          memberType = await ApiService.getMemberType(memberId: memberId);
          print('✅ 4단계: 회원 타입 조회 완료 - $memberType');
        } catch (e) {
          print('⚠️ 회원 타입 조회 실패: $e');
          memberType = '';
        }
      }
      
      setState(() {
        _allTsInfoList = allTsInfo;
        _availableTsIds = availableTsIds;
        _memberType = memberType;
      });
      
      print('✅ 5단계: UI 상태 업데이트 완료');
      
    } catch (e, stackTrace) {
      print('❌ 타석 정보 로드 실패: $e');
      print('❌ 스택 트레이스: $stackTrace');
      setState(() {
        _allTsInfoList = [];
        _availableTsOptions = [];
        _availableTsIds = {};
        _memberType = '';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      print('✅ 최종: 로딩 상태 해제 완료');
      print('   전체 타석 수: ${_allTsInfoList.length}');
      print('   가용한 타석 수: ${_availableTsIds.length}');
    }
  }

  // 타석 사용 가능 여부 확인 (전체 제약조건 체크)
  bool _isTsAvailable(Map<String, dynamic> tsInfo) {
    final tsId = tsInfo['ts_id']?.toString() ?? '';
    final tsStatus = tsInfo['ts_status']?.toString() ?? '';
    final memberTypeProhibited = tsInfo['member_type_prohibited']?.toString() ?? '';
    
    // 1. 타석 상태 체크
    if (tsStatus != '예약가능') {
      return false;
    }
    
    // 2. 회원 타입 제한 체크
    if (memberTypeProhibited.isNotEmpty && _memberType.isNotEmpty) {
      final prohibitedTypes = memberTypeProhibited.split(',').map((t) => t.trim()).toList();
      if (prohibitedTypes.contains(_memberType)) {
        return false;
      }
    }
    
    // 3. 시간대 충돌 체크 (가용한 타석 목록에 포함되어 있는지 확인)
    return _availableTsIds.contains(tsId);
  }

  // 비활성화 사유 반환 (구체적인 사유 제공)
  String _getDisabledReason(Map<String, dynamic> tsInfo) {
    final tsId = tsInfo['ts_id']?.toString() ?? '';
    final tsStatus = tsInfo['ts_status']?.toString() ?? '';
    final memberTypeProhibited = tsInfo['member_type_prohibited']?.toString() ?? '';
    
    // 1. 타석 상태에 따른 사유 체크
    if (tsStatus != '예약가능') {
      switch (tsStatus) {
        case '예약중지':
          return '예약중지';
        case '정비중':
          return '정비중';
        case '고장':
          return '고장';
        case '청소중':
          return '청소중';
        case '사용중지':
          return '사용중지';
        default:
          return '사용불가';
      }
    }
    
    // 2. 회원 타입 제한 체크
    if (memberTypeProhibited.isNotEmpty && _memberType.isNotEmpty) {
      final prohibitedTypes = memberTypeProhibited.split(',').map((t) => t.trim()).toList();
      if (prohibitedTypes.contains(_memberType)) {
        return '회원타입제한';
      }
    }
    
    // 3. 시간대 충돌 체크
    if (!_availableTsIds.contains(tsId)) {
      return '예약중';
    }
    
    return '';
  }

  // 타석 선택 처리
  void _selectTs(String tsId) {
    setState(() {
      _selectedTsId = tsId;
    });
    
    print('🎯 타석 선택됨: $tsId');
    widget.onTsSelected(tsId);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('타석 정보를 조회하는 중...'),
          ],
        ),
      );
    }

    if (_allTsInfoList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              '타석 정보를 찾을 수 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 선택된 시간 정보 표시
            if (widget.selectedTime != null) ...[
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFF0F9F4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color(0xFF00A86B).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: Color(0xFF00A86B),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '선택된 시간: ${widget.selectedTime}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00A86B),
                      ),
                    ),
                    Spacer(),
                    Text(
                      '가용 타석: ${_availableTsIds.length}개',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
            ],
            
            // 타석 그리드 (3열)
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.28,
              ),
              itemCount: _allTsInfoList.length,
              itemBuilder: (context, index) {
                final tsInfo = _allTsInfoList[index];
                final tsId = tsInfo['ts_id']?.toString() ?? '';
                final isAvailable = _isTsAvailable(tsInfo);
                final disabledReason = _getDisabledReason(tsInfo);
                final isSelected = _selectedTsId == tsId;
                
                return GestureDetector(
                  onTap: isAvailable ? () => _selectTs(tsId) : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Color(0xFFF0F9F4)
                          : isAvailable 
                              ? Colors.white 
                              : Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                            ? Color(0xFF00A86B) 
                            : isAvailable 
                                ? Color(0xFFE0E0E0) 
                                : Color(0xFFCCCCCC),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isAvailable ? [
                        BoxShadow(
                          color: isSelected 
                              ? Color(0xFF00A86B).withOpacity(0.2)
                              : Colors.black.withOpacity(0.05),
                          blurRadius: isSelected ? 8 : 4,
                          offset: Offset(0, isSelected ? 3 : 2),
                        ),
                      ] : null,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 불가 사유 (타석 번호 위에 표시)
                          if (!isAvailable) ...[
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Color(0xFFE53E3E).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Color(0xFFE53E3E).withOpacity(0.3),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                disabledReason,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFE53E3E),
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(height: 6),
                          ],
                          
                          // 타석 아이콘 (활성화된 타석만)
                          if (isAvailable) ...[
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? Color(0xFF00A86B).withOpacity(0.1)
                                    : Color(0xFF06B6D4).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.sports_golf,
                                size: 22,
                                color: isSelected ? Color(0xFF00A86B) : Color(0xFF06B6D4),
                              ),
                            ),
                            SizedBox(height: 6),
                          ],
                          
                          // 타석 번호
                          Text(
                            '${tsId}번 타석',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isAvailable 
                                  ? (isSelected ? Color(0xFF00A86B) : Color(0xFF333333))
                                  : Color(0xFF999999),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
} 