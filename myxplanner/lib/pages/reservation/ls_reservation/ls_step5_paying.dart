import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../services/tile_design_service.dart';

class LsStep5Paying extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;
  final DateTime? selectedDate;
  final String? selectedInstructor;
  final String? selectedTime;
  final int? selectedDuration;
  final Function(dynamic) onMembershipSelected;
  final dynamic selectedMembership;
  final Map<String, dynamic>? lessonCountingData;
  final Map<String, Map<String, dynamic>> proInfoMap;
  final Map<String, Map<String, Map<String, dynamic>>> proScheduleMap;

  const LsStep5Paying({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
    this.selectedDate,
    this.selectedInstructor,
    this.selectedTime,
    this.selectedDuration,
    required this.onMembershipSelected,
    this.selectedMembership,
    this.lessonCountingData,
    required this.proInfoMap,
    required this.proScheduleMap,
  }) : super(key: key);

  @override
  _LsStep5PayingState createState() => _LsStep5PayingState();
}

class _LsStep5PayingState extends State<LsStep5Paying> {
  List<String> _selectedMembershipIds = [];
  List<Map<String, dynamic>> _membershipList = [];
  bool _isLoading = true;

  // 확정된 회원권별 배정 시간을 저장 (membershipId: allocatedMinutes)
  Map<String, int> _allocatedMinutes = {};

  @override
  void initState() {
    super.initState();

    // 디버깅 로그 추가
    print('\n=== Step5 초기화 ===');
    print('selectedMembership 타입: ${widget.selectedMembership.runtimeType}');
    print('selectedMembership 값: ${widget.selectedMembership}');

    // selectedMembership이 List인 경우 (복수 선택)
    if (widget.selectedMembership is List) {
      final membershipList = widget.selectedMembership as List;
      _selectedMembershipIds = membershipList
          .map((item) {
            if (item is Map<String, dynamic>) {
              return 'contract_${item['contract_history_id']}';
            } else if (item is String) {
              return item;
            }
            return null;
          })
          .where((id) => id != null)
          .cast<String>()
          .toList();
      print('List에서 추출한 IDs: $_selectedMembershipIds');
    }
    // selectedMembership이 Map인 경우 id 추출
    else if (widget.selectedMembership is Map<String, dynamic>) {
      final membershipMap = widget.selectedMembership as Map<String, dynamic>;
      final id = 'contract_${membershipMap['contract_history_id']}';
      _selectedMembershipIds = [id];
      print('Map에서 추출한 ID: $id');
    }
    // String인 경우
    else if (widget.selectedMembership is String) {
      _selectedMembershipIds = [widget.selectedMembership as String];
      print('String으로 설정한 ID: ${widget.selectedMembership}');
    } else {
      _selectedMembershipIds = [];
      print('빈 리스트로 설정');
    }
    print('최종 _selectedMembershipIds: $_selectedMembershipIds');
    print('====================\n');

    _loadMembershipData();
  }

  @override
  void didUpdateWidget(LsStep5Paying oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 레슨시간이 변경된 경우 데이터 다시 로드
    if (widget.selectedDuration != oldWidget.selectedDuration ||
        widget.selectedTime != oldWidget.selectedTime) {
      _loadMembershipData();
    }
  }

