import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

const String adminUid = '1RTxZHUV1NbvNlFsXhwl5LeEgFw1';

class IdeaImageService {
  static final Map<String, String?> _urlCache = {};

  static String toId(String title) =>
      title.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9æøå]+'), '_');

  static Future<String?> fetchCoverUrl(String ideaId) async {
    if (_urlCache.containsKey(ideaId)) return _urlCache[ideaId];
    try {
      final doc = await FirebaseFirestore.instance
          .collection('ideas')
          .doc(ideaId)
          .get();
      final url = doc.data()?['coverImageUrl'] as String?;
      _urlCache[ideaId] = url;
      return url;
    } catch (_) {
      _urlCache[ideaId] = null;
      return null;
    }
  }

  static Future<String?> uploadCover(String ideaId, XFile picked) async {
    final tmpDir = await getTemporaryDirectory();
    final outPath = '${tmpDir.path}/idea_cover_$ideaId.jpg';

    final compressed = await FlutterImageCompress.compressAndGetFile(
      picked.path,
      outPath,
      minWidth: 1024,
      minHeight: 1024,
      quality: 85,
      format: CompressFormat.jpeg,
    );
    if (compressed == null) throw Exception('Compression failed');

    final ref = FirebaseStorage.instance.ref('ideas/$ideaId/cover.jpg');
    await ref.putFile(File(compressed.path));
    final url = await ref.getDownloadURL();

    await FirebaseFirestore.instance
        .collection('ideas')
        .doc(ideaId)
        .set({'coverImageUrl': url}, SetOptions(merge: true));

    _urlCache[ideaId] = url;
    return url;
  }
}
