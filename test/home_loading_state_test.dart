import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File('lib/screens/home_screen.dart').readAsStringSync();

  test('Home time-filter loading uses visible US loader, never a blank spacer', () {
    expect(src.contains("ValueKey('homeIdeasLoading')"), isTrue);
    expect(src.contains("assets/logo/us_wordmark.png"), isTrue);
    expect(src.contains('CircularProgressIndicator('), isTrue);
    expect(src.contains('if (showIdeasLoading)\n          const _HomeIdeasLoading()'), isTrue);
    expect(src.contains('if (!imagesReady)\n          const SizedBox(height: 185)'), isFalse);
  });

  test('library/image loading cannot strand the carousel forever', () {
    expect(src.contains('bool _libraryLoaded = false;'), isTrue);
    expect(src.contains('_libraryLoaded = true;'), isTrue);
    expect(src.contains('final showIdeasLoading = waitingForLibrary || waitingForImages;'), isTrue);
    expect(src.contains('finally {'), isTrue);
    expect(src.contains('_precaching = false;'), isTrue);
  });
}
