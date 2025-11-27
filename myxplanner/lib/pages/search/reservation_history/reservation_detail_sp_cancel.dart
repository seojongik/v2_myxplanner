import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import 'reservation_detail_ts_cancel.dart';
import 'reservation_detail_ls_cancel.dart';

/// 특수 예약 (프로그램 예약) 취소 서비스
class SpReservationCancelService {
  /// 프로그램 예약 취소 메인 함수
  static Future<bool> cancelProgramReservation({
    required String programId,
    required BuildContext context,
    required DateTime reservationStartTime,
  }) async {
    try {
      print('');
      print('═══════════════════════════════════════════════════════════');
      print('프로그램 예약 취소 시작');
      print('═══════════════════════════════════════════════════════════');
      print('program_id: $programId');
      
      // 1. 프로그램 구성 동적 분석
      final programStructure = await _analyzeProgramStructure(programId);
      if (programStructure == null) {
        print('❌ 프로그램 구성 분석 실패');
        return false;
      }
      
      print('프로그램 구성 분석 완료:');
      print('  - 타석 예약: ${programStructure.tsReservations.length}개');
      print('  - 레슨 예약: ${programStructure.lsReservations.length}개');
      print('  - 참여자: ${programStructure.participants.length}명');
      
      // 2. 프로그램 취소 정책 조회 (v2_program_settings 사용)
      final programPolicy = await _getProgramCancellationPolicy(reservationStartTime);
      if (!programPolicy['canCancel']) {
        print('❌ 프로그램 취소가 불가능한 상태입니다');
        return false;
      }
      
      final programPenaltyPercent = programPolicy['penaltyPercent'] as int;
      print('프로그램 통합 페널티: ${programPenaltyPercent}%');
      
      // 3. 프로그램 전체 예약 취소 처리 (참여자 + 빈 슬롯 모두 포함)
      bool allSuccess = true;
      
      // 3-1. 모든 타석 예약 취소 (참여자 + 빈 슬롯)
      if (programStructure.hasTs) {
        print('');
        print('🔄 타석 예약 전체 취소 처리: ${programStructure.tsReservations.length}개');
        
        for (final tsRecord in programStructure.tsReservations) {
          final reservationId = tsRecord.reservationId;
          final memberName = tsRecord.memberName ?? '빈 슬롯';
          
          print('  - 타석 취소: $reservationId ($memberName)');
          
          final success = await TsReservationCancelService.cancelTsReservation(
            reservationId: reservationId,
            context: context,
            reservationStartTime: reservationStartTime,
            programPenaltyPercent: programPenaltyPercent,
          );
          
          if (!success) {
            print('❌ 타석 예약 취소 실패: $reservationId');
            allSuccess = false;
            break;
          }
          
          print('✅ 타석 예약 취소 성공: $reservationId');
        }
        
        if (allSuccess) {
          print('✅ 모든 타석 예약 취소 완료');
        }
      }
      
      // 3-2. 모든 레슨 예약 취소 (참여자 + 빈 슬롯)
      if (allSuccess && programStructure.hasLs) {
        print('');
        print('🔄 레슨 예약 전체 취소 처리: ${programStructure.lsReservations.length}개');
        
        for (final lsRecord in programStructure.lsReservations) {
          final lsId = lsRecord.lsId;
          final memberName = lsRecord.memberName ?? '빈 슬롯';
          
          print('  - 레슨 취소: $lsId ($memberName)');
          
          final success = await LsReservationCancelService.cancelLsReservation(
            lsId: lsId,
            context: context,
            reservationStartTime: reservationStartTime,
            programPenaltyPercent: programPenaltyPercent,
          );
          
          if (!success) {
            print('❌ 레슨 예약 취소 실패: $lsId');
            allSuccess = false;
            break;
          }
          
          print('✅ 레슨 예약 취소 성공: $lsId');
        }
        
        if (allSuccess) {
          print('✅ 모든 레슨 예약 취소 완료');
        }
      }
      
      // 4. 프로그램 구성요소 취소 후 통합 잔액 재계산
      if (allSuccess && programStructure.hasLs) {
        print('');
        print('🔄 프로그램 구성요소 취소 후 통합 잔액 재계산 시작');
        
        // 모든 레슨 예약의 계약 ID 수집
        final contractIds = programStructure.lsReservations
          .map((ls) => ls.lsId)
          .where((lsId) => lsId.isNotEmpty)
          .toSet();
        
        for (final lsId in contractIds) {
          final recalcSuccess = await _recalculateBalanceAfterProgramCancel(lsId);
          if (!recalcSuccess) {
            print('⚠️ 잔액 재계산 실패: $lsId (프로그램 취소는 성공)');
          }
        }
        
        print('✅ 프로그램 구성요소 통합 잔액 재계산 완료');
      }
      
      // 5. 프로그램 예약에는 별도 쿠폰 복구 로직 없음 (개별 TS/LS에서 처리)
      
      print('');
      print('═══════════════════════════════════════════════════════════');
      print('프로그램 예약 취소 완료: ${allSuccess ? "성공" : "실패"}');
      print('═══════════════════════════════════════════════════════════');
      print('');
      
      return allSuccess;
      
    } catch (e) {
      print('❌ 프로그램 예약 취소 오류: $e');
      return false;
    }
  }
  
