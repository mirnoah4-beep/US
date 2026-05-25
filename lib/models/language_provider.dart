import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/strings.dart';

class LanguageProvider extends ChangeNotifier {
  static const _key = 'app_language';
  bool _isNorwegian = false;

  LanguageProvider() {
    _init();
  }

  bool get isNorwegian => _isNorwegian;
  AppStrings get s => AppStrings(isNorwegian: _isNorwegian);

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      _isNorwegian = saved == 'no';
    } else {
      final code = PlatformDispatcher.instance.locale.languageCode;
      _isNorwegian = code == 'nb' || code == 'nn' || code == 'no';
    }
    notifyListeners();
  }

  Future<void> setNorwegian(bool value) async {
    if (_isNorwegian == value) return;
    _isNorwegian = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value ? 'no' : 'en');
  }
}
