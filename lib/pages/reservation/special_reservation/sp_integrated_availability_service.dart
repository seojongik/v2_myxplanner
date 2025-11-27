import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import 'package:intl/intl.dart';
import 'sp_ts_availability_service.dart';
import 'sp_ls_availability_service.dart';

class SpIntegratedAvailabilityService {
  /// 특수 예약 통합 가용성 조회 (타석 + 레슨)
  static Future<Map<String, dynamic>> findIntegratedAvailableOptions({
    required String branchId,
    required String memberId,
    required DateTime selectedDate,
    required String? selectedProId,
    required String? selectedProName,
    required Map<String, dynamic> specialSettings,
  }) async {
    try {
      final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      print('');
      print('╔═══════════════════════════════════════════════════════════╗');
      print('║  통합 가용성 서비스 호출됨                               ║');
      print('╚═══════════════════════════════════════════════════════════╝');
      print('🔍 통합 가용성 조회 시작');
      print('📅 날짜: $selectedDateStr');
      print('🎯 지점 ID: $branchId');
      print('👤 회원 ID: $memberId');
      print('👨‍🏫 프로 ID: $selectedProId');
      print('👨‍🏫 프로 이름: $selectedProName');
      
      // hasInstructorOption 계산
      int totalLsMin = 0;
      specialSettings.forEach((key, value) {
        if (key.startsWith('ls_min(')) {
          int minValue = 0;
          if (value != null && value.toString().isNotEmpty) {
            minValue = int.tryParse(value.toString()) ?? 0;
          }
          totalLsMin += minValue;
        }
      });
      final hasInstructorOption = totalLsMin > 0;
      
      print('🎓 레슨 옵션 포함: $hasInstructorOption (총 레슨시간: ${totalLsMin}분)');
      
      // 1. 타석 가용성 조회
      print('\n📋 1단계: 타석 가용성 조회');
      final tsDurationMinutes = int.tryParse(specialSettings['ts_min']?.toString() ?? '60') ?? 60;
      print('   요청 타석 시간: ${tsDurationMinutes}분');

      final tsResult = await SpTsAvailabilityService.findAvailableTimeSlotsForAllTs(
        branchId: branchId,
        memberId: memberId,
        selectedDate: selectedDate,
        durationMinutes: tsDurationMinutes,
        timeSlotInterval: 5,
      );

      if (!tsResult['success']) {
        print('❌ 타석 가용성 조회 실패: ${tsResult['error']}');
        print('🔍 실패 원인 상세:');
        print('   - 에러 메시지: ${tsResult['error']}');
        return tsResult;
      }

      final tsAvailability = tsResult['time_slot_availability'] as List<Map<String, dynamic>>;
      print('✅ 타석 가용 시간대: ${tsAvailability.length}개');

      if (tsAvailability.isEmpty) {
        print('❌ 타석 가용 시간대가 0개입니다!');
        print('   (상세 사유는 위의 [타석] 로그를 확인하세요)');
        return {
          'success': false,
          'error': '선택한 날짜에 예약 가능한 타석 시간대가 없습니다.'
        };
      }
      
      // 2. 레슨 옵션이 있는 경우 레슨 가용성 조회
      List<Map<String, dynamic>> lsAvailability = [];
      if (hasInstructorOption && selectedProId != null && selectedProName != null) {
        print('\n📋 2단계: 레슨 가용성 조회');
        print('   선택된 프로: $selectedProName (ID: $selectedProId)');

        final lsResult = await SpLsAvailabilityService.findAvailableLessonTimeOptions(
          branchId: branchId,
          memberId: memberId,
          selectedDate: selectedDate,
          selectedProId: selectedProId,
          selectedProName: selectedProName,
          specialSettings: specialSettings,
        );

        if (!lsResult['success']) {
          print('❌ 레슨 가용성 조회 실패: ${lsResult['error']}');
          print('🔍 실패 원인 상세:');
          print('   - 에러 메시지: ${lsResult['error']}');
          return lsResult;
        }

        lsAvailability = lsResult['available_options'] as List<Map<String, dynamic>>;
        print('✅ 레슨 가용 시간대: ${lsAvailability.length}개');

        if (lsAvailability.isEmpty) {
          print('❌ 레슨 가용 시간대가 0개입니다!');
          print('   (상세 사유는 위의 [레슨] 로그를 확인하세요)');
          return {
            'success': false,
            'error': '선택한 날짜에 예약 가능한 레슨 시간대가 없습니다.'
          };
        }
      }
      
      // 3. 통합 가용성 계산
      print('\n📋 3단계: 통합 가용성 계산');
      print('   타석 가용 시간대: ${tsAvailability.length}개');
      print('   레슨 가용 시간대: ${lsAvailability.length}개');
      print('   모드: ${hasInstructorOption ? "타석+레슨 조합" : "타석 전용"}');

      final integratedOptions = _calculateIntegratedAvailability(
        tsAvailability,
        lsAvailability,
        hasInstructorOption,
        tsDurationMinutes,
      );

      print('✅ 통합 가용성 조회 완료');
      print('   최종 예약 가능 시간대: ${integratedOptions.length}개');

      if (integratedOptions.isEmpty) {
        print('');
        print('❌❌❌ 최종 예약 가능 시간대가 0개입니다! ❌❌❌');
        print('🔍 상세 분석:');
        if (hasInstructorOption) {
          print('   모드: 타석+레슨 조합 모드');
          print('   타석 가용 시간대: ${tsAvailability.length}개');
          print('   레슨 가용 시간대: ${lsAvailability.length}개');
          print('');
          print('   🔍 실패 원인: 타석 시간과 레슨 시간이 정확히 일치하는 시간대가 없습니다!');
          print('   ⚠️  타석+레슨 조합 모드에서는 타석 시작/종료 시간과 레슨 시작/종료 시간이');
          print('      정확히 일치해야만 예약 가능합니다.');
          print('');
          print('   📊 타석 가용 시간 (처음 5개):');
          for (int i = 0; i < tsAvailability.length && i < 5; i++) {
            final slot = tsAvailability[i];
            print('      ${i + 1}. ${slot['start_time']} ~ ${slot['end_time']} (타석 ${slot['available_ts_count']}개)');
          }
          if (tsAvailability.length > 5) {
            print('      ... 외 ${tsAvailability.length - 5}개 더');
          }
          print('');
          print('   📊 레슨 가용 시간 (처음 5개):');
          for (int i = 0; i < lsAvailability.length && i < 5; i++) {
            final slot = lsAvailability[i];
            print('      ${i + 1}. ${slot['start_time']} ~ ${slot['end_time']}');
          }
          if (lsAvailability.length > 5) {
            print('      ... 외 ${lsAvailability.length - 5}개 더');
          }
        } else {
          print('   모드: 타석 전용 모드');
          print('   타석 가용 시간대: ${tsAvailability.length}개');
          print('   ⚠️  이 경우는 발생하지 않아야 합니다 (타석 가용 시간이 있으면 통합 결과도 있어야 함)');
        }
        print('');
        return {
          'success': false,
          'error': hasInstructorOption
              ? '타석과 레슨 시간이 일치하는 시간대가 없습니다.'
              : '예약 가능한 시간이 없습니다.'
        };
      }
      
      return {
        'success': true,
        'integrated_options': integratedOptions,
        'has_instructor_option': hasInstructorOption,
        'ts_duration_minutes': tsDurationMinutes,
        'ts_availability': tsAvailability,
        'ls_availability': lsAvailability,
        'summary': {
          'date': selectedDateStr,
          'total_integrated_options': integratedOptions.length,
          'ts_only_mode': !hasInstructorOption,
          'combined_mode': hasInstructorOption,
        }
      };
      
    } catch (e) {
      print('❌ 통합 가용성 조회 실패: $e');
      return {
        'success': false,
        'error': '통합 가용성 조회 중 오류: $e'
      };
    }
  }
  
