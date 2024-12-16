import 'package:flutter/foundation.dart';

class NetworkLogger {
  static void logRequest({
    required String url,
    required String method,
    required Map<String, String> headers,
    dynamic body,
  }) {
    if (kDebugMode) {
      print('\n🌐 REQUEST ➡️');
      print('URL: $url');
      print('Method: $method');
      print('Headers: $headers');
      if (body != null) {
        print('Body: $body');
      }
    }
  }

  static void logResponse({
    required String url,
    required int statusCode,
    required String body,
  }) {
    if (kDebugMode) {
      print('\n🌐 RESPONSE ⬅️');
      print('URL: $url');
      print('Status Code: $statusCode');
      print('Body: $body');
      print('----------------------------------------');
    }
  }

  static void logError({
    required String url,
    required dynamic error,
  }) {
    if (kDebugMode) {
      print('\n❌ ERROR');
      print('URL: $url');
      print('Error: $error');
      print('----------------------------------------');
    }
  }
}
