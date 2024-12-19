import 'dart:convert';
import 'package:flutter/foundation.dart';

class NetworkLogger {
  static final JsonEncoder _encoder = const JsonEncoder.withIndent('  ');
  static const int _maxLineLength = 800;

  static void _printLongString(String text) {
    final pattern = RegExp('.{1,$_maxLineLength}');
    pattern.allMatches(text).forEach((match) {
      debugPrint(match.group(0));
    });
  }

  static String _formatJson(dynamic json) {
    try {
      if (json is String) {
        // Try to parse string as JSON first
        try {
          final dynamic jsonData = jsonDecode(json);
          return _encoder.convert(jsonData);
        } catch (_) {
          return json;
        }
      } else if (json is Map || json is List) {
        return _encoder.convert(json);
      } else {
        return json.toString();
      }
    } catch (e) {
      debugPrint('Error formatting JSON: $e');
      return json.toString();
    }
  }

  static void logRequest({
    required String url,
    required String method,
    required Map<String, String> headers,
    dynamic body,
  }) {
    if (kDebugMode) {
      try {
        final StringBuffer log = StringBuffer();
        log.writeln('\n🌐 REQUEST ➡️');
        log.writeln('URL: $url');
        log.writeln('Method: $method');
        log.writeln('Headers: ${_formatJson(headers)}');
        if (body != null) {
          log.writeln('Body: ${_formatJson(body)}');
        }
        
        debugPrint('REQUEST LOG START ==================');
        _printLongString(log.toString());
        debugPrint('REQUEST LOG END ====================');
      } catch (e) {
        debugPrint('Error logging request: $e');
      }
    }
  }

  static void logResponse({
    required String url,
    required int statusCode,
    required String body,
  }) {
    if (kDebugMode) {
      try {
        final StringBuffer log = StringBuffer();
        log.writeln('\n🌐 RESPONSE ⬅️');
        log.writeln('URL: $url');
        log.writeln('Status Code: $statusCode');
        log.writeln('Body length: ${body.length} characters');
        
        debugPrint('RESPONSE LOG START ==================');
        _printLongString(log.toString());
        
        // Print the body separately to ensure it's not truncated
        debugPrint('RESPONSE BODY START ==================');
        _printLongString(_formatJson(body));
        debugPrint('RESPONSE BODY END ====================');
        
        debugPrint('RESPONSE LOG END ====================');
      } catch (e) {
        debugPrint('Error logging response: $e');
        debugPrint('Raw response body length: ${body.length}');
        // Try to print raw body in chunks
        debugPrint('RAW RESPONSE BODY START ==================');
        _printLongString(body);
        debugPrint('RAW RESPONSE BODY END ====================');
      }
    }
  }

  static void logError({
    required String url,
    required dynamic error,
  }) {
    if (kDebugMode) {
      try {
        final StringBuffer log = StringBuffer();
        log.writeln('\n❌ ERROR');
        log.writeln('URL: $url');
        log.writeln('Error: $error');
        if (error is Error && error.stackTrace != null) {
          log.writeln('Stack trace:');
          log.writeln(error.stackTrace.toString());
        }
        
        debugPrint('ERROR LOG START ==================');
        _printLongString(log.toString());
        debugPrint('ERROR LOG END ====================');
      } catch (e) {
        debugPrint('Error logging error: $e');
      }
    }
  }
}