  /// 통합 가용성 계산
  static List<Map<String, dynamic>> _calculateIntegratedAvailability(
    List<Map<String, dynamic>> tsAvailability,
    List<Map<String, dynamic>> lsAvailability,
    bool hasInstructorOption,
    int tsDurationMinutes,
  ) {
    final integratedOptions = <Map<String, dynamic>>[];
    
    if (!hasInstructorOption) {
      // 타석만 있는 경우: 타석 가용성이 곧 통합 결과
      print('🎯 타석 전용 모드: 타석 가용성을 그대로 사용');
      
      for (final tsSlot in tsAvailability) {
        integratedOptions.add({
          'type': 'ts_only',
          'start_time': tsSlot['start_time'],
          'end_time': tsSlot['end_time'],
          'duration_minutes': tsDurationMinutes,
          'available_ts': tsSlot['available_ts'],
          'available_ts_count': tsSlot['available_ts_count'],
        });
      }
      
      print('   타석 전용 옵션: ${integratedOptions.length}개');
      
    } else {
      // 타석 + 레슨 조합 모드: 겹치는 시간대 찾기
      print('🎯 타석+레슨 조합 모드: 겹치는 시간대 찾기');
      
      for (final lsSlot in lsAvailability) {
        final lsStartTime = lsSlot['start_time'] as String;
        final lsEndTime = lsSlot['end_time'] as String;
        
        // 레슨 시간과 겹치는 타석 시간대 찾기
        final matchingTsSlots = tsAvailability.where((tsSlot) {
          final tsStartTime = tsSlot['start_time'] as String;
          final tsEndTime = tsSlot['end_time'] as String;
          
          // 시간이 정확히 일치하는 경우
          return tsStartTime == lsStartTime && tsEndTime == lsEndTime;
        }).toList();
        
        if (matchingTsSlots.isNotEmpty) {
          final matchingTsSlot = matchingTsSlots.first;
          
          integratedOptions.add({
            'type': 'combined',
            'start_time': lsStartTime,
            'end_time': lsEndTime,
            'duration_minutes': lsSlot['total_duration'],
            'available_ts': matchingTsSlot['available_ts'],
            'available_ts_count': matchingTsSlot['available_ts_count'],
            'lesson_details': lsSlot['lesson_details'],
            'block_details': lsSlot['block_details'],
          });
        }
      }
      
      print('   타석+레슨 조합 옵션: ${integratedOptions.length}개');
    }
    
    // 결과 출력
    print('\n📅 최종 통합 예약 가능 시간대:');
    for (int i = 0; i < integratedOptions.length && i < 10; i++) {
      final option = integratedOptions[i];
      final type = option['type'] as String;
      final startTime = option['start_time'] as String;
      final endTime = option['end_time'] as String;
      final tsCount = option['available_ts_count'] as int;
      
      if (type == 'ts_only') {
        print('   ${startTime}~${endTime}: 타석 전용 (가용 타석 ${tsCount}개)');
      } else {
        final lessonDetails = option['lesson_details'] as List<Map<String, dynamic>>;
        final lessonInfo = lessonDetails.map((lesson) => 
          '레슨${lesson['lesson_number']}(${lesson['start_time']}~${lesson['end_time']})').join(' ');
        print('   ${startTime}~${endTime}: 타석+레슨 조합 (가용 타석 ${tsCount}개, $lessonInfo)');
      }
    }
    if (integratedOptions.length > 10) {
      print('   ... 외 ${integratedOptions.length - 10}개 시간대 더');
    }
    
    return integratedOptions;
  }
  