  /// 프로그램 취소 정책 조회
  static Future<Map<String, dynamic>> _getProgramCancellationPolicy(DateTime reservationStartTime) async {
    try {
      print('');
      print('🔍 프로그램 취소 정책 조회 시작 (v2_program_settings)');
      
      // 1. v2_program_settings의 취소 정책 조회 (apply_sequence 순으로 정렬)
      final policies = await ApiService.getData(
        table: 'v2_cancellation_policy',
        where: [
          {'field': 'db_table', 'operator': '=', 'value': 'v2_program_settings'}
        ],
        orderBy: [
          {'field': 'apply_sequence', 'direction': 'ASC'}
        ],
      );
      
      if (policies.isEmpty) {
        print('❌ 프로그램 취소 정책을 찾을 수 없습니다');
        return {'canCancel': true, 'penaltyPercent': 0}; // 정책이 없으면 무료 취소
      }
      
      // 2. 현재 시간과 예약 시작 시간의 차이를 분 단위로 계산
      final now = DateTime.now();
      final timeDifferenceInMinutes = reservationStartTime.difference(now).inMinutes;
      
      print('현재 시간: $now');
      print('예약 시작 시간: $reservationStartTime');
      print('시간 차이: ${timeDifferenceInMinutes}분');
      
      // 3. 현재 시간이 예약 시작 시간을 지났다면 apply_sequence 1번 적용
      if (timeDifferenceInMinutes < 0) {
        print('⚠️ 예약 시작 시간이 지났습니다. apply_sequence 1번 적용');
        final firstPolicy = policies.firstWhere(
          (policy) => int.parse(policy['apply_sequence'].toString()) == 1,
          orElse: () => policies.first,
        );
        final penaltyPercent = int.parse(firstPolicy['penalty_percent'].toString());
        print('✅ 적용할 정책: apply_sequence 1번, ${penaltyPercent}% 페널티');
        return {
          'canCancel': true,
          'penaltyPercent': penaltyPercent,
          'policyFound': true,
        };
      }
      
      // 4. apply_sequence 순으로 정책 적용
      for (final policy in policies) {
        final minBeforeUse = int.parse(policy['_min_before_use'].toString());
        final penaltyPercent = int.parse(policy['penalty_percent'].toString());
        final sequence = int.parse(policy['apply_sequence'].toString());
        
        print('정책 확인 - sequence: $sequence, min_before_use: $minBeforeUse, penalty: $penaltyPercent%');
        
        if (timeDifferenceInMinutes <= minBeforeUse) {
          print('✅ 적용할 정책 발견: ${penaltyPercent}% 페널티');
          return {
            'canCancel': true,
            'penaltyPercent': penaltyPercent,
            'policyFound': true,
          };
        }
      }
      
      // 5. 어떤 정책에도 해당하지 않으면 무료 취소 가능
      print('✅ 무료 취소 가능 기간');
      return {'canCancel': true, 'penaltyPercent': 0, 'policyFound': false};
      
    } catch (e) {
      print('❌ 프로그램 취소 정책 조회 오류: $e');
      return {'canCancel': false, 'penaltyPercent': 0};
    }
  }
  
