import 'content_item.dart';

/// A single child's profile linked to a parent's account. Stored locally
/// for now (Milestone 1) and will sync with Firestore later (Milestone 4)
/// without changing this shape.
class ChildProfile {
  ChildProfile({
    required this.id,
    required this.name,
    required this.avatarId,
    Map<String, int>? starsByLevelKey,
    Set<String>? weakItemKeys,
    this.soundEnabled = true,
  })  : starsByLevelKey = starsByLevelKey ?? {},
        weakItemKeys = weakItemKeys ?? {};

  final String id;
  String name;
  String avatarId;

  /// Level key in the form "group_index" (e.g. "arabicLetters_0") with the
  /// number of stars earned (0-4) as its value. A missing key means the
  /// level hasn't been played yet.
  final Map<String, int> starsByLevelKey;

  /// Items (letters/numbers) the parent marked as weak points — in the form
  /// "group_symbol" (e.g. "arabicLetters_أ"). Added as bonus rounds at the
  /// end of every future level in the same group until the parent removes
  /// them (see the weak points screen and GameScreen._buildRoundItems).
  final Set<String> weakItemKeys;

  bool soundEnabled;

  static String levelKey(ContentGroup group, int levelIndex) =>
      '${group.name}_$levelIndex';

  int starsFor(ContentGroup group, int levelIndex) =>
      starsByLevelKey[levelKey(group, levelIndex)] ?? 0;

  /// The first level is always unlocked; any level after it unlocks once
  /// the one before it has at least one star (i.e. completed).
  bool isLevelUnlocked(ContentGroup group, int levelIndex) {
    if (levelIndex == 0) return true;
    return starsFor(group, levelIndex - 1) > 0;
  }

  void setStars(ContentGroup group, int levelIndex, int stars) {
    final key = levelKey(group, levelIndex);
    final current = starsByLevelKey[key] ?? 0;
    // We keep the child's best score, never lowering it if they try again and do worse.
    starsByLevelKey[key] = stars > current ? stars : current;
  }

  /// Clears an entire group's progress (all stars) — locks all its levels
  /// except the first one again. Doesn't clear marked weak points (a
  /// separate, independent feature).
  void resetProgress(ContentGroup group) {
    starsByLevelKey.removeWhere((key, _) => key.startsWith('${group.name}_'));
  }

  static String weakItemKey(ContentGroup group, String symbol) => '${group.name}_$symbol';

  bool isWeakItem(ContentGroup group, String symbol) =>
      weakItemKeys.contains(weakItemKey(group, symbol));

  void setWeakItem(ContentGroup group, String symbol, bool isWeak) {
    final key = weakItemKey(group, symbol);
    if (isWeak) {
      weakItemKeys.add(key);
    } else {
      weakItemKeys.remove(key);
    }
  }

  /// Symbols marked as weak points for a given group (without the group
  /// name prefix).
  List<String> weakSymbolsFor(ContentGroup group) {
    final prefix = '${group.name}_';
    return weakItemKeys
        .where((k) => k.startsWith(prefix))
        .map((k) => k.substring(prefix.length))
        .toList();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarId': avatarId,
        'starsByLevelKey': starsByLevelKey,
        'weakItemKeys': weakItemKeys.toList(),
        'soundEnabled': soundEnabled,
      };

  factory ChildProfile.fromJson(Map<String, dynamic> json) => ChildProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        avatarId: json['avatarId'] as String,
        starsByLevelKey: Map<String, int>.from(
          (json['starsByLevelKey'] as Map?) ?? {},
        ),
        weakItemKeys: Set<String>.from(
          (json['weakItemKeys'] as List?) ?? const [],
        ),
        soundEnabled: json['soundEnabled'] as bool? ?? true,
      );
}
