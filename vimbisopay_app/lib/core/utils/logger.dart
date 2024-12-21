import 'package:flutter/foundation.dart';

class Logger {
  static const String _tag = 'VimbisoPay';

  static void lifecycle(String message) {
    _log('🔄 LIFECYCLE', message);
  }

  static void state(String message) {
    _log('📊 STATE', message);
  }

  static void data(String message) {
    _log('💾 DATA', message);
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _log('❌ ERROR', message);
    if (error != null) {
      debugPrint('[$_tag/❌ ERROR] Error details: $error');
      if (stackTrace != null) {
        debugPrint('[$_tag/❌ ERROR] Stack trace:\n$stackTrace');
      }
    }
  }

  static void interaction(String message) {
    _log('👆 INTERACTION', message);
  }

  static void performance(String message) {
    _log('⚡ PERFORMANCE', message);
  }

  static void _log(String type, String message) {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$_tag/$type] [$timestamp] $message');
  }
}