  /// 프로그램 구성 동적 분석
  static Future<ProgramReservationStructure?> _analyzeProgramStructure(String programId) async {
    try {
      print('');
      print('🔍 프로그램 구성 분석 시작');
      
      // 1. 타석 예약 조회
      final tsReservations = await _getTsReservations(programId);
      print('타석 예약 조회 완료: ${tsReservations.length}개');
      
      // 2. 레슨 예약 조회
      final lsReservations = await _getLsReservations(programId);
      print('레슨 예약 조회 완료: ${lsReservations.length}개');
      
      // 3. 참여자 정보 추출
      final participants = _extractParticipants(tsReservations, lsReservations);
      print('참여자 추출 완료: ${participants.length}명');
      
      // 4. 세션 정보 추출
      final sessions = _extractSessions(lsReservations);
      print('세션 정보 추출 완료: ${sessions.length}개');
      
      // 5. 최대 인원 수 계산
      final maxPlayerNo = _getMaxPlayerNo(tsReservations, lsReservations);
      print('최대 인원 수: ${maxPlayerNo}명');
      
      return ProgramReservationStructure(
        programId: programId,
        hasTs: tsReservations.isNotEmpty,
        hasLs: lsReservations.isNotEmpty,
        tsReservations: tsReservations,
        lsReservations: lsReservations,
        participants: participants,
        sessions: sessions,
        maxPlayerNo: maxPlayerNo,
      );
      
    } catch (e) {
      print('❌ 프로그램 구성 분석 오류: $e');
      return null;
    }
  }
  
  /// 타석 예약 조회
  static Future<List<TsReservationRecord>> _getTsReservations(String programId) async {
    final tsData = await ApiService.getData(
      table: 'v2_priced_TS',
      where: [
        {'field': 'program_id', 'operator': '=', 'value': programId}
      ],
      orderBy: [
        {'field': 'reservation_id', 'direction': 'ASC'}
      ],
    );
    
    return tsData.map((data) => TsReservationRecord.fromJson(data)).toList();
  }
  
  /// 레슨 예약 조회
  static Future<List<LsReservationRecord>> _getLsReservations(String programId) async {
    final lsData = await ApiService.getData(
      table: 'v2_LS_orders',
      where: [
        {'field': 'program_id', 'operator': '=', 'value': programId}
      ],
      orderBy: [
        {'field': 'LS_id', 'direction': 'ASC'}
      ],
    );
    
    return lsData.map((data) => LsReservationRecord.fromJson(data)).toList();
  }
  
