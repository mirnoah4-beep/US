import 'package:firebase_storage/firebase_storage.dart';

/// Resolves a chat image's Storage PATH to a download URL, once per path.
///
/// Messages store paths, not URLs, so every read goes through Storage rules
/// (only current couple members can resolve them). The resolved URL is then
/// cached in memory for the session so scrolling never re-resolves.
class ChatImageCache {
  ChatImageCache._();

  static final Map<String, Future<String>> _urls = {};

  static Future<String> urlFor(String storagePath) =>
      _urls.putIfAbsent(storagePath, () {
        final f = FirebaseStorage.instance.ref(storagePath).getDownloadURL();
        // Don't cache failures — let the next build retry.
        f.catchError((Object e) {
          _urls.remove(storagePath);
          throw e;
        });
        return f;
      });
}
