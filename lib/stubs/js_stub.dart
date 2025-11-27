// Stub file for non-web platforms
// This file provides empty implementations for web-only APIs

class JsObject {
  static JsObject jsify(Map<String, dynamic> map) => JsObject();
  dynamic callMethod(String method, List<dynamic> args) => null;
  dynamic operator [](String key) => null;
  void operator []=(String key, dynamic value) {}
  bool hasProperty(String property) => false;
}

class _JsContext {
  dynamic operator [](String key) => _JsObject();
  void operator []=(String key, dynamic value) {}
  bool hasProperty(String property) => false;
  dynamic callMethod(String method, List<dynamic> args) => null;
}

class _JsObject {
  dynamic operator [](String key) => null;
  void operator []=(String key, dynamic value) {}
  dynamic callMethod(String method, List<dynamic> args) => null;
}

class JsArray {
  int get length => 0;
  dynamic operator [](int index) => null;
}

// Export js namespace - match dart:js structure
class JsContext {
  dynamic operator [](String key) => _JsObject();
  void operator []=(String key, dynamic value) {}
  bool hasProperty(String property) => false;
  dynamic callMethod(String method, List<dynamic> args) => null;
}

// Top-level context to match dart:js
final context = JsContext();

// Top-level allowInterop to match dart:js
dynamic allowInterop(Function f) => f;

// Export js namespace class for 'as js' imports
class Js {
  dynamic get context => context;
  dynamic allowInterop(Function f) => allowInterop(f);
}

final js = Js();

// Export js_util namespace - use top-level functions to match dart:js_util
dynamic dartify(dynamic obj) => obj;
dynamic jsify(dynamic obj) => obj;
Future<dynamic> promiseToFuture(dynamic promise) => Future.value(null);
dynamic callMethod(dynamic obj, String method, List<dynamic> args) => null;
dynamic getProperty(dynamic obj, String property) => null;

// For compatibility
class JsUtil {
  static dynamic dartify(dynamic obj) => dartify(obj);
  static dynamic jsify(dynamic obj) => jsify(obj);
  static Future<dynamic> promiseToFuture(dynamic promise) => promiseToFuture(promise);
  static dynamic callMethod(dynamic obj, String method, List<dynamic> args) => callMethod(obj, method, args);
  static dynamic getProperty(dynamic obj, String property) => getProperty(obj, property);
}

final js_util = JsUtil();