  /// 참여자 정보 추출
  static List<ParticipantInfo> _extractParticipants(
    List<TsReservationRecord> tsReservations,
    List<LsReservationRecord> lsReservations,
  ) {
    final Map<String, ParticipantInfo> participantMap = {};
    
    // 타석 예약에서 참여자 추출
    for (final tsRecord in tsReservations) {
      if (tsRecord.memberId != null && tsRecord.memberId!.isNotEmpty) {
        final memberId = tsRecord.memberId!;
        if (!participantMap.containsKey(memberId)) {
          participantMap[memberId] = ParticipantInfo(
            memberId: memberId,
            memberName: tsRecord.memberName ?? '',
            tsReservationIds: [],
            lsIds: [],
            slotNumber: _extractSlotNumber(tsRecord.reservationId),
          );
        }
        participantMap[memberId]!.tsReservationIds.add(tsRecord.reservationId);
      }
    }
    
    // 레슨 예약에서 참여자 추출
    for (final lsRecord in lsReservations) {
      if (lsRecord.memberId != null && lsRecord.memberId!.isNotEmpty) {
        final memberId = lsRecord.memberId!;
        if (!participantMap.containsKey(memberId)) {
          participantMap[memberId] = ParticipantInfo(
            memberId: memberId,
            memberName: lsRecord.memberName ?? '',
            tsReservationIds: [],
            lsIds: [],
            slotNumber: _extractSlotNumber(lsRecord.lsId),
          );
        }
        participantMap[memberId]!.lsIds.add(lsRecord.lsId);
      }
    }
    
    return participantMap.values.toList()
      ..sort((a, b) => a.slotNumber.compareTo(b.slotNumber));
  }
  
  /// 세션 정보 추출
  static List<SessionInfo> _extractSessions(List<LsReservationRecord> lsReservations) {
    final Map<String, SessionInfo> sessionMap = {};
    
    for (final lsRecord in lsReservations) {
      // 시간 기반 세션 식별 (예: 12:15, 12:30)
      final sessionKey = lsRecord.lsStartTime ?? '';
      
      if (!sessionMap.containsKey(sessionKey)) {
        sessionMap[sessionKey] = SessionInfo(
          sessionId: sessionKey,
          startTime: _parseTime(lsRecord.lsStartTime),
          endTime: _parseTime(lsRecord.lsEndTime),
          sessionMinutes: lsRecord.lsNetMin ?? 0,
          lsIds: [],
        );
      }
      
      sessionMap[sessionKey]!.lsIds.add(lsRecord.lsId);
    }
    
    return sessionMap.values.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }
  
  /// 슬롯 번호 추출 (예: "250718_2_1215_1/2" -> 1)
  static int _extractSlotNumber(String reservationId) {
    final regex = RegExp(r'_(\d+)/\d+$');
    final match = regex.firstMatch(reservationId);
    return match != null ? int.parse(match.group(1)!) : 1;
  }
  
  /// 최대 인원 수 계산
  static int _getMaxPlayerNo(
    List<TsReservationRecord> tsReservations,
    List<LsReservationRecord> lsReservations,
  ) {
    int maxFromTs = 1;
    int maxFromLs = 1;
    
    // 타석 예약에서 최대 인원 추출
    for (final tsRecord in tsReservations) {
      final regex = RegExp(r'_\d+/(\d+)$');
      final match = regex.firstMatch(tsRecord.reservationId);
      if (match != null) {
        final total = int.parse(match.group(1)!);
        maxFromTs = maxFromTs < total ? total : maxFromTs;
      }
    }
    
    // 레슨 예약에서 최대 인원 추출
    for (final lsRecord in lsReservations) {
      final regex = RegExp(r'_\d+/(\d+)$');
      final match = regex.firstMatch(lsRecord.lsId);
      if (match != null) {
        final total = int.parse(match.group(1)!);
        maxFromLs = maxFromLs < total ? total : maxFromLs;
      }
    }
    
    return maxFromTs > maxFromLs ? maxFromTs : maxFromLs;
  }
  
