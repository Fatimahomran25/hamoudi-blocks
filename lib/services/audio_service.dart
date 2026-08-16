import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../data/content_repository.dart';
import '../models/content_item.dart';

/// أحداث صوتية عامة (بدون رمز محدد) — كل وحدة تطابق ملف واحد أو أكثر
/// بـ assets/audio/phrases/. تعريف عنصر تعليمي محدد (حرف/رقم) له ميثود
/// مستقل ([AudioService.playContentIntro]) لأنه يحتاج الرمز نفسه.
enum GameAudioEvent {
  /// نقرة واجهة بسيطة — اهتزاز لمسي بس، بدون ملف صوت مخصص.
  buttonTap,

  /// ترحيب عام ببداية الجلسة ("يلا يا بطل! جاهز نلعب؟").
  levelIntro,

  /// تشجيع عشوائي عند الإجابة الصحيحة (4 عبارات متنوعة، راجعي [play]).
  correctAnswer,

  /// عبارة مواساة ودّية عند لمس منصّة غلط.
  wrongAnswer,

  /// تهنئة إنهاء المستوى بنجاح.
  levelWin,

  /// تشجيع "حاول مرة ثانية" عند نفاد القلوب.
  levelRetry,

  /// تلميح اتجاه — يُستدعى فعلياً عبر [playHintDirection] لأنه يحتاج
  /// الاتجاه (قدامك/يمين/يسار)؛ موجود هنا فقط لاكتمال التعداد.
  hintDirection,

  /// صوت "بوينج" مرح وقت القفز.
  jump,
}

/// نقطة وصل واحدة لكل صوت باللعبة — كل الأصوات مقاطع مسجّلة مسبقاً بصوت
/// عربي سعودي طبيعي (Azure Neural TTS، صوت ar-SA-HamedNeural)، مو TTS حي
/// بالجهاز، بحيث الجودة ثابتة على كل الأجهزة (راجعي قسم "جودة الصوت"
/// بالبرومت الأصلي). الملفات بـ assets/audio/content/ (تعريف كل حرف/رقم
/// وقت البحث — "يا بطل! قول: أ... أسد!")، assets/audio/content_found/
/// (تكرار الحرف 3 مرات عند النجاح — "لقينا حرف الألف! الألف! الألف!
/// الألف!" — عشان يرسخ بذاكرة الطفل)، و assets/audio/phrases/ (عبارات
/// عامة).
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  bool soundEnabled = true;

  final AudioPlayer _player = AudioPlayer();
  final Random _random = Random();

  Future<void> _playAsset(String relativePath) async {
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/$relativePath'));
    } catch (_) {
      // ملف صوت غايب أو تعذّر التشغيل — نتجاهله بأمان، اللعب يكمل بصمت
      // بدل ما يطيح التطبيق بـ Exception.
    }
  }

  Future<void> play(GameAudioEvent event) async {
    if (!soundEnabled) return;
    HapticFeedback.lightImpact();
    switch (event) {
      case GameAudioEvent.buttonTap:
      case GameAudioEvent.hintDirection:
        return; // بدون ملف مخصص — راجعي playHintDirection للتلميح.
      case GameAudioEvent.levelIntro:
        return _playAsset('phrases/level_intro.wav');
      case GameAudioEvent.correctAnswer:
        final variant = _random.nextInt(4) + 1; // 4 عبارات تشجيع متنوعة.
        return _playAsset('phrases/correct_answer_$variant.wav');
      case GameAudioEvent.wrongAnswer:
        return _playAsset('phrases/wrong_answer.wav');
      case GameAudioEvent.levelWin:
        return _playAsset('phrases/level_win.wav');
      case GameAudioEvent.levelRetry:
        return _playAsset('phrases/level_retry.wav');
      case GameAudioEvent.jump:
        return _playAsset('phrases/jump.wav');
    }
  }

  /// تلميح اتجاه — [direction] واحدة من 'ahead' / 'left' / 'right' /
  /// 'behind' (نفس القيم اللي يرسلها assets/game3d/game.js). أي قيمة غير
  /// معروفة تُعامل كـ 'ahead' بأمان بدل ما تفشل بصمت.
  Future<void> playHintDirection(String direction) async {
    if (!soundEnabled) return;
    HapticFeedback.lightImpact();
    const valid = {'ahead', 'left', 'right', 'behind'};
    final safe = valid.contains(direction) ? direction : 'ahead';
    return _playAsset('phrases/hint_direction_$safe.wav');
  }

  /// نطق تعريف عنصر تعليمي (حرف/رقم) حسب رمزه [symbol] (مثلاً 'أ' أو 'A'
  /// أو '٣'). يحوّل الرمز لمفتاح ملف عبر [_contentAudioKey] بالاعتماد على
  /// ترتيب [ContentRepository] نفسه — فأي تعديل مستقبلي على المحتوى
  /// (إضافة/حذف عنصر) ينعكس تلقائياً بدون تعديل هالميثود.
  Future<void> playContentIntro(String symbol) async {
    if (!soundEnabled) return;
    final key = _contentAudioKey(symbol);
    if (key == null) return;
    return _playAsset('content/$key.wav');
  }

  /// تكرار احتفالي بالحرف/الرقم 3 مرات لما الطفل يوصله صح ("لقينا حرف
  /// الألف! الألف! الألف! الألف!") — يحل محل التشجيع العام
  /// ([GameAudioEvent.correctAnswer]) عشان الاسم يرسخ بذاكرة الطفل
  /// (راجعي قسم "آلية اللعب" — طلب تكرار صريح من المستخدمة).
  Future<void> playFoundContent(String symbol) async {
    if (!soundEnabled) return;
    HapticFeedback.lightImpact();
    final key = _contentAudioKey(symbol);
    if (key == null) return;
    return _playAsset('content_found/$key.wav');
  }

  String? _contentAudioKey(String symbol) {
    final groups = <String, List<ContentItem>>{
      'ar_letter': ContentRepository.arabicLetters,
      'en_letter': ContentRepository.englishLetters,
      'ar_number': ContentRepository.arabicNumbers,
      'en_number': ContentRepository.englishNumbers,
    };
    for (final entry in groups.entries) {
      final index = entry.value.indexWhere((item) => item.symbol == symbol);
      if (index != -1) return '${entry.key}_$index';
    }
    return null;
  }
}
