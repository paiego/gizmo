import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gizmo_rules/gizmo_rules.dart';

import '../account/local_score.dart';
import '../game/session.dart';
import '../theme.dart';
import '../widgets/chance_marks.dart';
import '../widgets/gizmo_button.dart';
import '../widgets/icon_view.dart';
import 'result_screen.dart';

enum _Phase { look, gap, choose, correct, incorrect }

/// Board travel, slides, and the correct-pick bounce are off for now.
const _animate = false;

enum _Edge { left, right, top, bottom }

const _lookTime = Duration(milliseconds: 3000);

/// Level at which the original is shown for a quarter of [_lookTime].
const _lookFloorLevel = 19;
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

/// How long the original stays up. Level 1 keeps [_lookTime]. Each later
/// level is shorter, and level [_lookFloorLevel] and after hold at one quarter.
Duration _lookDuration(int level) {
  final steps = (level - 1).clamp(0, _lookFloorLevel - 1);
  final drop = _lookTime.inMilliseconds * 3 ~/ 4;
  final span = _lookFloorLevel - 1;
  return Duration(
    milliseconds: _lookTime.inMilliseconds - drop * steps ~/ span,
  );
}

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
    this.userId,
    this.localOnly = false,
    this.scores = const LocalScoreStore(),
  });

  final String playerName;
  final GameSession? session;
  final bool adminMode;

  /// Firebase user id this run is allowed to score. Null on the online path
  /// until the result screen submits to the server.
  final String? userId;

  /// Keep the score on the device for [userId]. Do not submit it.
  final bool localOnly;
  final LocalScoreStore scores;

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
  final _nextLevel = TextEditingController();
  BuiltRound? _round;
  _Phase _phase = _Phase.look;
  _Edge _enterEdge = _Edge.left;
  _Edge _exitEdge = _Edge.right;
  List<_Edge> _choiceEdges = const [];
  var _scatter = 0;
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
      _enter.forward(from: 0);
      setState(() => _phase = _Phase.choose);
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
    _scatter = _motion.nextInt(1 << 30);
    _nextLevel.clear();
    _enter.stop();
    _enter.value = 0;
    _cheer.stop();
    _cheer.value = 0;
    _look.duration = _lookDuration(_session.level);
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
      if (_animate) {
        _exit.forward(from: 0);
      } else {
        _exit.value = 1;
      }
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

  void _submitLevel(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      _session.clearQueuedLevel();
      return;
    }
    final value = int.tryParse(trimmed);
    if (value == null || value < 1) return;
    _session.queueLevel(value);
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
    _submitLevel(_nextLevel.text);
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
            userId: widget.userId,
            localOnly: widget.localOnly,
            scores: widget.scores,
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
    _nextLevel.dispose();
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
                  Expanded(
                    child: Row(
                      children: [
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
                        const SizedBox(width: 12),
                        Text(
                          'Level ',
                          style: TextStyle(fontSize: 16, color: chrome.muted),
                        ),
                        Text(
                          '${_session.level}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: chrome.ink,
                          ),
                        ),
                        if (widget.adminMode && _phase == _Phase.choose) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 64,
                            child: TextField(
                              controller: _nextLevel,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: _submitLevel,
                              onSubmitted: _submitLevel,
                              style: TextStyle(fontSize: 16, color: chrome.ink),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Next',
                                filled: true,
                                fillColor: chrome.paper,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        ] else if (widget.adminMode) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Admin',
                            style: TextStyle(fontSize: 13, color: chrome.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
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
                      scatter: _scatter,
                      cue: _session.rounds.isEmpty,
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
    required this.scatter,
    required this.cue,
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
  final int scatter;

  /// First round of the run: the look and choice prompts.
  final bool cue;
  final ValueChanged<int> onTap;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    if (phase == _Phase.gap) return const SizedBox.expand();
    if (phase == _Phase.look) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final board = constraints.biggest;
          final size = _placeChoices(
            board,
            round.choices.length,
            scatter,
            topInset: cue ? 40 : 0,
          ).cell;
          final block = size + 32;
          final iconLeft = (board.width - size) / 2;
          final iconTop = (board.height - block) / 2;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              if (cue)
                Positioned(
                  left: 20,
                  right: 20,
                  top: math.max(4.0, iconTop - 40),
                  height: 32,
                  child: _Cue(label: 'Remember Me!'),
                ),
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
        final layout = _choiceLayout(
          board,
          round.choices.length,
          scatter,
          topInset: cue ? 40 : 0,
        );
        return AnimatedBuilder(
          animation: Listenable.merge([exit, enter, cheer]),
          builder: (context, _) {
            final t = phase == _Phase.incorrect
                ? (_animate ? exit.value : 1.0)
                : 0.0;
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
            final choiceTop = layout.slots
                .map((slot) => slot.dy)
                .reduce(math.min);
            final shown = phase == _Phase.incorrect ? layout.pairCell : layout.cell;
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                if (cue && phase == _Phase.choose)
                  Positioned(
                    left: 20,
                    right: 20,
                    top: math.max(4.0, choiceTop - 40),
                    height: 32,
                    child: const _Cue(label: 'Find Me!'),
                  ),
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
                    top: originalOffset.dy + shown + 10,
                    width: shown,
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
    final pairing = phase == _Phase.incorrect &&
        (index == originalIndex || index == tapped);
    final shown = pairing ? layout.pairCell : layout.cell;
    final cheering = phase == _Phase.correct && index == tapped;
    final pulse =
        _animate && cheering ? math.sin(cheer.value * math.pi) : 0.0;
    final mark = cheering
        ? 1.0
        : phase == _Phase.incorrect && index == originalIndex
            ? 1 - dissolve
            : 0.0;
    Widget icon = _Choice(
      key: ValueKey(index),
      assembly: round.choices[index],
      size: shown,
      mark: mark,
      onTap: phase == _Phase.choose ? () => onTap(index) : null,
    );
    if (pulse > 0) {
      icon = Transform.scale(scale: 1 + (0.1 * pulse), child: icon);
    }
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      width: shown,
      height: shown,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          icon,
          if (cheering && pulse > 0)
            IgnorePointer(
              child: Center(
                child: SizedBox.square(
                  dimension: _choiceDiameter(layout.cell),
                  child: Opacity(
                    opacity: (1 - cheer.value).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.82 + (0.46 * cheer.value),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: GizmoLook.of(context)
                                .ink
                                .withValues(alpha: 0.35),
                            width: 3,
                          ),
                        ),
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
      return grid + _offscreen(grid, layout, board) * slide;
    }
    if (phase == _Phase.incorrect && tapped != null) {
      final target = layout.pairSlot(index == originalIndex ? 0 : 1);
      return Offset.lerp(grid, target, settle)!;
    }
    final arrived =
        Curves.easeOutCubic.transform(enter.value.clamp(0.0, 1.0));
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

  /// The side-by-side comparison shrinks when two full cells would leave the board.
  double get pairCell => math.min(cell, (board.width - pairGap) / 2);

  Offset pairSlot(int place) {
    final shown = pairCell;
    final pairWidth = shown * 2 + pairGap;
    final y = math.max(0.0, (board.height - _compareFooter - shown) / 2);
    return Offset(
      (board.width - pairWidth) / 2 + place * (shown + pairGap),
      y,
    );
  }
}

const _boardMargin = 14.0;

/// Inset used only to pick the icon size. Half of the old edge margin stays
/// for placement, and this keeps each icon the size it had at 28 points.
const _sizeMargin = 28.0;
const _choiceGap = 12.0;

/// Highest choice count. Every level uses a cell this full set can still pack.
const _fullChoices = 8;

/// One size for every level. The roomy early-game cell, capped so eight
/// pictures still clear one another. The count on screen does not change it.
double _iconSize(Size board) {
  final roomy = _roomySize(board);
  final packed = _maxPackedCell(board, _fullChoices);
  return math.min(roomy, packed);
}

/// Half again the roomy estimate for a three-choice board.
double _roomySize(Size board) {
  final innerW = math.max(0.0, board.width - _sizeMargin * 2);
  final innerH = math.max(0.0, board.height - _sizeMargin * 2);
  const columns = 2;
  const rows = 3;
  const count = 3;
  final widthBudget = innerW - _choiceGap * (columns - 1);
  final heightBudget = innerH - _choiceGap * (rows - 1);
  final cap = math.min(widthBudget / columns, heightBudget / rows);
  final fromArea = math.sqrt(0.36 * innerW * innerH / count) - _choiceGap;
  final grown = math.max(48.0, math.min(cap, fromArea)) * 1.5;
  return math.min(grown, _largestFit(innerW, innerH, count));
}

/// Largest cell whose ink circles pack [count] icons inside the edge margin.
double _maxPackedCell(Size board, int count) {
  final innerW = math.max(0.0, board.width - _boardMargin * 2);
  final innerH = math.max(0.0, board.height - _boardMargin * 2);
  var best = 48.0;
  for (var columns = 1; columns <= count; columns++) {
    final rows = (count + columns - 1) ~/ columns;
    final cell = math.min(
      _axisCell(innerW, columns),
      _axisCell(innerH, rows),
    );
    if (cell > best) best = cell;
  }
  return best;
}

/// Largest cell for [slots] along one side. Ink stops 1px inside the cell,
/// and neighboring ink stays [_choiceGap] apart.
double _axisCell(double inner, int slots) {
  if (slots <= 1) return inner;
  final span = slots - 1;
  return (inner - span * (_choiceGap - 2)) / slots;
}

/// Largest cell that can pack [count] icons inside the inner board.
double _largestFit(double innerW, double innerH, int count) {
  var best = 48.0;
  for (var columns = 1; columns <= count; columns++) {
    final rows = (count + columns - 1) ~/ columns;
    final cellW = (innerW - _choiceGap * (columns - 1)) / columns;
    final cellH = (innerH - _choiceGap * (rows - 1)) / rows;
    final fit = math.min(cellW, cellH);
    if (fit > best) best = fit;
  }
  return best;
}

_ChoiceLayout _choiceLayout(
  Size board,
  int count,
  int seed, {
  double topInset = 0,
}) {
  final placed = _placeChoices(board, count, seed, topInset: topInset);
  return _ChoiceLayout(
    cell: placed.cell,
    slots: placed.slots,
    centered: List.filled(count, false),
    board: board,
    pairGap: math.max(_choiceGap, 24.0),
  );
}

/// Random spots for [count] icons at the shared cell size. A full set that
/// has no spare room lands on a jittered grid of the same size.
({double cell, List<Offset> slots}) _placeChoices(
  Size board,
  int count,
  int seed, {
  double topInset = 0,
}) {
  final cell = _iconSize(board);
  final minX = _boardMargin;
  final minY = _boardMargin + topInset;
  final maxX = math.max(minX, board.width - _boardMargin - cell);
  final maxY = math.max(minY, board.height - _boardMargin - cell);
  final need = math.max(0.0, cell - 2) + _choiceGap;
  final random = math.Random(seed);
  final slots = _scatter(count, minX, minY, maxX, maxY, need, random) ??
      _inkGrid(count, minX, minY, maxX, maxY, need, random);
  return (cell: cell, slots: slots);
}

/// Random spots inside the margins. Null when the ink circles have no spare room.
List<Offset>? _scatter(
  int count,
  double minX,
  double minY,
  double maxX,
  double maxY,
  double need,
  math.Random random,
) {
  if (maxX < minX || maxY < minY) return null;
  for (var restart = 0; restart < 80; restart++) {
    final slots = <Offset>[];
    var filled = true;
    for (var index = 0; index < count; index++) {
      var placed = false;
      for (var attempt = 0; attempt < 80; attempt++) {
        final candidate = Offset(
          minX + random.nextDouble() * (maxX - minX),
          minY + random.nextDouble() * (maxY - minY),
        );
        if (slots.every((other) => _circlesApart(candidate, other, need))) {
          slots.add(candidate);
          placed = true;
          break;
        }
      }
      if (!placed) {
        filled = false;
        break;
      }
    }
    if (filled) return slots;
  }
  return null;
}

/// Columns of ink circles at [need] apart, with leftover room used as jitter.
List<Offset> _inkGrid(
  int count,
  double minX,
  double minY,
  double maxX,
  double maxY,
  double need,
  math.Random random,
) {
  final spanX = math.max(0.0, maxX - minX);
  final spanY = math.max(0.0, maxY - minY);
  var columns = 1;
  var bestSlack = double.negativeInfinity;
  for (var cols = 1; cols <= count; cols++) {
    final rows = (count + cols - 1) ~/ cols;
    final slackX = spanX - (cols - 1) * need;
    final slackY = spanY - (rows - 1) * need;
    if (slackX < -0.5 || slackY < -0.5) continue;
    final slack = math.min(slackX, slackY);
    if (slack > bestSlack) {
      bestSlack = slack;
      columns = cols;
    }
  }
  final rows = (count + columns - 1) ~/ columns;
  final xs = _spread(columns, spanX, need, random);
  final ys = _spread(rows, spanY, need, random);
  final cells = [
    for (var row = 0; row < rows; row++)
      for (var col = 0; col < columns; col++)
        Offset(minX + xs[col], minY + ys[row]),
  ]..shuffle(random);
  return cells.take(count).toList();
}

List<double> _spread(int slots, double span, double pitch, math.Random random) {
  if (slots <= 1) {
    final slack = math.max(0.0, span);
    return [random.nextDouble() * slack];
  }
  final slack = span - (slots - 1) * pitch;
  if (slack <= 0) {
    final step = span / (slots - 1);
    return [for (var i = 0; i < slots; i++) step * i];
  }
  final weights = [
    for (var i = 0; i < slots + 1; i++) random.nextDouble() + 0.05,
  ];
  final sum = weights.fold(0.0, (total, weight) => total + weight);
  var cursor = 0.0;
  final positions = <double>[];
  for (var i = 0; i < slots; i++) {
    cursor += slack * weights[i] / sum;
    positions.add(cursor);
    cursor += pitch;
  }
  return positions;
}

bool _circlesApart(Offset a, Offset b, double need) {
  final dx = a.dx - b.dx;
  final dy = a.dy - b.dy;
  return dx * dx + dy * dy >= need * need;
}

Offset _offscreen(Offset slot, _ChoiceLayout layout, Size board) {
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
  if (!_animate) return Offset.zero;
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
    final diameter = _choiceDiameter(size);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconView(assembly: assembly, size: size),
          SizedBox.square(
            dimension: diameter,
            child: _CircleTap(
              onTap: onTap,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: chrome.ink.withValues(alpha: mark),
                    width: mark > 0 ? 3 : 0,
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Choice circle: 1px outside the ink, which is the cell edge.
double _choiceDiameter(double size) => size;

class _CircleTap extends SingleChildRenderObjectWidget {
  const _CircleTap({required this.onTap, required super.child});

  final VoidCallback? onTap;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderCircleTap(onTap);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderCircleTap renderObject) {
    renderObject.onTap = onTap;
  }
}

class _RenderCircleTap extends RenderProxyBox {
  _RenderCircleTap(this._onTap);

  VoidCallback? _onTap;
  TapGestureRecognizer? _tap;

  set onTap(VoidCallback? value) {
    if (value == _onTap) return;
    _onTap = value;
    _syncTap();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _syncTap();
  }

  @override
  void detach() {
    _tap?.dispose();
    _tap = null;
    super.detach();
  }

  void _syncTap() {
    if (!attached) return;
    if (_onTap == null) {
      _tap?.dispose();
      _tap = null;
      return;
    }
    _tap ??= TapGestureRecognizer(debugOwner: this);
    _tap!.onTap = _onTap;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final center = size.center(Offset.zero);
    if ((position - center).distance > size.shortestSide / 2) return false;
    hitTestChildren(result, position: position);
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) _tap?.addPointer(event);
  }
}

class _Cue extends StatelessWidget {
  const _Cue({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: GizmoLook.of(context).ink,
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
