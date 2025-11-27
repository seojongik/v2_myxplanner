import '../../stubs/js_stub.dart' if (dart.library.js) 'dart:js' as js;
import '../../stubs/js_stub.dart' if (dart.library.js_util) 'dart:js_util' as js_util;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class FirebaseWebService {
  static bool isFirebaseAvailable() {
    if (!kIsWeb) return false;
    
    try {
      final hasReady = js.context.hasProperty('firebaseReady');
      final hasGetDoc = js.context.hasProperty('getFirebaseDocument');
      final hasSetDoc = js.context.hasProperty('setFirebaseDocument');
      
      print('🔍 [FirebaseWebService] window.firebaseReady: $hasReady');
      print('🔍 [FirebaseWebService] window.getFirebaseDocument: $hasGetDoc');
      print('🔍 [FirebaseWebService] window.setFirebaseDocument: $hasSetDoc');
      
      return hasReady && hasGetDoc && hasSetDoc;
    } catch (e) {
      print('❌ [FirebaseWebService] 확인 중 에러: $e');
      return false;
    }
  }
  
  static Future<void> addDocument(String collection, Map<String, dynamic> data) async {
    if (!isFirebaseAvailable()) {
      throw Exception('Firebase not available');
    }
    
    try {
      final db = js.context['firestoreDb'];
      final docRef = js_util.callMethod(db, 'collection', [collection]);
      await js_util.promiseToFuture(js_util.callMethod(docRef, 'add', [js_util.jsify(data)]));
    } catch (e) {
      throw Exception('Failed to add document: $e');
    }
  }
  
  static Future<void> setDocument(String collection, String docId, Map<String, dynamic> data) async {
    if (!isFirebaseAvailable()) {
      throw Exception('Firebase not available');
    }
    
    try {
      print('🔍 [FirebaseWebService] 문서 설정 시작: $collection/$docId');
      print('🔍 [FirebaseWebService] 데이터: $data');
      
      // 간단한 콜백 방식 구현
      final completer = Completer<void>();
      
      final onSuccess = js.allowInterop((result) {
        try {
          print('✅ [FirebaseWebService] 설정 콜백 성공');
          completer.complete();
        } catch (e) {
          print('❌ [FirebaseWebService] 설정 콜백 처리 에러: $e');
          completer.completeError(e);
        }
      });
      
      final onError = js.allowInterop((error) {
        print('❌ [FirebaseWebService] 설정 콜백 에러: $error');
        completer.completeError(Exception('Firebase error: $error'));
      });
      
      // 데이터를 JSON 문자열로 변환 후 전달
      final jsonString = jsonEncode(data);
      print('🔍 [FirebaseWebService] JSON 문자열: $jsonString');
      
      // JavaScript 콜백 함수 호출 (JSON 문자열로 전달)
      js.context.callMethod('setFirebaseDocumentCallback', [collection, docId, jsonString, onSuccess, onError]);
      
      await completer.future;
      print('✅ [FirebaseWebService] 문서 설정 성공: $collection/$docId');
      
    } catch (e) {
      print('❌ [FirebaseWebService] 문서 설정 실패: $e');
      throw Exception('Failed to set document: $e');
    }
  }
  
  static Future<String> testJSInterop() async {
    try {
      print('🧪 [FirebaseWebService] JS interop 테스트 시작');
      
      final testFunction = js.context['testJSFunction'];
      if (testFunction == null) {
        return 'testJSFunction이 존재하지 않음';
      }
      
      // 방법 1: 직접 호출
      print('🧪 [FirebaseWebService] 방법 1: 직접 호출');
      final result1 = js_util.callMethod(testFunction, 'call', [null, 'param1', 'param2']);
      print('🧪 [FirebaseWebService] 방법 1 결과: $result1');
      
      return js_util.dartify(result1)?.toString() ?? 'null';
      
    } catch (e) {
      print('❌ [FirebaseWebService] JS interop 테스트 실패: $e');
      return 'Error: $e';
    }
  }

  static Future<Map<String, dynamic>?> getDocument(String collection, String docId) async {
    if (!isFirebaseAvailable()) {
      throw Exception('Firebase not available');
    }
    
    try {
      print('🔍 [FirebaseWebService] 문서 조회 시작: $collection/$docId');
      
      // 간단한 콜백 방식 구현
      final completer = Completer<Map<String, dynamic>?>();
      
      final onSuccess = js.allowInterop((result) {
        try {
          print('✅ [FirebaseWebService] 콜백 성공');
          print('🔍 [FirebaseWebService] result 타입: ${result.runtimeType}');
          print('🔍 [FirebaseWebService] result 내용: $result');

          // JavaScript에서 JSON 문자열로 전달된 데이터를 파싱
          String jsonString;
          if (result is String) {
            jsonString = result;
          } else {
            // fallback: dartify 사용
            final dartResult = js_util.dartify(result);
            if (dartResult is String) {
              jsonString = dartResult;
            } else {
              jsonString = dartResult.toString();
            }
          }

          print('🔍 [FirebaseWebService] JSON 문자열: $jsonString');

          final resultMap = jsonDecode(jsonString) as Map<String, dynamic>;
          print('🔍 [FirebaseWebService] 파싱된 Map: $resultMap');

          final exists = resultMap['exists'] as bool?;
          print('🔍 [FirebaseWebService] exists: $exists');

          if (exists == true) {
            final data = resultMap['data'];
            print('🔍 [FirebaseWebService] data 타입: ${data.runtimeType}');
            print('🔍 [FirebaseWebService] data 내용: $data');

            if (data is Map<String, dynamic>) {
              print('✅ [FirebaseWebService] 최종 데이터: $data');
              completer.complete(data);
              return;
            }
          }

          print('ℹ️ [FirebaseWebService] 문서 없음: $collection/$docId');
          completer.complete(null);
        } catch (e) {
          print('❌ [FirebaseWebService] 콜백 처리 에러: $e');
          print('❌ [FirebaseWebService] 스택 트레이스: ${StackTrace.current}');
          completer.completeError(e);
        }
      });
      
      final onError = js.allowInterop((error) {
        print('❌ [FirebaseWebService] 콜백 에러: $error');
        completer.completeError(Exception('Firebase error: $error'));
      });
      
      // JavaScript 콜백 함수 호출
      js.context.callMethod('getFirebaseDocumentCallback', [collection, docId, onSuccess, onError]);
      
      return await completer.future;
      
    } catch (e) {
      print('❌ [FirebaseWebService] 문서 조회 실패: $e');
      throw Exception('Failed to get document: $e');
    }
  }
  
  static Future<List<Map<String, dynamic>>> getCollection(String collection, {
    String? whereField,
    String? whereOperator, 
    dynamic whereValue,
  }) async {
    if (!isFirebaseAvailable()) {
      throw Exception('Firebase not available');
    }
    
    try {
      final db = js.context['firestoreDb'];
      var query = js_util.callMethod(db, 'collection', [collection]);
      
      if (whereField != null && whereOperator != null && whereValue != null) {
        query = js_util.callMethod(query, 'where', [whereField, whereOperator, whereValue]);
      }
      
      final snapshot = await js_util.promiseToFuture(js_util.callMethod(query, 'get', []));
      final docs = js_util.getProperty(snapshot, 'docs');
      
      final List<Map<String, dynamic>> results = [];
      final docsLength = js_util.getProperty(docs, 'length');
      
      for (int i = 0; i < docsLength; i++) {
        final doc = js_util.getProperty(docs, i.toString());
        final data = js_util.getProperty(doc, 'data');
        final dataResult = js_util.callMethod(data, 'call', [doc]);
        final docId = js_util.getProperty(doc, 'id');
        
        final dartData = js_util.dartify(dataResult);
        if (dartData is Map) {
          final docData = Map<String, dynamic>.from(dartData);
          docData['id'] = docId;
          results.add(docData);
        }
      }
      
      return results;
    } catch (e) {
      throw Exception('Failed to get collection: $e');
    }
  }
}