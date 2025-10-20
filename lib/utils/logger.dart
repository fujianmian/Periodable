import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class FileLogger {
  static Future<void> log(String message, {String name = 'AppLog'}) async {
    // Always log in debug console if possible
    if (kDebugMode) {
      developer.log(message, name: name);
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/debug_log.txt');
      final timestamp = DateTime.now().toIso8601String();
      await file.writeAsString('[$timestamp][$name] $message\n',
          mode: FileMode.append);
    } catch (e) {
      // Ignore any file write errors silently
    }
  }
}
