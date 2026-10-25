import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gizmo_rules/gizmo_rules.dart';

import '../game/session.dart';
import '../theme.dart';
import '../widgets/chance_marks.dart';
import '../widgets/gizmo_button.dart';
import '../widgets/icon_view.dart';
import 'result_screen.dart';

enum _Phase { look, gap, choose, correct, incorrect }

const _exitSlide = Duration(milliseconds: 420);
const _exitSettle = Duration(milliseconds: 380);
const _exitDissolve = Duration(milliseconds: 450);
const _compareFooter = 88.0;

double get _slideEnd => _exitSlide.inMilliseconds / _exitMilliseconds;

double get _settleEnd =>
    (_exitSlide + _exitSettle).inMilliseconds / _exitMilliseconds;

double get _exitMilliseconds =>
    (_exitSlide + _exitSettle + _exitDissolve).inMilliseconds.toDouble();

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, required this.playerName, this.session});

  final String playerName;
  final GameSession? session;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> with TickerProviderStateMixin {
  late final GameSession _session;
  late final AnimationController _look;
  late final AnimationController _exit;
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
    _exit = AnimationController(
      vsync: this,
      duration: _exitSlide + _exitSettle + _exitDissolve,
    );
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
    _exit.value = 0;
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
    if (!correct) {
      _exit.forward(from: 0);
      return;
    }
    _timer = Timer(const Duration(milliseconds: 400), () {
      if (!_alive || !mounted) return;
      _finish(round: round, correct: true);
    });
  }

  void _continue() {
    final round = _round;
    if (round == null || _phase != _Phase.incorrect || !_exit.isCompleted) {
      return;
    }
    _finish(round: round, correct: false);
  }

  void _finish({required BuiltRound round, required bool correct}) {
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
  }

  @override
  void dispose() {
    _alive = false;
    _timer?.cancel();
    _look.removeStatusListener(_onLook);
    _look.dispose();
    _exit.dispose();
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
                      exit: _exit,
                      onTap: _tap,
                      onContinue: _continue,
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
    required this.exit,
    required this.onTap,
    required this.onContinue,
  });

  final BuiltRound round;
  final _Phase phase;
  final int? tapped;
  final Animation<double> look;
  final Animation<double> exit;
  final ValueChanged<int> onTap;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    if (phase == _Phase.gap) return const SizedBox.expand();
    if (phase == _Phase.look) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final size = math
              .min(constraints.maxWidth - 48, 280.0)
              .clamp(120.0, 280.0)
              .toDouble();
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final board = constraints.biggest;
        final layout = _choiceLayout(board, round.choices.length);
        return AnimatedBuilder(
          animation: exit,
          builder: (context, _) {
            final t = phase == _Phase.incorrect ? exit.value : 0.0;
            final slide = _span(t, 0, _slideEnd, Curves.easeIn);
            final settle =
                _span(t, _slideEnd, _settleEnd, Curves.easeInOutCubic);
            final dissolve = _span(t, _settleEnd, 1, Curves.easeInOut);
            final originalOffset = _slotOffset(
              index: originalIndex,
              layout: layout,
              board: board,
              slide: slide,
              settle: settle,
              originalIndex: originalIndex,
            );
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (var index = 0; index < round.choices.length; index++)
                  _placed(
                    index: index,
                    layout: layout,
                    board: board,
                    slide: slide,
                    settle: settle,
                    dissolve: dissolve,
                    originalIndex: originalIndex,
                  ),
                if (phase == _Phase.incorrect && dissolve > 0)
                  Positioned(
                    left: originalOffset.dx,
                    top: originalOffset.dy + layout.cell + 10,
                    width: layout.cell,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: dissolve,
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'original',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: inkColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (phase == _Phase.incorrect && settle == 1)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 16,
                    child:
                        GizmoButton(label: 'Continue', onPressed: onContinue),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _placed({
    required int index,
    required _ChoiceLayout layout,
    required Size board,
    required double slide,
    required double settle,
    required double dissolve,
    required int originalIndex,
  }) {
    final offset = _slotOffset(
      index: index,
      layout: layout,
      board: board,
      slide: slide,
      settle: settle,
      originalIndex: originalIndex,
    );
    final mark = phase == _Phase.correct && index == tapped
        ? 1.0
        : phase == _Phase.incorrect && index == originalIndex
            ? 1 - dissolve
            : 0.0;
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      width: layout.cell,
      height: layout.cell,
      child: _Choice(
        key: ValueKey(index),
        assembly: round.choices[index],
        size: layout.cell,
        mark: mark,
        onTap: phase == _Phase.choose ? () => onTap(index) : null,
      ),
    );
  }

  Offset _slotOffset({
    required int index,
    required _ChoiceLayout layout,
    required Size board,
    required double slide,
    required double settle,
    required int originalIndex,
  }) {
    final leaving =
        phase == _Phase.incorrect && index != originalIndex && index != tapped;
    final grid = layout.slots[index];
    if (leaving) {
      return grid +
          _offscreen(grid, layout, board, layout.centered[index]) * slide;
    }
    if (phase == _Phase.incorrect && tapped != null) {
      final target = layout.pairSlot(index == originalIndex ? 0 : 1);
      return Offset.lerp(grid, target, settle)!;
    }
    return grid;
  }
}

class _ChoiceLayout {
  const _ChoiceLayout({
    required this.cell,
    required this.slots,
    required this.centered,
    required this.board,
    required this.pairGap,
  });

  final double cell;
  final List<Offset> slots;
  final List<bool> centered;
  final Size board;
  final double pairGap;

  Offset pairSlot(int place) {
    final pairWidth = cell * 2 + pairGap;
    final y = math.max(0.0, (board.height - _compareFooter - cell) / 2);
    return Offset(
      (board.width - pairWidth) / 2 + place * (cell + pairGap),
      y,
    );
  }
}

_ChoiceLayout _choiceLayout(Size board, int count) {
  const gap = 12.0;
  final raw = math
      .min((board.width - 40 - gap) / 2, 140.0)
      .clamp(48.0, 140.0)
      .toDouble();
  final rows = (count + 1) ~/ 2;
  final gridWidth = raw * 2 + gap;
  final gridHeight = rows * raw + (rows - 1) * gap;
  final scale = math.min(
    1.0,
    math.min(board.width / (gridWidth + 40), board.height / gridHeight),
  );
  final cell = raw * scale;
  final scaledGap = gap * scale;
  final width = cell * 2 + scaledGap;
  final height = rows * cell + (rows - 1) * scaledGap;
  final origin = Offset((board.width - width) / 2, (board.height - height) / 2);
  final slots = <Offset>[];
  final centered = <bool>[];
  for (var index = 0; index < count; index++) {
    final alone = index == count - 1 && count.isOdd;
    final x = alone
        ? origin.dx + (width - cell) / 2
        : origin.dx + (index % 2) * (cell + scaledGap);
    final y = origin.dy + (index ~/ 2) * (cell + scaledGap);
    slots.add(Offset(x, y));
    centered.add(alone);
  }
  return _ChoiceLayout(
    cell: cell,
    slots: slots,
    centered: centered,
    board: board,
    pairGap: math.max(scaledGap, 24.0 * scale),
  );
}

Offset _offscreen(
    Offset slot, _ChoiceLayout layout, Size board, bool centered) {
  if (centered) return Offset(0, board.height - slot.dy + layout.cell);
  final mid = slot.dx + layout.cell / 2;
  if (mid < board.width / 2) return Offset(-(slot.dx + layout.cell + 8), 0);
  return Offset(board.width - slot.dx + 8, 0);
}

double _span(double t, double begin, double end, Curve curve) {
  if (t <= begin) return 0;
  if (t >= end) return 1;
  return curve.transform((t - begin) / (end - begin));
}

class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.assembly,
    required this.size,
    required this.mark,
    required this.onTap,
  });

  final Assembly assembly;
  final double size;
  final double mark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x00000000),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              IconView(assembly: assembly, size: size),
              if (mark > 0)
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: inkColor.withValues(alpha: mark),
                        width: 3,
                      ),
                    ),
                  ),
                ),
            ],
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
