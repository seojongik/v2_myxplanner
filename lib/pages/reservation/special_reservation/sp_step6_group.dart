import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import 'sp_integrated_availability_service.dart';

class SpStep6Group extends StatefulWidget {
  final Function(List<Map<String, dynamic>>)? onGroupCompleted;
  final DateTime? selectedDate;
  final int? selectedProId;
  final String? selectedProName;
  final String? selectedTime;
  final String? selectedTsId;
  final Map<String, dynamic>? selectedContract;
  final Map<String, dynamic> specialSettings;
  final Map<String, dynamic>? step5CalculatedData;

  const SpStep6Group({
    Key? key,
    this.onGroupCompleted,
    this.selectedDate,
    this.selectedProId,
    this.selectedProName,
    this.selectedTime,
    this.selectedTsId,
    this.selectedContract,
    required this.specialSettings,
    this.step5CalculatedData,
  }) : super(key: key);

  @override
  State<SpStep6Group> createState() => _SpStep6GroupState();
}

class _SpStep6GroupState extends State<SpStep6Group> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _invitedMembers = [];
  List<Map<String, dynamic>> _searchResults = [];
  TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  
  // 그룹 레슨 관련 상태
  List<Map<String, dynamic>> _validGroupMembers = [];
  List<Map<String, dynamic>> _selectedGroupMembers = [];
  List<Map<String, dynamic>> _otherInvitedMembers = [];
  bool _showInviteOthersPopup = false;
  
  // 다른 멤버 초대 팝업 상태
  List<Map<String, dynamic>> _inviteInputs = [];
  TextEditingController _searchInviteController = TextEditingController();
  List<Map<String, dynamic>> _inviteSearchResults = [];
  bool _isInviteSearching = false;
  
  // 팝업 내 임시 shopping cart
  List<Map<String, dynamic>> _tempInviteCart = [];

  @override
  void initState() {
    super.initState();
    _debugPrintStepInfo();
    _loadInitialData();
  }

  void _debugPrintStepInfo() {
    print('');
    print('═══════════════════════════════════════════════════════════');
    print('STEP6 (동반자 초대) 진입 - 선택된 예약 정보');
    print('═══════════════════════════════════════════════════════════');
    print('선택된 날짜: ${widget.selectedDate?.toString().split(' ')[0] ?? 'null'}');
    print('선택된 프로: ${widget.selectedProName ?? 'null'} (ID: ${widget.selectedProId ?? 'null'})');
    print('선택된 시간: ${widget.selectedTime ?? 'null'}');
    print('선택된 타석: ${widget.selectedTsId ?? 'null'}번 타석');
    
    if (widget.selectedContract != null) {
      print('선택된 회원권: ${widget.selectedContract!['contract_name'] ?? 'null'}');
    }
    
    print('');
    print('그룹레슨 설정:');
    final maxPlayerNo = int.tryParse(widget.specialSettings['max_player_no']?.toString() ?? '1') ?? 1;
    print('  최대 인원: ${maxPlayerNo}명');
    print('  현재 초대된 인원: ${_invitedMembers.length}명');
    print('  추가 초대 가능: ${maxPlayerNo - 1 - _invitedMembers.length}명');
    print('═══════════════════════════════════════════════════════════');
    print('');
  }

  // 만료일 기준으로 계약을 정렬하는 함수 (만료일 가까운 순)
  List<Map<String, dynamic>> _sortContractsByExpiryDate(List<Map<String, dynamic>> contracts) {
    final sortedContracts = List<Map<String, dynamic>>.from(contracts);
    
    sortedContracts.sort((a, b) {
      final expiryA = a['expiry_date'] as String?;
      final expiryB = b['expiry_date'] as String?;
      
      // null인 경우 무제한으로 간주하여 뒤로 보냄
      if (expiryA == null && expiryB == null) return 0;
      if (expiryA == null) return 1;
      if (expiryB == null) return -1;
      
      try {
        final dateA = DateTime.parse(expiryA);
        final dateB = DateTime.parse(expiryB);
        return dateA.compareTo(dateB); // 가까운 날짜가 앞에 오도록
      } catch (e) {
        // 파싱 실패 시 문자열 비교
        return expiryA.compareTo(expiryB);
      }
    });
    
    return sortedContracts;
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 4개의 쿼리 실행
      await _executeQueries();
      
      print('🔄 동반자 초대 단계 초기 데이터 로드 완료');
      
    } catch (e) {
      print('❌ 동반자 초대 단계 데이터 로드 실패: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _executeQueries() async {
    try {
      // 현재 로그인한 사용자 정보 가져오기
      final currentUser = await ApiService.getCurrentUser();
      if (currentUser == null) {
        print('❌ 현재 사용자 정보를 가져올 수 없습니다.');
        return;
      }

      final branchId = ApiService.getCurrentBranchId();
      if (branchId == null || branchId.isEmpty) {
        print('❌ branchId를 가져올 수 없습니다.');
        return;
      }

      final memberId = currentUser['member_id'];

      print('\n======== 그룹 레슨 쿼리 실행 ========');
      print('Branch ID: $branchId (ApiService.getCurrentBranchId())');
      print('Member ID: $memberId');
      print('');

      // 1. v2_group 테이블에서 관계된 멤버들 조회
      print('1️⃣ v2_group 테이블 쿼리 실행...');
      print('   조회 조건: branch_id=$branchId, member_id=$memberId');
      
      // 현재 멤버가 주체인 관계들 조회
      final myRelations = await ApiService.getData(
        table: 'v2_group',
        fields: ['branch_id', 'member_id', 'member_name', 'member_type', 'member_phone', 'relation', 'related_member_id', 'related_member_name', 'related_member_phone', '_is_master', 'registered_at'],
        where: [
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
      );

      // 현재 멤버가 related_member인 관계들 조회
      final relatedToMe = await ApiService.getData(
        table: 'v2_group',
        fields: ['branch_id', 'member_id', 'member_name', 'member_type', 'member_phone', 'relation', 'related_member_id', 'related_member_name', 'related_member_phone', '_is_master', 'registered_at'],
        where: [
          {'field': 'related_member_id', 'operator': '=', 'value': memberId},
        ],
      );

      print('   ✅ 내가 주체인 관계 (${myRelations.length}개):');
      for (var relation in myRelations) {
        print('      - ${relation['member_name']} → ${relation['related_member_name']} (관계: ${relation['relation']}, Master: ${relation['_is_master']})');
      }

      print('   ✅ 나와 관계된 멤버 (${relatedToMe.length}개):');
      for (var relation in relatedToMe) {
        print('      - ${relation['member_name']} → ${relation['related_member_name']} (관계: ${relation['relation']}, Master: ${relation['_is_master']})');
      }

      // 모든 관련 멤버 ID 수집 (중복 제거)
      Set<String> allMemberIds = {};
      
      // 현재 사용자 추가
      allMemberIds.add(memberId.toString());
      
      // 내가 주체인 관계의 related_member들 추가
      for (var relation in myRelations) {
        if (relation['related_member_id'] != null) {
          allMemberIds.add(relation['related_member_id'].toString());
        }
      }
      
      // 나와 관계된 멤버들의 member_id 추가
      for (var relation in relatedToMe) {
        if (relation['member_id'] != null) {
          allMemberIds.add(relation['member_id'].toString());
        }
      }

      print('   📋 그룹 전체 멤버 ID 목록: ${allMemberIds.toList()}');
      print('');

      // 2. v3_members 테이블에서 그룹 멤버들의 상세 정보 조회
      print('2️⃣ v3_members 테이블 쿼리 실행...');
      final memberIds = allMemberIds.toList();

      // 멤버 상세 정보를 저장할 Map
      final memberDetailsMap = <String, Map<String, dynamic>>{};

      for (var memberId in memberIds) {
        final memberDetails = await ApiService.getData(
          table: 'v3_members',
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'member_id', 'operator': '=', 'value': memberId},
          ],
        );
        
        if (memberDetails.isNotEmpty) {
          final detail = memberDetails.first;
          memberDetailsMap[memberId] = detail;
          print('   ✅ 멤버 상세정보 - ${detail['member_name']} (ID: $memberId):');
          print('      - 전화번호: ${detail['member_phone'] ?? 'N/A'}');
          print('      - 회원타입: ${detail['member_type'] ?? 'N/A'}');
        }
      }
      print('');

      // 현재 프로그램 ID와 선택된 날짜, 프로 ID 가져오기
      final currentProgramId = widget.specialSettings['program_id']?.toString() ?? '';
      final selectedProId = widget.selectedProId?.toString() ?? '';
      final selectedDate = widget.selectedDate ?? DateTime.now();
      
      print('   현재 프로그램 ID: $currentProgramId');
      print('   선택된 프로 ID: $selectedProId');
      print('   선택된 날짜: ${selectedDate.toString().split(' ')[0]}');
      print('');

      // 3-4. 각 멤버의 계약 종합 검증
      print('3️⃣ 그룹 멤버 계약 종합 검증...');
      final validMembers = <Map<String, dynamic>>[];
      
      // 모든 그룹 멤버 정보 수집
      final allGroupMembers = <Map<String, dynamic>>[];
      
      // 현재 멤버가 주체인 관계에서 related_member들 추가
      for (var relation in myRelations) {
        final memberId = relation['related_member_id'].toString();
        final memberDetail = memberDetailsMap[memberId];
        allGroupMembers.add({
          'member_id': relation['related_member_id'],
          'member_name': relation['related_member_name'],
          'member_phone': relation['related_member_phone'],
          'member_type': memberDetail?['member_type'] ?? '',
        });
      }
      
      // 현재 멤버가 related_member인 관계에서 주체 멤버들 추가
      for (var relation in relatedToMe) {
        final memberId = relation['member_id'].toString();
        final memberDetail = memberDetailsMap[memberId];
        allGroupMembers.add({
          'member_id': relation['member_id'],
          'member_name': relation['member_name'],
          'member_phone': relation['member_phone'],
          'member_type': memberDetail?['member_type'] ?? '',
        });
      }
      
      // 현재 사용자 자신도 추가
      if (currentUser != null) {
        final currentUserId = currentUser['member_id'].toString();
        final currentUserDetail = memberDetailsMap[currentUserId];
        allGroupMembers.add({
          'member_id': currentUser['member_id'],
          'member_name': currentUser['member_name'] ?? '본인',
          'member_phone': currentUser['member_phone'] ?? '',
          'member_type': currentUserDetail?['member_type'] ?? currentUser['member_type'] ?? '',
        });
      }
      
      for (var memberId in memberIds) {
        print('');
        print('   🔍 멤버 ID $memberId 계약 검증 중...');
        
        final validation = await validateMemberContractsForReservation(
          branchId: branchId,
          memberId: memberId,
          proId: selectedProId,
          reservationDate: selectedDate,
          programId: currentProgramId,
          specialSettings: widget.specialSettings,
        );

        // 멤버 기본 정보 찾기
        final memberInfo = allGroupMembers.firstWhere(
          (m) => m['member_id'].toString() == memberId,
          orElse: () => {'member_name': '알 수 없음', 'member_phone': '', 'member_id': memberId}
        );

        if (validation['isValid']) {
          print('   ✅ 멤버 ID $memberId: 예약 가능한 계약 보유');
          
          // 본인이 아닌 경우에만 유효한 멤버 리스트에 추가
          if (memberId != currentUser['member_id'].toString()) {
            validMembers.add({
              'member_id': memberId,
              'member_name': memberInfo['member_name'],
              'member_phone': memberInfo['member_phone'],
              'member_type': memberInfo['member_type'] ?? '',
              'totalValidLSBalance': validation['totalValidLSBalance'],
              'totalValidBillBalance': validation['totalValidBillBalance'],
              'validLSContracts': validation['validLSContracts'],
              'validBillContracts': validation['validBillContracts'],
              'validation': validation,
            });
          }
          
          // 유효한 LS 계약 표시
          if (validation['validLSContracts'].isNotEmpty) {
            print('      🟢 유효한 LS 계약:');
            for (var contract in validation['validLSContracts']) {
              final historyId = contract['contract_history_id'];
              final balance = contract['balance'];
              final expiryDate = contract['expiry_date']?.toString().split(' ')[0] ?? 'N/A';
              final proName = contract['pro_name'] ?? 'N/A';
              print('        - Contract $historyId: ${balance}분 (만료: $expiryDate, 프로: $proName)');
            }
          }
          
          // 유효한 Bill 계약 표시
          if (validation['validBillContracts'].isNotEmpty) {
            print('      🟢 유효한 Bill 계약:');
            for (var contract in validation['validBillContracts']) {
              final historyId = contract['contract_history_id'];
              final balance = contract['balance'];
              final expiryDate = contract['expiry_date']?.toString().split(' ')[0] ?? 'N/A';
              print('        - Contract $historyId: ${balance}분 (만료: $expiryDate)');
            }
          }
          
          print('      📊 총 사용 가능 잔액: LS ${validation['totalValidLSBalance']}분 + Bill ${validation['totalValidBillBalance']}분');
          
        } else {
          print('   ❌ 멤버 ID $memberId: 예약 불가능 (유효한 계약 없음)');
        }
        
        // 유효하지 않은 계약들 표시 (컴팩트)
        if (validation['invalidContracts'].isNotEmpty) {
          print('      🔴 사용 불가능한 계약:');
          final contractsByReason = <String, List<String>>{};
          
          // 사유별로 그룹화
          for (var contract in validation['invalidContracts']) {
            final historyId = contract['contract_history_id'];
            final type = contract['type'];
            final balance = contract['balance'];
            final reason = contract['reason'];
            
            String shortReason;
            if (reason.contains('프로 불일치')) {
              shortReason = '프로불일치';
            } else if (reason.contains('잔액 부족')) {
              shortReason = '잔액부족';
            } else if (reason.contains('유효기간 만료')) {
              shortReason = '기간만료';
            } else if (reason.contains('프로그램 예약 불가')) {
              shortReason = '프로그램불가';
            } else {
              shortReason = '기타';
            }
            
            final contractInfo = '$type$historyId(${balance}분)';
            if (!contractsByReason.containsKey(shortReason)) {
              contractsByReason[shortReason] = [];
            }
            contractsByReason[shortReason]!.add(contractInfo);
          }
          
          // 사유별로 컴팩트하게 출력
          contractsByReason.forEach((reason, contracts) {
            print('        - $reason: ${contracts.join(', ')}');
          });
        }
      }
      
      // 유효한 그룹 멤버들을 상태에 저장
      setState(() {
        _validGroupMembers = validMembers;
      });
      
      print('\n======== 쿼리 실행 완료 ========\n');
      
    } catch (e) {
      print('❌ 쿼리 실행 중 오류 발생: $e');
    }
  }

  // 종합적인 계약 유효성 검증 (재사용 가능한 함수)
  static Future<Map<String, dynamic>> validateMemberContractsForReservation({
    required String branchId,
    required String memberId,
    required String proId,
    required DateTime reservationDate,
    required String programId,
    required Map<String, dynamic> specialSettings,
  }) async {
    try {
      print('🔍 계약 유효성 종합 검증 - 멤버: $memberId, 프로: $proId, 날짜: ${reservationDate.toString().split(' ')[0]}, 프로그램: $programId');
      
      final result = <String, dynamic>{
        'isValid': false,
        'validLSContracts': <Map<String, dynamic>>[],
        'validBillContracts': <Map<String, dynamic>>[],
        'invalidContracts': <Map<String, dynamic>>[],
        'totalValidLSBalance': 0,
        'totalValidBillBalance': 0,
      };

      // 1. LS 계약 조회 및 검증
      print('\n📊 LS 계약 조회 시작...');
      final lsCountings = await ApiService.getData(
        table: 'v3_LS_countings',
        fields: [
          'contract_history_id', 'LS_counting_id', 'LS_balance_min_after', 
          'LS_expiry_date', 'pro_id', 'pro_name'
        ],
        where: [
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
        orderBy: [
          {'field': 'contract_history_id', 'direction': 'DESC'},
          {'field': 'LS_counting_id', 'direction': 'DESC'},
        ],
      );
      print('   - 조회된 LS counting 레코드 수: ${lsCountings.length}개');

      // LS 계약별 최신 잔액 및 검증
      final Map<String, Map<String, dynamic>> latestLSByContract = {};
      for (var counting in lsCountings) {
        final contractId = counting['contract_history_id'].toString();
        if (!latestLSByContract.containsKey(contractId) ||
            (counting['LS_counting_id'] > latestLSByContract[contractId]!['LS_counting_id'])) {
          latestLSByContract[contractId] = counting;
        }
      }
      print('   - 계약별 최신 잔액 추출 완료: ${latestLSByContract.length}개 계약');

      for (var entry in latestLSByContract.entries) {
        final contractHistoryId = entry.key;
        final counting = entry.value;
        final balanceValue = counting['LS_balance_min_after'];
        final balanceInt = balanceValue is int ? balanceValue : 
                          (balanceValue is String ? int.tryParse(balanceValue) ?? 0 : 0);
        
        print('\n   📋 LS 계약 검증: $contractHistoryId');
        print('      - 원본 잔액값: $balanceValue (타입: ${balanceValue.runtimeType})');
        print('      - 변환된 잔액: $balanceInt분');
        print('      - 만료일: ${counting['LS_expiry_date']}');
        print('      - 계약 프로: ${counting['pro_id']} (${counting['pro_name']})');
        print('      - 대상 프로: $proId');
        
        final validation = await _validateSingleContract(
          contractHistoryId: contractHistoryId,
          balance: balanceInt,
          expiryDate: counting['LS_expiry_date'],
          contractProId: counting['pro_id'],
          targetProId: proId,
          reservationDate: reservationDate,
          programId: programId,
          contractType: 'LS',
        );

        if (validation['isValid']) {
          print('      ✅ 계약 유효함! 검증 통과');
          (result['validLSContracts'] as List<Map<String, dynamic>>).add({
            'contract_history_id': contractHistoryId,
            'balance': balanceInt,
            'expiry_date': counting['LS_expiry_date'],
            'pro_id': counting['pro_id'],
            'pro_name': counting['pro_name'],
            'validation_details': validation,
          });
          result['totalValidLSBalance'] = (result['totalValidLSBalance'] as int) + balanceInt;
        } else {
          print('      ❌ 계약 무효: ${validation['reason']}');
          print('      검증 상세: ${validation['checks']}');
          (result['invalidContracts'] as List<Map<String, dynamic>>).add({
            'contract_history_id': contractHistoryId,
            'type': 'LS',
            'balance': balanceInt,
            'reason': validation['reason'],
          });
        }
      }

      // 2. Bill 계약 조회 및 검증
      print('\n📊 Bill 계약 조회 시작...');
      final billTimes = await ApiService.getData(
        table: 'v2_bill_times',
        fields: [
          'contract_history_id', 'bill_min_id', 'bill_balance_min_after', 
          'contract_TS_min_expiry_date'
        ],
        where: [
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
        orderBy: [
          {'field': 'contract_history_id', 'direction': 'DESC'},
          {'field': 'bill_min_id', 'direction': 'DESC'},
        ],
      );
      print('   - 조회된 Bill time 레코드 수: ${billTimes.length}개');

      // Bill 계약별 최신 잔액 및 검증
      final Map<String, Map<String, dynamic>> latestBillByContract = {};
      for (var bill in billTimes) {
        final contractId = bill['contract_history_id'].toString();
        if (!latestBillByContract.containsKey(contractId) ||
            (bill['bill_min_id'] > latestBillByContract[contractId]!['bill_min_id'])) {
          latestBillByContract[contractId] = bill;
        }
      }
      print('   - 계약별 최신 잔액 추출 완료: ${latestBillByContract.length}개 계약');

      for (var entry in latestBillByContract.entries) {
        final contractHistoryId = entry.key;
        final bill = entry.value;
        final billBalanceValue = bill['bill_balance_min_after'];
        final billBalanceInt = billBalanceValue is int ? billBalanceValue : 
                              (billBalanceValue is String ? int.tryParse(billBalanceValue) ?? 0 : 0);
        
        print('\n   📋 Bill 계약 검증: $contractHistoryId');
        print('      - 원본 잔액값: $billBalanceValue (타입: ${billBalanceValue.runtimeType})');
        print('      - 변환된 잔액: $billBalanceInt분');
        print('      - 만료일: ${bill['contract_TS_min_expiry_date']}');
        
        final validation = await _validateSingleContract(
          contractHistoryId: contractHistoryId,
          balance: billBalanceInt,
          expiryDate: bill['contract_TS_min_expiry_date'],
          contractProId: null, // Bill 계약은 프로 제한 없음
          targetProId: proId,
          reservationDate: reservationDate,
          programId: programId,
          contractType: 'Bill',
        );

        if (validation['isValid']) {
          print('      ✅ 계약 유효함! 검증 통과');
          (result['validBillContracts'] as List<Map<String, dynamic>>).add({
            'contract_history_id': contractHistoryId,
            'balance': billBalanceInt,
            'expiry_date': bill['contract_TS_min_expiry_date'],
            'validation_details': validation,
          });
          result['totalValidBillBalance'] = (result['totalValidBillBalance'] as int) + billBalanceInt;
        } else {
          print('      ❌ 계약 무효: ${validation['reason']}');
          print('      검증 상세: ${validation['checks']}');
          (result['invalidContracts'] as List<Map<String, dynamic>>).add({
            'contract_history_id': contractHistoryId,
            'type': 'Bill',
            'balance': billBalanceInt,
            'reason': validation['reason'],
          });
        }
      }

      // 3. 타석 시간 요구사항 체크
      print('\n📊 타석 시간 요구사항 체크...');
      final tsMinValue = specialSettings['ts_min'];
      final requiredTsMin = tsMinValue is int ? tsMinValue : 
                           (tsMinValue is String ? int.tryParse(tsMinValue) ?? 0 : 0);
      bool tsRequirementMet = true;
      
      print('   - 필요 타석 시간: ${requiredTsMin}분 (원본: $tsMinValue, 타입: ${tsMinValue.runtimeType})');
      print('   - 보유 타석 시간: ${result['totalValidBillBalance']}분');
      
      if (requiredTsMin > 0) {
        final totalBillBalance = result['totalValidBillBalance'] as int;
        if (totalBillBalance < requiredTsMin) {
          tsRequirementMet = false;
          print('   ❌ 타석 시간 부족: 필요 ${requiredTsMin}분, 보유 ${totalBillBalance}분');
        } else {
          print('   ✅ 타석 시간 충족: 필요 ${requiredTsMin}분, 보유 ${totalBillBalance}분');
        }
      } else {
        print('   ✅ 타석 시간 요구사항 없음');
      }

      // 4. 전체 유효성 판단 (기존 조건 + 타석 시간 요구사항)
      print('\n📊 전체 유효성 판단...');
      final hasValidContracts = (result['validLSContracts'] as List).isNotEmpty || (result['validBillContracts'] as List).isNotEmpty;
      result['isValid'] = hasValidContracts && tsRequirementMet;

      print('   - 유효한 LS 계약: ${(result['validLSContracts'] as List).length}개');
      print('   - 유효한 Bill 계약: ${(result['validBillContracts'] as List).length}개');
      print('   - 계약 조건 충족: ${hasValidContracts ? '✅' : '❌'}');
      print('   - 타석 시간 충족: ${tsRequirementMet ? '✅' : '❌'}');
      print('   - 최종 유효성: ${result['isValid'] ? '✅ 예약 가능' : '❌ 예약 불가능'}');
      
      return result;
      
    } catch (e) {
      print('❌ 계약 유효성 검증 실패 (멤버: $memberId): $e');
      return {
        'isValid': false,
        'error': e.toString(),
        'validLSContracts': <Map<String, dynamic>>[],
        'validBillContracts': <Map<String, dynamic>>[],
        'invalidContracts': <Map<String, dynamic>>[],
        'totalValidLSBalance': 0,
        'totalValidBillBalance': 0,
      };
    }
  }

  // 개별 계약 검증
  static Future<Map<String, dynamic>> _validateSingleContract({
    required String contractHistoryId,
    required int balance,
    required dynamic expiryDate,
    required dynamic contractProId,
    required String targetProId,
    required DateTime reservationDate,
    required String programId,
    required String contractType,
  }) async {
    final result = <String, dynamic>{
      'isValid': false,
      'reason': '',
      'checks': <String, bool>{
        'hasBalance': false,
        'withinExpiry': false,
        'proMatches': false,
        'programAvailable': false,
      },
    };

    try {
      print('        🔍 단계별 검증 시작...');
      
      // 1. 잔액 확인
      print('        1️⃣ 잔액 확인: $balance분');
      if (balance > 0) {
        print('           ✅ 잔액 충분');
        (result['checks'] as Map<String, bool>)['hasBalance'] = true;
      } else {
        print('           ❌ 잔액 부족');
        result['reason'] = '잔액 부족 ($balance분)';
        return result;
      }

      // 2. 유효기간 확인
      print('        2️⃣ 유효기간 확인: $expiryDate');
      if (expiryDate != null) {
        try {
          final expiry = DateTime.parse(expiryDate.toString());
          final reservationDateStr = reservationDate.toString().split(' ')[0];
          final expiryDateStr = expiry.toString().split(' ')[0];
          
          print('           예약일: $reservationDateStr');
          print('           만료일: $expiryDateStr');
          
          if (reservationDate.isBefore(expiry) || reservationDate.isAtSameMomentAs(expiry)) {
            print('           ✅ 유효기간 내');
            (result['checks'] as Map<String, bool>)['withinExpiry'] = true;
          } else {
            print('           ❌ 유효기간 만료');
            result['reason'] = '유효기간 만료 (만료일: ${expiryDate.toString().split(' ')[0]})';
            return result;
          }
        } catch (e) {
          print('           ❌ 유효기간 형식 오류: $e');
          result['reason'] = '유효기간 형식 오류';
          return result;
        }
      } else {
        print('           ✅ 유효기간 제한 없음');
        (result['checks'] as Map<String, bool>)['withinExpiry'] = true; // 유효기간이 없으면 통과
      }

      // 3. 프로 매칭 확인 (LS 계약만)
      print('        3️⃣ 프로 매칭 확인 (계약 타입: $contractType)');
      if (contractType == 'LS') {
        print('           계약 프로: $contractProId');
        print('           선택 프로: $targetProId');
        
        if (contractProId != null && contractProId.toString() == targetProId) {
          print('           ✅ 프로 매칭됨');
          (result['checks'] as Map<String, bool>)['proMatches'] = true;
        } else {
          print('           ❌ 프로 불일치');
          result['reason'] = '프로 불일치 (계약 프로: $contractProId, 선택 프로: $targetProId)';
          return result;
        }
      } else {
        print('           ✅ Bill 계약 - 프로 제한 없음');
        (result['checks'] as Map<String, bool>)['proMatches'] = true; // Bill 계약은 프로 제한 없음
      }

      // 4. 프로그램 예약 가능 여부 확인
      print('        4️⃣ 프로그램 예약 가능 여부 확인');
      print('           계약 ID: $contractHistoryId');
      print('           프로그램 ID: $programId');
      
      final programCheck = await _checkContractProgramAvailability(contractHistoryId, programId);
      print('           프로그램 예약 가능: $programCheck');
      
      if (programCheck) {
        print('           ✅ 프로그램 예약 가능');
        (result['checks'] as Map<String, bool>)['programAvailable'] = true;
      } else {
        print('           ❌ 프로그램 예약 불가');
        result['reason'] = '프로그램 예약 불가';
        return result;
      }

      // 모든 조건을 만족하면 유효
      print('        ✅ 모든 검증 통과!');
      result['isValid'] = true;
      result['reason'] = '유효한 계약';
      
      return result;
      
    } catch (e) {
      result['reason'] = '검증 중 오류: $e';
      return result;
    }
  }

  // contract_history_id로 프로그램 예약 가능 여부 확인
  static Future<bool> _checkContractProgramAvailability(String contractHistoryId, String currentProgramId) async {
    try {
      // 1. v3_contract_history에서 contract_id 조회
      final contractHistory = await ApiService.getData(
        table: 'v3_contract_history',
        fields: ['contract_id'],
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
        ],
      );

      if (contractHistory.isEmpty) {
        return false;
      }

      final contractId = contractHistory.first['contract_id'];

      // 2. v2_contracts에서 program_reservation_availability 조회
      final contracts = await ApiService.getData(
        table: 'v2_contracts',
        fields: ['program_reservation_availability'],
        where: [
          {'field': 'contract_id', 'operator': '=', 'value': contractId},
        ],
      );

      if (contracts.isEmpty) {
        return false;
      }

      final programAvailability = contracts.first['program_reservation_availability']?.toString() ?? '';
      
      // 3. 프로그램 예약 가능 여부 확인
      if (programAvailability.isEmpty || currentProgramId.isEmpty) {
        return false;
      }

      final availablePrograms = programAvailability.split(',').map((e) => e.trim()).toList();
      return availablePrograms.contains(currentProgramId);
      
    } catch (e) {
      print('❌ Contract validation 실패 (History ID: $contractHistoryId): $e');
      return false;
    }
  }

  // 최대 인원 수 계산
  int _getMaxPlayerCount() {
    return int.tryParse(widget.specialSettings['max_player_no']?.toString() ?? '1') ?? 1;
  }

  // 추가 초대 가능한 인원 수 계산 (본인 제외)
  int _getAvailableSlots() {
    return _getMaxPlayerCount() - 1 - _getTotalSelectedCount(); // 본인 제외
  }

  // 전체 선택된 인원 수 계산
  int _getTotalSelectedCount() {
    return _selectedGroupMembers.length + _otherInvitedMembers.length;
  }

  // 회원 검색
  Future<void> _searchMembers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      print('🔍 회원 검색: $query');
      
      // TODO: 실제 회원 검색 API 구현
      await Future.delayed(Duration(milliseconds: 300)); // 임시 딜레이
      
      // 실제 회원 검색
      final searchResults = await ApiService.getData(
        table: 'v3_members',
        where: [
          {'field': 'member_name', 'operator': 'LIKE', 'value': '%$query%'},
        ],
      );

      setState(() {
        _searchResults = searchResults;
      });
      
      print('📋 검색 결과: ${searchResults.length}명');
      
    } catch (e) {
      print('❌ 회원 검색 실패: $e');
      setState(() {
        _searchResults = [];
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  // 동반자 초대
  void _inviteMember(Map<String, dynamic> member) {
    if (_getAvailableSlots() <= 0) {
      _showMessage('더 이상 초대할 수 없습니다.');
      return;
    }

    // 이미 초대된 회원인지 확인
    final alreadyInvited = _invitedMembers.any(
      (invited) => invited['member_id'] == member['member_id']
    );

    if (alreadyInvited) {
      _showMessage('이미 초대된 회원입니다.');
      return;
    }

    setState(() {
      _invitedMembers.add(member);
      _searchResults = [];
      _searchController.clear();
    });

    print('✅ 동반자 초대: ${member['member_name']} (${member['member_id']})');
    _showMessage('${member['member_name']}님을 초대했습니다.');
  }

  // 동반자 초대 취소
  void _removeMember(Map<String, dynamic> member) {
    setState(() {
      _invitedMembers.removeWhere(
        (invited) => invited['member_id'] == member['member_id']
      );
    });

    print('❌ 동반자 초대 취소: ${member['member_name']} (${member['member_id']})');
    _showMessage('${member['member_name']}님의 초대를 취소했습니다.');
  }

  // 그룹 구성 완료
  void _completeGroupSetup() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 선택된 그룹 멤버와 초대된 다른 멤버를 합쳐서 최종 참여자 목록 생성
      final allInvitedMembers = <Map<String, dynamic>>[];
      
      // 디버깅: _selectedGroupMembers 상세 확인
      print('🔍 [allInvitedMembers 구성 전] _selectedGroupMembers 상세:');
      for (int i = 0; i < _selectedGroupMembers.length; i++) {
        final member = _selectedGroupMembers[i];
        print('   멤버 ${i + 1}: ${member}'); // 전체 데이터 출력
      }
      print('🔍 [allInvitedMembers 구성 전] _otherInvitedMembers 상세:');
      for (int i = 0; i < _otherInvitedMembers.length; i++) {
        final member = _otherInvitedMembers[i];
        print('   멤버 ${i + 1}: ${member}'); // 전체 데이터 출력
      }
      print('🔍 [allInvitedMembers 구성 전] _invitedMembers 상세:');
      for (int i = 0; i < _invitedMembers.length; i++) {
        final member = _invitedMembers[i];
        print('   멤버 ${i + 1}: ${member}'); // 전체 데이터 출력
      }
      
      // 그룹 멤버 추가 (결제완료 처리 대상)
      allInvitedMembers.addAll(_selectedGroupMembers.map((member) => {
        ...member,
        'is_group_member': true, // 그룹 멤버 표시
      }));
      
      // 다른 초대 멤버 추가 (체크인전 상태 유지)
      allInvitedMembers.addAll(_otherInvitedMembers.map((member) => {
        ...member,
        'is_group_member': false, // 일반 초대 멤버 표시
      }));
      
      // 일반 초대 멤버도 추가 (_invitedMembers)
      allInvitedMembers.addAll(_invitedMembers.map((member) => {
        ...member,
        'is_group_member': false, // 일반 초대 멤버 표시
        'is_regular_invite': true, // 일반 초대 구분용
      }));

      print('');
      print('🎯 그룹 구성 완료 - 타석 수용인원 검증 시작');
      print('총 참여 인원: ${allInvitedMembers.length + 1}명 (본인 포함)');
      print('선택된 그룹 멤버: ${_selectedGroupMembers.length}명');
      print('초대된 다른 멤버: ${_otherInvitedMembers.length}명');
      print('일반 초대 멤버: ${_invitedMembers.length}명');
      print('');
      print('🔍 [다이얼로그 호출 전] allInvitedMembers 상세:');
      for (int i = 0; i < allInvitedMembers.length; i++) {
        final member = allInvitedMembers[i];
        final memberName = member['member_name'] ?? member['name'] ?? '이름없음';
        final memberId = member['member_id']?.toString() ?? '아이디없음';
        final isGroupMember = member['is_group_member'] ?? false;
        print('   멤버 ${i + 1}: $memberName (ID: $memberId, 그룹멤버: $isGroupMember)');
      }
      print('');

      // 타석 수용인원 검증 및 재배정 처리
      final shouldProceed = await _checkTsCapacityAndConfirm(allInvitedMembers);
      
      if (!shouldProceed) {
        print('❌ 사용자가 타석 재배정을 취소했습니다.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // DB 업데이트 실행
      await _updateDatabaseForGroupCompletion(allInvitedMembers);

      print('✅ 그룹 구성 완료 및 DB 업데이트 성공');

      // 부모 컴포넌트에 결과 전달
      if (widget.onGroupCompleted != null) {
        widget.onGroupCompleted!(allInvitedMembers);
      }

    } catch (e) {
      print('❌ 그룹 구성 완료 중 오류 발생: $e');
      _showMessage('그룹 구성 완료 중 오류가 발생했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 타석 수용인원 검증 및 재배정 확인
  Future<bool> _checkTsCapacityAndConfirm(List<Map<String, dynamic>> allInvitedMembers) async {
    try {
      print('');
      print('═══════════════════════════════════════════════════════════');
      print('📊 타석 수용인원 검증 시작');
      print('═══════════════════════════════════════════════════════════');
      
      // 현재 타석 정보 조회
      final currentUser = ApiService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('현재 사용자 정보를 찾을 수 없습니다.');
      }

      final branchId = ApiService.getCurrentBranchId() ?? '';
      final currentTsId = widget.selectedTsId;
      
      if (currentTsId == null) {
        print('❌ 타석이 선택되지 않았습니다.');
        return true; // 타석이 없으면 계속 진행
      }
      
      print('현재 선택된 타석: ${currentTsId}번');
      
      // v2_ts_info에서 현재 타석의 max_person 조회
      final tsInfoList = await ApiService.getData(
        table: 'v2_ts_info',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'ts_id', 'operator': '=', 'value': currentTsId},
        ],
        fields: ['ts_id', 'max_person'],
      );
      
      if (tsInfoList.isEmpty) {
        print('⚠️ 타석 정보를 찾을 수 없습니다. 타석 ID: $currentTsId');
        return true; // 정보가 없으면 계속 진행
      }
      
      final currentTsInfo = tsInfoList.first;
      final maxPerson = currentTsInfo['max_person'];
      final totalMembers = allInvitedMembers.length + 1; // 본인 포함
      
      print('');
      print('📌 타석 수용인원 정보:');
      print('   - 타석 최대 수용인원: ${maxPerson ?? "제한없음"}명');
      print('   - 예약 인원: ${totalMembers}명 (본인 포함)');
      print('   - 초과 여부: ${maxPerson != null && totalMembers > maxPerson ? "초과 ⚠️" : "정상 ✅"}');
      print('');
      
      // max_person이 null이면 제한 없음으로 간주
      if (maxPerson == null) {
        print('✅ 타석 수용인원 제한이 없습니다. 계속 진행합니다.');
        return true;
      }
      
      // 수용인원 초과 여부 확인
      final isOverCapacity = totalMembers > maxPerson;
      
      if (isOverCapacity) {
        print('⚠️ 타석 수용인원 초과!');
        print('   필요 인원: $totalMembers명');
        print('   수용 가능: $maxPerson명');
        print('   초과 인원: ${totalMembers - maxPerson}명');
        print('');
        
        // 다른 타석 선택 강제
        final reassignmentResult = await _showTsReassignmentDialog(
          currentTsId: currentTsId,
          currentMaxPerson: maxPerson,
          requiredCapacity: totalMembers,
          isForced: true,
          groupMembers: allInvitedMembers,
        );
        
        if (reassignmentResult == null) {
          print('❌ 사용자가 타석 재배정을 취소했습니다.');
          return false;
        }
        
        // 재배정 결과를 allInvitedMembers에 반영
        _applyTsReassignmentResult(allInvitedMembers, reassignmentResult);
        print('✅ 타석 재배정 완료');
        
        for (final member in allInvitedMembers) {
          final assignedTsId = member['assigned_ts_id'] ?? currentTsId;
          print('   - ${member['member_name']}: ${assignedTsId}번 타석 배정');
        }
        
      } else {
        print('✅ 타석 수용인원 이내입니다.');
        print('   사용 인원: $totalMembers명 / 수용 가능: $maxPerson명');
        print('');
        
        // 수용인원 이내여도 확인 팝업 표시
        final reassignmentResult = await _showTsReassignmentDialog(
          currentTsId: currentTsId,
          currentMaxPerson: maxPerson,
          requiredCapacity: totalMembers,
          isForced: false,
          groupMembers: allInvitedMembers,
        );
        
        if (reassignmentResult == null) {
          // 기본 타석 유지 선택
          print('✅ 현재 타석 유지: ${currentTsId}번');
        } else {
          // 재배정 결과를 allInvitedMembers에 반영
          _applyTsReassignmentResult(allInvitedMembers, reassignmentResult);
          print('✅ 타석 재배정 적용');
          
          for (final member in allInvitedMembers) {
            final assignedTsId = member['assigned_ts_id'] ?? currentTsId;
            print('   - ${member['member_name']}: ${assignedTsId}번 타석 배정');
          }
        }
      }
      
      print('═══════════════════════════════════════════════════════════');
      print('');
      
      return true;
      
    } catch (e) {
      print('❌ 타석 수용인원 검증 중 오류: $e');
      // 오류가 발생해도 계속 진행
      return true;
    }
  }

  // 타석 재배정 다이얼로그
  Future<Map<String, dynamic>?> _showTsReassignmentDialog({
    required String currentTsId,
    required int currentMaxPerson,
    required int requiredCapacity,
    required bool isForced,
    required List<Map<String, dynamic>> groupMembers,
  }) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: !isForced, // 강제인 경우 배경 클릭 불가
      builder: (BuildContext context) {
        return _TsReassignmentDialog(
          currentTsId: currentTsId,
          currentMaxPerson: currentMaxPerson,
          requiredCapacity: requiredCapacity,
          isForced: isForced,
          selectedDate: widget.selectedDate,
          selectedTime: widget.selectedTime,
          selectedProId: widget.selectedProId,
          specialSettings: widget.specialSettings,
          groupMembers: groupMembers,
        );
      },
    );
  }

  // 타석 재배정 결과 적용
  void _applyTsReassignmentResult(List<Map<String, dynamic>> allInvitedMembers, Map<String, dynamic> result) {
    final assignmentType = result['type'] as String;
    
    if (assignmentType == 'same_ts') {
      // 같은 타석 사용 - 모든 멤버가 동일한 타석
      final selectedTsId = result['ts_id'] as String;
      for (final member in allInvitedMembers) {
        member['assigned_ts_id'] = selectedTsId;
      }
      print('📌 모든 멤버를 ${selectedTsId}번 타석에 배정');
      
    } else if (assignmentType == 'individual') {
      // 개별 타석 배정 - 각 멤버별로 다른 타석
      final assignments = result['assignments'] as Map<String, String>;
      for (final member in allInvitedMembers) {
        final memberId = member['member_id']?.toString() ?? '';
        final assignedTsId = assignments[memberId];
        if (assignedTsId != null) {
          member['assigned_ts_id'] = assignedTsId;
        }
      }
      print('📌 개별 타석 배정 적용');
    }
  }

  // 그룹 완료를 위한 DB 업데이트
  Future<void> _updateDatabaseForGroupCompletion(List<Map<String, dynamic>> allInvitedMembers) async {
    final currentUser = ApiService.getCurrentUser();
    if (currentUser == null) {
      throw Exception('현재 사용자 정보를 찾을 수 없습니다.');
    }

    final branchId = ApiService.getCurrentBranchId() ?? 'test'; // 기본값 'test' 사용
    final reservationDate = widget.selectedDate;
    final tsId = widget.selectedTsId;
    final selectedTime = widget.selectedTime;
    
    print('🔍 DB 업데이트 시작 디버깅:');
    print('   - currentUser: $currentUser');
    print('   - branchId: $branchId');
    print('   - ApiService.getCurrentBranchId(): ${ApiService.getCurrentBranchId()}');

    if (reservationDate == null || tsId == null || selectedTime == null) {
      throw Exception('예약 정보가 완전하지 않습니다.');
    }

    print('📝 DB 업데이트 시작 - ${allInvitedMembers.length}명 처리');

    // 개별 배정이 있는지 확인
    bool hasIndividualAssignment = allInvitedMembers.any((member) {
      final assignedTsId = member['assigned_ts_id']?.toString();
      return assignedTsId != null && assignedTsId != tsId;
    });

    // 예약 ID 패턴 생성 (예: 250717_2_1320_2/2)
    final dateStr = DateFormat('yyMMdd').format(reservationDate);
    final timeStr = selectedTime.replaceAll(':', '');
    final baseReservationId = '${dateStr}_${tsId}_${timeStr}';

    // 개별 배정이 있으면 본인 예약 ID 정리 (슬롯 번호 제거)
    if (hasIndividualAssignment) {
      print('🔄 개별 배정 감지 - 본인 예약 ID 정리 및 각 멤버별로 타석과 reservation_id 업데이트 예정');
      await _cleanupOwnerReservationId(baseReservationId, branchId);
    }

    // 현재 몇 번째 슬롯인지 확인하기 위해 기존 데이터 조회
    final existingSlots = await ApiService.getData(
      table: 'v2_priced_TS',
      where: [
        {'field': 'reservation_id', 'operator': 'LIKE', 'value': '${baseReservationId}_%'},
      ],
    );

    // 2/2 슬롯부터 시작 (1/2은 본인이 이미 차지)
    int slotNumber = 2;
    
    for (final member in allInvitedMembers) {
      // 개별 타석 배정인지 확인
      final assignedTsId = member['assigned_ts_id']?.toString();
      final memberTsId = assignedTsId ?? tsId;
      
      // reservation_id 생성 로직 분기
      String memberReservationId;
      if (hasIndividualAssignment) {
        // 개별 배정 모드 - 모든 멤버가 슬롯 번호 없음
        final memberDateStr = DateFormat('yyMMdd').format(reservationDate);
        final memberTimeStr = selectedTime.replaceAll(':', '');
        memberReservationId = '${memberDateStr}_${memberTsId}_${memberTimeStr}';
        print('📍 개별 배정 모드: ${memberTsId}번 타석 (슬롯 번호 없음)');
      } else {
        // 같은 타석 사용 - 슬롯 번호 사용
        memberReservationId = '${baseReservationId}_${slotNumber}/${widget.specialSettings['max_player_no']}';
        print('📍 같은 타석 사용: ${tsId}번 타석 (슬롯 ${slotNumber}/${widget.specialSettings['max_player_no']})');
      }
      
      try {
        print('🔄 처리 중: ${member['name'] ?? member['member_name']}');
        print('   - member_id: ${member['member_id']}');
        print('   - assigned_ts_id: ${memberTsId}');
        print('   - reservation_id: ${memberReservationId}');
        print('   - is_group_member: ${member['is_group_member']}');
        
        // 그룹 멤버인지 확인
        final isGroupMember = member['is_group_member'] as bool;
        
        if (isGroupMember) {
          // 그룹 멤버: 결제완료 처리
          await _updateGroupMemberSlot(member, memberReservationId, memberTsId, branchId, reservationDate);
        } else {
          // 일반 초대 멤버: 멤버 정보만 업데이트
          await _updateInvitedMemberSlot(member, memberReservationId, memberTsId, branchId);
        }
        
        // 개별 배정 모드가 아닌 경우에만 슬롯 번호 증가
        if (!hasIndividualAssignment) {
          slotNumber++;
        }
        
      } catch (e) {
        print('❌ ${member['name'] ?? member['member_name']} 처리 중 오류: $e');
        throw Exception('${member['name'] ?? member['member_name']} 처리 중 오류가 발생했습니다: $e');
      }
    }
    
    print('✅ DB 업데이트 완료');
  }

  // 기존 그룹 예약 레코드 삭제 (개별 배정 시)
  Future<void> _deleteExistingGroupReservation(String baseReservationId, String branchId) async {
    try {
      print('🗑️ 기존 그룹 예약 레코드 삭제 시작');
      
      print('🔍 삭제 로직 디버깅:');
      print('   - baseReservationId: $baseReservationId');
      print('   - branchId: $branchId');
      
      // 1. v2_bill_min에서 기존 그룹 예약 레코드 삭제
      // baseReservationId 자체와 baseReservationId_로 시작하는 모든 레코드 찾기
      final billMinRecords = await ApiService.getData(
        table: 'v2_bill_min',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'reservation_id', 'operator': 'LIKE', 'value': '${baseReservationId}%'},
        ],
      );
      
      print('   삭제할 v2_bill_min 레코드: ${billMinRecords.length}개');
      for (final record in billMinRecords) {
        final billMinId = record['bill_min_id'];
        final reservationId = record['reservation_id']?.toString();
        print('   - 삭제: bill_min_id=$billMinId, reservation_id=$reservationId');
        
        if (billMinId != null) {
          try {
            await ApiService.deleteData(
              table: 'v2_bill_min',
              where: [
                {'field': 'bill_min_id', 'operator': '=', 'value': billMinId},
                {'field': 'branch_id', 'operator': '=', 'value': branchId},
              ],
            );
            print('     ✅ v2_bill_min 레코드 삭제 성공: $billMinId');
          } catch (e) {
            print('     ❌ v2_bill_min 레코드 삭제 실패: $billMinId, 오류: $e');
          }
        }
      }
      
      // 2. v2_priced_TS에서 기존 그룹 예약 레코드 삭제
      final pricedTSRecords = await ApiService.getData(
        table: 'v2_priced_TS',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'reservation_id', 'operator': 'LIKE', 'value': '${baseReservationId}%'},
        ],
      );
      
      print('   삭제할 v2_priced_TS 레코드: ${pricedTSRecords.length}개');
      for (final record in pricedTSRecords) {
        final reservationId = record['reservation_id']?.toString();
        print('   - 삭제: reservation_id=$reservationId');
        
        if (reservationId != null) {
          try {
            await ApiService.deleteData(
              table: 'v2_priced_TS',
              where: [
                {'field': 'reservation_id', 'operator': '=', 'value': reservationId},
                {'field': 'branch_id', 'operator': '=', 'value': branchId},
              ],
            );
            print('     ✅ v2_priced_TS 레코드 삭제 성공: $reservationId');
          } catch (e) {
            print('     ❌ v2_priced_TS 레코드 삭제 실패: $reservationId, 오류: $e');
          }
        }
      }
      
      // 3. 레슨 관련 테이블도 삭제 (v3_LS_countings, v2_LS_orders)
      final lsCountingRecords = await ApiService.getData(
        table: 'v3_LS_countings',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'reservation_id', 'operator': 'LIKE', 'value': '${baseReservationId}%'},
        ],
      );
      
      print('   삭제할 v3_LS_countings 레코드: ${lsCountingRecords.length}개');
      for (final record in lsCountingRecords) {
        final reservationId = record['reservation_id']?.toString();
        if (reservationId != null) {
          try {
            await ApiService.deleteData(
              table: 'v3_LS_countings',
              where: [
                {'field': 'reservation_id', 'operator': '=', 'value': reservationId},
                {'field': 'branch_id', 'operator': '=', 'value': branchId},
              ],
            );
            print('     ✅ v3_LS_countings 레코드 삭제 성공: $reservationId');
          } catch (e) {
            print('     ❌ v3_LS_countings 레코드 삭제 실패: $reservationId, 오류: $e');
          }
          
          try {
            await ApiService.deleteData(
              table: 'v2_LS_orders',
              where: [
                {'field': 'reservation_id', 'operator': '=', 'value': reservationId},
                {'field': 'branch_id', 'operator': '=', 'value': branchId},
              ],
            );
            print('     ✅ v2_LS_orders 레코드 삭제 성공: $reservationId');
          } catch (e) {
            print('     ❌ v2_LS_orders 레코드 삭제 실패: $reservationId, 오류: $e');
          }
        }
      }
      
      print('✅ 기존 그룹 예약 레코드 삭제 과정 완료');
      
    } catch (e) {
      print('❌ 기존 그룹 예약 레코드 삭제 중 일부 오류 발생: $e');
      print('⚠️ 일부 오류가 있었지만 계속 진행합니다.');
      // 삭제 과정에서 오류가 있어도 계속 진행 (중요하지 않은 오류일 수 있음)
    }
  }

  // 본인 예약을 개별 예약으로 재생성
  Future<void> _recreateOwnerIndividualReservation(String baseReservationId, String branchId, DateTime reservationDate) async {
    try {
      final currentUser = ApiService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('현재 사용자 정보를 찾을 수 없습니다.');
      }

      final memberId = currentUser['member_id']?.toString() ?? '';
      final memberName = currentUser['member_name']?.toString() ?? '';
      final memberType = currentUser['member_type']?.toString() ?? '';
      final memberPhone = currentUser['member_phone']?.toString() ?? '';
      
      // 개별 배정 시 본인도 슬롯 번호 없이 재생성
      final newReservationId = baseReservationId; // 슬롯 번호 없는 형식
      
      print('👤 본인 개별 예약 재생성: $memberName');
      print('   - 기존 reservation_id 패턴: ${baseReservationId}_1/2 등');
      print('   - 새 reservation_id: $newReservationId (슬롯 번호 제거)');
      print('   - ts_id: ${widget.selectedTsId}');
      print('   - branch_id: $branchId');
      print('   - 현재 ApiService 브랜치 ID: ${ApiService.getCurrentBranchId()}');

      // 먼저 동일한 reservation_id가 이미 있는지 확인
      final existingRecords = await ApiService.getData(
        table: 'v2_bill_min',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'reservation_id', 'operator': '=', 'value': newReservationId},
        ],
      );
      
      if (existingRecords.isNotEmpty) {
        print('⚠️ 이미 동일한 reservation_id($newReservationId)가 존재합니다. 스킵합니다.');
        return;
      }

      // 1. v2_bill_min 테이블에 개별 예약 생성
      final billMinData = {
        'branch_id': branchId,
        'member_id': memberId,
        'bill_date': DateFormat('yyyy-MM-dd').format(reservationDate),
        'bill_text': '${widget.selectedTsId}번 타석(${widget.selectedTime} ~ ${_calculateEndTime(widget.selectedTime!)})',
        'bill_type': '타석이용',
        'reservation_id': newReservationId,
        'bill_total_min': 50,
        'bill_discount_min': 0,
        'bill_min': 50,
        'bill_status': '결제완료',
        'bill_timestamp': DateTime.now().toIso8601String(),
      };
      
      print('📝 v2_bill_min 생성 데이터: $billMinData');
      
      await ApiService.addData(
        table: 'v2_bill_min',
        data: billMinData,
      );

      // 2. v2_priced_TS 테이블에 개별 예약 생성
      await ApiService.addData(
        table: 'v2_priced_TS',
        data: {
          'branch_id': branchId,
          'reservation_id': newReservationId,
          'ts_id': widget.selectedTsId,
          'ts_status': '결제완료',
          'member_id': memberId,
          'member_type': memberType,
          'member_name': memberName,
          'member_phone': memberPhone,
          'bill_min': 50,
        },
      );

      print('✅ 본인 개별 예약 재생성 완료');

    } catch (e) {
      print('❌ 본인 개별 예약 재생성 실패: $e');
      throw Exception('본인 개별 예약 재생성 중 오류가 발생했습니다: $e');
    }
  }

  // 시간 계산 헬퍼 함수
  String _calculateEndTime(String startTime) {
    final parts = startTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    
    final startDateTime = DateTime(2000, 1, 1, hour, minute);
    final endDateTime = startDateTime.add(Duration(minutes: 50));
    
    return '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}';
  }

  // 그룹 멤버 슬롯 업데이트 (결제완료 처리)
  Future<void> _updateGroupMemberSlot(Map<String, dynamic> member, String reservationId, String memberTsId, String branchId, DateTime reservationDate) async {
    final memberId = member['member_id']?.toString() ?? '';
    final memberName = member['member_name'] ?? member['name'] ?? '';
    final memberType = member['member_type'] ?? '';
    final memberPhone = member['member_phone'] ?? member['phone'] ?? '';

    print('💳 그룹 멤버 결제완료 처리: $memberName');

    // 기존 빈 슬롯을 찾아서 업데이트
    // 현재 그룹 예약의 빈 슬롯 (체크인전 상태)을 찾아서 멤버 정보와 타석 업데이트
    final dateStr = DateFormat('yyMMdd').format(reservationDate);
    final timeStr = widget.selectedTime!.replaceAll(':', '');
    final baseReservationId = '${dateStr}_${widget.selectedTsId}_${timeStr}';
    
    // 체크인전 상태의 빈 슬롯 찾기
    print('🔍 빈 슬롯 검색 중...');
    print('   - baseReservationId: ${baseReservationId}');
    print('   - branch_id: ${branchId}');
    
    final emptySlots = await ApiService.getData(
      table: 'v2_priced_TS',
      where: [
        {'field': 'branch_id', 'operator': '=', 'value': branchId},
        {'field': 'reservation_id', 'operator': 'LIKE', 'value': '${baseReservationId}_%'},
        {'field': 'ts_status', 'operator': '=', 'value': '체크인전'},
      ],
      orderBy: [{'field': 'reservation_id', 'direction': 'ASC'}],
      limit: 1,
    );
    
    print('   - 찾은 빈 슬롯 수: ${emptySlots.length}');
    
    if (emptySlots.isEmpty) {
      print('❌ 업데이트할 빈 슬롯을 찾을 수 없습니다.');
      print('   검색 패턴: ${baseReservationId}_%');
      
      // 모든 관련 슬롯 확인 (디버깅용)
      final allSlots = await ApiService.getData(
        table: 'v2_priced_TS',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'reservation_id', 'operator': 'LIKE', 'value': '${baseReservationId}%'},
        ],
      );
      print('   전체 관련 슬롯 수: ${allSlots.length}');
      for (final slot in allSlots) {
        print('     - ${slot['reservation_id']}: ${slot['ts_status']} (member_id: ${slot['member_id']})');
      }
      
      throw Exception('업데이트할 빈 슬롯을 찾을 수 없습니다.');
    }
    
    final oldReservationId = emptySlots.first['reservation_id'].toString();
    final oldSlotData = emptySlots.first;
    print('   - 기존 슬롯: ${oldReservationId}');
    print('   - 새 reservation_id: ${reservationId}');
    print('   - 새 ts_id: ${memberTsId}');
    
    // 개별 배정인지 확인 (reservation_id 형식이 다름)
    final isIndividualAssignment = !reservationId.contains('/');
    
    if (isIndividualAssignment) {
      print('📝 개별 배정: 기존 슬롯 삭제 후 새 레코드 생성');
      
      // 1. 기존 빈 슬롯 삭제
      try {
        print('   🗑️ v2_priced_TS 삭제 시도...');
        print('      - table: v2_priced_TS');
        print('      - reservation_id: ${oldReservationId}');
        print('      - branch_id: ${branchId}');
        
        await ApiService.deleteData(
          table: 'v2_priced_TS',
          where: [
            {'field': 'reservation_id', 'operator': '=', 'value': oldReservationId},
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
          ],
        );
        print('   ✅ v2_priced_TS 삭제 완료');
      } catch (e) {
        print('   ❌ v2_priced_TS 삭제 실패:');
        print('      오류: $e');
      }
      
      print('   ℹ️ v2_bill_times는 별도로 처리됩니다.');
      
      // 2. 새로운 개별 예약 생성
      try {
        print('   📝 v2_priced_TS 생성 시도...');
        print('      기존 슬롯 데이터 확인:');
        print('      - ts_date: ${oldSlotData['ts_date']}');
        print('      - ts_start: ${oldSlotData['ts_start']}');
        print('      - ts_end: ${oldSlotData['ts_end']}');
        print('      - ts_payment_method: ${oldSlotData['ts_payment_method']}');
        print('      - program_id: ${oldSlotData['program_id']}');
        print('      - program_name: ${oldSlotData['program_name']}');
        
        final pricedTsData = {
          'branch_id': branchId,
          'reservation_id': reservationId,
          'ts_id': memberTsId,
          'ts_date': oldSlotData['ts_date'],
          'ts_start': oldSlotData['ts_start'],
          'ts_end': oldSlotData['ts_end'],
          'ts_payment_method': oldSlotData['ts_payment_method'],
          'ts_status': '결제완료',
          'member_id': memberId,
          'member_type': memberType,
          'member_name': memberName,
          'member_phone': memberPhone,
          'total_amt': oldSlotData['total_amt'] ?? 10000,
          'term_discount': oldSlotData['term_discount'] ?? 0,
          'coupon_discount': oldSlotData['coupon_discount'] ?? 0,
          'total_discount': oldSlotData['total_discount'] ?? 0,
          'net_amt': oldSlotData['net_amt'] ?? 10000,
          'discount_min': oldSlotData['discount_min'] ?? 50,
          'normal_min': oldSlotData['normal_min'] ?? 0,
          'extracharge_min': oldSlotData['extracharge_min'] ?? 0,
          'ts_min': oldSlotData['ts_min'] ?? 50,
          'bill_min': 50,
          'time_stamp': DateTime.now().toIso8601String(),
          'program_id': oldSlotData['program_id'],
          'program_name': oldSlotData['program_name'],
        };
        
        print('      새 레코드 데이터:');
        print('      - reservation_id: ${reservationId}');
        print('      - ts_id: ${memberTsId}');
        print('      - member_id: ${memberId}');
        print('      - member_name: ${memberName}');
        
        final pricedTsResult = await ApiService.addData(
          table: 'v2_priced_TS',
          data: pricedTsData,
        );
        print('   ✅ v2_priced_TS 생성 완료');
        
        // v2_priced_TS 생성 후 bill_min_id 연결을 위한 정보 저장
        member['new_priced_ts_created'] = true;
        
      } catch (e) {
        print('   ❌ v2_priced_TS 생성 실패:');
        print('      오류: $e');
        throw e; // 오류를 다시 던져서 전체 프로세스 중단
      }
      
      print('   ✅ 개별 배정: v2_priced_TS 처리 완료');
      
    } else {
      print('📝 같은 타석: 기존 슬롯 업데이트');
      
      // 같은 타석 사용 - 기존처럼 업데이트
      await ApiService.updateData(
        table: 'v2_priced_TS',
        data: {
          'ts_status': '결제완료',
          'member_id': memberId,
          'member_type': memberType,
          'member_name': memberName,
          'member_phone': memberPhone,
          'bill_min': 50,
        },
        where: [
          {'field': 'reservation_id', 'operator': '=', 'value': oldReservationId},
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
        ],
      );
      
      await ApiService.updateData(
        table: 'v2_bill_min',
        data: {
          'member_id': memberId,
          'bill_status': '결제완료',
        },
        where: [
          {'field': 'reservation_id', 'operator': '=', 'value': oldReservationId},
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
        ],
      );
    }

    // 3. v3_LS_countings와 v2_LS_orders 업데이트 (레슨이 있는 특수타석예약만)
    // has_lesson 대신 ls_min이 있는지 확인
    bool hasLesson = false;
    widget.specialSettings.forEach((key, value) {
      if (key.startsWith('ls_min(') && key.endsWith(')')) {
        final lsMin = int.tryParse(value.toString()) ?? 0;
        if (lsMin > 0) hasLesson = true;
      }
    });
    
    print('📝 레슨 업데이트 확인 - hasLesson: $hasLesson');
    if (hasLesson) {
      if (isIndividualAssignment) {
        print('✅ 개별 배정: 기존 체크인전 레슨 슬롯에 멤버 정보만 업데이트');
        await _updateExistingLessonSlotsForMember(member, branchId, reservationDate);
      } else {
        print('✅ 같은 타석: v3_LS_countings/v2_LS_orders 업데이트 진행');
        await _updateLSCountingsAndOrdersForGroupMember(member, reservationId, memberTsId, branchId, reservationDate);
      }
    } else {
      print('⚠️ 레슨이 없는 예약이므로 v3_LS_countings/v2_LS_orders 업데이트 생략');
    }

    // 4. v2_bill_times 업데이트 (개별 배정 시 특별 처리)
    if (isIndividualAssignment) {
      print('📝 개별 배정: v2_bill_times 업데이트');
      
      try {
        // 기존 v2_bill_times 레코드 찾기
        final existingBillTimes = await ApiService.getData(
          table: 'v2_bill_times',
          where: [
            {'field': 'reservation_id', 'operator': '=', 'value': oldReservationId},
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
          ],
        );
        
        if (existingBillTimes.isNotEmpty) {
          print('   기존 v2_bill_times 레코드 발견: ${existingBillTimes.length}개');
          
          // 기존 레코드 삭제
          for (final record in existingBillTimes) {
            final billMinId = record['bill_min_id'];
            if (billMinId != null) {
              await ApiService.deleteData(
                table: 'v2_bill_times',
                where: [
                  {'field': 'bill_min_id', 'operator': '=', 'value': billMinId},
                  {'field': 'branch_id', 'operator': '=', 'value': branchId},
                ],
              );
              print('   ✅ 기존 v2_bill_times 삭제: bill_min_id=${billMinId}');
            }
          }
          
          // 새로운 v2_bill_times 생성
          final validBillContracts = member['validBillContracts'] as List<Map<String, dynamic>>? ?? [];
          
          if (validBillContracts.isNotEmpty) {
            final contract = validBillContracts.first;
            final contractHistoryId = contract['contract_history_id'];
            final balanceBefore = contract['balance'] as int? ?? 0;
            const billMin = 50;
            final balanceAfter = balanceBefore - billMin;
            
            final billTimesData = {
              'branch_id': branchId,
              'member_id': memberId,
              'bill_date': DateFormat('yyyy-MM-dd').format(reservationDate),
              'bill_text': '${memberTsId}번 타석(${widget.selectedTime} ~ ${_calculateEndTime(widget.selectedTime!)})',
              'bill_type': '타석이용',
              'reservation_id': reservationId,  // 새로운 reservation_id
              'bill_total_min': 50,
              'bill_discount_min': 0,
              'bill_min': billMin,
              'bill_balance_min_before': balanceBefore,
              'bill_balance_min_after': balanceAfter,
              'bill_timestamp': DateTime.now().toIso8601String(),
              'bill_status': '결제완료',
              'contract_history_id': contractHistoryId,
              'contract_TS_min_expiry_date': contract['expiry_date'],
            };
            
            final billTimesResult = await ApiService.addData(
              table: 'v2_bill_times',
              data: billTimesData,
            );
            print('   ✅ 새로운 v2_bill_times 생성 완료');
            
            // v2_bill_times 생성 후 bill_min_id 가져와서 v2_priced_TS 업데이트
            if (member['new_priced_ts_created'] == true) {
              try {
                // 방금 생성된 v2_bill_times의 bill_min_id 조회
                final newBillTimes = await ApiService.getData(
                  table: 'v2_bill_times',
                  where: [
                    {'field': 'reservation_id', 'operator': '=', 'value': reservationId},
                    {'field': 'member_id', 'operator': '=', 'value': memberId},
                    {'field': 'branch_id', 'operator': '=', 'value': branchId},
                  ],
                  orderBy: [{'field': 'bill_min_id', 'direction': 'DESC'}],
                  limit: 1,
                );
                
                if (newBillTimes.isNotEmpty) {
                  final billMinId = newBillTimes.first['bill_min_id'];
                  
                  // v2_priced_TS에 bill_min_id 업데이트
                  await ApiService.updateData(
                    table: 'v2_priced_TS',
                    data: {'bill_min_id': billMinId},
                    where: [
                      {'field': 'reservation_id', 'operator': '=', 'value': reservationId},
                      {'field': 'member_id', 'operator': '=', 'value': memberId},
                      {'field': 'branch_id', 'operator': '=', 'value': branchId},
                    ],
                  );
                  print('   ✅ v2_priced_TS에 bill_min_id(${billMinId}) 연결 완료');
                }
              } catch (e) {
                print('   ⚠️ v2_priced_TS bill_min_id 연결 실패: $e');
              }
            }
          }
        } else {
          print('   ⚠️ 기존 v2_bill_times 레코드가 없습니다.');
        }
      } catch (e) {
        print('   ❌ v2_bill_times 처리 실패: $e');
      }
    } else {
      // 같은 타석: 기존 방식대로 업데이트
      await _updateBillTimesForGroupMember(member, reservationId, branchId, reservationDate);
    }
  }

  // 일반 초대 멤버 슬롯 업데이트 (체크인전 상태)
  Future<void> _updateInvitedMemberSlot(Map<String, dynamic> member, String reservationId, String memberTsId, String branchId) async {
    final memberId = member['member_id']?.toString();
    final memberName = member['name'] ?? '';
    final memberPhone = member['phone'] ?? '';
    final isMember = member['is_member'] as bool? ?? false;

    print('👤 일반 초대 멤버 정보 업데이트: $memberName');

    // v2_priced_TS 멤버 정보만 업데이트 (ts_status는 체크인전 유지)
    final updateData = <String, dynamic>{
      'member_name': memberName,
      'member_phone': memberPhone,
    };

    if (isMember && memberId != null) {
      updateData['member_id'] = memberId;
      // 회원 타입 조회
      try {
        final memberInfo = await ApiService.getData(
          table: 'v3_members',
          where: [
            {'field': 'member_id', 'operator': '=', 'value': memberId},
          ],
        );
        if (memberInfo.isNotEmpty) {
          updateData['member_type'] = memberInfo.first['member_type'] ?? '';
        }
      } catch (e) {
        print('⚠️ 회원 타입 조회 실패: $e');
      }
    }

    // 배정된 타석 ID 추가
    updateData['ts_id'] = memberTsId;
    
    await ApiService.updateData(
      table: 'v2_priced_TS',
      data: updateData,
      where: [
        {'field': 'reservation_id', 'operator': '=', 'value': reservationId},
      ],
    );
  }

  // 그룹 멤버를 위한 v3_LS_countings와 v2_LS_orders 업데이트 (세션별)
  Future<void> _updateLSCountingsAndOrdersForGroupMember(Map<String, dynamic> member, String reservationId, String memberTsId, String branchId, DateTime reservationDate) async {
    print('\n🔧 v3_LS_countings/v2_LS_orders 업데이트 시작');
    print('   - 멤버: ${member['member_name']} (ID: ${member['member_id']})');
    print('   - 예약 ID: $reservationId');
    
    // Step 5에서 계산된 데이터 사용
    if (widget.step5CalculatedData == null) {
      print('❌ Step 5 계산 데이터가 없습니다. 기존 로직 사용.');
      await _updateLSCountingsAndOrdersForGroupMemberLegacy(member, reservationId, memberTsId, branchId, reservationDate);
      return;
    }
    
    final calculatedData = widget.step5CalculatedData!;
    final lessonSessions = calculatedData['lesson_sessions'] as List<dynamic>? ?? [];
    
    if (lessonSessions.isEmpty) {
      print('❌ 레슨 세션 데이터가 없습니다. 기존 로직 사용.');
      await _updateLSCountingsAndOrdersForGroupMemberLegacy(member, reservationId, memberTsId, branchId, reservationDate);
      return;
    }
    
    print('✅ Step 5 계산 데이터 사용: ${lessonSessions.length}개 세션');
    
    final memberId = member['member_id']?.toString() ?? '';
    final memberName = member['member_name'] ?? member['name'] ?? '';
    final memberType = member['member_type'] ?? '';
    
    // 해당 멤버의 유효한 LS 계약 정보 가져오기
    final validContracts = member['validLSContracts'] as List<Map<String, dynamic>>? ?? [];
    
    print('   - 유효한 LS 계약 수: ${validContracts.length}');
    
    if (validContracts.isEmpty) {
      print('⚠️ ${memberName}: 유효한 LS 계약이 없어 v3_LS_countings/v2_LS_orders 업데이트 생략');
      return;
    }

    // 만료일 가까운 순으로 정렬 후 첫 번째 계약 사용
    final sortedContracts = _sortContractsByExpiryDate(validContracts);
    final contract = sortedContracts.first;
    final contractHistoryId = contract['contract_history_id']?.toString() ?? '';
    var currentBalance = contract['balance'] as int? ?? 0;
    final expiryDate = contract['expiry_date'];
    
    print('   - 선택된 계약: $contractHistoryId (잔액: ${currentBalance}분, 만료: $expiryDate)');

    // reservationId에서 슬롯 번호 추출 (예: 250718_2_1220_2/2 → 2)
    final slotMatch = RegExp(r'_(\d+)/\d+$').firstMatch(reservationId);
    final slotNumber = slotMatch?.group(1) ?? '1';

    print('🔄 ${memberName}의 레슨 세션별 업데이트 시작 (${lessonSessions.length}개 세션)');
    print('   - 기본 예약 ID: $reservationId');

    for (var i = 0; i < lessonSessions.length; i++) {
      final session = lessonSessions[i] as Map<String, dynamic>;
      final sessionNumber = session['session_number']?.toString() ?? '';
      final lsMin = session['ls_min'] as int? ?? 0;
      final lsId = session['ls_id']?.toString() ?? '';
      
      // memberTsId를 사용하여 LS_id 재생성 (개별 타석 배정 지원)
      final lsIdParts = lsId.split('_');
      String sessionLsId = lsId;
      if (lsIdParts.length >= 4) {
        // LS_id 형식: 250718_2_1525_1/2 → 250718_3_1525_2/2 (memberTsId 사용)
        final datePart = lsIdParts[0];
        final timePart = lsIdParts[2];
        final slotPart = lsIdParts[3].replaceFirst(RegExp(r'\d+/'), '${slotNumber}/');
        sessionLsId = '${datePart}_${memberTsId}_${timePart}_${slotPart}';
      }
      
      print('   📍 세션 $sessionNumber (${i+1}/${lessonSessions.length}): LS_id = $sessionLsId');

      // 잔액 계산
      final balanceAfter = currentBalance - lsMin;

      // v3_LS_countings 업데이트
      try {
        final updateData = <String, dynamic>{
          'LS_status': '차감완료',
          'member_id': memberId,
          'member_name': memberName,
          'member_type': memberType,
          'LS_contract_id': contractHistoryId,
          'contract_history_id': contractHistoryId,
          'LS_balance_min_before': currentBalance,
          'LS_balance_min_after': balanceAfter,
        };
        
        // LS_expiry_date가 있는 경우만 추가
        if (expiryDate != null && expiryDate != 'N/A') {
          updateData['LS_expiry_date'] = expiryDate;
        }
        
        await ApiService.updateData(
          table: 'v3_LS_countings',
          data: updateData,
          where: [
            {'field': 'LS_id', 'operator': '=', 'value': sessionLsId},
            {'field': 'LS_status', 'operator': '=', 'value': '체크인전'}, // 빈 슬롯만 업데이트
          ],
        );
        print('✅ v3_LS_countings 업데이트 성공: ${sessionLsId}');
      } catch (e) {
        print('❌ v3_LS_countings 업데이트 실패: ${sessionLsId} - $e');
        // 실패해도 계속 진행
      }

      // v2_LS_orders 업데이트 (기존 시간은 그대로 유지, 멤버 정보만 업데이트)
      await ApiService.updateData(
        table: 'v2_LS_orders',
        data: {
          'LS_status': '결제완료',
          'member_id': memberId,
          'member_name': memberName,
          'member_type': memberType,
          'LS_contract_id': contractHistoryId,
        },
        where: [
          {'field': 'LS_id', 'operator': '=', 'value': sessionLsId},
        ],
      );

      print('✅ 세션 ${sessionNumber} 업데이트 완료: ${sessionLsId} (${currentBalance}분 → ${balanceAfter}분)');
      
      currentBalance = balanceAfter;
    }

    print('📊 ${memberName}의 모든 레슨 세션 업데이트 완료');
  }

  // 기존 로직 (Step 5 데이터가 없을 때 사용)
  Future<void> _updateLSCountingsAndOrdersForGroupMemberLegacy(Map<String, dynamic> member, String reservationId, String memberTsId, String branchId, DateTime reservationDate) async {
    final memberId = member['member_id']?.toString() ?? '';
    final memberName = member['member_name'] ?? member['name'] ?? '';
    final memberType = member['member_type'] ?? '';

    // 해당 멤버의 유효한 LS 계약 정보 가져오기
    final validContracts = member['validLSContracts'] as List<Map<String, dynamic>>? ?? [];
    
    print('   - 유효한 LS 계약 수: ${validContracts.length}');
    
    if (validContracts.isEmpty) {
      print('⚠️ ${memberName}: 유효한 LS 계약이 없어 v3_LS_countings/v2_LS_orders 업데이트 생략');
      return;
    }

    // 만료일 가까운 순으로 정렬 후 첫 번째 계약 사용
    final sortedContracts = _sortContractsByExpiryDate(validContracts);
    final contract = sortedContracts.first;
    final contractHistoryId = contract['contract_history_id']?.toString() ?? '';
    var currentBalance = contract['balance'] as int? ?? 0;
    final expiryDate = contract['expiry_date'];
    
    print('   - 선택된 계약: $contractHistoryId (잔액: ${currentBalance}분, 만료: $expiryDate)');

    // 레슨 세션 정보 추출 (예: ls_min(2) = 15, ls_min(4) = 15)
    final lsSessions = <Map<String, dynamic>>[];
    final allTimeSlots = <Map<String, dynamic>>[];
    
    // 모든 ls_min과 ls_break_min 수집
    widget.specialSettings.forEach((key, value) {
      if (key.startsWith('ls_min(') && key.endsWith(')')) {
        final sessionNumber = key.substring(7, key.length - 1);
        final lsMin = int.tryParse(value.toString()) ?? 0;
        if (lsMin > 0) {
          lsSessions.add({
            'session_number': sessionNumber,
            'ls_min': lsMin,
          });
          allTimeSlots.add({
            'type': 'session',
            'number': int.parse(sessionNumber),
            'minutes': lsMin,
          });
        }
      } else if (key.startsWith('ls_break_min(') && key.endsWith(')')) {
        final breakNumber = key.substring(13, key.length - 1);
        final breakMin = int.tryParse(value.toString()) ?? 0;
        if (breakMin > 0) {
          allTimeSlots.add({
            'type': 'break',
            'number': int.parse(breakNumber),
            'minutes': breakMin,
          });
        }
      }
    });
    
    // 번호 순으로 정렬
    allTimeSlots.sort((a, b) => a['number'].compareTo(b['number']));
    
    print('   - 레슨 세션 수: ${lsSessions.length}');
    print('   - 레슨 세션 정보: ${lsSessions.map((s) => 'ls_min(${s['session_number']})=${s['ls_min']}분').join(', ')}');

    // 시간 계산
    final selectedTime = widget.selectedTime ?? '';
    var currentTime = selectedTime;

    // reservationId에서 슬롯 번호 추출 (예: 250718_2_1220_2/2 → 2)
    final slotMatch = RegExp(r'_(\d+)/\d+$').firstMatch(reservationId);
    final slotNumber = slotMatch?.group(1) ?? '1';

    print('🔄 ${memberName}의 레슨 세션별 업데이트 시작 (${lsSessions.length}개 세션)');
    print('   - 기본 예약 ID: $reservationId');
    print('   - 선택된 시간: $selectedTime');
    print('   - 전체 시간 슬롯: ${allTimeSlots.map((s) => '${s['type']}(${s['number']})=${s['minutes']}분').join(', ')}');

    for (var i = 0; i < lsSessions.length; i++) {
      final session = lsSessions[i];
      final sessionNumber = session['session_number'];
      final lsMin = session['ls_min'] as int;
      
      // 세션별 LS_id 생성 (예: 250718_2_1220_2/2, 250718_2_1235_2/2)
      String sessionLsId;
      
      // 날짜를 yymmdd 형식으로 변환
      final dateStr = reservationDate.toString().substring(2, 10).replaceAll('-', '');
      
      // 슬롯 번호 추출 (reservationId에서)
      final slotMatch = RegExp(r'_(\d+)/\d+$').firstMatch(reservationId);
      final slotPart = slotMatch?.group(0) ?? '_1/1';
      
      // 세션 시작 시간 계산
      final timeParts = currentTime.split(':');
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      
      // 이전 세션들의 시간 합계 계산
      int totalMinutesBefore = 0;
      
      // 첫 번째 세션부터 이전 세션까지의 모든 시간을 계산
      for (int j = 0; j < i; j++) {
        final prevSession = lsSessions[j];
        final prevSessionNum = int.parse(prevSession['session_number']);
        totalMinutesBefore += prevSession['ls_min'] as int;
        
        // 해당 세션 뒤의 브레이크 시간 추가
        final breakKey = 'ls_break_min($prevSessionNum)';
        final breakMin = int.tryParse(widget.specialSettings[breakKey]?.toString() ?? '0') ?? 0;
        if (breakMin > 0) {
          totalMinutesBefore += breakMin;
        }
      }
      
      minute += totalMinutesBefore;
      hour += minute ~/ 60;
      minute = minute % 60;
      
      // 시간을 hhmm 형식으로 변환
      final sessionTime = '${hour.toString().padLeft(2, '0')}${minute.toString().padLeft(2, '0')}';
      
      // LS_id 생성: 날짜_멤버타석ID_시간_슬롯번호 (개별 타석 배정 지원)
      sessionLsId = '${dateStr}_${memberTsId}_${sessionTime}${slotPart}';
      
      print('   📍 세션 $sessionNumber (${i+1}/${lsSessions.length}): LS_id = $sessionLsId');

      // 잔액 계산
      final balanceAfter = currentBalance - lsMin;

      // v3_LS_countings 업데이트
      try {
        final updateData = <String, dynamic>{
          'LS_status': '차감완료',
          'member_id': memberId,
          'member_name': memberName,
          'member_type': memberType,
          'LS_contract_id': contractHistoryId,
          'contract_history_id': contractHistoryId,
          'LS_balance_min_before': currentBalance,
          'LS_balance_min_after': balanceAfter,
        };
        
        // LS_expiry_date가 있는 경우만 추가
        if (expiryDate != null && expiryDate != 'N/A') {
          updateData['LS_expiry_date'] = expiryDate;
        }
        
        await ApiService.updateData(
          table: 'v3_LS_countings',
          data: updateData,
          where: [
            {'field': 'LS_id', 'operator': '=', 'value': sessionLsId},
            {'field': 'LS_status', 'operator': '=', 'value': '체크인전'}, // 빈 슬롯만 업데이트
          ],
        );
        print('✅ v3_LS_countings 업데이트 성공: ${sessionLsId}');
      } catch (e) {
        print('❌ v3_LS_countings 업데이트 실패: ${sessionLsId} - $e');
        // 실패해도 계속 진행
      }

      // v2_LS_orders 업데이트 (기존 시간은 그대로 유지, 멤버 정보만 업데이트)
      await ApiService.updateData(
        table: 'v2_LS_orders',
        data: {
          'LS_status': '결제완료',
          'member_id': memberId,
          'member_name': memberName,
          'member_type': memberType,
          'LS_contract_id': contractHistoryId,
        },
        where: [
          {'field': 'LS_id', 'operator': '=', 'value': sessionLsId},
        ],
      );

      print('✅ 세션 ${sessionNumber} 업데이트 완료: ${sessionLsId} (${currentBalance}분 → ${balanceAfter}분)');
      
      currentBalance = balanceAfter;
    }

    print('📊 ${memberName}의 모든 레슨 세션 업데이트 완료');
  }

  // 개별 배정 시 기존 체크인전 레슨 슬롯에 멤버 정보 업데이트
  Future<void> _updateExistingLessonSlotsForMember(Map<String, dynamic> member, String branchId, DateTime reservationDate) async {
    try {
      final memberId = member['member_id']?.toString() ?? '';
      final memberName = member['member_name'] ?? '';
      final memberType = member['member_type'] ?? '';
      
      print('📚 레슨 슬롯 업데이트: ${memberName}');
      
      // 해당 날짜의 체크인전 레슨 슬롯 찾기
      print('   조회 조건:');
      print('     - branch_id: ${branchId}');
      print('     - LS_date: ${DateFormat('yyyy-MM-dd').format(reservationDate)}');
      print('     - LS_status: 체크인전');
      
      final checkInPendingSlots = await ApiService.getData(
        table: 'v2_LS_orders',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'LS_date', 'operator': '=', 'value': DateFormat('yyyy-MM-dd').format(reservationDate)},
          {'field': 'LS_status', 'operator': '=', 'value': '체크인전'},
        ],
      );
      
      print('   찾은 체크인전 레슨 슬롯: ${checkInPendingSlots.length}개');
      
      // 각 슬롯 정보 출력
      for (int i = 0; i < checkInPendingSlots.length; i++) {
        final slot = checkInPendingSlots[i];
        print('     슬롯 ${i+1}: LS_id=${slot['LS_id']}, member_id=${slot['member_id']}, LS_status=${slot['LS_status']}');
      }
      
      if (checkInPendingSlots.isNotEmpty) {
        // 빈 슬롯(member_id가 null인 것)만 업데이트
        final emptySlots = checkInPendingSlots.where((slot) => 
          slot['member_id'] == null || slot['member_id'].toString().isEmpty
        ).toList();
        
        print('   빈 슬롯(member_id가 null인 것): ${emptySlots.length}개');
        
        // 현재 잔액 추적을 위한 변수 초기화
        final validLSContracts = member['validLSContracts'] as List<Map<String, dynamic>>? ?? [];
        int? currentBalance;
        Map<String, dynamic>? selectedContract;
        
        if (validLSContracts.isNotEmpty) {
          // 만료일 가까운 순으로 정렬 후 첫 번째 계약 사용
          final sortedContracts = _sortContractsByExpiryDate(validLSContracts);
          selectedContract = sortedContracts.first;
          currentBalance = selectedContract['balance'] as int? ?? 0;
          print('   - 선택된 계약: ${selectedContract['contract_history_id']} (초기잔액: ${currentBalance}분)');
        }
        
        for (final slot in emptySlots) {
          final lsId = slot['LS_id'];
          
          try {
            print('   🔄 v2_LS_orders 업데이트 시도: ${lsId}');
            print('     업데이트 데이터:');
            print('       - member_id: ${memberId}');
            print('       - member_name: ${memberName}');
            print('       - member_type: ${memberType}');
            print('       - LS_status: 결제완료');
            
            // v2_LS_orders 업데이트
            await ApiService.updateData(
              table: 'v2_LS_orders',
              data: {
                'member_id': memberId,
                'member_name': memberName,
                'member_type': memberType,
                'LS_status': '결제완료',
              },
              where: [
                {'field': 'LS_id', 'operator': '=', 'value': lsId},
                {'field': 'branch_id', 'operator': '=', 'value': branchId},
              ],
            );
            print('   ✅ v2_LS_orders 업데이트 성공: ${lsId}');
            
          } catch (e) {
            print('   ❌ v2_LS_orders 업데이트 실패: ${lsId}');
            print('     오류: $e');
            continue;
          }
          
          // v3_LS_countings 업데이트
          try {
            if (selectedContract != null && currentBalance != null) {
              final contractHistoryId = selectedContract['contract_history_id'];
              final balanceBefore = currentBalance!;
              final lsNetMin = slot['LS_net_min'] as int? ?? 15;
              final balanceAfter = balanceBefore - lsNetMin;
              
              print('   🔄 v3_LS_countings 업데이트 시도: ${lsId}');
              print('     업데이트 데이터:');
              print('       - contract_history_id: ${contractHistoryId}');
              print('       - LS_balance_min_before: ${balanceBefore}');
              print('       - LS_balance_min_after: ${balanceAfter}');
              print('       - LS_net_min: ${lsNetMin}');
              
              await ApiService.updateData(
                table: 'v3_LS_countings',
                data: {
                  'member_id': memberId,
                  'member_name': memberName,
                  'member_type': memberType,
                  'LS_status': '차감완료',
                  'LS_contract_id': selectedContract['LS_contract_id'],
                  'contract_history_id': contractHistoryId,
                  'LS_balance_min_before': balanceBefore,
                  'LS_balance_min_after': balanceAfter,
                },
                where: [
                  {'field': 'LS_id', 'operator': '=', 'value': lsId},
                  {'field': 'branch_id', 'operator': '=', 'value': branchId},
                ],
              );
              print('   ✅ v3_LS_countings 업데이트 성공: ${lsId} (${balanceBefore}분 → ${balanceAfter}분)');
              
              // 다음 슬롯을 위해 잔액 업데이트
              currentBalance = balanceAfter;
            } else {
              print('   ⚠️ 유효한 LS 계약이 없어서 v3_LS_countings 업데이트 스킵: ${lsId}');
            }
          } catch (e) {
            print('   ❌ v3_LS_countings 업데이트 실패: ${lsId}');
            print('     오류: $e');
          }
        }
        
        print('✅ 모든 레슨 슬롯 업데이트 완료');
      } else {
        print('⚠️ 업데이트할 체크인전 레슨 슬롯이 없습니다.');
      }
      
    } catch (e) {
      print('❌ 레슨 슬롯 업데이트 실패: $e');
      // 실패해도 계속 진행
    }
  }

  // 개별 배정 시 본인 예약 ID 정리 (슬롯 번호 제거)
  Future<void> _cleanupOwnerReservationId(String baseReservationId, String branchId) async {
    try {
      print('🧹 본인 예약 ID 정리 시작');
      
      // 1. v2_priced_TS에서 본인 예약(_1/2) 찾기
      final ownerReservationId = '${baseReservationId}_1/2';
      
      final ownerPricedTs = await ApiService.getData(
        table: 'v2_priced_TS',
        where: [
          {'field': 'reservation_id', 'operator': '=', 'value': ownerReservationId},
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
        ],
      );
      
      if (ownerPricedTs.isNotEmpty) {
        // reservation_id에서 _1/2 제거
        await ApiService.updateData(
          table: 'v2_priced_TS',
          data: {'reservation_id': baseReservationId},
          where: [
            {'field': 'reservation_id', 'operator': '=', 'value': ownerReservationId},
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
          ],
        );
        print('   ✅ v2_priced_TS: ${ownerReservationId} → ${baseReservationId}');
      }
      
      // 2. v2_bill_times에서 본인 예약(_1/2) 찾기
      final ownerBillTimes = await ApiService.getData(
        table: 'v2_bill_times',
        where: [
          {'field': 'reservation_id', 'operator': '=', 'value': ownerReservationId},
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
        ],
      );
      
      if (ownerBillTimes.isNotEmpty) {
        // reservation_id에서 _1/2 제거
        await ApiService.updateData(
          table: 'v2_bill_times',
          data: {'reservation_id': baseReservationId},
          where: [
            {'field': 'reservation_id', 'operator': '=', 'value': ownerReservationId},
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
          ],
        );
        print('   ✅ v2_bill_times: ${ownerReservationId} → ${baseReservationId}');
      }
      
      print('✅ 본인 예약 ID 정리 완료');
      
    } catch (e) {
      print('❌ 본인 예약 ID 정리 실패: $e');
      // 실패해도 계속 진행
    }
  }

  // 그룹 멤버를 위한 v2_bill_times 업데이트
  Future<void> _updateBillTimesForGroupMember(Map<String, dynamic> member, String reservationId, String branchId, DateTime reservationDate) async {
    final memberId = member['member_id']?.toString() ?? '';

    // 해당 멤버의 유효한 Bill 계약 정보 가져오기
    final validBillContracts = member['validBillContracts'] as List<Map<String, dynamic>>? ?? [];
    
    if (validBillContracts.isEmpty) {
      print('⚠️ ${member['member_name']}: 유효한 Bill 계약이 없어 v2_bill_times 업데이트 생략');
      return;
    }

    // 만료일 가까운 순으로 정렬 후 첫 번째 계약 사용
    final sortedBillContracts = _sortContractsByExpiryDate(validBillContracts);
    final contract = sortedBillContracts.first;
    final contractHistoryId = contract['contract_history_id']?.toString() ?? '';
    final balanceBefore = contract['balance'] as int? ?? 0;
    final billMin = 50; // 타석 분수
    final balanceAfter = balanceBefore - billMin;
    final expiryDate = contract['expiry_date'];

    await ApiService.updateData(
      table: 'v2_bill_times',
      data: {
        'bill_status': '결제완료',
        'member_id': memberId,
        'bill_balance_min_before': balanceBefore,
        'bill_balance_min_after': balanceAfter,
        'contract_history_id': contractHistoryId,
        'contract_TS_min_expiry_date': expiryDate,
        'bill_min': billMin,
      },
      where: [
        {'field': 'reservation_id', 'operator': '=', 'value': reservationId},
      ],
    );

    print('💰 Bill 차감 완료: ${member['member_name']} (${balanceBefore}분 → ${balanceAfter}분)');
  }


  // 메시지 표시
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  // 초대 팝업 리셋
  void _resetInvitePopup() {
    _inviteInputs.clear();
    _searchInviteController.clear();
    _inviteSearchResults.clear();
    _isInviteSearching = false;
    _tempInviteCart.clear(); // 임시 cart 초기화
  }

  // 전화번호 포맷 정규화 (010-1234-5678 형태로 변환)
  String _normalizePhoneNumber(String phone) {
    // 숫자만 추출
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    
    // 11자리 숫자인 경우 010-1234-5678 형태로 변환
    if (digits.length == 11 && digits.startsWith('010')) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    }
    
    return phone; // 변환할 수 없는 경우 원본 반환
  }

  // 전화번호로 회원 검색 (정확한 일치만)
  Future<void> _searchMemberByPhone(String phone) async {
    if (phone.trim().isEmpty) {
      setState(() {
        _inviteSearchResults = [];
      });
      return;
    }

    setState(() {
      _isInviteSearching = true;
      _inviteSearchResults = [];
    });

    try {
      // 전화번호 정규화
      final normalizedPhone = _normalizePhoneNumber(phone);
      
      final searchResults = await ApiService.getData(
        table: 'v3_members',
        where: [
          {'field': 'member_phone', 'operator': '=', 'value': normalizedPhone},
        ],
      );

      // 이미 선택된 그룹 멤버와 초대된 멤버는 제외
      final filteredResults = searchResults.where((member) {
        final memberId = member['member_id'].toString();
        
        // 현재 사용자 본인 제외
        final currentUser = ApiService.getCurrentUser();
        if (currentUser != null && memberId == currentUser['member_id'].toString()) {
          return false;
        }
        
        // 이미 선택된 그룹 멤버인지 확인
        final alreadySelectedGroup = _selectedGroupMembers.any(
          (selected) => selected['member_id'].toString() == memberId
        );
        
        // 이미 초대된 멤버인지 확인
        final alreadyInvited = _otherInvitedMembers.any(
          (invited) => invited['member_id']?.toString() == memberId
        );
        
        // 임시 장바구니에 있는지 확인
        final alreadyInTempCart = _tempInviteCart.any(
          (cartMember) => cartMember['member_id']?.toString() == memberId
        );
        
        return !alreadySelectedGroup && !alreadyInvited && !alreadyInTempCart;
      }).toList();

      setState(() {
        if (filteredResults.isNotEmpty) {
          // 회원이 존재하면 멤버 검색 결과 표시
          _inviteSearchResults = filteredResults;
        } else if (searchResults.isNotEmpty) {
          // 회원이 존재하지만 이미 선택된 경우
          _inviteSearchResults = [];
          if (searchResults.isNotEmpty) {
            final member = searchResults.first;
            final currentUser = ApiService.getCurrentUser();
            if (currentUser != null && member['member_id'].toString() == currentUser['member_id'].toString()) {
              _showMessage('본인은 초대할 수 없습니다.');
            } else {
              _showMessage('이미 선택된 멤버입니다.');
            }
          }
        } else {
          // 회원이 없으면 비회원 초대 폼 표시를 위해 특별한 결과 설정
          _inviteSearchResults = [{
            'is_non_member': true,
            'phone': normalizedPhone,
          }];
        }
      });
      
    } catch (e) {
      print('❌ 회원 검색 실패: $e');
      setState(() {
        _inviteSearchResults = [];
      });
      _showMessage('검색 중 오류가 발생했습니다.');
    } finally {
      setState(() {
        _isInviteSearching = false;
      });
    }
  }

  // 입력 필드 추가
  void _addInviteInput() {
    if (_inviteInputs.length < _getAvailableSlots()) {
      setState(() {
        _inviteInputs.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'nameController': TextEditingController(),
          'phoneController': TextEditingController(),
          'is_member': false,
          'member_id': null,
          'member_name': '',
          'verified': false,
        });
      });
    }
  }

  // 입력 필드 제거
  void _removeInviteInput(int index) {
    setState(() {
      final input = _inviteInputs[index];
      input['nameController']?.dispose();
      input['phoneController']?.dispose();
      _inviteInputs.removeAt(index);
    });
  }

  // 전화번호로 회원 조회
  Future<void> _lookupMemberByPhone(int index) async {
    final input = _inviteInputs[index];
    final phone = input['phoneController'].text.trim();
    
    if (phone.isEmpty) {
      _showMessage('전화번호를 입력해주세요.');
      return;
    }

    // 전화번호 정규화
    final normalizedPhone = _normalizePhoneNumber(phone);

    try {
      final results = await ApiService.getData(
        table: 'v3_members',
        where: [
          {'field': 'member_phone', 'operator': '=', 'value': normalizedPhone},
        ],
      );

      setState(() {
        if (results.isNotEmpty) {
          final member = results.first;
          
          // 본인이거나 이미 선택된 멤버인지 확인
          final memberId = member['member_id'].toString();
          final currentUser = ApiService.getCurrentUser();
          
          final isSelf = currentUser != null && memberId == currentUser['member_id'].toString();
          final alreadySelected = _selectedGroupMembers.any(
            (selected) => selected['member_id'].toString() == memberId
          );
          final alreadyInvited = _otherInvitedMembers.any(
            (invited) => invited['member_id']?.toString() == memberId
          );
          
          if (isSelf) {
            _showMessage('본인은 초대할 수 없습니다.');
            return;
          }
          
          if (alreadySelected || alreadyInvited) {
            _showMessage('이미 선택된 멤버입니다.');
            return;
          }
          
          input['is_member'] = true;
          input['member_id'] = member['member_id'];
          input['member_name'] = member['member_name'];
          input['nameController'].text = member['member_name'] ?? '';
          input['phoneController'].text = normalizedPhone; // 정규화된 번호로 업데이트
          input['verified'] = true;
          
          _showMessage('회원 정보를 찾았습니다: ${member['member_name']}');
        } else {
          input['is_member'] = false;
          input['member_id'] = null;
          input['member_name'] = '';
          input['phoneController'].text = normalizedPhone; // 정규화된 번호로 업데이트
          input['verified'] = false; // 비회원은 이름을 입력해야 하므로 false
          
          _showMessage('등록되지 않은 번호입니다. 비회원으로 초대하려면 이름을 입력하세요.');
        }
      });
      
    } catch (e) {
      print('❌ 회원 조회 실패: $e');
      _showMessage('회원 조회 중 오류가 발생했습니다.');
    }
  }

  // 초대 완료 가능 여부 확인
  bool _canCompleteInvite() {
    // 임시 shopping cart에 초대할 멤버가 있어야 함
    return _tempInviteCart.isNotEmpty;
  }

  // 초대 완료
  void _completeInvite() {
    final inviteCount = _tempInviteCart.length;
    
    setState(() {
      // 임시 cart의 내용을 실제 초대 목록으로 이동
      _otherInvitedMembers.addAll(_tempInviteCart);
      _showInviteOthersPopup = false;
      _resetInvitePopup();
    });
    
    _showMessage('${inviteCount}명이 초대 목록에 추가되었습니다.');
  }

  // 검색 결과에서 멤버 선택
  void _selectInviteMember(Map<String, dynamic> member) {
    // 이미 임시 cart에 있는지 확인
    final memberId = member['member_id'].toString();
    final alreadyInCart = _tempInviteCart.any(
      (cartMember) => cartMember['member_id']?.toString() == memberId
    );
    
    if (alreadyInCart) {
      _showMessage('이미 선택된 멤버입니다.');
      return;
    }
    
    // 임시 cart + 기존 선택된 멤버 수 확인
    final currentTotal = _getTotalSelectedCount() + _tempInviteCart.length;
    if (currentTotal >= _getMaxPlayerCount() - 1) {
      _showMessage('최대 인원을 초과할 수 없습니다.');
      return;
    }
    
    setState(() {
      _tempInviteCart.add({
        'name': member['member_name'],
        'phone': member['member_phone'],
        'is_member': true,
        'member_id': member['member_id'],
      });
      _inviteSearchResults.clear();
      _searchInviteController.clear();
    });
    
    _showMessage('${member['member_name']}님을 장바구니에 추가했습니다.');
  }

  // 비회원으로 초대 (이름 입력 후)
  void _inviteAsNonMember(String phone, String name) {
    // 이미 임시 cart에 같은 전화번호가 있는지 확인
    final normalizedPhone = _normalizePhoneNumber(phone);
    final alreadyInCart = _tempInviteCart.any(
      (cartMember) => cartMember['phone'] == normalizedPhone
    );
    
    if (alreadyInCart) {
      _showMessage('이미 선택된 번호입니다.');
      return;
    }
    
    // 임시 cart + 기존 선택된 멤버 수 확인
    final currentTotal = _getTotalSelectedCount() + _tempInviteCart.length;
    if (currentTotal >= _getMaxPlayerCount() - 1) {
      _showMessage('최대 인원을 초과할 수 없습니다.');
      return;
    }
    
    setState(() {
      _tempInviteCart.add({
        'name': name.trim(),
        'phone': normalizedPhone,
        'is_member': false,
        'member_id': null,
      });
      _inviteSearchResults.clear();
      _searchInviteController.clear();
    });
    
    _showMessage('$name님을 장바구니에 추가했습니다.');
  }

  // 임시 장바구니에서 멤버 제거
  void _removeTempInviteCartMember(int index) {
    final member = _tempInviteCart[index];
    setState(() {
      _tempInviteCart.removeAt(index);
    });
    _showMessage('${member['name']}님을 장바구니에서 제거했습니다.');
  }

  // 초대된 멤버 제거
  void _removeInvitedMember(int index) {
    final member = _otherInvitedMembers[index];
    setState(() {
      _otherInvitedMembers.removeAt(index);
    });
    _showMessage('${member['name']}님의 초대를 취소했습니다.');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchInviteController.dispose();
    for (var input in _inviteInputs) {
      input['nameController']?.dispose();
      input['phoneController']?.dispose();
    }
    super.dispose();
  }

  // 유효한 그룹 멤버 타일
  Widget _buildValidGroupMemberTile(Map<String, dynamic> member) {
    final isSelected = _selectedGroupMembers.any(
      (selected) => selected['member_id'] == member['member_id']
    );

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            if (isSelected) {
              setState(() {
                _selectedGroupMembers.removeWhere(
                  (selected) => selected['member_id'] == member['member_id']
                );
              });
            } else {
              if (_getTotalSelectedCount() < _getMaxPlayerCount()) {
                await _handleMemberSelection(member);
              }
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? Color(0xFFF0FDF4) : Colors.white,
              border: Border.all(
                color: isSelected ? Color(0xFF10B981) : Color(0xFFE5E7EB),
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // 선택 상태 표시
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? Color(0xFF10B981) : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? Color(0xFF10B981) : Color(0xFFD1D5DB),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: isSelected
                      ? Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
                SizedBox(width: 12),
                
                // 프로필 아이콘
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFF10B981).withOpacity(0.1),
                  child: Icon(
                    Icons.person,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                
                // 멤버 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member['member_name'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        member['member_phone'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      SizedBox(height: 4),
                      _buildMemberContractInfo(member),
                    ],
                  ),
                ),
                
                // 선택 가능 여부 표시
                if (!isSelected && _getTotalSelectedCount() >= _getMaxPlayerCount())
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '정원초과',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 멤버 계약 정보 표시
  Widget _buildMemberContractInfo(Map<String, dynamic> member) {
    final validLSContracts = member['validLSContracts'] as List<Map<String, dynamic>>? ?? [];
    final validBillContracts = member['validBillContracts'] as List<Map<String, dynamic>>? ?? [];
    
    final hasMultipleLSContracts = validLSContracts.length > 1;
    final hasMultipleBillContracts = validBillContracts.length > 1;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LS ${member['totalValidLSBalance']}분 + 타석 ${member['totalValidBillBalance']}분',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF10B981),
            fontWeight: FontWeight.w500,
          ),
        ),
        if (hasMultipleLSContracts || hasMultipleBillContracts) ...[
          SizedBox(height: 2),
          Row(
            children: [
              if (hasMultipleLSContracts)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'LS 계약 ${validLSContracts.length}개',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFFF59E0B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              if (hasMultipleLSContracts && hasMultipleBillContracts)
                SizedBox(width: 4),
              if (hasMultipleBillContracts)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '타석 계약 ${validBillContracts.length}개',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF8B5CF6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  // 멤버 선택 처리 (다중 계약 고려)
  Future<void> _handleMemberSelection(Map<String, dynamic> member) async {
    final validLSContracts = member['validLSContracts'] as List<Map<String, dynamic>>? ?? [];
    final validBillContracts = member['validBillContracts'] as List<Map<String, dynamic>>? ?? [];
    
    // LS 계약이 여러 개인 경우 선택 다이얼로그 표시
    if (validLSContracts.length > 1) {
      final selectedContract = await _showContractSelectionDialog(
        member['member_name'] ?? '',
        validLSContracts,
        'LS 계약'
      );
      
      if (selectedContract != null) {
        // 선택된 계약으로 멤버 정보 업데이트
        final updatedMember = Map<String, dynamic>.from(member);
        updatedMember['selectedLSContract'] = selectedContract;
        updatedMember['validLSContracts'] = [selectedContract]; // 선택된 계약만 남김
        
        setState(() {
          _selectedGroupMembers.add(updatedMember);
        });
      }
    } 
    // Bill 계약이 여러 개인 경우 선택 다이얼로그 표시
    else if (validBillContracts.length > 1) {
      final selectedContract = await _showContractSelectionDialog(
        member['member_name'] ?? '',
        validBillContracts,
        'Bill 계약'
      );
      
      if (selectedContract != null) {
        // 선택된 계약으로 멤버 정보 업데이트
        final updatedMember = Map<String, dynamic>.from(member);
        updatedMember['selectedBillContract'] = selectedContract;
        updatedMember['validBillContracts'] = [selectedContract]; // 선택된 계약만 남김
        
        setState(() {
          _selectedGroupMembers.add(updatedMember);
        });
      }
    }
    // 계약이 각각 1개씩만 있는 경우 바로 추가
    else {
      setState(() {
        _selectedGroupMembers.add(member);
      });
    }
  }

  // 계약 선택 다이얼로그
  Future<Map<String, dynamic>?> _showContractSelectionDialog(
    String memberName,
    List<Map<String, dynamic>> contracts,
    String contractType
  ) async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$memberName - $contractType 선택',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '여러 개의 유효한 계약이 있습니다. 사용할 계약을 선택해주세요.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                SizedBox(height: 16),
                
                // 계약 목록
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: contracts.length,
                    separatorBuilder: (context, index) => SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final contract = contracts[index];
                      return _buildContractSelectionTile(contract, contractType);
                    },
                  ),
                ),
                
                SizedBox(height: 16),
                // 취소 버튼
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      '취소',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 계약 선택 타일
  Widget _buildContractSelectionTile(Map<String, dynamic> contract, String contractType) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(contract),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '계약 ${contract['contract_history_id']}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
                Spacer(),
                Text(
                  '${contract['balance']}분',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Color(0xFF6B7280)),
                SizedBox(width: 4),
                Text(
                  '만료: ${contract['expiry_date']?.toString().split(' ')[0] ?? 'N/A'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            if (contract['pro_name'] != null) ...[
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Color(0xFF6B7280)),
                  SizedBox(width: 4),
                  Text(
                    '프로: ${contract['pro_name']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 선택된 멤버 요약
  Widget _buildSelectedMembersSummary() {
    final totalSelected = _getTotalSelectedCount();
    final maxCount = _getMaxPlayerCount();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border.all(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '선택된 참여자',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: totalSelected == maxCount ? Color(0xFF10B981) : Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalSelected/$maxCount명',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          
          if (totalSelected == 0) ...[
            Text(
              '아직 참여자가 선택되지 않았습니다.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          ] else ...[
            // 그룹 멤버들
            if (_selectedGroupMembers.isNotEmpty) ...[
              Text(
                '그룹 멤버 (${_selectedGroupMembers.length}명)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF374151),
                ),
              ),
              SizedBox(height: 4),
              ..._selectedGroupMembers.map((member) => Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Text(
                  '• ${member['member_name']} (${member['member_phone']})',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              )),
              if (_otherInvitedMembers.isNotEmpty) SizedBox(height: 8),
            ],
            
            // 초대된 멤버들
            if (_otherInvitedMembers.isNotEmpty) ...[
              Text(
                '초대 멤버 (${_otherInvitedMembers.length}명)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF374151),
                ),
              ),
              SizedBox(height: 4),
              ..._otherInvitedMembers.map((member) => Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Text(
                  '• ${member['name']} (${member['phone']}) ${member['is_member'] ? '[회원]' : '[비회원]'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              )),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                ),
              ),
              SizedBox(height: 12),
              Text(
                '동반자 초대 정보를 준비 중...',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목 및 설명
          Text(
            '동반자를 초대하세요',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '최대 ${_getMaxPlayerCount()}명까지 함께 예약할 수 있습니다. (현재 ${_invitedMembers.length + 1}명)',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
          SizedBox(height: 20),
          
          // 예약 정보 요약
          _buildReservationSummary(),
          
          // 그룹 멤버 선택
          if (_validGroupMembers.isNotEmpty) ...[
            Text(
              '그룹 멤버 선택 (유효한 계약 보유자)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            SizedBox(height: 8),
            Text(
              '현재 그룹에서 예약 가능한 멤버들입니다. 선택하여 함께 예약하세요.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: 12),
            ..._validGroupMembers.map((member) => _buildValidGroupMemberTile(member)),
            SizedBox(height: 20),
          ],
          
          // 다른 멤버 초대 버튼
          if (_getTotalSelectedCount() < _getMaxPlayerCount()) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showInviteOthersPopup = true;
                  });
                },
                icon: Icon(Icons.person_add, color: Color(0xFFF59E0B)),
                label: Text(
                  '다른 멤버 초대 (${_getAvailableSlots()}명 추가 가능)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Color(0xFFF59E0B), width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
          ],
          
          // 선택된 멤버 요약
          _buildSelectedMembersSummary(),
          
          SizedBox(height: 30),
          
          // 완료 버튼
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _completeGroupSetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                '그룹 구성 완료',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
        
        // 다른 멤버 초대 팝업
        if (_showInviteOthersPopup) _buildInviteOthersPopup(),
      ],
    );
  }

  // 다른 멤버 초대 팝업
  Widget _buildInviteOthersPopup() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          margin: EdgeInsets.all(20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  children: [
                    Text(
                      '다른 멤버 초대',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    Spacer(),
                    Text(
                      '최대 ${_getAvailableSlots()}명 추가 가능',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    SizedBox(width: 12),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _showInviteOthersPopup = false;
                          _resetInvitePopup();
                        });
                      },
                      icon: Icon(Icons.close, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              
              // 내용
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 전화번호 검색 섹션
                      Text(
                        '멤버 검색',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchInviteController,
                              decoration: InputDecoration(
                                hintText: '전화번호 입력',
                                prefixIcon: Icon(Icons.phone, color: Color(0xFF6B7280)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Color(0xFFF59E0B)),
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              onChanged: (value) {
                                // 전화번호가 완전히 입력되면 자동 검색
                                final normalizedPhone = _normalizePhoneNumber(value);
                                if (normalizedPhone.length >= 13) { // 010-1234-5678 형식
                                  _searchMemberByPhone(value);
                                } else if (value.trim().isEmpty) {
                                  setState(() {
                                    _inviteSearchResults = [];
                                  });
                                }
                              },
                            ),
                          ),
                          SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () => _searchMemberByPhone(_searchInviteController.text),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFF59E0B),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            child: Text('조회'),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      
                      // 검색 결과 표시
                      if (_isInviteSearching)
                        Container(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                            ),
                          ),
                        )
                      else if (_inviteSearchResults.isNotEmpty) ...[
                        // 검색 결과가 비회원 폼인지 회원인지 확인
                        if (_inviteSearchResults.first.containsKey('is_non_member'))
                          _buildNonMemberInviteTile(_inviteSearchResults.first['phone'])
                        else
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Color(0xFFF0FDF4),
                              border: Border.all(color: Color(0xFF10B981)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: _inviteSearchResults.map((member) => 
                                _buildInviteSearchResultTile(member)
                              ).toList(),
                            ),
                          ),
                        SizedBox(height: 16),
                      ],
                      
                      // 구분선
                      Divider(color: Color(0xFFE5E7EB), thickness: 1),
                      SizedBox(height: 16),
                      
                      // 초대 목록 섹션 (임시 장바구니 표시)
                      Text(
                        '초대 장바구니 (${_tempInviteCart.length}명)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      SizedBox(height: 12),
                      
                      if (_tempInviteCart.isEmpty)
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Color(0xFFF9FAFB),
                            border: Border.all(color: Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.people_outline, color: Color(0xFF6B7280), size: 32),
                                SizedBox(height: 8),
                                Text(
                                  '초대된 멤버가 없습니다.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '위에서 전화번호를 검색하여 멤버를 초대하세요.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._tempInviteCart.asMap().entries.map((entry) {
                          final index = entry.key;
                          final member = entry.value;
                          return _buildTempInviteCartCard(index, member);
                        }),
                    ],
                  ),
                ),
              ),
              
              // 하단 버튼
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _showInviteOthersPopup = false;
                            _resetInvitePopup();
                          });
                        },
                        child: Text('취소'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _canCompleteInvite() ? _completeInvite : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('초대 완료'),
                      ),
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

  // 검색 결과 타일 (회원/비회원 구분)
  Widget _buildInviteSearchResultTile(Map<String, dynamic> member) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectInviteMember(member),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Color(0xFF10B981)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFF10B981).withOpacity(0.1),
                  child: Icon(
                    Icons.person_outline,
                    color: Color(0xFF10B981),
                    size: 18,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            member['member_name'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '회원',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        '회원 정보가 확인되었습니다.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _selectInviteMember(member),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: Text(
                    '초대',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 비회원 초대 타일
  Widget _buildNonMemberInviteTile(String phone) {
    final nameController = TextEditingController();
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFF59E0B)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFF59E0B).withOpacity(0.1),
                child: Icon(
                  Icons.person_add_outlined,
                  color: Color(0xFFF59E0B),
                  size: 18,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '등록되지 않은 번호',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '비회원',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      '비회원으로 초대하려면 이름을 입력하세요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: '이름 입력',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFFF59E0B)),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    _inviteAsNonMember(phone, name);
                  } else {
                    _showMessage('이름을 입력해주세요.');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Text(
                  '초대',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 임시 장바구니 멤버 카드
  Widget _buildTempInviteCartCard(int index, Map<String, dynamic> member) {
    final isMember = member['is_member'] as bool;
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFFEF3C7), // 임시 상태를 나타내는 노란색 배경
        border: Border.all(color: Color(0xFFF59E0B)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isMember ? Color(0xFF10B981).withOpacity(0.1) : Color(0xFFF59E0B).withOpacity(0.1),
            child: Icon(
              isMember ? Icons.person : Icons.person_add_outlined,
              color: isMember ? Color(0xFF10B981) : Color(0xFFF59E0B),
              size: 18,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      member['name'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isMember ? Color(0xFF10B981) : Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isMember ? '회원' : '비회원',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  member['phone'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _removeTempInviteCartMember(index),
            icon: Icon(Icons.close, color: Color(0xFFEF4444), size: 18),
            constraints: BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  // 초대된 멤버 카드
  Widget _buildInvitedMemberCard(int index, Map<String, dynamic> member) {
    final isMember = member['is_member'] as bool;
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border.all(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isMember ? Color(0xFF10B981).withOpacity(0.1) : Color(0xFFF59E0B).withOpacity(0.1),
            child: Icon(
              isMember ? Icons.person : Icons.person_add_outlined,
              color: isMember ? Color(0xFF10B981) : Color(0xFFF59E0B),
              size: 18,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      member['name'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isMember ? Color(0xFF10B981) : Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isMember ? '회원' : '비회원',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  member['phone'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _removeInvitedMember(index),
            icon: Icon(Icons.close, color: Color(0xFFEF4444), size: 18),
            constraints: BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  // 입력 필드 타일
  Widget _buildInviteInputTile(int index, Map<String, dynamic> input) {
    final nameController = input['nameController'] as TextEditingController;
    final phoneController = input['phoneController'] as TextEditingController;
    final isVerified = input['verified'] as bool;
    final isMember = input['is_member'] as bool;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '멤버 ${index + 1}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              Spacer(),
              if (isVerified)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isMember ? Color(0xFF10B981) : Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isMember ? '회원' : '비회원',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              SizedBox(width: 8),
              IconButton(
                onPressed: () => _removeInviteInput(index),
                icon: Icon(Icons.close, color: Color(0xFFEF4444), size: 18),
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          SizedBox(height: 12),
          
          // 전화번호 입력
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: '전화번호',
                    hintText: '010-1234-5678',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFFF59E0B)),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (_) {
                    if (isVerified) {
                      setState(() {
                        input['verified'] = false;
                        input['is_member'] = false;
                        input['member_id'] = null;
                        nameController.clear();
                      });
                    }
                  },
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _lookupMemberByPhone(index),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Text(
                  '조회',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          
          // 이름 입력
          TextField(
            controller: nameController,
            enabled: !isMember || !isVerified,
            onChanged: (value) {
              // 비회원인 경우 이름 입력 시 검증 완료 처리
              if (!isMember && value.trim().isNotEmpty) {
                setState(() {
                  input['verified'] = true;
                });
              } else if (!isMember) {
                setState(() {
                  input['verified'] = false;
                });
              }
            },
            decoration: InputDecoration(
              labelText: '이름',
              hintText: isMember ? '회원 이름 자동 입력' : '이름을 입력하세요',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFFF59E0B)),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              filled: isMember && isVerified,
              fillColor: isMember && isVerified ? Color(0xFFF9FAFB) : null,
            ),
          ),
        ],
      ),
    );
  }

  // 예약 정보 요약 위젯
  Widget _buildReservationSummary() {
    if (widget.selectedDate == null) {
      return SizedBox.shrink();
    }

    final dateStr = DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(widget.selectedDate!);
    final timeStr = widget.selectedTime ?? '--:--';
    final proNameStr = widget.selectedProName ?? '프로 미선택';
    final tsStr = widget.selectedTsId != null ? '${widget.selectedTsId}번 타석' : '타석 미선택';
    
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFF59E0B).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '예약 정보',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF92400E),
            ),
          ),
          SizedBox(height: 8),
          _buildInfoRow('날짜', dateStr, Icons.calendar_today),
          if (widget.selectedProName != null)
            _buildInfoRow('강사', proNameStr, Icons.person),
          _buildInfoRow('시간', timeStr, Icons.access_time),
          if (widget.selectedTsId != null)
            _buildInfoRow('타석', tsStr, Icons.sports_golf),
          if (widget.selectedContract != null)
            _buildInfoRow('회원권', widget.selectedContract!['contract_name'] ?? '', Icons.payment),
        ],
      ),
    );
  }

  // 회원 검색 결과 타일
  Widget _buildMemberSearchTile(Map<String, dynamic> member) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFFF59E0B).withOpacity(0.1),
            child: Icon(
              Icons.person,
              color: Color(0xFFF59E0B),
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member['member_name'] ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  member['member_phone'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _inviteMember(member),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(
              '초대',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // 초대된 동반자 타일
  Widget _buildInvitedMemberTile(Map<String, dynamic> member) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFF0FDF4),
        border: Border.all(color: Color(0xFF10B981).withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFF10B981).withOpacity(0.1),
            child: Icon(
              Icons.person,
              color: Color(0xFF10B981),
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member['member_name'] ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  member['member_phone'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _removeMember(member),
            icon: Icon(
              Icons.close,
              color: Color(0xFFEF4444),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // 정보 행 위젯
  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Color(0xFF92400E),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF92400E),
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
}

// 타석 재배정 다이얼로그 위젯
class _TsReassignmentDialog extends StatefulWidget {
  final String currentTsId;
  final int currentMaxPerson;
  final int requiredCapacity;
  final bool isForced;
  final DateTime? selectedDate;
  final String? selectedTime;
  final int? selectedProId;
  final Map<String, dynamic> specialSettings;
  final List<Map<String, dynamic>> groupMembers;

  const _TsReassignmentDialog({
    Key? key,
    required this.currentTsId,
    required this.currentMaxPerson,
    required this.requiredCapacity,
    required this.isForced,
    this.selectedDate,
    this.selectedTime,
    this.selectedProId,
    required this.specialSettings,
    required this.groupMembers,
  }) : super(key: key);

  @override
  State<_TsReassignmentDialog> createState() => _TsReassignmentDialogState();
}

class _TsReassignmentDialogState extends State<_TsReassignmentDialog> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _availableTsList = [];
  String? _selectedNewTsId;
  String _assignmentType = 'same_ts'; // 'same_ts' or 'individual'
  Map<String, String> _individualAssignments = {}; // memberId -> tsId
  String? _currentMemberType;

  @override
  void initState() {
    super.initState();
    // 디버깅: 전달받은 그룹 멤버 확인
    print('');
    print('🔍 [재배정 다이얼로그] 전달받은 정보:');
    print('   그룹 멤버 수: ${widget.groupMembers.length}명');
    for (int i = 0; i < widget.groupMembers.length; i++) {
      final member = widget.groupMembers[i];
      final memberName = member['member_name'] ?? member['name'] ?? '이름없음';
      final memberId = member['member_id']?.toString() ?? '아이디없음';
      final isGroupMember = member['is_group_member'] ?? false;
      print('   멤버 ${i + 1}: $memberName (ID: $memberId, 그룹멤버: $isGroupMember)');
    }
    print('');
    
    // 수용인원 초과 시 강제로 개별 배정
    if (widget.requiredCapacity > widget.currentMaxPerson) {
      _assignmentType = 'individual';
    }
    _loadAvailableTsList();
  }

  Future<void> _loadAvailableTsList() async {
    try {
      print('');
      print('🔍 대체 가능한 타석 검색 시작');
      print('   필요 수용인원: ${widget.requiredCapacity}명 이상');
      print('   현재 타석: ${widget.currentTsId}번 (수용인원: ${widget.currentMaxPerson}명)');
      print('   배정 유형: ${_assignmentType == "same_ts" ? "같은 타석 사용" : "개별 타석 배정"}');
      
      final currentUser = ApiService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다.');
      }

      final branchId = ApiService.getCurrentBranchId() ?? '';
      final memberId = currentUser['member_id']?.toString() ?? '';

      // 현재 사용자의 회원 타입 조회
      _currentMemberType = await _getMemberType(memberId);
      print('   현재 회원 타입: $_currentMemberType');
      
      // 1. 모든 타석 정보 조회 (member_type_prohibited 포함)
      final allTsInfo = await ApiService.getData(
        table: 'v2_ts_info',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
        ],
        fields: ['ts_id', 'ts_status', 'max_person', 'ts_min_minimum', 'ts_min_maximum', 'member_type_prohibited'],
      );
      
      print('   전체 타석 수: ${allTsInfo.length}개');
      
      // 각 타석별 상세 정보 로그 출력
      for (final ts in allTsInfo) {
        final tsId = ts['ts_id']?.toString() ?? '';
        final tsStatus = ts['ts_status']?.toString() ?? '';
        final maxPerson = ts['max_person'];
        final memberTypeProhibited = ts['member_type_prohibited']?.toString() ?? '';
        
        print('   📍 타석 ${tsId}번:');
        print('     - 상태: $tsStatus');
        print('     - 최대수용: ${maxPerson ?? "제한없음"}명');
        print('     - 회원타입제한: ${memberTypeProhibited.isEmpty ? "없음" : memberTypeProhibited}');
      }
      
      // 2. 수용인원 조건에 맞는 타석 필터링
      final capacityFilteredTs = <Map<String, dynamic>>[];
      for (final ts in allTsInfo) {
        final tsId = ts['ts_id']?.toString() ?? '';
        final maxPerson = ts['max_person'];
        
        bool passesCapacity = false;
        String capacityReason = '';
        
        // 배정 유형에 따라 다른 수용인원 기준 적용
        if (_assignmentType == 'same_ts') {
          // 같은 타석 사용: 그룹 전체를 수용할 수 있어야 함
          if (maxPerson == null) {
            passesCapacity = true;
            capacityReason = '수용인원 제한 없음';
          } else if (maxPerson >= widget.requiredCapacity) {
            passesCapacity = true;
            capacityReason = '그룹 전체 수용 가능 (${maxPerson}명 >= ${widget.requiredCapacity}명)';
          } else {
            capacityReason = '그룹 전체 수용 불가 (${maxPerson}명 < ${widget.requiredCapacity}명)';
          }
        } else {
          // 개별 타석 배정: 최소 1명만 수용할 수 있으면 됨
          if (maxPerson == null) {
            passesCapacity = true;
            capacityReason = '수용인원 제한 없음';
          } else if (maxPerson >= 1) {
            passesCapacity = true;
            capacityReason = '개별 배정 가능 (${maxPerson}명 수용)';
          } else {
            capacityReason = '수용 불가 (${maxPerson}명)';
          }
        }
        
        if (passesCapacity) {
          print('   ✅ 타석 ${tsId}번: $capacityReason');
          capacityFilteredTs.add(ts);
        } else {
          print('   ❌ 타석 ${tsId}번: $capacityReason');
        }
      }
      
      print('   수용인원 조건 충족 타석: ${capacityFilteredTs.length}개');
      
      // 3. 가용성 체크 (기존 예약 충돌 확인)
      if (widget.selectedDate != null && widget.selectedTime != null) {
        print('   선택된 시간: ${widget.selectedTime}');
        
        // 선택된 시간대에 예약 충돌이 있는지 직접 체크
        // v2_priced_TS 테이블에서 해당 날짜/시간의 예약 조회
        final selectedDateStr = widget.selectedDate!.toIso8601String().split('T')[0];
        
        // 예약된 타석 조회
        final reservations = await ApiService.getData(
          table: 'v2_priced_TS',
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'ts_date', 'operator': '=', 'value': selectedDateStr},
          ],
          fields: ['ts_id', 'ts_start', 'ts_end', 'ts_status', 'member_id'],
        );
        
        print('   해당 날짜 전체 예약 수: ${reservations.length}개');
        
        // 현재 사용자 정보 가져오기
        final currentUser = ApiService.getCurrentUser();
        final currentMemberId = currentUser?['member_id']?.toString() ?? '';
        
        // 선택된 시간과 충돌하는 타석 찾기 (본인 예약 제외)
        final conflictingTsIds = <String>{};
        final selectedStartTime = widget.selectedTime!;
        
        // 선택된 시간을 분으로 변환
        final selectedParts = selectedStartTime.split(':');
        final selectedMinutes = int.parse(selectedParts[0]) * 60 + int.parse(selectedParts[1]);
        
        // 예약 시간을 50분으로 가정 (타석 시간)
        final selectedEndMinutes = selectedMinutes + 50;
        
        for (final reservation in reservations) {
          final tsId = reservation['ts_id']?.toString() ?? '';
          final tsStart = reservation['ts_start']?.toString() ?? '';
          final tsEnd = reservation['ts_end']?.toString() ?? '';
          final tsStatus = reservation['ts_status']?.toString() ?? '';
          final reservationMemberId = reservation['member_id']?.toString() ?? '';
          
          // 취소된 예약은 제외
          if (tsStatus == '취소') continue;
          
          // 본인의 예약은 충돌에서 제외
          if (reservationMemberId == currentMemberId) {
            print('     타석 ${tsId}번: 본인 예약으로 충돌 제외 (${tsStart}-${tsEnd})');
            continue;
          }
          
          // 시간 변환
          final startParts = tsStart.split(':');
          final endParts = tsEnd.split(':');
          final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
          final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
          
          // 버퍼 시간 추가 (10분)
          final bufferedEndMinutes = endMinutes + 10;
          
          // 충돌 체크
          if ((selectedMinutes >= startMinutes && selectedMinutes < bufferedEndMinutes) ||
              (selectedEndMinutes > startMinutes && selectedEndMinutes <= bufferedEndMinutes) ||
              (selectedMinutes <= startMinutes && selectedEndMinutes >= bufferedEndMinutes)) {
            conflictingTsIds.add(tsId);
            print('     타석 ${tsId}번: 예약 충돌 (${tsStart}-${tsEnd})');
          }
        }
        
        print('   충돌 타석 수: ${conflictingTsIds.length}개');
        print('   충돌 타석 ID: ${conflictingTsIds.toList()}');
        
        // 수용인원 충족 + 충돌하지 않는 + 회원타입 제한 체크
        _availableTsList = [];
        for (final ts in capacityFilteredTs) {
          final tsId = ts['ts_id']?.toString() ?? '';
          final isNotConflicting = !conflictingTsIds.contains(tsId);
          final memberTypeProhibited = ts['member_type_prohibited']?.toString() ?? '';
          
          // 회원 타입 제한 체크
          bool canUseTsForMembers = true;
          if (memberTypeProhibited.isNotEmpty) {
            final prohibitedTypes = memberTypeProhibited.split(',').map((t) => t.trim()).toList();
            
            if (_assignmentType == 'same_ts') {
              // 같은 타석 모드: 모든 그룹 멤버가 사용 가능해야 함 (예약자는 이미 확정)
              for (final member in widget.groupMembers) {
                final memberType = member['member_type']?.toString() ?? '';
                if (memberType.isNotEmpty && prohibitedTypes.contains(memberType)) {
                  canUseTsForMembers = false;
                  print('     타석 ${tsId}번: 그룹 멤버 ${member['member_name']}($memberType) 회원타입 제한');
                  break;
                }
              }
            } else {
              // 개별 배정 모드: 개별 드롭다운에서 체크하므로 여기서는 모든 타석 포함
              canUseTsForMembers = true;
            }
          }
          
          if (!isNotConflicting) {
            print('     ❌ 타석 ${tsId}번: 시간 충돌로 제외');
          } else if (!canUseTsForMembers) {
            print('     ❌ 타석 ${tsId}번: 회원타입 제한으로 제외 (제한: $memberTypeProhibited)');
          } else {
            print('     ✅ 타석 ${tsId}번: 최종 사용 가능');
            _availableTsList.add(ts);
          }
        }
        
        print('   최종 가용 타석: ${_availableTsList.length}개');
        for (final ts in _availableTsList) {
          final tsId = ts['ts_id']?.toString() ?? '';
          final maxPerson = ts['max_person'];
          final memberTypeProhibited = ts['member_type_prohibited']?.toString() ?? '';
          print('     - 타석 ${tsId}번 (수용: ${maxPerson ?? "제한없음"}명, 제한: ${memberTypeProhibited.isEmpty ? "없음" : memberTypeProhibited})');
        }
        
      } else {
        // 날짜/시간 정보가 없으면 수용인원만 체크
        _availableTsList = capacityFilteredTs;
      }
      
      // 현재 타석이 이미 사용 가능한 리스트에 있으면 맨 앞으로 이동
      final currentTs = allTsInfo.firstWhere(
        (ts) => ts['ts_id']?.toString() == widget.currentTsId,
        orElse: () => {},
      );
      
      if (currentTs.isNotEmpty) {
        final wasAlreadyInList = _availableTsList.any((ts) => ts['ts_id']?.toString() == widget.currentTsId);
        
        if (wasAlreadyInList) {
          // 이미 리스트에 있으면 맨 앞으로 이동
          _availableTsList.removeWhere((ts) => ts['ts_id']?.toString() == widget.currentTsId);
          _availableTsList.insert(0, currentTs);
          print('   📌 현재 타석 ${widget.currentTsId}번을 리스트 맨 앞으로 이동');
        } else {
          print('   📌 현재 타석 ${widget.currentTsId}번은 조건을 충족하지 않아 제외됨');
        }
      }
      
      print('   최종 선택 가능 타석: ${_availableTsList.length}개');
      
      // 최종 리스트의 타석들 출력
      print('   최종 타석 목록:');
      for (int i = 0; i < _availableTsList.length; i++) {
        final ts = _availableTsList[i];
        final tsId = ts['ts_id']?.toString() ?? '';
        final maxPerson = ts['max_person'];
        final isCurrent = tsId == widget.currentTsId;
        print('     ${i + 1}. 타석 ${tsId}번 (수용: ${maxPerson ?? "제한없음"}명)${isCurrent ? " ← 현재" : ""}');
      }
      print('');
      
      setState(() {
        _isLoading = false;
      });
      
    } catch (e) {
      print('❌ 가용 타석 조회 실패: $e');
      setState(() {
        _isLoading = false;
        _availableTsList = [];
      });
    }
  }

  // 회원 타입 조회
  Future<String> _getMemberType(String memberId) async {
    try {
      final memberData = await ApiService.getData(
        table: 'v3_members',
        where: [
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
        fields: ['member_type'],
      );
      
      if (memberData.isNotEmpty) {
        return memberData.first['member_type']?.toString() ?? '';
      }
      return '';
    } catch (e) {
      print('❌ 회원 타입 조회 실패: $e');
      return '';
    }
  }

  // 회원 타입 제한 체크
  bool _canUseTsForMemberType(Map<String, dynamic> tsInfo, String memberType) {
    final memberTypeProhibited = tsInfo['member_type_prohibited']?.toString() ?? '';
    if (memberTypeProhibited.isEmpty) return true;
    
    final prohibitedTypes = memberTypeProhibited.split(',');
    return !prohibitedTypes.contains(memberType);
  }

  @override
  Widget build(BuildContext context) {
    final isOverCapacity = widget.requiredCapacity > widget.currentMaxPerson;
    
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isOverCapacity ? Icons.warning : Icons.info_outline,
            color: isOverCapacity ? Colors.orange : Colors.blue,
            size: 24,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              isOverCapacity ? '타석 수용인원 초과' : '타석 배정 확인',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(maxHeight: 600),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 현재 상황 설명
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isOverCapacity 
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isOverCapacity 
                      ? Colors.orange.withOpacity(0.3)
                      : Colors.blue.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '예약 인원: ${widget.requiredCapacity}명',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '현재 타석(${widget.currentTsId}번) 수용인원: ${widget.currentMaxPerson}명',
                      style: TextStyle(
                        color: isOverCapacity ? Colors.deepOrange : Colors.grey[700],
                      ),
                    ),
                    if (isOverCapacity) ...[
                      SizedBox(height: 8),
                      Text(
                        '⚠️ ${widget.requiredCapacity - widget.currentMaxPerson}명 초과되었습니다.',
                        style: TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '다른 타석을 선택해주세요.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ] else ...[
                      SizedBox(height: 8),
                      Text(
                        '✅ 현재 타석을 유지하거나 다른 타석을 선택할 수 있습니다.',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              SizedBox(height: 16),

              // 배정 방식 선택 (수용인원 초과가 아닌 경우만)
              if (!isOverCapacity) ...[
                Text(
                  '배정 방식',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 8),
                Column(
                  children: [
                    RadioListTile<String>(
                      value: 'same_ts',
                      groupValue: _assignmentType,
                      onChanged: (value) {
                        setState(() {
                          _assignmentType = value!;
                          _selectedNewTsId = null;
                          _individualAssignments.clear();
                        });
                        _loadAvailableTsList(); // 배정 유형 변경 시 리스트 재로드
                      },
                      title: Text(
                        '같은 타석',
                        style: TextStyle(fontSize: 12),
                      ),
                      subtitle: Text(
                        '모든 멤버 동일 타석',
                        style: TextStyle(fontSize: 10),
                      ),
                      dense: true,
                    ),
                    RadioListTile<String>(
                      value: 'individual',
                      groupValue: _assignmentType,
                      onChanged: (value) {
                        setState(() {
                          _assignmentType = value!;
                          _selectedNewTsId = null;
                          _individualAssignments.clear();
                        });
                        _loadAvailableTsList(); // 배정 유형 변경 시 리스트 재로드
                      },
                      title: Text(
                        '개별 배정',
                        style: TextStyle(fontSize: 12),
                      ),
                      subtitle: Text(
                        '멤버별 다른 타석',
                        style: TextStyle(fontSize: 10),
                      ),
                      dense: true,
                    ),
                  ],
                ),
                SizedBox(height: 16),
              ],
              
              // 타석 선택 리스트
              Text(
                _assignmentType == 'same_ts' ? '타석 선택' : '개별 타석 배정',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              
              if (_isLoading) ...[
                Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                  ),
                ),
              ] else if (_availableTsList.isEmpty) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '선택 가능한 타석이 없습니다.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _assignmentType == 'same_ts' 
                    ? _buildSameTsSelection()
                    : _buildIndividualAssignmentList(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (!widget.isForced) ...[
          TextButton(
            onPressed: () {
              // 현재 타석 유지
              Navigator.of(context).pop(null);
            },
            child: Text(
              '현재 타석 유지',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
        if (!widget.isForced || _availableTsList.isNotEmpty) ...[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(null);
            },
            child: Text(
              '취소',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
        ElevatedButton(
          onPressed: _canConfirm()
            ? () {
                final result = _buildResult();
                Navigator.of(context).pop(result);
              }
            : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFF59E0B),
            foregroundColor: Colors.white,
          ),
          child: Text('확인'),
        ),
      ],
    );
  }

  // 같은 타석 선택 UI
  Widget _buildSameTsSelection() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _availableTsList.length,
      itemBuilder: (context, index) {
        final ts = _availableTsList[index];
        final tsId = ts['ts_id']?.toString() ?? '';
        final maxPerson = ts['max_person'];
        final isCurrentTs = tsId == widget.currentTsId;
        final isCapacitySufficient = maxPerson == null || 
                                     maxPerson >= widget.requiredCapacity;
        
        return RadioListTile<String>(
          value: tsId,
          groupValue: _selectedNewTsId ?? (isCurrentTs && !widget.isForced ? widget.currentTsId : null),
          onChanged: isCapacitySufficient 
            ? (value) {
                setState(() {
                  _selectedNewTsId = value;
                });
              }
            : null,
          title: Row(
            children: [
              Text(
                '${tsId}번 타석',
                style: TextStyle(
                  fontWeight: isCurrentTs ? FontWeight.bold : FontWeight.normal,
                  color: isCapacitySufficient ? Colors.black : Colors.grey,
                ),
              ),
              if (isCurrentTs) ...[
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '현재',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            '수용인원: ${maxPerson ?? "제한없음"}명',
            style: TextStyle(
              fontSize: 12,
              color: isCapacitySufficient 
                ? Colors.grey[600]
                : Colors.red,
            ),
          ),
          activeColor: Color(0xFFF59E0B),
        );
      },
    );
  }

  // 개별 배정 UI
  Widget _buildIndividualAssignmentList() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: widget.groupMembers.length,
      itemBuilder: (context, index) {
        final member = widget.groupMembers[index];
        final memberName = member['member_name'] ?? member['name'] ?? '';
        final memberId = member['member_id']?.toString() ?? '';
        final memberType = member['member_type'] ?? _currentMemberType ?? '';
        final assignedTsId = _individualAssignments[memberId];
        
        return Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                memberName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                '회원타입: $memberType',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: assignedTsId,
                decoration: InputDecoration(
                  labelText: '타석 선택',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                items: _availableTsList
                  .where((ts) => _canUseTsForMemberType(ts, memberType))
                  .map((ts) {
                    final tsId = ts['ts_id']?.toString() ?? '';
                    final maxPerson = ts['max_person'];
                    final isCurrentTs = tsId == widget.currentTsId;
                    
                    return DropdownMenuItem<String>(
                      value: tsId,
                      child: Text(
                        isCurrentTs 
                          ? '${tsId}번 타석 (현재 타석)' 
                          : '${tsId}번 타석 (수용: ${maxPerson ?? "제한없음"}명)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                onChanged: (value) {
                  setState(() {
                    if (value != null) {
                      _individualAssignments[memberId] = value;
                    } else {
                      _individualAssignments.remove(memberId);
                    }
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 확인 버튼 활성화 여부
  bool _canConfirm() {
    if (!widget.isForced && widget.requiredCapacity <= widget.currentMaxPerson) {
      return true; // 현재 타석 유지 가능
    }
    
    if (_assignmentType == 'same_ts') {
      return _selectedNewTsId != null;
    } else {
      return _individualAssignments.length == widget.groupMembers.length;
    }
  }

  // 결과 객체 생성
  Map<String, dynamic> _buildResult() {
    if (_assignmentType == 'same_ts') {
      return {
        'type': 'same_ts',
        'ts_id': _selectedNewTsId ?? widget.currentTsId,
      };
    } else {
      return {
        'type': 'individual',
        'assignments': _individualAssignments,
      };
    }
  }
}