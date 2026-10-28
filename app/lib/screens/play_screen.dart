import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gizmo_rules/gizmo_rules.dart';

import '../game/session.dart';
import '../theme.dart';
import '../widgets/chance_marks.dart';
import '../widgets/gizmo_button.dart';
import '../widgets/icon_view.dart';
import 'result_screen.dart';

enum _Phase { look, gap, choose, correct, incorrect }

enum _Edge { left, right, top, bottom }

const _lookTime = Duration(milliseconds: 3000);
const _gapTime = Duration(milliseconds: 400);
const _correctTime = Duration(milliseconds: 400);
const _travelTime = Duration(milliseconds: 400);
const _exitSlide = Duration(milliseconds: 420);
const _exitSettle = Duration(milliseconds: 380);
const _exitDissolve = Duration(milliseconds: 450);
const _compareFooter = 88.0;
const _offscreenMargin = 16.0;

double get _travelShare =>
    _travelTime.inMilliseconds / _lookTime.inMilliseconds;

double get _slideEnd => _exitSlide.inMilliseconds / _exitMilliseconds;

double get _settleEnd =>
    (_exitSlide + _exitSettle).inMilliseconds / _exitMilliseconds;

double get _exitMilliseconds =>
    (_exitSlide + _exitSettle + _exitDissolve).inMilliseconds.toDouble();

class PlayScreen extends StatefulWidget {
  const PlayScreen({
    super.key,
    required this.playerName,
    this.session,
    this.adminMode = false,
  });

