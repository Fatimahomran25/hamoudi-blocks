/// A single learning item: a letter or number + an example word + an emoji.
/// [symbol] is the letter/number itself, [exampleWord] is the spoken
/// example word, [emoji] is a visual cue the child understands without
/// reading.
class ContentItem {
  const ContentItem(this.symbol, this.exampleWord, this.emoji);

  final String symbol;
  final String exampleWord;
  final String emoji;
}

/// The four groups the entire game revolves around.
enum ContentGroup {
  arabicLetters,
  englishLetters,
  arabicNumbers,
  englishNumbers,
}

extension ContentGroupInfo on ContentGroup {
  String get titleAr {
    switch (this) {
      case ContentGroup.arabicLetters:
        return 'الحروف العربية';
      case ContentGroup.englishLetters:
        return 'English Letters';
      case ContentGroup.arabicNumbers:
        return 'الأرقام العربية';
      case ContentGroup.englishNumbers:
        return 'English Numbers';
    }
  }

  String get flagEmoji {
    switch (this) {
      case ContentGroup.arabicLetters:
      case ContentGroup.arabicNumbers:
        return '🇸🇦';
      case ContentGroup.englishLetters:
      case ContentGroup.englishNumbers:
        return '🇬🇧';
    }
  }

  /// Items per level (fixed per the original prompt: 4 items/level).
  static const int itemsPerLevel = 4;
}
