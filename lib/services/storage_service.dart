import 'dart:io';
import 'dart:ui' as ui;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Which stage of the chat-image pipeline failed. Surfaced in Crashlytics
/// and (as `step · code`, never a URL or token) in the failed bubble, so a
/// real-device failure is diagnosable from one reproduction.
enum ChatImageStep { compress, dimensions, upload, verify, firestore }

class ChatImageSendException implements Exception {
  ChatImageSendException(this.step, this.cause, {this.path, this.bytes, this.contentType});
  final ChatImageStep step;
  final Object cause;
  final String? path;
  final int? bytes;
  final String? contentType;

  String get code =>
      cause is FirebaseException ? (cause as FirebaseException).code : cause.runtimeType.toString();
  String get message =>
      cause is FirebaseException ? ((cause as FirebaseException).message ?? '') : cause.toString();

  /// Safe for logs and the debug line: no download URLs, no tokens.
  String get diagnostic => '${step.name} · $code';

  @override
  String toString() =>
      'ChatImageSendException(step=${step.name} code=$code path=$path '
      'bytes=$bytes contentType=$contentType) $message';
}

class StorageService {
  /// One compression policy for every image the app uploads (memories, chat):
  /// JPEG, ≤1024 px on the short side, q85 — comfortably under the 5 MB
  /// Storage-rules cap.
  static Future<File> compressToJpeg(XFile picked, String outName) async {
    final tmpDir = await getTemporaryDirectory();
    final outPath = '${tmpDir.path}/$outName.jpg';
    final compressed = await FlutterImageCompress.compressAndGetFile(
      picked.path,
      outPath,
      minWidth: 1024,
      minHeight: 1024,
      quality: 85,
      format: CompressFormat.jpeg,
    );
    if (compressed == null) throw Exception('Compression failed');
    return File(compressed.path);
  }

  static Future<({int width, int height})> _dimensionsOf(File file) async {
    final img = await ui.instantiateImageCodec(await file.readAsBytes());
    final frame = await img.getNextFrame();
    final w = frame.image.width;
    final h = frame.image.height;
    frame.image.dispose();
    img.dispose();
    return (width: w, height: h);
  }

  /// Chat image: uploads to the couple-scoped, immutable path the Storage
  /// rules allow, and returns the PATH (not a URL) plus dimensions. The path
  /// is what the message stores; readers resolve it through Storage rules.
  static Future<({String storagePath, int width, int height, int bytes})> uploadChatImage(
    String coupleId,
    String messageId,
    XFile picked,
  ) async {
    const contentType = 'image/jpeg';
    final path = 'couples/$coupleId/chatImages/$messageId.jpg';

    final File file;
    try {
      file = await compressToJpeg(picked, 'chat_$messageId');
    } catch (e) {
      throw ChatImageSendException(ChatImageStep.compress, e, path: path);
    }
    final bytes = await file.length();

    final ({int width, int height}) dims;
    try {
      dims = await _dimensionsOf(file);
    } catch (e) {
      throw ChatImageSendException(ChatImageStep.dimensions, e, path: path, bytes: bytes);
    }

    final ref = FirebaseStorage.instance.ref(path);
    try {
      // contentType is set EXPLICITLY — the Storage rule requires image/*
      // and must never depend on MIME sniffing.
      await ref.putFile(file, SettableMetadata(contentType: contentType));
    } catch (e) {
      throw ChatImageSendException(ChatImageStep.upload, e,
          path: path, bytes: bytes, contentType: contentType);
    }

    // Prove the object landed with the metadata we sent, before we write a
    // message that points at it.
    try {
      final md = await ref.getMetadata();
      if (kDebugMode) {
        debugPrint('[chatImage] uploaded $path size=${md.size} contentType=${md.contentType}');
      }
    } catch (e) {
      throw ChatImageSendException(ChatImageStep.verify, e,
          path: path, bytes: bytes, contentType: contentType);
    }

    return (storagePath: path, width: dims.width, height: dims.height, bytes: bytes);
  }

  /// Post-failure probe: does the object exist? (object-not-found → false;
  /// any other error is reported as "unknown" rather than guessed.)
  static Future<String> chatImageExists(String path) async {
    try {
      final md = await FirebaseStorage.instance.ref(path).getMetadata();
      return 'yes (${md.size} B, ${md.contentType})';
    } on FirebaseException catch (e) {
      return e.code == 'object-not-found' ? 'no' : 'unknown (${e.code})';
    } catch (_) {
      return 'unknown';
    }
  }

  static Future<String> uploadMemoryImage(
    String coupleId,
    String docId,
    XFile picked,
  ) async {
    final compressed = await compressToJpeg(picked, 'memory_$docId');
    final ref = FirebaseStorage.instance
        .ref('couples/$coupleId/memories/$docId.jpg');
    await ref.putFile(
      compressed,
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
}
