import 'dart:io';

import 'package:flutter/foundation.dart';

/// Windows dagitiminda acilis hatalarini exe yanina yazar.
abstract final class BootLog {
  static Future<void> write(String message) async {
    if (kIsWeb) return;
    if (!Platform.isWindows) return;
    try {
      final dir = File(Platform.resolvedExecutable).parent;
      final log = File('${dir.path}\\boot_log.txt');
      final line =
          '[${DateTime.now().toIso8601String()}] $message${Platform.lineTerminator}';
      await log.writeAsString(line, mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  static Future<void> clear() async {
    if (kIsWeb || !Platform.isWindows) return;
    try {
      final dir = File(Platform.resolvedExecutable).parent;
      final log = File('${dir.path}\\boot_log.txt');
      if (await log.exists()) await log.delete();
    } catch (_) {}
  }
}