  /// 시간 문자열 파싱
  static DateTime _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return DateTime.now();
    
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return DateTime(2000, 1, 1, hour, minute);
      }
    } catch (e) {
      print('⚠️ 시간 파싱 오류: $timeStr');
    }
    
    return DateTime.now();
  }
  
  /// 프로그램 구성요소 취소 후 통합 잔액 재계산
  static Future<bool> _recalculateBalanceAfterProgramCancel(String lsId) async {
    try {
      print('');
      print('🔄 통합 잔액 재계산 시작 (LS_id: $lsId)');
      
      // 1. 해당 LS_id의 계약 정보를 v3_LS_countings에서 직접 조회
      final lsCountingData = await ApiService.getData(
        table: 'v3_LS_countings',
        where: [
          {'field': 'LS_id', 'operator': '=', 'value': lsId}
        ],
        limit: 1,
      );
      
      if (lsCountingData.isEmpty) {
        print('❌ LS_counting 정보를 찾을 수 없습니다: $lsId');
        return false;
      }
      
      final lsCounting = lsCountingData.first;
      final contractHistoryId = lsCounting['contract_history_id'];
      
      if (contractHistoryId == null) {
        print('❌ contract_history_id를 찾을 수 없습니다');
        return false;
      }
      
      print('계약 ID: $contractHistoryId');
      
      // 2. 해당 계약의 모든 LS_countings 조회 (시간순 정렬)
      final allCountings = await ApiService.getData(
        table: 'v3_LS_countings',
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId}
        ],
        orderBy: [
          {'field': 'LS_counting_id', 'direction': 'ASC'}
        ],
      );
      
      print('전체 counting 레코드 수: ${allCountings.length}개');
      
      if (allCountings.isEmpty) {
        print('⚠️ counting 레코드가 없습니다');
        return true;
      }
      
      // 3. 잔액 연쇄 재계산
      int? previousAfterBalance;
      
      for (int i = 0; i < allCountings.length; i++) {
        final counting = allCountings[i];
        final countingId = counting['LS_counting_id'];
        final transactionType = counting['LS_transaction_type'] ?? '';
        final status = counting['LS_status'] ?? '';
        final netMin = (counting['LS_net_min'] ?? 0).toInt();
        
        // 첫 번째 레코드의 before_balance는 그대로 유지
        int newBeforeBalance;
        if (i == 0) {
          newBeforeBalance = (counting['LS_balance_min_before'] ?? 0).toInt();
        } else {
          newBeforeBalance = previousAfterBalance ?? 0;
        }
        
        // after_balance 계산
        int newAfterBalance;
        if (status == '예약취소') {
          // 취소된 레코드는 잔액 변화 없음
          newAfterBalance = newBeforeBalance;
        } else if (transactionType == '레슨권 구매') {
          // 구매는 잔액 증가
          newAfterBalance = (newBeforeBalance + netMin).toInt();
        } else if (transactionType == '레슨차감') {
          // 차감은 잔액 감소
          newAfterBalance = (newBeforeBalance - netMin).toInt();
        } else {
          // 기타의 경우 원래 로직 유지
          newAfterBalance = (newBeforeBalance - netMin).toInt();
        }
        
        print('  레코드 ${i + 1}: counting_id $countingId');
        print('    타입: $transactionType, 상태: $status');
        print('    before: ${counting['LS_balance_min_before']} → $newBeforeBalance');
        print('    net_min: $netMin');
        print('    after: ${counting['LS_balance_min_after']} → $newAfterBalance');
        
        // 4. DB 업데이트 (값이 변경된 경우만)
        if ((counting['LS_balance_min_before'] ?? 0).toInt() != newBeforeBalance || 
            (counting['LS_balance_min_after'] ?? 0).toInt() != newAfterBalance) {
          
          final updateResult = await ApiService.updateData(
            table: 'v3_LS_countings',
            where: [
              {'field': 'LS_counting_id', 'operator': '=', 'value': countingId}
            ],
            data: {
              'LS_balance_min_before': newBeforeBalance,
              'LS_balance_min_after': newAfterBalance,
              'updated_at': DateTime.now().toIso8601String(),
            },
          );
          
          final updateSuccess = updateResult['success'] == true;
          
          if (!updateSuccess) {
            print('❌ 잔액 재계산 업데이트 실패: counting_id $countingId');
            return false;
          }
          
          print('✅ 잔액 재계산 업데이트 완료: counting_id $countingId');
        } else {
          print('ℹ️ 잔액 변화 없음: counting_id $countingId');
        }
        
        previousAfterBalance = newAfterBalance;
      }
      
      print('✅ 통합 잔액 재계산 완료');
      return true;
      
    } catch (e) {
      print('❌ 통합 잔액 재계산 오류: $e');
      return false;
    }
  }
  
}

