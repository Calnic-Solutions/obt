import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Puts a copy of a recording where the person using the phone can find it.
///
/// Everything the app downloads lands in its own private storage, which no
/// file manager or other player can open. A finished Set is something people
/// want to keep and pass on, so downloading it also writes a copy into the
/// phone's Downloads folder - the top of it, where a search for the Set's
/// name finds the file straight away.
class DownloadsExport {
  DownloadsExport._();

  static const MethodChannel _channel = MethodChannel('obt/downloads');

  /// Copies [sourcePath] into the phone's Downloads folder as [fileName].
  /// Returns where it landed, or null if the phone would not take it.
  static Future<String?> save({
    required String sourcePath,
    required String fileName,
  }) async {
    final name = _safe(fileName);

    try {
      if (Platform.isAndroid) {
        final saved = await _saveOnAndroid(sourcePath, name);
        if (saved != null) debugPrint('DOWNLOADED TO: $saved');
        return saved;
      }

      // iOS has no shared Downloads folder: the app's documents directory
      // is what the Files app exposes, so a copy there is the same gesture.
      final directory = Directory(
        p.join((await getApplicationDocumentsDirectory()).path, 'Downloads'),
      );
      await directory.create(recursive: true);

      final copy = await File(sourcePath).copy(p.join(directory.path, name));
      debugPrint('DOWNLOADED TO: ${copy.path}');
      return copy.path;
    } catch (e) {
      debugPrint('DOWNLOADS EXPORT FAILED ($fileName): $e');
      return null;
    }
  }

  /// Tries the write first and only asks for permission if it is refused.
  ///
  /// From Android 10 the file goes through MediaStore and needs no permission
  /// at all - and on Android 13+ the old storage permission no longer exists,
  /// so asking for it up front returns "denied" and would block a write that
  /// was always going to succeed.
  static Future<String?> _saveOnAndroid(String sourcePath, String name) async {
    Future<String?> write() => _channel.invokeMethod<String>(
      'saveToDownloads',
      {'sourcePath': sourcePath, 'fileName': name},
    );

    try {
      return await write();
    } on PlatformException catch (e) {
      debugPrint('DOWNLOADS EXPORT REFUSED ($name): ${e.message}');

      if (!await Permission.storage.request().isGranted) return null;
      return write();
    }
  }

  /// Keeps a Set or passage name usable as a file name.
  static String _safe(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? 'recording' : cleaned;
  }
}
