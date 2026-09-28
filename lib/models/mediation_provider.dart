import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/mediation_service.dart';
import 'mediation.dart';

/// Streams the couple's talks (server-written documents only). Re-inits on
/// couple change, like the other couple-scoped providers.
class MediationProvider extends ChangeNotifier {
  String _coupleId = '';
  StreamSubscription<List<Mediation>>? _sub;
  List<Mediation> _items = const [];
  bool _initialized = false;

  List<Mediation> get items => _items;
  bool get initialized => _initialized;
  Mediation? get current => _items.where((m) => m.isOpen).firstOrNull;
  List<Mediation> get activeAgreements => _items.where((m) => m.isActive).toList();
  Mediation? byId(String id) => _items.where((m) => m.id == id).firstOrNull;

  void init(String coupleId) {
    if (coupleId == _coupleId && _sub != null) return;
    _sub?.cancel();
    _coupleId = coupleId;
    _items = const [];
    _initialized = false;
    if (coupleId.isEmpty) { notifyListeners(); return; }
    _sub = MediationService.stream(coupleId).listen((list) {
      _items = list;
      _initialized = true;
      notifyListeners();
    }, onError: (Object e) {
      if (kDebugMode) debugPrint('[MediationProvider] stream error: $e');
      _initialized = true;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
