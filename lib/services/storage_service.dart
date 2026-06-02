import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
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
