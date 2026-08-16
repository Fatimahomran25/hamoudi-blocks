import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/child_profile.dart';
import '../models/content_item.dart';

/// Manages the list of child profiles + the currently active child + their
/// progress in each level.
///
/// Fully local for now (Milestone 1). In Milestone 4, optional Firestore
/// sync is added on top of this same layer (the exact same methods, so the
/// rest of the screens need no changes — just an extra cloud save/read call
/// added here).
class ProfileService extends ChangeNotifier {
  static const _kChildrenKey = 'children_profiles';
  static const _kActiveChildKey = 'active_child_id';
  static const _uuid = Uuid();

  List<ChildProfile> _children = [];
  String? _activeChildId;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  List<ChildProfile> get children => List.unmodifiable(_children);

  ChildProfile? get activeChild {
    if (_activeChildId == null) return null;
    try {
      return _children.firstWhere((c) => c.id == _activeChildId);
    } catch (_) {
      return _children.isNotEmpty ? _children.first : null;
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kChildrenKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _children = list
          .map((e) => ChildProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    _activeChildId = prefs.getString(_kActiveChildKey);
    _activeChildId ??= _children.isNotEmpty ? _children.first.id : null;
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kChildrenKey,
      jsonEncode(_children.map((c) => c.toJson()).toList()),
    );
    if (_activeChildId != null) {
      await prefs.setString(_kActiveChildKey, _activeChildId!);
    }
  }

  Future<ChildProfile> addChild({
    required String name,
    required String avatarId,
  }) async {
    final child = ChildProfile(id: _uuid.v4(), name: name, avatarId: avatarId);
    _children.add(child);
    _activeChildId = child.id;
    await _persist();
    notifyListeners();
    return child;
  }

  Future<void> setActiveChild(String childId) async {
    _activeChildId = childId;
    await _persist();
    notifyListeners();
  }

  Future<void> updateAvatar(String childId, String avatarId) async {
    final child = _children.firstWhere((c) => c.id == childId);
    child.avatarId = avatarId;
    await _persist();
    notifyListeners();
  }

  Future<void> setSoundEnabled(String childId, bool enabled) async {
    final child = _children.firstWhere((c) => c.id == childId);
    child.soundEnabled = enabled;
    await _persist();
    notifyListeners();
  }

  Future<void> recordLevelResult({
    required String childId,
    required ContentGroup group,
    required int levelIndex,
    required int starsEarned,
  }) async {
    final child = _children.firstWhere((c) => c.id == childId);
    child.setStars(group, levelIndex, starsEarned);
    await _persist();
    notifyListeners();
  }

  /// Toggles the "weak point" flag on an item (letter/number) — see
  /// lib/screens/settings/weak_points_screen.dart.
  Future<void> setWeakItem({
    required String childId,
    required ContentGroup group,
    required String symbol,
    required bool isWeak,
  }) async {
    final child = _children.firstWhere((c) => c.id == childId);
    child.setWeakItem(group, symbol, isWeak);
    await _persist();
    notifyListeners();
  }

  /// Clears an entire group's progress (all stars, locking every level except the first).
  Future<void> resetGroupProgress({
    required String childId,
    required ContentGroup group,
  }) async {
    final child = _children.firstWhere((c) => c.id == childId);
    child.resetProgress(group);
    await _persist();
    notifyListeners();
  }
}
