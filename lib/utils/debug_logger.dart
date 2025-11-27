import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;

/// 터미널과 브라우저 콘솔 모두에 로그를 출력하는 유틸리티
class DebugLogger {
  /// 로그 출력 (터미널과 브라우저 콘솔 모두에 출력)
  static void log(String message, {String? tag}) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logMessage = tag != null ? '[$timestamp] [$tag] $message' : '[$timestamp] $message';
    
    // 터미널에 출력 (Flutter의 debugPrint 사용)
    debugPrint(logMessage);
    
    // 브라우저 콘솔에도 출력 (웹 환경에서만)
    if (kIsWeb) {
      print(logMessage);
    }
    
    // developer.log도 사용 (더 상세한 로깅)
    developer.log(
      message,
      name: tag ?? 'MyGolfPlanner',
      time: DateTime.now(),
    );
  }
  
  /// 에러 로그 출력
  static void error(String message, {Object? error, StackTrace? stackTrace, String? tag}) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logMessage = tag != null 
        ? '[$timestamp] [ERROR] [$tag] $message'
        : '[$timestamp] [ERROR] $message';
    
    debugPrint(logMessage);
    
    if (kIsWeb) {
      print(logMessage);
    }
    
    if (error != null) {
      debugPrint('Error: $error');
      if (kIsWeb) {
        print('Error: $error');
      }
    }
    
    if (stackTrace != null) {
      debugPrint('StackTrace: $stackTrace');
      if (kIsWeb) {
        print('StackTrace: $stackTrace');
      }
    }
    
    developer.log(
      message,
      name: tag ?? 'MyGolfPlanner',
      level: 1000, // ERROR level
      error: error,
      stackTrace: stackTrace,
      time: DateTime.now(),
    );
  }
  
  /// 경고 로그 출력
  static void warning(String message, {String? tag}) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logMessage = tag != null 
        ? '[$timestamp] [WARNING] [$tag] $message'
        : '[$timestamp] [WARNING] $message';
    
    debugPrint(logMessage);
    
    if (kIsWeb) {
      print(logMessage);
    }
    
    developer.log(
      message,
      name: tag ?? 'MyGolfPlanner',
      level: 900, // WARNING level
      time: DateTime.now(),
    );
  }
  
  /// 정보 로그 출력
  static void info(String message, {String? tag}) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logMessage = tag != null 
        ? '[$timestamp] [INFO] [$tag] $message'
        : '[$timestamp] [INFO] $message';
    
    debugPrint(logMessage);
    
    if (kIsWeb) {
      print(logMessage);
    }
    
    developer.log(
      message,
      name: tag ?? 'MyGolfPlanner',
      level: 800, // INFO level
      time: DateTime.now(),
    );
  }
}

