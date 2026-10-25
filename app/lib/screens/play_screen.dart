import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gizmo_rules/gizmo_rules.dart';

import '../game/session.dart';
import '../theme.dart';
import '../widgets/chance_marks.dart';
import '../widgets/icon_view.dart';
import 'result_screen.dart';

enum _Phase { look, gap, choose, correct, incorrect }

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, required this.playerName, this.session});

  final String playerName;
  final GameSession? session;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen>
    with SingleTickerProviderStateMixin {
  late final GameSession _session;
  late final AnimationController _look;
  BuiltRound? _round;
  _Phase _phase = _Phase.look;
  int? _tapped;
  Timer? _timer;
  var _alive = true;

  @override
  void initState() {
    super.initState();
    _session = widget.session ?? GameSession();
    _look = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..addStatusListener(_onLook);
    _startRound(notify: false);
  }

  void _onLook(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_alive) return;
    setState(() => _phase = _Phase.gap);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), () {
      if (!_alive || !mounted) return;
      setState(() => _phase = _Phase.choose);
    });
  }

  void _startRound({bool notify = true}) {
    _timer?.cancel();
    _round = _session.deal();
    _tapped = null;
    _phase = _Phase.look;
    _look.forward(from: 0);
    if (notify && mounted) setState(() {});
  }

  void _tap(int index) {
    if (_phase != _Phase.choose || !_alive) return;
    final round = _round!;
    final correct = round.choices[index] == round.original;
    setState(() {
      _tapped = index;
      _phase = correct ? _Phase.correct : _Phase.incorrect;
    });
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: correct ? 400 : 800), () {
      if (!_alive || !mounted) return;
      final finished = _session.answer(round: round, correct: correct);
      if (finished) {
        _alive = false;
        _timer?.cancel();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              playerName: widget.playerName,
              transcript: _session.transcript(widget.playerName),
            ),
          ),
        );
        return;
      }
      _startRound();
    });
  }

  @override
  void dispose() {
    _alive = false;
    _timer?.cancel();
    _look.removeStatusListener(_onLook);
    _look.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final round = _round;
    return Scaffold(
      backgroundColor: boardColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 20, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Leave',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back, color: inkColor),
                  ),
                  const Text(
                    'Score ',
                    style: TextStyle(fontSize: 16, color: mutedColor),
                  ),
                  Text(
                    '${_session.score}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  ChanceMarks(remaining: _session.chances),
                ],
              ),
            ),
            Expanded(
              child: round == null
                  ? const SizedBox.shrink()
                  : _Board(
                      round: round,
                      phase: _phase,
                      tapped: _tapped,
                      look: _look,
                      onTap: _tap,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({
    required this.round,
    required this.phase,
    required this.tapped,
    required this.look,
    required this.onTap,
  });

  final BuiltRound round;
  final _Phase phase;
  final int? tapped;
  final Animation<double> look;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    if (phase == _Phase.gap) return const SizedBox.expand();
    if (phase == _Phase.look) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final size = math
              .min(constraints.maxWidth - 48, 280.0)
              .clamp(120.0, 280.0);
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconView(assembly: round.original, size: size),
              const SizedBox(height: 28),
              _LookBar(animation: look, width: size * 0.72),
            ],
          );
        },
      );
    }

    final originalIndex = round.choices.indexOf(round.original);
    final marked = phase == _Phase.correct
        ? tapped
        : phase == _Phase.incorrect
        ? originalIndex
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final cell = math
            .min((constraints.maxWidth - 40 - gap) / 2, 140.0)
            .clamp(48.0, 140.0);
        final rows = <Widget>[];
        for (var index = 0; index < round.choices.length; index += 2) {
          final left = index;
          final right = index + 1;
          rows.add(
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Choice(
                  assembly: round.choices[left],
                  size: cell,
                  marked: marked == left,
                  dimmed: phase == _Phase.incorrect && marked != left,
                  onTap: phase == _Phase.choose ? () => onTap(left) : null,
                ),
                if (right < round.choices.length) ...[
                  const SizedBox(width: gap),
                  _Choice(
                    assembly: round.choices[right],
                    size: cell,
                    marked: marked == right,
                    dimmed: phase == _Phase.incorrect && marked != right,
                    onTap: phase == _Phase.choose ? () => onTap(right) : null,
                  ),
                ],
              ],
            ),
          );
          if (right < round.choices.length - 1) {
            rows.add(const SizedBox(height: gap));
          }
        }
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: rows),
            ),
          ),
        );
      },
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.assembly,
    required this.size,
    required this.marked,
    required this.dimmed,
    required this.onTap,
  });

  final Assembly assembly;
  final double size;
  final bool marked;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.28 : 1,
      child: Material(
        color: const Color(0x00000000),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: marked ? Border.all(color: inkColor, width: 3) : null,
            ),
            child: IconView(assembly: assembly, size: size),
          ),
        ),
      ),
    );
  }
}

class _LookBar extends StatelessWidget {
  const _LookBar({required this.animation, required this.width});

  final Animation<double> animation;
  final double width;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final remaining = (1 - animation.value).clamp(0.0, 1.0);
        return SizedBox(
          width: width,
          height: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFD5D5D5),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: remaining,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: inkColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
