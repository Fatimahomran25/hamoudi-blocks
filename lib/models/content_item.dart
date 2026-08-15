/// عنصر تعليمي واحد: حرف أو رقم + كلمة مثال + إيموجي.
/// [symbol] هو الحرف/الرقم نفسه، [exampleWord] كلمة المثال المنطوقة،
/// [emoji] رمز بصري يفهمه الطفل بدون قراءة.
class ContentItem {
  const ContentItem(this.symbol, this.exampleWord, this.emoji);

  final String symbol;
  final String exampleWord;
  final String emoji;
}

/// المجموعات الأربع اللي تدور حولها اللعبة كلها.
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

  /// عدد العناصر بكل مستوى (ثابت حسب البرومت: 4 عناصر/مستوى).
  static const int itemsPerLevel = 4;
}
