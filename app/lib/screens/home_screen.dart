import 'package:flutter/material.dart';
import 'package:gizmo_rules/gizmo_rules.dart';

import '../api/gizmo_client.dart';
import '../name_store.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/gizmo_button.dart';
import 'leaderboard_screen.dart';
import 'name_screen.dart';
import 'play_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.playerName,
    required this.client,
    required this.names,
    required this.palette,
    required this.onPlayerName,
    required this.onPalette,
  });

  final String playerName;
  final GizmoClient client;
  final NameStore names;
  final IconPalette palette;
  final ValueChanged<String> onPlayerName;
  final ValueChanged<IconPalette> onPalette;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  PlayerSummary? _summary;
  String? _error;
  var _loading = true;
  var _subscribed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subscribed) return;
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      gizmoRouteObserver.subscribe(this, route);
      _subscribed = true;
    }
  }

  @override
  void dispose() {
    gizmoRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await widget.client.fetchBest(widget.playerName);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _summary = null;
        _loading = false;
        _error = 'The scoreboard is unreachable.';
      });
    }
  }

  Future<void> _changeName() async {
    final next = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => NameScreen(
          initialName: widget.playerName,
          popOnSave: true,
          onSubmit: widget.names.write,
        ),
      ),
    );
    if (next != null && next != widget.playerName) {
      widget.onPlayerName(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final best = _summary?.bestScore;
    final runs = _summary?.runCount;
    return Scaffold(
      backgroundColor: boardColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gizmo',
                style: TextStyle(fontSize: 16, color: mutedColor),
              ),
              const SizedBox(height: 4),
              Text(
                widget.playerName,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  _Stat(
                    label: 'Best',
                    value: _loading
                        ? '…'
                        : best == null
                            ? '—'
                            : '$best',
                  ),
                  const SizedBox(width: 12),
                  _Stat(
                    label: 'Runs',
                    value: _loading
                        ? '…'
                        : runs == null
                            ? '—'
                            : '$runs',
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: mutedColor)),
              ],
              const Spacer(),
              const Text(
                'Colors',
                style: TextStyle(fontSize: 16, color: mutedColor),
              ),
              const SizedBox(height: 8),
              _PalettePicker(
                selected: widget.palette,
                onSelected: widget.onPalette,
              ),
              const SizedBox(height: 16),
              GizmoButton(
                label: 'Play',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PlayScreen(playerName: widget.playerName),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              GizmoButton(
                label: 'Leaderboard',
                filled: false,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LeaderboardScreen(
                        playerName: widget.playerName,
                        client: widget.client,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              GizmoButton(
                label: 'Change name',
                filled: false,
                onPressed: _changeName,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PalettePicker extends StatelessWidget {
  const _PalettePicker({required this.selected, required this.onSelected});

  final IconPalette selected;
  final ValueChanged<IconPalette> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < iconPalettes.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _PaletteChoice(
              palette: iconPalettes[i],
              selected: iconPalettes[i] == selected,
              onSelected: onSelected,
            ),
          ),
        ],
      ],
    );
  }
}

class _PaletteChoice extends StatelessWidget {
  const _PaletteChoice({
    required this.palette,
    required this.selected,
    required this.onSelected,
  });

  final IconPalette palette;
  final bool selected;
  final ValueChanged<IconPalette> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: palette.label,
      child: InkWell(
        onTap: () => onSelected(palette),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          key: ValueKey('palette-${palette.id}'),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? inkColor : const Color(0xFFD5D5D5),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 16,
                  child: Row(
                    children: [
                      for (final color in colorRing)
                        Expanded(
                          child: ColoredBox(
                            color: Color(palette.values[color]!),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                palette.label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? inkColor : mutedColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: paperColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: mutedColor)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
