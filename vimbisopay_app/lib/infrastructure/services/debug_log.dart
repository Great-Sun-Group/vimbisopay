import 'dart:io';
import 'package:path_provider/path_provider.dart';

class DebugLog {
  static Future<void> log(String message) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/notification_debug.log');
      final timestamp = DateTime.now().toIso8601String();
      await file.writeAsString('[$timestamp] $message\n', mode: FileMode.append);
    } catch (e) {
      // Silently fail if we can't write to the log
    }
  }

  static Future<String> getLog() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/notification_debug.log');
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      // Silently fail if we can't read the log
    }
    return '';
  }

  static Future<void> clear() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/notification_debug.log');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Silently fail if we can't delete the log
    }
  }
}
