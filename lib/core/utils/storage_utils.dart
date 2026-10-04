import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class StorageUtils {
  /// Copies an image picked from the gallery into the app's secure local document directory.
  /// This ensures the image persists even if the original gallery image is deleted.
  static Future<String?> persistImageLocally(String originalFilePath) async {
    try {
      final originalFile = File(originalFilePath);
      if (!await originalFile.exists()) return null;

      final appDir = await getApplicationDocumentsDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(originalFilePath)}';
      final savedImagePath = p.join(appDir.path, fileName);

      final savedFile = await originalFile.copy(savedImagePath);
      return savedFile.path;
    } catch (e) {
      debugPrint("Error saving image: $e");
      return null;
    }
  }

  /// Exports a JSON string to a physical file on the device's downloads/documents folder
  static Future<File> saveBackupFile(String jsonString) async {
    final appDir = await getApplicationDocumentsDirectory(); // Or getExternalStorageDirectory() on Android
    final backupFile = File(p.join(appDir.path, 'companion_backup_${DateTime.now().millisecondsSinceEpoch}.json'));
    return await backupFile.writeAsString(jsonString);
  }

  /// Deletes an image previously created by [persistImageLocally].
  /// Files outside the app documents directory are never touched.
  static Future<void> deleteLocalImage(String? path) async {
    if (path == null) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      if (!p.isWithin(appDir.path, path)) return;
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint("Error deleting image: $e");
    }
  }
}
