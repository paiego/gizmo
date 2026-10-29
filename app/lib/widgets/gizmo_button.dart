import 'package:flutter/material.dart';

import '../theme.dart';

class GizmoButton extends StatelessWidget {
  const GizmoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final look = GizmoLook.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final text = Text(
      label,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: filled ? look.paper : look.ink,
      ),
    );
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: look.ink,
                foregroundColor: look.paper,
                disabledBackgroundColor: Color.alphaBlend(
                  look.ink.withValues(alpha: 0.35),
                  look.board,
                ),
                shape: shape,
              ),
              child: text,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: look.ink,
                side: BorderSide(color: look.ink, width: 1.5),
                shape: shape,
              ),
              child: text,
            ),
    );
  }
}
