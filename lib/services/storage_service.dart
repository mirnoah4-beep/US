import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class StorageService {
  static Future<String> uploadMemoryImage(
    String coupleId,
    String docId,
    XFile picked,
  ) async {
    final tmpDir = await getTemporaryDirectory();
    final outPath = '${tmpDir.path}/memory_$docId.jpg';
    final compressed = await FlutterImageCompress.compressAndGetFile(
      picked.path,
      outPath,
      minWidth: 1024,
      minHeight: 1024,
      quality: 85,
      format: CompressFormat.jpeg,
    );
    if (compressed == null) throw Exception('Compression failed');
    final ref = FirebaseStorage.instance
        .ref('couples/$coupleId/memories/$docId.jpg');
    await ref.putFile(
      File(compressed.path),
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  static Future<void> deleteMemoryImage(String coupleId, String docId) async {
    try {
      await FirebaseStorage.instance
          .ref('couples/$coupleId/memories/$docId.jpg')
          .delete();
    } catch (_) {}
  }

  static Future<String> uploadAvatar(String uid, File file) async {
    final ref = FirebaseStorage.instance.ref('users/$uid/avatar.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  static Future<void> deleteUserFiles(String uid) async {
    try {
      final ref = FirebaseStorage.instance.ref('users/$uid');
      final result = await ref.listAll();
      for (final item in result.items) {
        await item.delete();
      }
    } catch (_) {}
  }
}
