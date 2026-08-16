import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../theme/app_theme.dart';

/// A big button (≥60px tall) with thick black borders and a box shadow —
/// touch-first, no keyboard. Vibrates/plays a tap sound on press so the
/// child feels immediate feedback.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.emoji,
    this.color = AppColors.red,
    this.textColor = Colors.white,
    this.expand = true,
  });

  final String label;
  final String? emoji;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed == null
            ? null
            : () {
                AudioService.instance.play(GameAudioEvent.buttonTap);
                onPressed!();
              },
        child: NeoBox(
          color: onPressed == null ? AppColors.surfaceLight : color,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 28),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (emoji != null) ...[
                  Text(emoji!, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
