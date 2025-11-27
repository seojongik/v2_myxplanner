// Stub file for non-web platforms
// This file provides empty implementations for web-only APIs

class Window {
  dynamic get localStorage => _LocalStorage();
  dynamic get location => _Location();
  dynamic get history => _History();
  dynamic get navigator => _Navigator();
}

class _LocalStorage {
  dynamic operator [](String key) => null;
  void operator []=(String key, dynamic value) {}
  void remove(String key) {}
}

class _Location {
  String get href => '';
}

class _History {
  dynamic get state => null;
  void replaceState(dynamic state, String title, String? url) {}
}

class _Navigator {
  dynamic get userAgent => '';
}

class _Document {
  dynamic get head => _Head();
  List<dynamic> querySelectorAll(String selector) => [];
}

class _Head {
  void append(dynamic element) {}
}

class ScriptElement {
  String? src;
  String? type;
  bool? async;
  Stream<dynamic> get onLoad => Stream<dynamic>.empty();
  ScriptElement();
}

class AudioElement {
  String? src;
  double volume = 1.0;
  Future<void> play() => Future.value();
  AudioElement();
}

// Storage type alias
typedef Storage = _LocalStorage;

// Create html namespace object
final window = Window();
final document = _Document();

// Export html namespace - match dart:html structure
class Html {
  Window get window => Window();
  _Document get document => _Document();
}

// Export AudioElement at top level for direct access
// For compatibility with 'as html' imports
final html = Html();

