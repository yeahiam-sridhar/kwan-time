import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/kwan_theme.dart';

class KwanFab extends StatefulWidget {
  const KwanFab({
    required this.onAdd,
    required this.onVoice,
    super.key,
  });

  final VoidCallback onAdd;
  final VoidCallback onVoice;

  @override
  State<KwanFab> createState() => _KwanFabState();
}

class _KwanFabState extends State<KwanFab> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final base = GestureDetector(
      onTap: widget.onAdd,
      onLongPressStart: (_) => setState(() => _pressing = true),
      onLongPressEnd: (_) {
        setState(() => _pressing = false);
        widget.onVoice();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: _pressing ? 64 : 56,
        height: _pressing ? 64 : 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _pressing ? KwanColors.inPerson : KwanColors.accent,
          boxShadow: [
            BoxShadow(
              blurRadius: _pressing ? 30 : 20,
              color: (_pressing ? KwanColors.inPerson : KwanColors.accent).withValues(alpha: 0.5),
            ),
          ],
        ),
        child: Icon(
          _pressing ? Icons.mic_rounded : Icons.add_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );

    if (_pressing) {
      return base;
    }

    return base.animate(onPlay: (controller) => controller.repeat(reverse: true)).scaleXY(
          end: 1.06,
          duration: 1200.ms,
          curve: Curves.easeInOut,
        );
  }
}