  final String playerName;
  final GameSession? session;
  final bool adminMode;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> with TickerProviderStateMixin {
  late final GameSession _session;
  late final AnimationController _look;
  late final AnimationController _exit;
  late final AnimationController _enter;
  late final AnimationController _cheer;
  static const _cheerSound = MethodChannel('gizmo/cheer');
  final _motion = math.Random();
  BuiltRound? _round;
  _Phase _phase = _Phase.look;
  _Edge _enterEdge = _Edge.left;
  _Edge _exitEdge = _Edge.right;
  List<_Edge> _choiceEdges = const [];
  int? _tapped;
  Timer? _timer;
  var _alive = true;

  @override
  void initState() {
    super.initState();
    _session = widget.session ?? GameSession(adminMode: widget.adminMode);
    _look = AnimationController(vsync: this, duration: _lookTime)
      ..addStatusListener(_onLook);
    _exit = AnimationController(
      vsync: this,
      duration: _exitSlide + _exitSettle + _exitDissolve,
    );
    _enter = AnimationController(vsync: this, duration: _travelTime);
    _cheer = AnimationController(vsync: this, duration: _correctTime);
    _startRound(notify: false);
  }

  void _onLook(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_alive) return;
    setState(() => _phase = _Phase.gap);
    _timer?.cancel();
    _timer = Timer(_gapTime, () {
      if (!_alive || !mounted) return;
      _enter.value = 0;
      setState(() => _phase = _Phase.choose);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_alive || !mounted || _phase != _Phase.choose) return;
        _enter.forward(from: 0);
      });
    });
  }

  void _startRound({bool notify = true}) {
    _timer?.cancel();
    _round = _session.deal();
    _tapped = null;
    _phase = _Phase.look;
    _enterEdge = _pickEdge();
    _exitEdge = _otherEdge(_enterEdge);
    _choiceEdges = [
      for (var index = 0; index < _round!.choices.length; index++) _pickEdge(),
    ];
    _enter.stop();
    _enter.value = 0;
    _cheer.stop();
    _cheer.value = 0;
    _look.forward(from: 0);
    _exit.value = 0;
    if (notify && mounted) setState(() {});
  }

  _Edge _pickEdge() => _Edge.values[_motion.nextInt(_Edge.values.length)];

  _Edge _otherEdge(_Edge avoid) {
    final options = [
      for (final edge in _Edge.values)
        if (edge != avoid) edge,
    ];
    return options[_motion.nextInt(options.length)];
  }

  void _tap(int index) {
    if (_phase != _Phase.choose || !_alive) return;
    final round = _round!;
    final correct = round.choices[index] == round.original;
    _enter.value = 1;
    setState(() {
      _tapped = index;
      _phase = correct ? _Phase.correct : _Phase.incorrect;
    });
    _timer?.cancel();
    if (!correct) {
      _exit.forward(from: 0);
      return;
    }
    _cheer.forward(from: 0);
    _celebrate();
    _timer = Timer(_correctTime, () {
      if (!_alive || !mounted) return;
      _finish(round: round, correct: true);
    });
  }

  void _celebrate() {
    if (WidgetsBinding.instance is! WidgetsFlutterBinding) return;
    HapticFeedback.successNotification();
    unawaited(_playCheer());
  }

  Future<void> _playCheer() async {
    try {
      await _cheerSound.invokeMethod<void>('play');
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
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
            adminMode: widget.adminMode,
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
    _enter.dispose();
    _cheer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final round = _round;
    final chrome = GizmoLook.of(context);
    return Scaffold(
      backgroundColor: chrome.board,
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
                    icon: Icon(Icons.arrow_back, color: chrome.ink),
                  ),
                  Text(
                    'Score ',
                    style: TextStyle(fontSize: 16, color: chrome.muted),
                  ),
                  Text(
                    '${_session.score}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: chrome.ink,
                    ),
                  ),
                  if (widget.adminMode) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Admin',
                      style: TextStyle(fontSize: 13, color: chrome.muted),
                    ),
                  ],
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
                      enter: _enter,
                      cheer: _cheer,
                      enterEdge: _enterEdge,
                      exitEdge: _exitEdge,
                      choiceEdges: _choiceEdges,
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
    required this.enter,
    required this.cheer,
    required this.enterEdge,
    required this.exitEdge,
    required this.choiceEdges,
    required this.onTap,
    required this.onContinue,
  });

  final BuiltRound round;
  final _Phase phase;
  final int? tapped;
  final Animation<double> look;
  final Animation<double> exit;
  final Animation<double> enter;
  final Animation<double> cheer;
  final _Edge enterEdge;
  final _Edge exitEdge;
  final List<_Edge> choiceEdges;
  final ValueChanged<int> onTap;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    if (phase == _Phase.gap) return const SizedBox.expand();
    if (phase == _Phase.look) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final board = constraints.biggest;
          final size =
              math.min(board.width - 48, 280.0).clamp(120.0, 280.0).toDouble();
          final block = size + 32;
          final iconLeft = (board.width - size) / 2;
          final iconTop = (board.height - block) / 2;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: iconLeft,
                top: iconTop,
                width: size,
                height: size,
                child: AnimatedBuilder(
                  animation: look,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: _lookTravel(
                        t: look.value,
                        enter: enterEdge,
                        exit: exitEdge,
                        board: board,
                        origin: Offset(iconLeft, iconTop),
                        extent: size,
                      ),
                      child: child,
                    );
                  },
                  child: IconView(assembly: round.original, size: size),
                ),
              ),
              Positioned(
                left: iconLeft + size * 0.14,
                top: iconTop + size + 28,
                width: size * 0.72,
                child: _LookBar(animation: look, width: size * 0.72),
              ),
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
          animation: Listenable.merge([exit, enter, cheer]),
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
                    context: context,
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
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'original',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: GizmoLook.of(context).ink,
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
    required BuildContext context,
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
    final cheering = phase == _Phase.correct && index == tapped;
    final pulse = cheering ? math.sin(cheer.value * math.pi) : 0.0;
    final mark = cheering
        ? 1.0
        : phase == _Phase.incorrect && index == originalIndex
            ? 1 - dissolve
            : 0.0;
    Widget icon = _Choice(
      key: ValueKey(index),
      assembly: round.choices[index],
      size: layout.cell,
      mark: mark,
      onTap: phase == _Phase.choose ? () => onTap(index) : null,
    );
    if (pulse > 0) {
      icon = Transform.scale(scale: 1 + (0.1 * pulse), child: icon);
    }
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      width: layout.cell,
      height: layout.cell,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          icon,
          if (cheering && pulse > 0)
            IgnorePointer(
              child: Opacity(
                opacity: (1 - cheer.value).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.82 + (0.46 * cheer.value),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color:
                            GizmoLook.of(context).ink.withValues(alpha: 0.35),
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
    final arrived = Curves.easeOutCubic.transform(enter.value.clamp(0.0, 1.0));
    final travel = _edgeDelta(choiceEdges[index], grid, layout.cell, board);
    return Offset.lerp(grid + travel, grid, arrived)!;
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

Offset _edgeDelta(_Edge edge, Offset origin, double extent, Size board) {
  switch (edge) {
    case _Edge.left:
      return Offset(-(origin.dx + extent + _offscreenMargin), 0);
    case _Edge.right:
      return Offset(board.width - origin.dx + _offscreenMargin, 0);
    case _Edge.top:
      return Offset(0, -(origin.dy + extent + _offscreenMargin));
    case _Edge.bottom:
      return Offset(0, board.height - origin.dy + _offscreenMargin);
  }
}

Offset _lookTravel({
  required double t,
  required _Edge enter,
  required _Edge exit,
  required Size board,
  required Offset origin,
  required double extent,
}) {
  final inward = _edgeDelta(enter, origin, extent, board);
  final outward = _edgeDelta(exit, origin, extent, board);
  if (t < _travelShare) {
    final u = Curves.easeOutCubic.transform(t / _travelShare);
    return Offset.lerp(inward, Offset.zero, u)!;
  }
  if (t > 1 - _travelShare) {
    final u =
        Curves.easeInCubic.transform((t - (1 - _travelShare)) / _travelShare);
    return Offset.lerp(Offset.zero, outward, u)!;
  }
  return Offset.zero;
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
    final chrome = GizmoLook.of(context);
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
                        color: chrome.ink.withValues(alpha: mark),
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
    final chrome = GizmoLook.of(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final remaining = (1 - animation.value).clamp(0.0, 1.0);
        return SizedBox(
          width: width,
          height: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: chrome.line,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: remaining,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: chrome.ink,
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
