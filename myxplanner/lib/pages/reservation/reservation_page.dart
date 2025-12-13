import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/tab_design_service.dart';
import '../../services/tile_design_service.dart';
import 'ts_reservation/step0_structure.dart';
import 'ls_reservation/ls_step0_structure.dart';
import 'special_reservation/special_reservation_page.dart';

class ReservationPage extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;
  final String? initialReservationType; // 초기 예약 타입 (ts_reservation, lesson_reservation 등)
  final DateTime? initialDate; // 초기 날짜 (레슨에서 타석 예약 시 사용)
  final String? initialTime; // 초기 시작 시간 (레슨에서 타석 예약 시 사용)

  const ReservationPage({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
    this.initialReservationType,
    this.initialDate,
    this.initialTime,
  }) : super(key: key);

  @override
  _ReservationPageState createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage> {
  List<Map<String, dynamic>> reservationTypes = [];
  bool isLoading = true;
  String? errorMessage;
  String? selectedReservationType; // 선택된 예약 타입
  bool isValidatingMembership = false; // 회원권 검증 상태

  @override
  void initState() {
    super.initState();
    _loadReservationTypes();
  }

  // 예약 타입들 로드
  Future<void> _loadReservationTypes() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // 기본 예약 타입들
      List<Map<String, dynamic>> types = [
        {
          'title': '타석 예약',
          'subtitle': '골프 연습장 타석을 예약하세요',
          'type': 'ts_reservation',
          'icon': Icons.sports_golf,
        },
        {
          'title': '레슨 예약',
          'subtitle': '전문 강사와 함께하는 골프 레슨',
          'type': 'lesson_reservation',
          'icon': Icons.school,
        },
      ];

      print('기본 예약 타입 로드 완료: ${types.length}개');

      List<Map<String, dynamic>> allSpecialSettings = [];
      try {
        // 특수 예약 타입들 로드 (검증에 필요한 모든 필드도 함께 조회)
        print('특수 예약 타입 로드 시작...');
        final branchId = widget.branchId ?? ApiService.getCurrentBranchId();
        
        // 검증에 필요한 모든 필드를 한 번에 조회
        final whereConditions = [
          {'field': 'category', 'operator': '=', 'value': '특수타석예약'},
          {'field': 'setting_status', 'operator': '=', 'value': '유효'},
        ];
        
        if (branchId != null) {
          whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
        }
        
        allSpecialSettings = await ApiService.getData(
          table: 'v2_base_option_setting',
          fields: ['table_name', 'field_name', 'option_value'],
          where: whereConditions,
        );

        print('특수 예약 API 응답: ${allSpecialSettings.length}개 항목');

        // 특수 예약 설정이 있는 경우에만 추가
        if (allSpecialSettings.isNotEmpty) {
          // 각 특수 예약 상품을 개별 타입으로 추가
          final Set<String> uniqueTableNames = {};
          for (final setting in allSpecialSettings) {
            print('특수 예약 설정: $setting');
            if (setting['table_name'] != null && setting['table_name'].toString().isNotEmpty) {
              uniqueTableNames.add(setting['table_name'].toString());
              print('추가된 테이블명: ${setting['table_name']}');
            }
          }

          print('유니크 테이블명 총 ${uniqueTableNames.length}개: $uniqueTableNames');

          // 각 특수 예약 상품을 개별 타일로 생성
          for (String tableName in uniqueTableNames) {
            types.add({
              'title': tableName,
              'subtitle': '특별한 골프 경험을 예약하세요',
              'type': tableName,
              'icon': Icons.star,
            });
            print('특수 예약 타일 추가: $tableName');
          }
        } else {
          print('특수 예약 설정이 없습니다. 기본 예약 타입만 표시합니다.');
        }

        print('최종 예약 타입 총 ${types.length}개');

      } catch (specialError) {
        print('특수 예약 로드 실패: $specialError');
        // 특수 예약 로드 실패해도 기본 예약은 보여주기
      }

      // 특수 예약 타입들에 대해 회원권 사전 검증 수행 (이미 조회한 설정 데이터 전달)
      await _validateSpecialReservationTypes(types, allSpecialSettings);

      // 비활성화된 항목(회원권 필요)은 목록에서 제거
      types = types.where((type) {
        final isEnabled = type['isEnabled'] ?? true;
        return isEnabled;
      }).toList();

      setState(() {
        reservationTypes = types;
        isLoading = false;
      });
      
      // 초기 예약 타입이 지정된 경우 자동 선택
      if (widget.initialReservationType != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _selectReservationType(widget.initialReservationType!);
          }
        });
      }

    } catch (e) {
      print('전체 예약 타입 로드 실패: $e');
      setState(() {
        errorMessage = '예약 타입을 불러오는데 실패했습니다: $e';
        isLoading = false;
      });
    }
  }

  // 특수 예약 타입들에 대한 회원권 사전 검증
  Future<void> _validateSpecialReservationTypes(
    List<Map<String, dynamic>> types,
    List<Map<String, dynamic>> allSpecialSettings,
  ) async {
    try {
      print('🔍 특수 예약 타입 회원권 사전 검증 시작');

      // widget.selectedMember를 우선 사용, 없으면 ApiService에서 가져오기
      final memberData = widget.selectedMember ?? ApiService.getCurrentUser();
      final memberId = memberData?['member_id'];

      if (memberId == null) {
        print('❌ 회원 ID가 없어서 검증 건너뜀');
        return;
      }

      print('✅ 회원 ID 확인: $memberId');
      
      final branchId = widget.branchId ?? ApiService.getCurrentBranchId();
      if (branchId == null) {
        print('❌ 브랜치 ID가 없어서 검증 건너뜀');
        return;
      }

      // 시간권과 레슨권 데이터 병렬 조회로 성능 개선
      print('💼 회원권 데이터 병렬 조회 시작...');
      final results = await Future.wait([
        ApiService.getMemberTimePassesByContractForProgram(
          memberId: memberId.toString(),
        ),
        ApiService.getMemberLsCountingDataForProgram(
          memberId: memberId.toString(),
        ),
      ]);
      
      final timePassContracts = results[0] as List<Map<String, dynamic>>;
      final lessonContractsResponse = results[1] as Map<String, dynamic>;
      final lessonContracts = (lessonContractsResponse['data'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>() ?? [];

      print('💼 회원권 조회 결과 - 시간권: ${timePassContracts.length}개, 레슨권: ${lessonContracts.length}개');

      // 이미 조회한 설정 데이터를 타입별로 그룹화 (메모리에서 처리)
      final Map<String, List<Map<String, dynamic>>> settingsByTableName = {};
      for (final setting in allSpecialSettings) {
        final tableName = setting['table_name']?.toString();
        if (tableName != null && tableName.isNotEmpty) {
          if (!settingsByTableName.containsKey(tableName)) {
            settingsByTableName[tableName] = [];
          }
          settingsByTableName[tableName]!.add(setting);
        }
      }

      // 각 특수 예약 타입 검증
      for (int i = 0; i < types.length; i++) {
        final type = types[i];
        final typeString = type['type'] as String;
        
        // 기본 예약 타입은 건너뛰기
        if (['ts_reservation', 'lesson_reservation'].contains(typeString)) {
          continue;
        }

        print('🔍 검증 중: $typeString');
        
        try {
          // 이미 조회한 설정 데이터에서 해당 타입의 설정만 필터링 (API 호출 없음)
          final specialSettings = settingsByTableName[typeString] ?? [];

          // 레슨 옵션 여부와 프로그램 ID 추출
          int totalLsMin = 0;
          String? programId;
          
          for (final setting in specialSettings) {
            final fieldName = setting['field_name']?.toString() ?? '';
            final optionValue = setting['option_value']?.toString() ?? '';
            
            if (fieldName.startsWith('ls_min(')) {
              if (optionValue.isNotEmpty) {
                final minValue = int.tryParse(optionValue) ?? 0;
                totalLsMin += minValue;
              }
            } else if (fieldName == 'program_id') {
              programId = optionValue;
            }
          }
          
          final hasInstructorOption = totalLsMin > 0;
          
          // 프로그램 접근 권한 확인
          bool hasValidProgramAccess = false;
          for (final contract in timePassContracts) {
            final programAvailability = contract['program_reservation_availability']?.toString() ?? '';
            if (programId != null && programAvailability.contains(programId)) {
              hasValidProgramAccess = true;
              break;
            }
          }
          
          // 회원권 유효성 판정
          bool isValidMembership = false;
          String missingMembership = '';

          if (!hasValidProgramAccess) {
            missingMembership = '프로그램 전용 회원권 (program_id: $programId)';
          } else if (hasInstructorOption) {
            // 레슨 포함: 시간권 + 레슨권 모두 필요
            if (timePassContracts.isNotEmpty && lessonContracts.isNotEmpty) {
              isValidMembership = true;
            } else {
              List<String> missing = [];
              if (timePassContracts.isEmpty) missing.add('타석용 시간권');
              if (lessonContracts.isEmpty) missing.add('레슨권');
              missingMembership = missing.join(' 및 ');
            }
          } else {
            // 타석 전용: 시간권만 필요
            if (timePassContracts.isNotEmpty) {
              isValidMembership = true;
            } else {
              missingMembership = '타석용 시간권';
            }
          }
          
          // 결과 적용
          types[i]['isEnabled'] = isValidMembership;
          if (!isValidMembership) {
            types[i]['disabledMessage'] = missingMembership;
            print('❌ $typeString: 회원권 부족 - $missingMembership');
          } else {
            print('✅ $typeString: 회원권 유효');
          }
          
        } catch (e) {
          print('❌ $typeString 검증 실패: $e');
          types[i]['isEnabled'] = false;
          types[i]['disabledMessage'] = '검증 실패';
        }
      }
      
      print('🔍 특수 예약 타입 회원권 사전 검증 완료');
      
    } catch (e) {
      print('❌ 특수 예약 타입 검증 실패: $e');
    }
  }

  // 예약 타입 선택 시 콘텐츠 변경
  void _selectReservationType(String type) async {
    // 선택된 타입의 정보 찾기
    final selectedType = reservationTypes.firstWhere(
      (item) => item['type'] == type,
      orElse: () => {},
    );

    // 비활성화된 타입을 선택한 경우 즉시 안내 메시지 표시
    if (selectedType['isEnabled'] == false) {
      final disabledMessage = selectedType['disabledMessage'] as String? ?? '이용할 수 없습니다';
      _showNoValidMembershipDialog(
        type, 
        disabledMessage, 
        false, // hasInstructorOption은 여기서는 중요하지 않음
        null,  // programId도 여기서는 중요하지 않음
      );
      return;
    }

    // 특수 예약의 경우 이미 사전 검증을 통과했으므로 바로 진행
    // 일반 타석/레슨 예약도 바로 진행
    setState(() {
      selectedReservationType = type;
    });
  }

  // 유효한 회원권이 없을 때 다이얼로그
  void _showNoValidMembershipDialog(String specialType, String missingMembership, bool hasInstructorOption, String? programId) {
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('이용 불가'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$specialType 예약에 필요한 회원권이 없습니다.'),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '부족한 회원권:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      missingMembership,
                      style: TextStyle(fontSize: 14, color: Colors.red[600]),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              Text(
                '필요한 회원권을 구매하신 후 이용해주세요.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('확인'),
            ),
          ],
        );
      },
    );
  }

  // 에러 다이얼로그
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('오류'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('확인'),
            ),
          ],
        );
      },
    );
  }

  // 메인 예약 화면으로 돌아가기
  void _goBackToMain() {
    // 레슨 조회에서 왔을 경우 (initialDate가 있으면) Navigator.pop()으로 조회 페이지로 복귀
    if (widget.initialDate != null) {
      Navigator.of(context).pop();
      return;
    }
    
    setState(() {
      selectedReservationType = null;
    });
  }

  // 선택된 예약 타입에 따른 콘텐츠 위젯 반환
  Widget _buildSelectedContent() {
    if (selectedReservationType == null) {
      return _buildReservationGrid();
    }

    switch (selectedReservationType) {
      case 'ts_reservation':
        return Step0Structure(
          isAdminMode: widget.isAdminMode,
          selectedMember: widget.selectedMember,
          branchId: widget.branchId,
          initialDate: widget.initialDate,
          initialTime: widget.initialTime,
        );
      case 'lesson_reservation':
        return LsStep0Structure(
          isAdminMode: widget.isAdminMode,
          selectedMember: widget.selectedMember,
          branchId: widget.branchId,
        );
      default:
        // 특수 예약 타입들 처리
        return SpecialReservationContent(
          isAdminMode: widget.isAdminMode,
          selectedMember: widget.selectedMember,
          branchId: widget.branchId,
          specialType: selectedReservationType,
        );
    }
  }

  // 예약 타입 그리드 위젯
  Widget _buildReservationGrid() {
    return TileDesignService.buildGrid(
      items: reservationTypes,
      onItemTap: _selectReservationType,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: TabDesignService.backgroundColor,
        appBar: TabDesignService.buildAppBar(title: '예약하기'),
        body: Center(
          child: TileDesignService.buildLoading(
            title: '예약하기',
            message: '예약 옵션을 불러오는 중...',
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: TabDesignService.backgroundColor,
        appBar: TabDesignService.buildAppBar(title: '예약하기'),
        body: Center(
          child: TileDesignService.buildError(
            errorMessage: errorMessage!,
            onRetry: _loadReservationTypes,
          ),
        ),
      );
    }

    // 앱바 제목 동적 변경
    String appBarTitle = '예약하기';
    if (selectedReservationType != null) {
      final selectedType = reservationTypes.firstWhere(
        (type) => type['type'] == selectedReservationType,
        orElse: () => {'title': '예약하기'},
      );
      appBarTitle = selectedType['title'];
    }

    return Scaffold(
      backgroundColor: TabDesignService.backgroundColor,
      appBar: TabDesignService.buildAppBar(
        title: appBarTitle,
        leading: selectedReservationType != null 
          ? IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: _goBackToMain,
            )
          : null,
      ),
      body: _buildSelectedContent(),
    );
  }
} 