import 'dart:io';

import 'package:image_picker/image_picker.dart';

import 'firestore_service.dart';
import 'storage_service.dart';

/// The ONE avatar pipeline (Settings/Profile and onboarding share it):
/// pick (camera/gallery — the OS permission prompt appears only now, on the
/// tapped action) → downscale → upload to users/{uid}/avatar.jpg →
/// write users/{uid}.avatarUrl. Returns null when the user cancelled the
/// picker; throws when the upload or the profile write fails.
class AvatarService {
  static Future<String?> pickAndUpload(String uid, ImageSource source) async {
    final xfile = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (xfile == null) return null;
    final url = await StorageService.uploadAvatar(uid, File(xfile.path));
    await FirestoreService.updateUser(uid, {'avatarUrl': url});
    return url;
  }
}
