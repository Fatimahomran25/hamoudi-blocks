import '../models/content_item.dart';

/// كل محتوى اللعبة التعليمي: 28 حرف عربي + 26 حرف إنجليزي + 10 أرقام عربية
/// + 10 أرقام إنجليزية. كل عنصر [الرمز, كلمة المثال, إيموجي].
/// (بعض الأزواج كلمة/إيموجي تقريبية لعدم وجود إيموجي مطابق 100% باليونيكود
/// — سهل تبديلها لاحقاً من هالملف وحده بدون لمس بقية الكود.)
class ContentRepository {
  ContentRepository._();

  static const List<ContentItem> arabicLetters = [
    ContentItem('أ', 'أسد', '🦁'),
    ContentItem('ب', 'بطة', '🦆'),
    ContentItem('ت', 'تفاح', '🍎'),
    ContentItem('ث', 'ثعلب', '🦊'),
    ContentItem('ج', 'جمل', '🐫'),
    ContentItem('ح', 'حصان', '🐴'),
    ContentItem('خ', 'خروف', '🐑'),
    ContentItem('د', 'دب', '🐻'),
    ContentItem('ذ', 'ذئب', '🐺'),
    ContentItem('ر', 'رمان', '🍇'),
    ContentItem('ز', 'زرافة', '🦒'),
    ContentItem('س', 'سمكة', '🐟'),
    ContentItem('ش', 'شمس', '☀️'),
    ContentItem('ص', 'صقر', '🦅'),
    ContentItem('ض', 'ضفدع', '🐸'),
    ContentItem('ط', 'طائرة', '✈️'),
    ContentItem('ظ', 'ظرف', '✉️'),
    ContentItem('ع', 'عصفور', '🐦'),
    ContentItem('غ', 'غزال', '🦌'),
    ContentItem('ف', 'فيل', '🐘'),
    ContentItem('ق', 'قطة', '🐱'),
    ContentItem('ك', 'كلب', '🐶'),
    ContentItem('ل', 'ليمون', '🍋'),
    ContentItem('م', 'موز', '🍌'),
    ContentItem('ن', 'نحلة', '🐝'),
    ContentItem('هـ', 'هدية', '🎁'),
    ContentItem('و', 'وردة', '🌹'),
    ContentItem('ي', 'يد', '✋'),
  ];

  static const List<ContentItem> englishLetters = [
    ContentItem('A', 'Apple', '🍎'),
    ContentItem('B', 'Ball', '⚽'),
    ContentItem('C', 'Cat', '🐱'),
    ContentItem('D', 'Dog', '🐶'),
    ContentItem('E', 'Elephant', '🐘'),
    ContentItem('F', 'Fish', '🐟'),
    ContentItem('G', 'Grapes', '🍇'),
    ContentItem('H', 'Hat', '🎩'),
    ContentItem('I', 'Ice Cream', '🍦'),
    ContentItem('J', 'Juice', '🧃'),
    ContentItem('K', 'Kite', '🪁'),
    ContentItem('L', 'Lion', '🦁'),
    ContentItem('M', 'Moon', '🌙'),
    ContentItem('N', 'Nest', '🪺'),
    ContentItem('O', 'Orange', '🍊'),
    ContentItem('P', 'Pizza', '🍕'),
    ContentItem('Q', 'Queen', '👑'),
    ContentItem('R', 'Rabbit', '🐰'),
    ContentItem('S', 'Sun', '☀️'),
    ContentItem('T', 'Tiger', '🐯'),
    ContentItem('U', 'Umbrella', '☂️'),
    ContentItem('V', 'Van', '🚐'),
    ContentItem('W', 'Watermelon', '🍉'),
    ContentItem('X', 'Xylophone', '🎹'),
    ContentItem('Y', 'Yoyo', '🪀'),
    ContentItem('Z', 'Zebra', '🦓'),
  ];

  static const List<ContentItem> arabicNumbers = [
    ContentItem('٠', 'صفر', '0️⃣'),
    ContentItem('١', 'واحد', '1️⃣'),
    ContentItem('٢', 'اثنان', '2️⃣'),
    ContentItem('٣', 'ثلاثة', '3️⃣'),
    ContentItem('٤', 'أربعة', '4️⃣'),
    ContentItem('٥', 'خمسة', '5️⃣'),
    ContentItem('٦', 'ستة', '6️⃣'),
    ContentItem('٧', 'سبعة', '7️⃣'),
    ContentItem('٨', 'ثمانية', '8️⃣'),
    ContentItem('٩', 'تسعة', '9️⃣'),
  ];

  static const List<ContentItem> englishNumbers = [
    ContentItem('0', 'Zero', '0️⃣'),
    ContentItem('1', 'One', '1️⃣'),
    ContentItem('2', 'Two', '2️⃣'),
    ContentItem('3', 'Three', '3️⃣'),
    ContentItem('4', 'Four', '4️⃣'),
    ContentItem('5', 'Five', '5️⃣'),
    ContentItem('6', 'Six', '6️⃣'),
    ContentItem('7', 'Seven', '7️⃣'),
    ContentItem('8', 'Eight', '8️⃣'),
    ContentItem('9', 'Nine', '9️⃣'),
  ];

  static List<ContentItem> forGroup(ContentGroup group) {
    switch (group) {
      case ContentGroup.arabicLetters:
        return arabicLetters;
      case ContentGroup.englishLetters:
        return englishLetters;
      case ContentGroup.arabicNumbers:
        return arabicNumbers;
      case ContentGroup.englishNumbers:
        return englishNumbers;
    }
  }

  /// يقسّم مجموعة كاملة لمستويات، كل مستوى 4 عناصر بالترتيب
  /// (آخر مستوى قد يكون أقل من 4 لو العدد الكلي غير قابل للقسمة على 4).
  static List<List<ContentItem>> levelsFor(ContentGroup group) {
    final items = forGroup(group);
    const perLevel = ContentGroupInfo.itemsPerLevel;
    final levels = <List<ContentItem>>[];
    for (var i = 0; i < items.length; i += perLevel) {
      final end = (i + perLevel <= items.length) ? i + perLevel : items.length;
      levels.add(items.sublist(i, end));
    }
    return levels;
  }
}