/// 프로그램 예약 구조 정보
class ProgramReservationStructure {
  final String programId;
  final bool hasTs;
  final bool hasLs;
  final List<TsReservationRecord> tsReservations;
  final List<LsReservationRecord> lsReservations;
  final List<ParticipantInfo> participants;
  final List<SessionInfo> sessions;
  final int maxPlayerNo;
  
  ProgramReservationStructure({
    required this.programId,
    required this.hasTs,
    required this.hasLs,
    required this.tsReservations,
    required this.lsReservations,
    required this.participants,
    required this.sessions,
    required this.maxPlayerNo,
  });
  
  // 동적 구성 판단
  bool get isGroupReservation => maxPlayerNo > 1;
  bool get isMultiSession => sessions.length > 1;
  bool get isCombinedReservation => hasTs && hasLs;
}

/// 참여자 정보
class ParticipantInfo {
  final String memberId;
  final String memberName;
  final List<String> tsReservationIds;
  final List<String> lsIds;
  final int slotNumber;
  
  ParticipantInfo({
    required this.memberId,
    required this.memberName,
    required this.tsReservationIds,
    required this.lsIds,
    required this.slotNumber,
  });
}

/// 세션 정보
class SessionInfo {
  final String sessionId;
  final DateTime startTime;
  final DateTime endTime;
  final int sessionMinutes;
  final List<String> lsIds;
  
  SessionInfo({
    required this.sessionId,
    required this.startTime,
    required this.endTime,
    required this.sessionMinutes,
    required this.lsIds,
  });
}

/// 타석 예약 레코드
class TsReservationRecord {
  final String reservationId;
  final String? memberId;
  final String? memberName;
  final String? tsStatus;
  final String? billId;
  final String? billMinId;
  
  TsReservationRecord({
    required this.reservationId,
    this.memberId,
    this.memberName,
    this.tsStatus,
    this.billId,
    this.billMinId,
  });
  
  factory TsReservationRecord.fromJson(Map<String, dynamic> json) {
    return TsReservationRecord(
      reservationId: json['reservation_id']?.toString() ?? '',
      memberId: json['member_id']?.toString(),
      memberName: json['member_name']?.toString(),
      tsStatus: json['ts_status']?.toString(),
      billId: json['bill_id']?.toString(),
      billMinId: json['bill_min_id']?.toString(),
    );
  }
}

/// 레슨 예약 레코드
class LsReservationRecord {
  final String lsId;
  final String? memberId;
  final String? memberName;
  final String? lsStatus;
  final String? lsStartTime;
  final String? lsEndTime;
  final int? lsNetMin;
  
  LsReservationRecord({
    required this.lsId,
    this.memberId,
    this.memberName,
    this.lsStatus,
    this.lsStartTime,
    this.lsEndTime,
    this.lsNetMin,
  });
  
  factory LsReservationRecord.fromJson(Map<String, dynamic> json) {
    return LsReservationRecord(
      lsId: json['LS_id']?.toString() ?? '',
      memberId: json['member_id']?.toString(),
      memberName: json['member_name']?.toString(),
      lsStatus: json['LS_status']?.toString(),
      lsStartTime: json['LS_start_time']?.toString(),
      lsEndTime: json['LS_end_time']?.toString(),
      lsNetMin: json['LS_net_min'] is int ? json['LS_net_min'] : int.tryParse(json['LS_net_min']?.toString() ?? '0'),
    );
  }
}