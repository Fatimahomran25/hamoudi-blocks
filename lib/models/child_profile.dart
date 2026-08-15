import 'content_item.dart';

/// بروفايل طفل واحد مرتبط بحساب الوالد. يُخزَّن محلياً الآن (Milestone 1)
/// وسيُزامَن مع Firestore لاحقاً (Milestone 4) بدون تغيير هذا الشكل.
class ChildProfile {
  ChildProfile({
    required this.id,
    required this.name,
    required this.avatarId,
    Map<String, int>? starsByLevelKey,
    this.soundEnabled = true,
  }) : starsByLevelKey = starsByLevelKey ?? {};

  final String id;
  String name;
  String avatarId;

  /// مفتاح المستوى بصيغة "group_index" (مثلاً "arabicLetters_0")
  /// وقيمته عدد النجوم المكتسبة (0-4). غياب المفتاح = المستوى لم يُلعب بعد.
  final Map<String, int> starsByLevelKey;

  bool soundEnabled;

  static String levelKey(ContentGroup group, int levelIndex) =>
      '${group.name}_$levelIndex';

  int starsFor(ContentGroup group, int levelIndex) =>
      starsByLevelKey[levelKey(group, levelIndex)] ?? 0;

  /// المستوى الأول دايماً مفتوح؛ أي مستوى بعده يفتح إذا اللي قبله فيه نجمة
  /// وحدة على الأقل (يعني اكتمل).
  bool isLevelUnlocked(ContentGroup group, int levelIndex) {
    if (levelIndex == 0) return true;
    return starsFor(group, levelIndex - 1) > 0;
  }

  void setStars(ContentGroup group, int levelIndex, int stars) {
    final key = levelKey(group, levelIndex);
    final current = starsByLevelKey[key] ?? 0;
    // نحتفظ بأعلى نتيجة حققها الطفل، ما ننزّلها لو حاول مرة ثانية وقصّر.
    starsByLevelKey[key] = stars > current ? stars : current;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarId': avatarId,
        'starsByLevelKey': starsByLevelKey,
        'soundEnabled': soundEnabled,
      };

  factory ChildProfile.fromJson(Map<String, dynamic> json) => ChildProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        avatarId: json['avatarId'] as String,
        starsByLevelKey: Map<String, int>.from(
          (json['starsByLevelKey'] as Map?) ?? {},
        ),
        soundEnabled: json['soundEnabled'] as bool? ?? true,
      );
}
