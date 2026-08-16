import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../data/content_repository.dart';
import '../models/content_item.dart';

/// Generic audio events (no specific symbol) — each maps to one or more
/// files under assets/audio/phrases/. A specific learning item (letter/
/// number) has its own method ([AudioService.playContentIntro]) since it
/// needs the symbol itself.
enum GameAudioEvent {
  /// Simple UI tap — haptic feedback only, no dedicated sound file.
  buttonTap,

  /// General welcome at the start of a session ("Come on, hero! Ready to play?").
  levelIntro,

  /// Random encouragement on a correct answer (4 varied phrases, see [play]).
  correctAnswer,

  /// A friendly, comforting phrase when touching a wrong pedestal.
  wrongAnswer,

  /// Congratulations for successfully finishing a level.
  levelWin,

  /// Encouraging "try again" when hearts run out.
  levelRetry,

  /// Direction hint — actually invoked via [playHintDirection] since it
  /// needs the direction (ahead/right/left/behind); exists here only to
  /// complete the enum.
  hintDirection,

  /// A cheerful "boing" sound on jump.
  jump,
}

/// The single point of contact for all game audio — every sound is a
/// pre-recorded clip in a natural Saudi Arabic voice (Azure Neural TTS,
/// voice ar-SA-HamedNeural), not live on-device TTS, so quality stays
/// consistent across every device (see the "audio quality" section of the
/// original prompt). Files live under assets/audio/content/ (each letter/
/// number's intro while searching — "Hero! Say: Alef... Lion!"),
/// assets/audio/content_found/ (the letter repeated 3 times on success —
/// "We found the letter Alef! Alef! Alef! Alef!" — so it sticks in the
/// child's memory), and assets/audio/phrases/ (general phrases).
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
      // Missing audio file or playback failed — ignore safely, gameplay
      // continues silently instead of throwing.
    }
  }

  Future<void> play(GameAudioEvent event) async {
    if (!soundEnabled) return;
    HapticFeedback.lightImpact();
    switch (event) {
      case GameAudioEvent.buttonTap:
      case GameAudioEvent.hintDirection:
        return; // No dedicated file — see playHintDirection for the hint.
      case GameAudioEvent.levelIntro:
        return _playAsset('phrases/level_intro.wav');
      case GameAudioEvent.correctAnswer:
        final variant = _random.nextInt(4) + 1; // 4 varied encouragement phrases.
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

  /// A direction hint — [direction] is one of 'ahead' / 'left' / 'right' /
  /// 'behind' (the same values sent by assets/game3d/game.js). Any unknown
  /// value is safely treated as 'ahead' instead of failing silently.
  Future<void> playHintDirection(String direction) async {
    if (!soundEnabled) return;
    HapticFeedback.lightImpact();
    const valid = {'ahead', 'left', 'right', 'behind'};
    final safe = valid.contains(direction) ? direction : 'ahead';
    return _playAsset('phrases/hint_direction_$safe.wav');
  }

  /// Speaks the intro for a learning item (letter/number) by its [symbol]
  /// (e.g. 'أ' or 'A' or '٣'). Maps the symbol to a file key via
  /// [_contentAudioKey], relying on [ContentRepository]'s own ordering — so
  /// any future content change (adding/removing an item) is reflected
  /// automatically without touching this method.
  Future<void> playContentIntro(String symbol) async {
    if (!soundEnabled) return;
    final key = _contentAudioKey(symbol);
    if (key == null) return;
    return _playAsset('content/$key.wav');
  }

  /// A celebratory repeat of the letter/number 3 times when the child
  /// reaches it correctly ("We found the letter Alef! Alef! Alef! Alef!")
  /// — replaces generic encouragement ([GameAudioEvent.correctAnswer]) so
  /// the name sticks in the child's memory (see the "gameplay mechanics"
  /// section — an explicit repetition request from the user).
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