  /// 특정 시간대의 상세 정보 가져오기
  static Map<String, dynamic> getOptionDetails(Map<String, dynamic> option) {
    final type = option['type'] as String;
    final startTime = option['start_time'] as String;
    final endTime = option['end_time'] as String;
    final durationMinutes = option['duration_minutes'] as int;
    final availableTs = option['available_ts'] as List<Map<String, dynamic>>;
    
    final details = <String, dynamic>{
      'type': type,
      'start_time': startTime,
      'end_time': endTime,
      'duration_minutes': durationMinutes,
      'available_ts': availableTs,
      'display_title': '',
      'display_subtitle': '',
      'display_details': <String>[],
    };
    
    if (type == 'ts_only') {
      details['display_title'] = '${startTime} ~ ${endTime}';
      details['display_subtitle'] = '타석 연습 (${durationMinutes}분)';
      details['display_details'] = [
        '가용 타석: ${availableTs.map((ts) => ts['ts_name']).join(', ')}',
        '연습 시간: ${durationMinutes}분',
      ];
    } else {
      final lessonDetails = option['lesson_details'] as List<Map<String, dynamic>>;
      final blockDetails = option['block_details'] as List<Map<String, dynamic>>;
      
      details['display_title'] = '${startTime} ~ ${endTime}';
      details['display_subtitle'] = '타석 + 레슨 조합 (${durationMinutes}분)';
      
      final detailsList = <String>[];
      detailsList.add('가용 타석: ${availableTs.map((ts) => ts['ts_name']).join(', ')}');
      
      for (final lesson in lessonDetails) {
        detailsList.add('레슨 ${lesson['lesson_number']}: ${lesson['start_time']}~${lesson['end_time']} (${lesson['duration']}분)');
      }
      
      final breakBlocks = blockDetails.where((block) => block['type'] == 'break').toList();
      if (breakBlocks.isNotEmpty) {
        detailsList.add('휴식 시간: ${breakBlocks.map((block) => '${block['start_time']}~${block['end_time']}(${block['duration']}분)').join(', ')}');
      }
      
      details['display_details'] = detailsList;
    }
    
    return details;
  }

