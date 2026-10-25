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
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final text = Text(
      label,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: filled ? paperColor : inkColor,
      ),
    );
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: inkColor,
                foregroundColor: paperColor,
                disabledBackgroundColor: const Color(0xFFBDBDBD),
                shape: shape,
              ),
              child: text,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: inkColor,
                side: const BorderSide(color: inkColor, width: 1.5),
                shape: shape,
              ),
              child: text,
            ),
    );
  }
}
