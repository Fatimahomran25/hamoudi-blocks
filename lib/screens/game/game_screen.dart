import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/content_repository.dart';
import '../../models/avatar_option.dart';
import '../../models/content_item.dart';
import '../../services/audio_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import 'level_result_screen.dart';

/// شاشة عالم اللعب ثلاثي الأبعاد الحقيقي (Milestone 2): WebView محلي
/// (بدون أي اتصال إنترنت) يعرض عالم Three.js المبني بـ assets/game3d/ —
/// شخصية بلوكية، جويستيك لمسي، قفز، منصّات موزعة 360°، قلوب، تلميح اتجاه.
///
/// جسر التواصل مع الصفحة عبر JavaScript Channel اسمه "GameChannel"
/// (تفاصيل كل رسالة موثّقة أعلى assets/game3d/game.js):
///   الصفحة → هنا: {type:'ready'} ثم {type:'audio', event, symbol?, direction?}
///            و {type:'result', outcome:'win'|'retry', ...} و {type:'exit'}.
///   هنا → الصفحة: window.HamoudiGame.init(config) بعد استقبال 'ready'.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.childId,
    required this.group,
    required this.levelIndex,
    this.startRoundIndex = 0,
  });

  final String childId;
  final ContentGroup group;
  final int levelIndex;

  /// أي عنصر بالمستوى (0-3) نبدأ منه. القيمة الافتراضية 0 (بداية مستوى
  /// جديدة). لما نرجع بعد "حاول مرة ثانية" نمرر نفس رقم الجولة اللي خلصت
  /// فيها القلوب، عشان "المستوى لا يرجع للخلف — فقط إعادة نفس السؤال"
  /// (راجعي قسم "نظام الفوز والخسارة" بالبرومت الأصلي).
  final int startRoundIndex;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final WebViewController _controller;
  bool _handledResult = false;

  /// تحويل مفاتيح رسائل الصوت القادمة من الجسر لـ [GameAudioEvent] المطابق.
  /// 'level_intro' و'hint_direction' مستثناة عمداً لأنها تحتاج معالجة
  /// خاصة (رمز العنصر أو الاتجاه) — راجعي [_handleAudioEvent].
  static const Map<String, GameAudioEvent> _audioEventMap = {
    'ui_tap': GameAudioEvent.buttonTap,
    'correct_answer': GameAudioEvent.correctAnswer,
    'wrong_answer': GameAudioEvent.wrongAnswer,
    'level_win': GameAudioEvent.levelWin,
    'level_retry': GameAudioEvent.levelRetry,
    'jump': GameAudioEvent.jump,
  };

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..addJavaScriptChannel('GameChannel', onMessageReceived: _onBridgeMessage)
      ..loadFlutterAsset('assets/game3d/index.html');
  }

  void _onBridgeMessage(JavaScriptMessage message) {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      return; // رسالة غير متوقعة — نتجاهلها بأمان بدل ما نكسر الشاشة.
    }

    switch (data['type']) {
      case 'ready':
        _sendInitConfig();
        break;
      case 'audio':
        _handleAudioEvent(data);
        break;
      case 'result':
        _handleResult(data);
        break;
      case 'exit':
        if (mounted) Navigator.of(context).maybePop();
        break;
    }
  }

  void _handleAudioEvent(Map<String, dynamic> data) {
    final event = data['event'] as String?;
    switch (event) {
      case 'level_intro':
        // مع رمز = تعريف عنصر تعليمي محدد (بداية جولة)؛ بدون رمز = ترحيب
        // عام ببداية الجلسة (راجعي startLevel() بـ assets/game3d/game.js).
        final symbol = data['symbol'] as String?;
        if (symbol != null) {
          AudioService.instance.playContentIntro(symbol);
        } else {
          AudioService.instance.play(GameAudioEvent.levelIntro);
        }
        break;
      case 'hint_direction':
        AudioService.instance.playHintDirection(data['direction'] as String? ?? 'ahead');
        break;
      case 'found_answer':
        // احتفال بتكرار الحرف/الرقم 3 مرات — يحتاج الرمز نفسه، راجعي
        // AudioService.playFoundContent.
        final symbol = data['symbol'] as String?;
        if (symbol != null) AudioService.instance.playFoundContent(symbol);
        break;
      default:
        final mapped = _audioEventMap[event];
        if (mapped != null) AudioService.instance.play(mapped);
    }
  }

  void _sendInitConfig() {
    final profileService = context.read<ProfileService>();
    final child = profileService.children.firstWhere(
      (c) => c.id == widget.childId,
      orElse: () => profileService.children.first,
    );
    final avatar = avatarById(child.avatarId);
    final items = ContentRepository.levelsFor(widget.group)[widget.levelIndex];

    final config = {
      'childName': child.name,
      'avatar': {
        'jacket': _toHex(avatar.jacketColor),
        'skin': _toHex(avatar.skinColor),
        'hair': _toHex(avatar.hairColor),
      },
      'items': items
          .map((i) => {'symbol': i.symbol, 'exampleWord': i.exampleWord, 'emoji': i.emoji})
          .toList(),
      'resumeAt': widget.startRoundIndex,
    };

    _controller.runJavaScript('window.HamoudiGame.init(${jsonEncode(config)})');
  }

  String _toHex(Color c) {
    String channel(double v) => (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${channel(c.r)}${channel(c.g)}${channel(c.b)}';
  }

  void _handleResult(Map<String, dynamic> data) {
    if (_handledResult || !mounted) return;
    _handledResult = true;

    if (data['outcome'] == 'win') {
      final heartsRemaining = (data['heartsRemaining'] as num?)?.toInt() ?? 0;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LevelResultScreen(
            childId: widget.childId,
            group: widget.group,
            levelIndex: widget.levelIndex,
            didWin: true,
            heartsRemaining: heartsRemaining,
          ),
        ),
      );
    } else if (data['outcome'] == 'retry') {
      final roundIndex = (data['roundIndex'] as num?)?.toInt() ?? 0;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LevelResultScreen(
            childId: widget.childId,
            group: widget.group,
            levelIndex: widget.levelIndex,
            didWin: false,
            heartsRemaining: 0,
            resumeRoundIndex: roundIndex,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: WebViewWidget(controller: _controller),
    );
  }
}
