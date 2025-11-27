import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';

class Step3SelectDuration extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;
  final DateTime? selectedDate;
  final String? selectedTime;
  final Function(int)? onDurationSelected;

  const Step3SelectDuration({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
    this.selectedDate,
    this.selectedTime,
    this.onDurationSelected,
  }) : super(key: key);

  @override
  _Step3SelectDurationState createState() => _Step3SelectDurationState();
}

class _Step3SelectDurationState extends State<Step3SelectDuration> {
  double _selectedDuration = 60; // 기본 60분
  double _minDuration = 30;      // 최소 30분
  double _maxDuration = 180;     // 최대 180분
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadTsInfo();
  }

  // 타석 정보 조회
  Future<void> _loadTsInfo() async {
    try {
      print('=== 타석 정보 조회 시작 ===');
      
      final tsInfoList = await ApiService.getTsInfo();
      
      if (tsInfoList.isNotEmpty) {
        // 모든 타석의 최소/최대/기본값 수집
        List<double> minimums = [];
        List<double> maximums = [];
        List<double> bases = [];
        
        for (final tsInfo in tsInfoList) {
          final minMinimum = double.tryParse(tsInfo['ts_min_minimum']?.toString() ?? '30') ?? 30;
          final minMaximum = double.tryParse(tsInfo['ts_min_maximum']?.toString() ?? '180') ?? 180;
          final minBase = double.tryParse(tsInfo['ts_min_base']?.toString() ?? '60') ?? 60;
          
          minimums.add(minMinimum);
          maximums.add(minMaximum);
          bases.add(minBase);
          
          print('타석 ${tsInfo['ts_id']}: 최소=${minMinimum}분, 최대=${minMaximum}분, 기본=${minBase}분');
        }
        
        // 전체 타석 중에서 최소값, 최대값, 평균 기본값 계산
        _minDuration = minimums.reduce((a, b) => a < b ? a : b);
        _maxDuration = maximums.reduce((a, b) => a > b ? a : b);
        _selectedDuration = bases.reduce((a, b) => a + b) / bases.length; // 평균값
        
        // 5분 단위로 조정
        _selectedDuration = (_selectedDuration / 5).round() * 5.0;
        
        print('=== 계산된 슬라이더 값 ===');
        print('최소값: ${_minDuration}분');
        print('최대값: ${_maxDuration}분');
        print('초기값: ${_selectedDuration}분');
        
        // 초기 선택값 콜백 호출
        if (widget.onDurationSelected != null) {
          widget.onDurationSelected!(_selectedDuration.toInt());
        }
      } else {
        print('타석 정보가 없음 - 기본값 사용');
      }
      
      setState(() {
        _isLoading = false;
      });
      
    } catch (e) {
      print('타석 정보 조회 실패: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 시간을 분 형식으로 변환 (분 단위로만 표시)
  String _formatDuration(double minutes) {
    return '${minutes.toInt()}분';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A86B)),
              ),
              SizedBox(height: 16),
              Text(
                '타석 정보를 조회 중...',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 연습 시간 선택 영역 (외부 decoration 제거)
          Container(
            width: double.infinity,
            height: (MediaQuery.of(context).size.width - 32) / 1.618, // step2와 동일한 황금비율
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), // 좌우 패딩 줄임
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 선택된 시간 표시
                  Text(
                    _formatDuration(_selectedDuration),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  SizedBox(height: 6), // 16에서 8로 줄임 (절반)
                  
                  // 슬라이더만 표시 (최소/최대값 제거)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 6), // 슬라이더 좌우 여백 최소화
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Color(0xFF00A86B),
                        inactiveTrackColor: Color(0xFFE0E0E0),
                        thumbColor: Color(0xFF00A86B),
                        overlayColor: Color(0xFF00A86B).withOpacity(0.2),
                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 18),
                        trackHeight: 8,
                        valueIndicatorShape: PaddleSliderValueIndicatorShape(),
                        valueIndicatorColor: Color(0xFF00A86B),
                        valueIndicatorTextStyle: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      child: Slider(
                        value: _selectedDuration,
                        min: _minDuration,
                        max: _maxDuration,
                        divisions: ((_maxDuration - _minDuration) / 5).round(), // 5분 단위
                        label: '${_selectedDuration.toInt()}분',
                        onChanged: (double value) {
                          setState(() {
                            _selectedDuration = value;
                          });
                          
                          // 콜백 호출
                          if (widget.onDurationSelected != null) {
                            widget.onDurationSelected!(value.toInt());
                          }
                        },
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 6), // 12에서 6으로 줄임 (절반)
                  
                  // 최소/최대값을 슬라이더 아래로 이동
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6), // 텍스트만 약간의 여백
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '최소 ${_minDuration.toInt()}분',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8E8E8E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '최대 ${_maxDuration.toInt()}분',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8E8E8E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 7), // 20에서 10으로 줄임 (절반)
                  
                  // 안내 텍스트
                  Text(
                    '슬라이더를 움직여 연습시간을 조정하세요',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFFBBBBBB),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 