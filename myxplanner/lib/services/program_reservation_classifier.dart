import 'api_service.dart';

/// 프로그램 예약 전용 상품과 일반 상품을 분류하는 서비스
/// 
/// 이 서비스는 계약 목록을 받아서 프로그램 전용 상품과 일반 상품을 구분합니다.
/// v2_contracts 테이블의 program_reservation_availability 필드를 기준으로 분류합니다.
/// 
/// 사용 예시:
/// 1. 일반 상품만 조회 (크레딧, 레슨권, 시간권 조회 페이지)
///    final generalContracts = await ProgramReservationClassifier.filterContracts(
///      contracts: allContracts,
///      branchId: branchId,
///      includeProgram: false,  // 프로그램 전용 상품 제외
///    );
/// 
/// 2. 프로그램 전용 상품만 조회 (프로그램 예약 조회 페이지)
///    final programContracts = await ProgramReservationClassifier.filterContracts(
///      contracts: allContracts,
///      branchId: branchId,
///      includeProgram: true,   // 프로그램 전용 상품만 포함
///      excludeGeneral: true,   // 일반 상품 제외
///    );
/// 
/// 3. 모든 상품 조회 (필터링 없음)
///    final allContracts = await ProgramReservationClassifier.filterContracts(
///      contracts: allContracts,
///      branchId: branchId,
///      includeProgram: true,   // 프로그램 전용 상품 포함
///      includeGeneral: true,   // 일반 상품도 포함
///    );
class ProgramReservationClassifier {
  
  /// 계약 목록을 프로그램 전용/일반 상품으로 분류하여 필터링
  /// 
  /// [contracts]: 필터링할 계약 목록
  /// [branchId]: 지점 ID
  /// [includeProgram]: 프로그램 전용 상품 포함 여부 (기본: false)
  /// [includeGeneral]: 일반 상품 포함 여부 (기본: true)
  /// [excludeGeneral]: 일반 상품 제외 여부 (기본: false) - includeGeneral보다 우선
  /// 
  /// 반환: 필터링된 계약 목록
  static Future<List<Map<String, dynamic>>> filterContracts({
    required List<Map<String, dynamic>> contracts,
    required String branchId,
    bool includeProgram = false,
    bool includeGeneral = true,
    bool excludeGeneral = false,
  }) async {
    final filteredContracts = <Map<String, dynamic>>[];
    
    print('=== 프로그램 분류 서비스 시작 ===');
    print('입력 계약 수: ${contracts.length}');
    print('includeProgram: $includeProgram');
    print('includeGeneral: $includeGeneral');
    print('excludeGeneral: $excludeGeneral');
    
    for (int i = 0; i < contracts.length; i++) {
      final contract = contracts[i];
      final contractId = contract['contract_id']?.toString();
      final contractName = contract['contract_name'] ?? '';
      
      if (contractId == null) {
        print('계약 $i: contract_id가 null, 건너뜀');
        continue;
      }
      
      try {
        // v2_contracts에서 프로그램 전용 상품 여부 확인
        final contractDetails = await ApiService.getData(
          table: 'v2_contracts',
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'contract_id', 'operator': '=', 'value': contractId},
          ],
        );
        
        if (contractDetails.isEmpty) {
          print('계약 $i ($contractName): v2_contracts에서 찾을 수 없음, 건너뜀');
          continue;
        }
        
        final detail = contractDetails[0];
        final programReservationAvailability = detail['program_reservation_availability']?.toString() ?? '';
        // null, 빈칸, '0'은 모두 일반 상품
        final isProgramContract = programReservationAvailability.isNotEmpty && programReservationAvailability != '0';

        print('계약 $i ($contractName): program_reservation_availability="$programReservationAvailability", isProgramContract=$isProgramContract');
        
        // 필터링 로직
        bool shouldInclude = false;
        
        if (isProgramContract) {
          // 프로그램 전용 상품인 경우
          if (includeProgram) {
            shouldInclude = true;
            print('  -> ✅ 프로그램 전용 상품 포함');
          } else {
            print('  -> ❌ 프로그램 전용 상품 제외');
          }
        } else {
          // 일반 상품인 경우
          if (excludeGeneral) {
            shouldInclude = false;
            print('  -> ❌ 일반 상품 제외 (excludeGeneral=true)');
          } else if (includeGeneral) {
            shouldInclude = true;
            print('  -> ✅ 일반 상품 포함');
          } else {
            print('  -> ❌ 일반 상품 제외 (includeGeneral=false)');
          }
        }
        
        if (shouldInclude) {
          filteredContracts.add(contract);
        }
        
      } catch (e) {
        print('계약 $i ($contractName): v2_contracts 조회 실패 - $e');
      }
    }
    
    print('필터링 결과: ${filteredContracts.length}/${contracts.length}개 계약');
    print('=== 프로그램 분류 서비스 종료 ===');
    
    return filteredContracts;
  }
  
  /// 단일 계약이 프로그램 전용 상품인지 확인
  /// 
  /// [contractId]: 계약 ID
  /// [branchId]: 지점 ID
  /// 
  /// 반환: 프로그램 전용 상품 여부
  static Future<bool> isProgramContract({
    required String contractId,
    required String branchId,
  }) async {
    try {
      final contractDetails = await ApiService.getData(
        table: 'v2_contracts',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'contract_id', 'operator': '=', 'value': contractId},
        ],
      );
      
      if (contractDetails.isEmpty) {
        return false;
      }

      final programReservationAvailability = contractDetails[0]['program_reservation_availability']?.toString() ?? '';
      // null, 빈칸, '0'은 모두 일반 상품
      return programReservationAvailability.isNotEmpty && programReservationAvailability != '0';

    } catch (e) {
      print('isProgramContract 에러: $e');
      return false;
    }
  }
  
  /// 프로그램 전용 상품의 프로그램 ID 목록 반환
  /// 
  /// [contractId]: 계약 ID
  /// [branchId]: 지점 ID
  /// 
  /// 반환: 프로그램 ID 목록 (콤마로 구분된 문자열을 List로 변환)
  static Future<List<String>> getProgramIds({
    required String contractId,
    required String branchId,
  }) async {
    try {
      final contractDetails = await ApiService.getData(
        table: 'v2_contracts',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'contract_id', 'operator': '=', 'value': contractId},
        ],
      );
      
      if (contractDetails.isEmpty) {
        return [];
      }

      final programReservationAvailability = contractDetails[0]['program_reservation_availability']?.toString() ?? '';
      // null, 빈칸, '0'은 모두 일반 상품
      if (programReservationAvailability.isEmpty || programReservationAvailability == '0') {
        return [];
      }

      return programReservationAvailability.split(',').map((id) => id.trim()).where((id) => id.isNotEmpty).toList();
      
    } catch (e) {
      print('getProgramIds 에러: $e');
      return [];
    }
  }
}