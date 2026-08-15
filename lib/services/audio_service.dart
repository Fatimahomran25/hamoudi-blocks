import 'package:flutter/services.dart';

/// نقطة وصل واحدة لكل صوت باللعبة. اليوم (Milestone 1) ما فيه ملفات صوت
/// مسجّلة بعد، فالتشغيل الفعلي "no-op" آمن (ما يسبب Exception لو الملف
/// غايب) + اهتزاز لمسي خفيف (Haptic) يعطي إحساس استجابة فورية بدون صوت.
///
/// بـ Milestone 3 (راجعي قسم "جودة الصوت" بالبرومت الأصلي):
/// 1) تُسجَّل كل المقاطع مسبقاً (Piper/Coqui محلياً، أو خدمة سحابية
///    بخطة مجانية، أو أداة أونلاين مجانية) وتُحفظ بـ assets/audio/*.mp3.
/// 2) يُستبدل جسم [play] هنا باستدعاء فعلي لـ AudioPlayer (حزمة
///    audioplayers) يشغّل الملف المطابق لـ [event.fileName].
/// باقي التطبيق يستدعي AudioService.instance.play(...) فقط، فسلك
/// الاستبدال محصور بهالملف وحده.
enum GameAudioEvent {
  buttonTap('ui_tap'),
  levelIntro('level_intro'),
  correctAnswer('correct_answer'),
  wrongAnswer('wrong_answer'),
  levelWin('level_win'),
  levelRetry('level_retry'),
  hintDirection('hint_direction'),
  jump('jump');

  const GameAudioEvent(this.fileName);
  final String fileName;
}

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  bool soundEnabled = true;

  Future<void> play(GameAudioEvent event) async {
    if (!soundEnabled) return;
    // TODO(milestone-3): AudioPlayer().play(AssetSource('audio/${event.fileName}.mp3'));
    HapticFeedback.lightImpact();
  }

  /// نطق تعريف عنصر تعليمي (حرف/رقم) — بالمستقبل يشغّل المقطع المسجّل
  /// المطابق لهالرمز تحديداً (كل حرف/رقم له ملف مستقل بـ assets/audio/).
  Future<void> playContentIntro(String symbolAssetKey) async {
    if (!soundEnabled) return;
    // TODO(milestone-3): AudioPlayer().play(AssetSource('audio/letters/$symbolAssetKey.mp3'));
  }
}
