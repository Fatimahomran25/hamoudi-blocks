import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/content_repository.dart';
import '../../models/avatar_option.dart';
import '../../models/child_profile.dart';
import '../../models/content_item.dart';
import '../../services/audio_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import 'level_result_screen.dart';

/// The real 3D game world screen (Milestone 2): a local WebView (no
/// internet connection needed) showing the Three.js world built in
/// assets/game3d/ — a blocky character, a touch joystick, jumping,
/// pedestals scattered at 360°, hearts, direction hints.
///
/// Bridge to the page over a JavaScript Channel named "GameChannel" (each
/// message is documented at the top of assets/game3d/game.js):
///   page → here: {type:'ready'} then {type:'audio', event, symbol?, direction?}
///          and {type:'result', outcome:'win'|'retry', ...} and {type:'exit'}.
///   here → page: window.HamoudiGame.init(config) after receiving 'ready'.
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

  /// Which item in the level (0-3) to start from. Defaults to 0 (a fresh
  /// level start). When returning after "try again" we pass the same round
  /// index where hearts ran out, so "the level doesn't restart — it just
  /// repeats the same question" (see the "win/loss system" section of the
  /// original prompt).
  final int startRoundIndex;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final WebViewController _controller;
  bool _handledResult = false;

  /// Maps audio message keys coming from the bridge to the matching
  /// [GameAudioEvent]. 'level_intro' and 'hint_direction' are deliberately
  /// excluded since they need special handling (the item's symbol or the
  /// direction) — see [_handleAudioEvent].
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
      return; // Unexpected message — ignore it safely instead of crashing the screen.
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
        // With a symbol = a specific learning item's intro (start of a
        // round); without a symbol = a general session welcome (see
        // startLevel() in assets/game3d/game.js).
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
        // Celebration repeating the letter/number 3 times — needs the
        // symbol itself, see AudioService.playFoundContent.
        final symbol = data['symbol'] as String?;
        if (symbol != null) AudioService.instance.playFoundContent(symbol);
        break;
      default:
        final mapped = _audioEventMap[event];
        if (mapped != null) AudioService.instance.play(mapped);
    }
  }

  /// The level's regular items (4) + the child's marked weak points in the
  /// same group (if any) as extra bonus rounds at the end — see "Child's
  /// Weak Points" in WeakPointsScreen. Duplicate items (already in the
  /// level) aren't repeated.
  List<ContentItem> _buildRoundItems(ChildProfile child) {
    final levelItems = ContentRepository.levelsFor(widget.group)[widget.levelIndex];
    final weakSymbols = child.weakSymbolsFor(widget.group);
    if (weakSymbols.isEmpty) return levelItems;

    final levelSymbols = levelItems.map((i) => i.symbol).toSet();
    final allGroupItems = ContentRepository.forGroup(widget.group);
    final bonusItems = weakSymbols
        .where((symbol) => !levelSymbols.contains(symbol))
        .map((symbol) => allGroupItems.firstWhere(
              (i) => i.symbol == symbol,
              orElse: () => allGroupItems.first,
            ))
        .toList();
    return [...levelItems, ...bonusItems];
  }

  void _sendInitConfig() {
    final profileService = context.read<ProfileService>();
    final child = profileService.children.firstWhere(
      (c) => c.id == widget.childId,
      orElse: () => profileService.children.first,
    );
    final avatar = avatarById(child.avatarId);
    final items = _buildRoundItems(child);

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
