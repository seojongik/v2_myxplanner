import 'dart:convert';
import 'package:crypto/crypto.dart';

class OTPService {
  /// 타석 OTP 생성
  /// branch_id, reservation_id와 현재 시간(5분 단위)를 조합해서 6자리 해시 생성
  static String generateStationOTP({
    required String branchId,
    required String reservationId,
    DateTime? customTime,
  }) {
    final now = customTime ?? DateTime.now();

    // 현재 시간을 5분 단위로 구획화
    final fiveMinuteBlock = _roundToFiveMinutes(now);

    // 조합할 문자열 생성
    final combinedString = '$branchId-$reservationId-$fiveMinuteBlock';

    // SHA-256 해시 생성
    final bytes = utf8.encode(combinedString);
    final digest = sha256.convert(bytes);

    // 해시값을 16진수 문자열로 변환 후 6자리 추출
    final hashString = digest.toString();

    // 해시값에서 숫자만 추출해서 6자리로 만들기
    final numericHash = hashString.replaceAll(RegExp(r'[^0-9]'), '');

    // 6자리 OTP 생성 (부족하면 패딩)
    String otp;
    if (numericHash.length >= 6) {
      otp = numericHash.substring(0, 6);
    } else {
      // 숫자가 부족한 경우 해시값의 각 문자를 ASCII 코드의 마지막 자리로 변환
      final buffer = StringBuffer(numericHash);
      for (int i = 0; i < hashString.length && buffer.length < 6; i++) {
        final char = hashString[i];
        if (!RegExp(r'[0-9]').hasMatch(char)) {
          buffer.write(char.codeUnitAt(0) % 10);
        }
      }
      otp = buffer.toString().substring(0, 6);
    }

    // OTP 생성 디버깅 로그
    print('=== [고객앱] OTP 생성 ===');
    print('branchId: $branchId');
    print('reservationId: $reservationId');
    print('fiveMinuteBlock: $fiveMinuteBlock');
    print('combinedString: $combinedString');
    print('생성된 OTP: $otp');
    print('========================');

    return otp;
  }
  
  /// 시간을 5분 단위로 반올림
  static String _roundToFiveMinutes(DateTime dateTime) {
    final totalMinutes = dateTime.hour * 60 + dateTime.minute;
    final roundedMinutes = (totalMinutes / 5).floor() * 5;
    final roundedHour = roundedMinutes ~/ 60;
    final roundedMinute = roundedMinutes % 60;
    
    return '${dateTime.year}${dateTime.month.toString().padLeft(2, '0')}${dateTime.day.toString().padLeft(2, '0')}'
           '${roundedHour.toString().padLeft(2, '0')}${roundedMinute.toString().padLeft(2, '0')}';
  }
  
  /// OTP 검증 (타석 PC에서 사용)
  static bool verifyStationOTP({
    required String branchId,
    required String reservationId,
    required String inputOTP,
    DateTime? customTime,
  }) {
    final now = customTime ?? DateTime.now();

    // 현재 시간 블록의 OTP 생성
    final currentOTP = generateStationOTP(
      branchId: branchId,
      reservationId: reservationId,
      customTime: now,
    );

    // 이전 시간 블록의 OTP도 체크 (5분 경계에서의 오차 허용)
    final previousTime = now.subtract(const Duration(minutes: 5));
    final previousOTP = generateStationOTP(
      branchId: branchId,
      reservationId: reservationId,
      customTime: previousTime,
    );
    
    return inputOTP == currentOTP || inputOTP == previousOTP;
  }
  
  /// OTP 유효 시간 확인 (분 단위)
  static int getOTPValidityMinutes() {
    return 5; // 5분간 유효
  }
  
  /// 다음 OTP 갱신까지 남은 시간 (초 단위)
  static int getSecondsUntilNextOTP() {
    final now = DateTime.now();
    final totalMinutes = now.hour * 60 + now.minute;
    final currentBlock = (totalMinutes / 5).floor();
    final nextBlock = currentBlock + 1;
    final nextBlockTime = nextBlock * 5;
    
    final nextBlockDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      nextBlockTime ~/ 60,
      nextBlockTime % 60,
    );
    
    return nextBlockDateTime.difference(now).inSeconds;
  }
}