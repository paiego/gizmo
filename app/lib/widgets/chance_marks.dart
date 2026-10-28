import 'package:flutter/material.dart';

import '../theme.dart';

class ChanceMarks extends StatelessWidget {
  const ChanceMarks({super.key, required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    final ink = GizmoLook.of(context).ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < 3; index++)
          Container(
            width: 14,
            height: 14,
            margin: EdgeInsets.only(left: index == 0 ? 0 : 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index < remaining ? ink : const Color(0x00000000),
              border: Border.all(color: ink, width: 2),
            ),
          ),
      ],
    );
  }
}
