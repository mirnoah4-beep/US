// Orphan-recovery contract for chat images — pure, no Firebase.
//
// A retry keeps the same message id/path. If the immutable object already
// landed, the retry must NOT try to overwrite it (the rules deny that, so the
// old behaviour could never succeed) and must only complete the message.

import 'package:flutter_test/flutter_test.dart';
import 'package:us_app/models/chat_image_send.dart';
import 'package:us_app/services/storage_service.dart';

const path = 'couples/c1/chatImages/m1.jpg';
const image = (storagePath: path, width: 800, height: 600, bytes: 1234);

class _Log {
  final calls = <String>[];
  bool objectInStorage = false;
  bool messageInFirestore = false;
  bool? probeAnswer;          // null = "cannot tell"
  bool failFirestore = false;
  bool failUpload = false;

  ChatImageSendSteps get steps => ChatImageSendSteps(
        objectExists: () async {
          calls.add('probe');
          return probeAnswer ?? (objectInStorage ? true : false);
        },
        upload: ({required bool skipUpload}) async {
          calls.add(skipUpload ? 'verify-only' : 'upload');
          if (!skipUpload) {
            if (objectInStorage) {
              // What the real rules do to an overwrite of an immutable object.
              throw ChatImageSendException(ChatImageStep.upload, StateError('unauthorized'), path: path);
            }
            if (failUpload) throw ChatImageSendException(ChatImageStep.upload, StateError('net'), path: path);
            objectInStorage = true;
          }
          return image;
        },
        sendMessage: (img) async {
          calls.add('send');
          if (failFirestore) throw StateError('permission-denied');
          messageInFirestore = true;
        },
      );
}

void main() {
  test('happy path: first attempt uploads then writes the message', () async {
    final l = _Log();
    final out = await sendChatImage(l.steps, isRetry: false);
    expect(l.calls, ['upload', 'send']);
    expect(out.reusedExistingObject, isFalse);
    expect(l.objectInStorage && l.messageInFirestore, isTrue);
  });

  test('orphan retry completes the Firestore message without overwriting Storage', () async {
    final l = _Log()..failFirestore = true;

    // Attempt 1: object lands, message write fails → reported as the
    // firestore step, object left behind (client cannot delete it).
    await expectLater(
      sendChatImage(l.steps, isRetry: false),
      throwsA(isA<ChatImageSendException>().having((e) => e.step, 'step', ChatImageStep.firestore)),
    );
    expect(l.objectInStorage, isTrue);
    expect(l.messageInFirestore, isFalse);
    l.calls.clear();

    // Attempt 2 (retry, same id/path): probe → exists → no upload, only send.
    l.failFirestore = false;
    final out = await sendChatImage(l.steps, isRetry: true);
    expect(l.calls, ['probe', 'verify-only', 'send']);
    expect(out.reusedExistingObject, isTrue);
    expect(l.messageInFirestore, isTrue);
  });

  test('without the recovery path the retry would be a denied overwrite (regression guard)', () async {
    final l = _Log()..objectInStorage = true;
    // A non-retry attempt against an existing object is exactly the old bug.
    await expectLater(
      sendChatImage(l.steps, isRetry: false),
      throwsA(isA<ChatImageSendException>().having((e) => e.step, 'step', ChatImageStep.upload)),
    );
    // The retry path never issues that overwrite.
    l.calls.clear();
    await sendChatImage(l.steps, isRetry: true);
    expect(l.calls, isNot(contains('upload')));
  });

  test('retry after an upload failure (object never landed) uploads again', () async {
    final l = _Log()..failUpload = true;
    await expectLater(sendChatImage(l.steps, isRetry: false), throwsA(isA<ChatImageSendException>()));
    expect(l.objectInStorage, isFalse);
    l.failUpload = false;
    l.calls.clear();
    await sendChatImage(l.steps, isRetry: true);
    expect(l.calls, ['probe', 'upload', 'send']);
    expect(l.objectInStorage && l.messageInFirestore, isTrue);
  });

  test('an inconclusive probe falls back to the full pipeline', () async {
    final l = _Log()..probeAnswer = null;
    await sendChatImage(l.steps, isRetry: true);
    expect(l.calls, ['probe', 'upload', 'send']);
  });

  test('the first attempt never probes (no extra round-trip on the hot path)', () async {
    final l = _Log();
    await sendChatImage(l.steps, isRetry: false);
    expect(l.calls, isNot(contains('probe')));
  });

  test('a failed message write on retry is still reported as the firestore step', () async {
    final l = _Log()..objectInStorage = true..failFirestore = true;
    await expectLater(
      sendChatImage(l.steps, isRetry: true),
      throwsA(isA<ChatImageSendException>().having((e) => e.step, 'step', ChatImageStep.firestore)),
    );
    expect(l.calls, ['probe', 'verify-only', 'send']);
  });
}
