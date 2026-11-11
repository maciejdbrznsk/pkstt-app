import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transit_models.dart';

/// Persists favorite stop groups and specific platform bays (e.g. Marszałkowska 01).
class FavoritesStore extends ChangeNotifier {
  FavoritesStore(this._prefs) {
    _load();
  }

  static const _storageKey = 'pkstt_favorite_stops_v1';

  final SharedPreferences _prefs;
  final List<FavoriteStop> _items = [];

  List<FavoriteStop> get items => List.unmodifiable(_items);

  bool isFavorite(String key) => _items.any((e) => e.key == key);

  static String groupKey(String groupId) => 'group:$groupId';

  static String bayKey(String groupId, String bayId) => 'bay:$groupId:$bayId';

  Future<void> toggle(FavoriteStop fav) async {
    final idx = _items.indexWhere((e) => e.key == fav.key);
    if (idx >= 0) {
      _items.removeAt(idx);
    } else {
      _items.insert(0, fav);
    }
    await _save();
    notifyListeners();
  }

  Future<void> removeByKey(String key) async {
    _items.removeWhere((e) => e.key == key);
    await _save();
    notifyListeners();
  }

  void _load() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _items
        ..clear()
        ..addAll(list.map((e) => FavoriteStop.fromJson(e as Map<String, dynamic>)));
    } catch (_) {
      // Ignore corrupt local state safely and start fresh.
    }
  }

  Future<void> _save() async {
    final encoded = jsonEncode(_items.map((e) => e.toJson()).toList());
    await _prefs.setString(_storageKey, encoded);
  }
}