  // 시간대별 그룹핑 기능 추가
  static Map<String, List<Map<String, dynamic>>> groupOptionsByHour(List<Map<String, dynamic>> options) {
    Map<String, List<Map<String, dynamic>>> groupedOptions = {};
    
    for (var option in options) {
      final startTime = option['start_time'] as String;
      final hour = startTime.split(':')[0]; // 시간 부분만 추출 (예: "12:10" -> "12")
      final hourKey = '${hour}시';
      
      if (!groupedOptions.containsKey(hourKey)) {
        groupedOptions[hourKey] = [];
      }
      groupedOptions[hourKey]!.add(option);
    }
    
    // 시간순으로 정렬
    final sortedKeys = groupedOptions.keys.toList()..sort((a, b) {
      final hourA = int.parse(a.replaceAll('시', ''));
      final hourB = int.parse(b.replaceAll('시', ''));
      return hourA.compareTo(hourB);
    });
    
    Map<String, List<Map<String, dynamic>>> sortedGroupedOptions = {};
    for (var key in sortedKeys) {
      sortedGroupedOptions[key] = groupedOptions[key]!;
    }
    
    print('');
    print('🕐 시간대별 그룹핑 결과:');
    sortedGroupedOptions.forEach((hour, options) {
      print('   $hour: ${options.length}개 조합');
    });
    print('');
    
    return sortedGroupedOptions;
  }

  // 모달용 간단한 옵션 정보 생성
  static Map<String, dynamic> getSimpleOptionInfo(Map<String, dynamic> option) {
    final startTime = option['start_time'] as String;
    final endTime = option['end_time'] as String;
    final durationMinutes = option['duration_minutes'] as int;
    final availableTsCount = option['available_ts_count'] as int;
    
    return {
      'display_time': '$startTime~$endTime',
      'duration_minutes': durationMinutes,
      'available_ts_count': availableTsCount,
      'start_time': startTime,
      'end_time': endTime,
      'full_option': option, // 전체 옵션 정보 보관
    };
  }
} 