  Future<void> _loadMembershipData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 당일 레슨 사용량 조회 (max_use_per_day 제한 적용용)
      Map<String, int> lessonDailyUsage = {};
      if (widget.selectedDate != null && widget.selectedMember != null) {
        final memberId = widget.selectedMember!['member_id']?.toString();
        final lessonDateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate!);
        if (memberId != null) {
          lessonDailyUsage = await ApiService.getLessonDailyUsageByContract(
            memberId: memberId,
            lessonDate: lessonDateStr,
          );
          print('\n=== 레슨 당일 사용량 조회 결과 ===');
          lessonDailyUsage.forEach((contractHistoryId, usedMinutes) {
            print('계약 $contractHistoryId: ${usedMinutes}분 이미 사용');
          });
        }
      }

      // 선택된 프로의 유효한 레슨 계약 조회
      List<Map<String, dynamic>> validContracts = [];
      
      if (widget.lessonCountingData != null && 
          widget.lessonCountingData!['success'] == true &&
          widget.selectedInstructor != null) {
        
        final data = widget.lessonCountingData!['data'] as List<dynamic>;
        
        // 선택된 프로의 계약만 필터링
        validContracts = data
            .where((record) => record['pro_id']?.toString() == widget.selectedInstructor)
            .map((record) => record as Map<String, dynamic>)
            .toList();
        
        print('\n=== 회원권 선택 단계 정보 ===');
        print('선택된 프로 ID: ${widget.selectedInstructor}');
        print('선택된 시간: ${widget.selectedTime}');
        print('선택된 레슨시간: ${widget.selectedDuration}분');
        print('계산된 종료시간: ${_getEndTime()}');
        print('\n=== 선택된 프로의 유효한 레슨 계약 ===');
        for (final contract in validContracts) {
          print('• LS_contract_id: ${contract['LS_contract_id']}');
          print('  - LS_counting_id: ${contract['LS_counting_id']}');
          print('  - LS_balance_min_after: ${contract['LS_balance_min_after']}');
          print('  - LS_expiry_date: ${contract['LS_expiry_date']}');
        }
        print('================================\n');
      }

      // contract_history_id만 사용하므로 LS_contract_id 기반 계약 상세 정보 조회는 불필요

      // 실제 레슨 계약 데이터로 회원권 목록 생성
      _membershipList = [];
      
      // 선택된 프로 이름 가져오기
      final proName = widget.proInfoMap[widget.selectedInstructor]?['pro_name'] ?? '알 수 없음';
      
      // 계약별로 그룹화하여 최신 잔여시간 사용
      Map<String, Map<String, dynamic>> contractGroups = {};
      
      for (final contract in validContracts) {
        final contractHistoryId = contract['contract_history_id']?.toString() ?? '';
        final balanceMin = int.tryParse(contract['LS_balance_min_after']?.toString() ?? '0') ?? 0;
        final countingId = contract['LS_counting_id']?.toString() ?? '';
        final expiryDate = contract['LS_expiry_date']?.toString() ?? '';
        
        // 디버깅: 개별 계약 정보 확인
        print('=== INDIVIDUAL CONTRACT DEBUG ===');
        print('contract_history_id: $contractHistoryId');
        print('LS_counting_id: $countingId');
        print('balanceMin: $balanceMin');
        print('==============================');
        
        // contract_history_id가 있는 경우만 처리
        if (contractHistoryId.isNotEmpty) {
          // contract_history_id별로 그룹화
          if (!contractGroups.containsKey(contractHistoryId)) {
            contractGroups[contractHistoryId] = {
              'contractHistoryId': contractHistoryId,
              'balanceMin': balanceMin,
              'countingId': countingId,
              'expiryDate': expiryDate,
            };
          } else {
            // 기존 그룹과 비교하여 더 최신 정보 사용 (잔여시간이 적은 것이 최신)
            final existingBalance = contractGroups[contractHistoryId]!['balanceMin'] as int;
            if (balanceMin < existingBalance) {
              contractGroups[contractHistoryId] = {
                'contractHistoryId': contractHistoryId,
                'balanceMin': balanceMin,
                'countingId': countingId,
                'expiryDate': expiryDate,
              };
            }
          }
        }
      }
      
      // contract_history_id들 수집하여 v2_contracts 상세 정보 조회
      final contractHistoryIds = contractGroups.keys.toList();
      Map<String, Map<String, dynamic>> contractDetails = {};
      if (contractHistoryIds.isNotEmpty) {
        contractDetails = await ApiService.getContractDetails(
          contractHistoryIds: contractHistoryIds,
        );
        print('\n=== 레슨 계약 상세 정보 조회 결과 ===');
        print('조회된 계약 상세 정보 수: ${contractDetails.length}');
      }

      // 그룹화된 계약들로 회원권 목록 생성
      for (final contractGroup in contractGroups.values) {
        final contractHistoryId = contractGroup['contractHistoryId'] as String;
        final balanceMin = contractGroup['balanceMin'] as int;
        final countingId = contractGroup['countingId'] as String;
        final expiryDate = contractGroup['expiryDate'] as String;
        
        // 계약 상세 정보 가져오기
        final contractDetail = contractDetails[contractHistoryId];
        final contractName = contractDetail?['contract_name'] ?? '레슨 계약';
        final contractMin = 300; // 기본 레슨 시간 (분)

        // max_ls_per_day 및 max_ls_min_session 제약조건 확인
        final maxLsPerDay = contractDetail?['max_ls_per_day'];
        final maxLsMinSession = contractDetail?['max_ls_min_session'];

        // 실제 사용 가능한 시간 계산 (당일 제한과 세션 제한 모두 고려)
        int usableMinutes = balanceMin;
        final usedToday = lessonDailyUsage[contractHistoryId] ?? 0;

        // max_ls_per_day 제약 적용 (하루 최대 사용 시간)
        if (maxLsPerDay != null && maxLsPerDay != 'null' && maxLsPerDay != '') {
          try {
            final maxDailyMinutes = int.tryParse(maxLsPerDay.toString());
            if (maxDailyMinutes != null && maxDailyMinutes > 0) {
              final remainingToday = maxDailyMinutes - usedToday;
              usableMinutes = usableMinutes < remainingToday ? usableMinutes : remainingToday;
              print('레슨 계약 $contractHistoryId: max_ls_per_day 제약 적용');
              print('  - 하루 최대: ${maxDailyMinutes}분');
              print('  - 오늘 사용: ${usedToday}분');
              print('  - 남은 시간: ${remainingToday}분');
            }
          } catch (e) {
            print('레슨 계약 $contractHistoryId: max_ls_per_day 파싱 오류 - $e');
          }
        }

        // max_ls_min_session 제약 적용 (세션당 최대 사용 시간)
        if (maxLsMinSession != null && maxLsMinSession != 'null' && maxLsMinSession != '') {
          try {
            final maxSessionMinutes = int.tryParse(maxLsMinSession.toString());
            if (maxSessionMinutes != null && maxSessionMinutes > 0) {
              usableMinutes = usableMinutes < maxSessionMinutes ? usableMinutes : maxSessionMinutes;
              print('레슨 계약 $contractHistoryId: max_ls_min_session 제약 적용');
              print('  - 세션당 최대: ${maxSessionMinutes}분');
            }
          } catch (e) {
            print('레슨 계약 $contractHistoryId: max_ls_min_session 파싱 오류 - $e');
          }
        }

        print('레슨 계약 $contractHistoryId: 최종 사용 가능 시간 ${usableMinutes}분');

        // 사용 가능한 시간이 0보다 크면 목록에 추가
        final isAvailableToday = usableMinutes > 0;

        // 디버깅: contract_history_id 값 확인
        print('=== CONTRACT DETAIL DEBUG ===');
        print('contractHistoryId: $contractHistoryId');
        print('countingId: $countingId');
        print('balanceMin: $balanceMin');
        print('expiryDate: $expiryDate');
        print('contractName: $contractName');
        print('max_ls_per_day: $maxLsPerDay');
        print('max_ls_min_session: $maxLsMinSession');
        print('isAvailableToday: $isAvailableToday');
        print('당일 사용량: ${lessonDailyUsage[contractHistoryId] ?? 0}분');
        print('============================');

        // max_ls_per_day 제약조건을 만족하는 경우만 멤버십 목록에 추가
        if (isAvailableToday && balanceMin > 0) {
          // 잔여 비율 계산 (LS_balance_min_after / LS_contract_min)
          final remainingRatio = contractMin > 0 ? (balanceMin / contractMin * 100).round() : 0;
          final usedMinutes = contractMin - balanceMin;

          // 유효기간 포맷 변환 (2025-12-02 → ~25.12.02)
          String formattedExpiryDate = '';
          if (expiryDate.isNotEmpty) {
            try {
              final parts = expiryDate.split('-');
              if (parts.length == 3) {
                final year = parts[0].substring(2); // '2025' → '25'
                final month = parts[1];
                final day = parts[2];
                formattedExpiryDate = ' (~$year.$month.$day)';
              }
            } catch (e) {
              print('유효기간 포맷 변환 오류: $e');
            }
          }

          _membershipList.add({
            'id': 'contract_$contractHistoryId',
            'name': '$contractName',
            'description': '잔여 시간 ${balanceMin}/${contractMin}분$formattedExpiryDate',
            'price': 0, // 이미 결제된 계약이므로 추가 비용 없음
            'remainingMinutes': balanceMin,
            'contractMinutes': contractMin,
            'usedMinutes': usedMinutes,
            'remainingRatio': remainingRatio,
            'expiryDate': expiryDate,
            'contractDate': '',
            'type': 'contract',
            'contractHistoryId': contractHistoryId,
            'countingId': countingId,
            'contractName': contractName,
            'proName': proName,
            'maxLsPerDay': maxLsPerDay,
            'maxLsMinSession': maxLsMinSession,
            'dailyUsage': lessonDailyUsage[contractHistoryId] ?? 0,
          });

          print('레슨 계약 $contractHistoryId: 멤버십 목록에 추가됨');
        } else {
          if (!isAvailableToday) {
            print('레슨 계약 $contractHistoryId: max_ls_per_day 제한으로 제외됨');
          } else if (balanceMin <= 0) {
            print('레슨 계약 $contractHistoryId: 잔액 부족으로 제외됨 (잔액: ${balanceMin}분)');
          }
        }

        // 디버깅: 최종 멤버십 리스트 상태 확인
        if (isAvailableToday && balanceMin > 0) {
          print('=== MEMBERSHIP LIST ADD DEBUG ===');
          print('추가된 contractHistoryId: $contractHistoryId');
          print('멤버십 리스트 항목: ${_membershipList.last}');
          print('================================');
        }

        // 현재 선택된 회원권이 이 계약과 일치하는지 확인
        if (widget.selectedMembership is List) {
          final selectedList = widget.selectedMembership as List;
          for (var item in selectedList) {
            if (item is Map<String, dynamic>) {
              final selectedContractHistoryId = item['contract_history_id']?.toString();
              if (selectedContractHistoryId == contractHistoryId &&
                  !_selectedMembershipIds.contains('contract_$contractHistoryId')) {
                _selectedMembershipIds.add('contract_$contractHistoryId');
              }
            }
          }
        } else if (widget.selectedMembership is Map<String, dynamic>) {
          final selectedMap = widget.selectedMembership as Map<String, dynamic>;
          final selectedContractHistoryId = selectedMap['contract_history_id']?.toString();
          if (selectedContractHistoryId == contractHistoryId &&
              !_selectedMembershipIds.contains('contract_$contractHistoryId')) {
            _selectedMembershipIds.add('contract_$contractHistoryId');
          }
        }
      }
      
    } catch (e) {
      print('회원권 데이터 로드 실패: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });

      // 사용 가능한 계약이 없으면 사용자에게 안내 메시지 표시
      if (_membershipList.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showNoAvailableContractsDialog();
        });
      }
    }
  }

  // 사용 가능한 계약이 없을 때 안내 다이얼로그
  void _showNoAvailableContractsDialog() {
    showDialog(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false, // 외부 터치로 닫기 방지
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text('사용 가능한 레슨권이 없습니다'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('다음과 같은 이유로 사용할 수 있는 레슨권이 없습니다:'),
              SizedBox(height: 12),
              Text('• 잔액이 부족한 경우'),
              Text('• 하루 사용 한도(일일 최대이용)를 초과한 경우'),
              Text('• 계약 조건에 맞지 않는 경우'),
              SizedBox(height: 12),
              Text('레슨권을 충전하거나 다른 날짜로 예약해주세요.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // 이전 스텝으로 돌아가기
                Navigator.of(context).pop();
              },
              child: Text('이전 단계로'),
            ),
          ],
        );
      },
    );
  }

  String _formatPrice(int price) {
    final formatter = NumberFormat('#,###');
    return '${formatter.format(price)}원';
  }

  // 선택된 레슨권들의 총 잔여시간 계산
  // 선택된 레슨권들의 총 사용 가능 시간 (max_ls_min_session 제약 포함)
  int _getTotalRemainingMinutes() {
    int total = 0;
    for (final id in _selectedMembershipIds) {
      final membership = _membershipList.firstWhere(
        (m) => m['id'] == id,
        orElse: () => {},
      );
      if (membership.isNotEmpty) {
        final remainingMinutes = (membership['remainingMinutes'] as int?) ?? 0;

        // max_ls_min_session 제약 확인
        final maxLsMinSession = membership['maxLsMinSession'];
        int usableMinutes = remainingMinutes;

        if (maxLsMinSession != null && maxLsMinSession != 'null' && maxLsMinSession != '') {
          try {
            final maxSessionMinutes = int.tryParse(maxLsMinSession.toString());
            if (maxSessionMinutes != null && maxSessionMinutes > 0) {
              // 세션당 최대 사용 시간과 잔액 중 작은 값 사용
              usableMinutes = usableMinutes < maxSessionMinutes ? usableMinutes : maxSessionMinutes;
            }
          } catch (e) {
            print('max_ls_min_session 파싱 오류: $e');
          }
        }

        total += usableMinutes;
      }
    }
    return total;
  }

  // 결제 완료 여부 확인 (외부에서 호출 가능)
  bool isPaymentComplete() {
    final requiredMinutes = widget.selectedDuration ?? 0;
    final coveredMinutes = _getTotalRemainingMinutes();
    return coveredMinutes >= requiredMinutes;
  }

  // 선택된 레슨권들의 정보 가져오기
  List<Map<String, dynamic>> _getSelectedMemberships() {
    return _membershipList
        .where((m) => _selectedMembershipIds.contains(m['id']))
        .toList();
  }

  // 특정 레슨권이 사용될 시간과 남을 시간 계산 (확정된 배정 사용)
  Map<String, int> _calculateUsageForMembership(String membershipId) {
    final membership = _membershipList.firstWhere(
      (m) => m['id'] == membershipId,
      orElse: () => {},
    );

    if (membership.isEmpty) {
      return {'useMinutes': 0, 'afterMinutes': 0};
    }

    final currentBalance = (membership['remainingMinutes'] as int?) ?? 0;

    if (!_selectedMembershipIds.contains(membershipId)) {
      // 선택되지 않은 경우
      return {
        'useMinutes': 0,
        'afterMinutes': currentBalance,
      };
    }

    // 확정된 배정 사용
    final useMinutes = _allocatedMinutes[membershipId] ?? 0;
    final afterMinutes = currentBalance - useMinutes;

    return {
      'useMinutes': useMinutes,
      'afterMinutes': afterMinutes,
    };
  }

  Widget _buildMembershipCard(Map<String, dynamic> membership, int index) {
    final isSelected = _selectedMembershipIds.contains(membership['id']);
    final isContract = membership['type'] == 'contract';
    final remainingMinutes = membership['remainingMinutes'] as int?;
    final isAvailable = remainingMinutes != null && remainingMinutes > 0;

    // 선택된 레슨권들의 총 잔액 계산
    final totalSelectedMinutes = _getTotalRemainingMinutes();
    final requiredMinutes = widget.selectedDuration ?? 0;
    final isSufficient = totalSelectedMinutes >= requiredMinutes;

    // 이미 충분한 시간이 확보되었고, 현재 타일이 선택되지 않았다면 비활성화
    final isDisabled = isSufficient && !isSelected;

    // 색상 선택 (TileDesignService 활용)
    final cardColor = TileDesignService.getColorByIndex(index);

    return GestureDetector(
      onTap: (isAvailable && !isDisabled) ? () {
        setState(() {
          if (isSelected) {
            // 선택 해제: 배정도 함께 제거
            _selectedMembershipIds.remove(membership['id']);
            _allocatedMinutes.remove(membership['id']);
          } else {
            // 선택 추가: 일단 추가만 하고 배정은 아래에서 계산
            _selectedMembershipIds.add(membership['id']);
          }
        });

        // 선택된 레슨권 정보들을 배열로 전달
        if (_selectedMembershipIds.isEmpty) {
          _allocatedMinutes.clear();
          widget.onMembershipSelected(null);
        } else {
          final selectedMemberships = _getSelectedMemberships();
          final selectedDurationMin = widget.selectedDuration ?? 0;

          // 이미 배정된 시간의 합계 계산
          int alreadyAllocated = 0;
          for (final id in _selectedMembershipIds) {
            if (_allocatedMinutes.containsKey(id)) {
              alreadyAllocated += _allocatedMinutes[id]!;
            }
          }

          // 남은 시간 (아직 배정되지 않은 시간)
          int remainingDuration = selectedDurationMin - alreadyAllocated;

          print('=== 배정 계산 시작 ===');
          print('전체 레슨 시간: ${selectedDurationMin}분');
          print('이미 배정된 시간: ${alreadyAllocated}분');
          print('남은 시간: ${remainingDuration}분');

          // 복수 레슨권의 경우 각 레슨권별 사용 시간 계산 (max_ls_min_session 제약 포함)
          List<Map<String, dynamic>> lessonInfoList = [];

          for (final selectedMembership in selectedMemberships) {
            final membershipId = selectedMembership['id'] as String;
            final currentBalance = (selectedMembership['remainingMinutes'] as int?) ?? 0;

            int useMinutes;

            // 이미 배정된 회원권인 경우: 기존 배정 유지
            if (_allocatedMinutes.containsKey(membershipId)) {
              useMinutes = _allocatedMinutes[membershipId]!;
              print('기존 배정 유지: ${selectedMembership['contractName']} - ${useMinutes}분');
            } else {
              // 새로 추가된 회원권: 남은 시간 배정
              if (remainingDuration <= 0) {
                useMinutes = 0;
              } else {
                // max_ls_min_session 제약 확인
                final maxLsMinSession = selectedMembership['maxLsMinSession'];
                int maxUsableMinutes = currentBalance;

                if (maxLsMinSession != null && maxLsMinSession != 'null' && maxLsMinSession != '') {
                  try {
                    final maxSessionMinutes = int.tryParse(maxLsMinSession.toString());
                    if (maxSessionMinutes != null && maxSessionMinutes > 0) {
                      maxUsableMinutes = maxUsableMinutes < maxSessionMinutes ? maxUsableMinutes : maxSessionMinutes;
                      print('max_ls_min_session 제약 적용: ${selectedMembership['contractName']}, 잔액 $currentBalance분 → 사용 가능 $maxUsableMinutes분');
                    }
                  } catch (e) {
                    print('max_ls_min_session 파싱 오류: $e');
                  }
                }

                // 실제 사용할 시간 계산 (필요한 시간, 잔액, 세션 제한 중 최소값)
                useMinutes = remainingDuration > maxUsableMinutes ? maxUsableMinutes : remainingDuration;
                remainingDuration -= useMinutes;

                // 배정 확정
                _allocatedMinutes[membershipId] = useMinutes;
                print('새 배정: ${selectedMembership['contractName']} - ${useMinutes}분');
              }
            }

            final newBalance = currentBalance - useMinutes;

            lessonInfoList.add({
              'pro_id': widget.selectedInstructor,
              'pro_name': widget.proInfoMap[widget.selectedInstructor]?['pro_name'] ?? '알 수 없음',
              'LS_start_time': widget.selectedTime,
              'LS_net_min': useMinutes,
              'LS_end_time': _getEndTime(),
              'LS_counting_id': selectedMembership['countingId'],
              'LS_balance_min_before': currentBalance,
              'LS_balance_min_after': newBalance,
              'LS_expiry_date': selectedMembership['expiryDate'],
              'contract_name': selectedMembership['contractName'],
              'contract_history_id': selectedMembership['contractHistoryId'],
            });
          }

          // 디버깅: 선택된 멤버십 정보 확인
          print('=== MEMBERSHIP SELECTED DEBUG ===');
          print('선택된 멤버십 수: ${lessonInfoList.length}');
          print('총 사용 시간: ${selectedDurationMin}분');
          print('확정된 배정: $_allocatedMinutes');
          print('================================');

          widget.onMembershipSelected(lessonInfoList);
        }
      } : null,
      child: Opacity(
        opacity: isDisabled ? 0.4 : 1.0,
        child: Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? cardColor.withOpacity(0.05)
                : (isDisabled ? Color(0xFFF3F4F6) : Colors.white),
            border: Border.all(
              color: isSelected
                  ? cardColor
                  : (isDisabled ? Color(0xFFD1D5DB) : Color(0xFFE5E7EB)),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: cardColor.withOpacity(0.2),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            children: [
              // 왼쪽 색상 바
              Container(
                width: 4,
                height: 80,
                decoration: BoxDecoration(
                  color: isSelected ? cardColor : cardColor.withOpacity(0.3),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
              ),
              SizedBox(width: 12),

              // 선택 표시 (체크박스)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected
                        ? cardColor
                        : (isDisabled ? Color(0xFFD1D5DB) : Color(0xFFD1D5DB)),
                    width: 2,
                  ),
                  color: isSelected ? cardColor : Colors.transparent,
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                    )
                  : null,
              ),
              SizedBox(width: 12),
            
            // 회원권 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 회원권명 - 프로명 제거하고 길게 표시
                  Text(
                    membership['name'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: (isAvailable && !isDisabled) ? Color(0xFF1F2937) : Color(0xFF9CA3AF),
                    ),
                  ),
                  SizedBox(height: 4),
                  // 잔여 시간 표시 - 폰트 사이즈 축소
                  Text(
                    membership['description'],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: (isAvailable && !isDisabled) ? Color(0xFF6B7280) : Color(0xFF9CA3AF),
                    ),
                  ),
                  // 레슨시간 및 예약 후 잔여시간 표시
                  if (isSelected) ...[
                    SizedBox(height: 4),
                    Builder(
                      builder: (context) {
                        final usage = _calculateUsageForMembership(membership['id']);
                        final useMinutes = usage['useMinutes'] ?? 0;
                        final afterMinutes = usage['afterMinutes'] ?? 0;

                        return Text(
                          '레슨시간 $useMinutes분 / 예약후 잔여시간 $afterMinutes분',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cardColor,
                          ),
                        );
                      },
                    ),
                  ],
                  SizedBox(height: 8),
                  // 레슨권 사용기간 표시
                  if (membership['contractDate'] != null && membership['contractDate'] != '') ...[
                    Row(
                      children: [
                        Icon(
                          Icons.date_range,
                          size: 14,
                          color: Color(0xFF6B7280),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '기간: ${membership['contractDate']} ~ ${membership['expiryDate']}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  // 시간 문자열을 분 단위로 변환 (HH:MM:SS 또는 HH:MM)
  int _timeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return hour * 60 + minute;
  }

  // 분을 시간 문자열로 변환 (HH:MM)
  String _minutesToTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  // 종료시간 계산
  String _getEndTime() {
    if (widget.selectedTime == null || widget.selectedDuration == null) return '--:--';
    
    final startTimeMinutes = _timeToMinutes('${widget.selectedTime}:00');
    final endTimeMinutes = startTimeMinutes + widget.selectedDuration!;
    return _minutesToTime(endTimeMinutes);
  }

  // 선택된 레슨권 요약 위젯 - 단순화
  Widget _buildSelectedSummary() {
    // 선택된 레슨권이 있어도 별도 요약 박스를 표시하지 않음
    // 각 타일에 상세 정보가 표시되므로 중복 제거
    return SizedBox.shrink();
  }

  // 레슨 정보 요약 위젯
  Widget _buildLessonSummary() {
    if (widget.selectedDate == null ||
        widget.selectedInstructor == null ||
        widget.selectedTime == null ||
        widget.selectedDuration == null) {
      return SizedBox.shrink();
    }

    final proName = widget.proInfoMap[widget.selectedInstructor]?['pro_name'] ?? '알 수 없음';
    final dateStr = DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(widget.selectedDate!);
    final timeRange = '${widget.selectedTime} ~ ${_getEndTime()}';

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

          SizedBox(height: 12),
          _buildInfoRow('날짜', dateStr, Icons.calendar_today),
          _buildInfoRow('강사', '$proName 프로', Icons.person),
          _buildInfoRow('시간', timeRange, Icons.access_time),
          _buildInfoRowWithPaymentStatus('레슨시간', '${widget.selectedDuration}분', Icons.timer),
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

  Widget _buildInfoRowWithPaymentStatus(String label, String value, IconData icon) {
    final requiredMinutes = widget.selectedDuration ?? 0;
    final coveredMinutes = _getTotalRemainingMinutes();
    final remainingMinutes = requiredMinutes - coveredMinutes;
    final isComplete = remainingMinutes <= 0;

    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              icon,
              size: 16,
              color: Color(0xFF6B7280),
            ),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 4),
                // 결제 상태 표시
                if (isComplete)
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Color(0xFF10B981),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '결제완료',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  )
                else
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(
                          text: '결제완료: ${coveredMinutes}분',
                          style: TextStyle(color: Color(0xFF10B981)),
                        ),
                        TextSpan(
                          text: ' | ',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                        TextSpan(
                          text: '결제대상: ${remainingMinutes}분',
                          style: TextStyle(color: Color(0xFFDC2626)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 필수 정보가 없는 경우
    if (widget.selectedDate == null || 
        widget.selectedInstructor == null || 
        widget.selectedTime == null ||
        widget.selectedDuration == null) {
      return Container(
        padding: EdgeInsets.all(16),
        constraints: BoxConstraints(minHeight: 200),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.payment_outlined,
                size: 48,
                color: Color(0xFF9CA3AF),
              ),
              SizedBox(height: 12),
              Text(
                '이전 단계를 먼저 완료해주세요',
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
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 로딩 상태
          if (_isLoading)
            Container(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '회원권 정보를 조회 중...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // 제목
            Text(
              '결제 방법을 선택하세요',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            SizedBox(height: 20),

            // 레슨 정보 요약 추가 (결제 상태 포함)
            _buildLessonSummary(),

            // 선택된 레슨권 요약
            _buildSelectedSummary(),

            // 회원권 목록 - Expanded 대신 Column 사용
            ..._membershipList.asMap().entries.map((entry) =>
              _buildMembershipCard(entry.value, entry.key)
            ).toList(),
          ],
        ],
      ),
    );
  }
} 