import '../services/storage_service.dart';

/// What the Storage step hands to the Firestore step.
typedef UploadedChatImage = ({String storagePath, int width, int height, int bytes});

/// The three side-effecting steps of sending a chat image, injected so the
/// orchestration below is testable without Firebase.
class ChatImageSendSteps {
  const ChatImageSendSteps({
    required this.objectExists,
    required this.upload,
    required this.sendMessage,
  });

  /// Does the immutable object already exist AND is it readable by the
  /// current member? `true` / `false`, or `null` when that could not be
  /// determined (network, unexpected error).
  final Future<bool?> Function() objectExists;

  /// Prepares the image (compress, dimensions) and — unless [skipUpload] —
  /// puts it in Storage. With [skipUpload] the object already there is
  /// verified and reused, never overwritten. Throws [ChatImageSendException].
  final Future<UploadedChatImage> Function({required bool skipUpload}) upload;

  /// Creates the Firestore message pointing at the object.
  final Future<void> Function(UploadedChatImage image) sendMessage;
}

class ChatImageSendOutcome {
  const ChatImageSendOutcome({required this.reusedExistingObject});

  /// True when the retry found the object already in Storage and only
  /// completed the Firestore message (the orphan-recovery path).
  final bool reusedExistingObject;
}

/// Upload → message, with orphan recovery on retry.
///
/// The first attempt always uploads. A *retry* keeps the same message id and
/// path (the object is immutable and the client cannot delete it), so it
/// first asks whether the object is already there: if it is, the upload is
/// skipped and only the message is written — turning a "file landed but the
/// message didn't" orphan back into a delivered message instead of a
/// permanently failing overwrite. If the probe says "not found" (or cannot
/// tell), the full pipeline runs again.
Future<ChatImageSendOutcome> sendChatImage(
  ChatImageSendSteps steps, {
  required bool isRetry,
}) async {
  var skipUpload = false;
  if (isRetry) {
    skipUpload = await steps.objectExists() == true;
  }
  final image = await steps.upload(skipUpload: skipUpload);
  try {
    await steps.sendMessage(image);
  } catch (e) {
    // Storage succeeded (or was reused) but the message did not — reported
    // as its own step, never folded into a generic "could not send".
    throw ChatImageSendException(ChatImageStep.firestore, e,
        path: image.storagePath, bytes: image.bytes, contentType: 'image/jpeg');
  }
  return ChatImageSendOutcome(reusedExistingObject: skipUpload);
}
