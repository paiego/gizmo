import 'package:flutter/material.dart';
import 'package:gizmo_rules/gizmo_rules.dart';

import '../api/gizmo_client.dart';
import '../theme.dart';
import '../widgets/gizmo_button.dart';
import 'leaderboard_screen.dart';
import 'play_screen.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.playerName,
    required this.transcript,
    this.client,
  });

  final String playerName;
  final SubmittedRun transcript;
  final GizmoClient? client;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  SavedRun? _saved;
  String? _error;
  var _settled = false;
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _submit();
  }

  GizmoClient get _client => widget.client ?? GizmoScope.of(context).client;

  Future<void> _submit() async {
    try {
      final saved = await _client.submitRun(widget.transcript);
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _settled = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not save this run.';
        _settled = true;
      });
    }
  }

  void _home() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final saved = _saved;
    return PopScope(
      canPop: _settled,
      child: Scaffold(
        backgroundColor: boardColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Score',
                  style: TextStyle(fontSize: 16, color: mutedColor),
                ),
                Text(
                  '${widget.transcript.score}',
                  style: const TextStyle(
                    fontSize: 72,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 16),
                if (!_settled)
                  const Text('Saving…', style: TextStyle(color: mutedColor))
                else if (_error != null)
                  Text(_error!, style: const TextStyle(color: mutedColor))
                else if (saved != null) ...[
                  if (saved.isNewPersonalBest)
                    const Text(
                      'New personal best',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (saved.isNewPersonalBest) const SizedBox(height: 6),
                  Text(
                    'Rank ${saved.rank}',
                    style: const TextStyle(fontSize: 18, color: mutedColor),
                  ),
                ],
                const Spacer(),
                GizmoButton(
                  label: 'Play again',
                  onPressed: _settled
                      ? () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PlayScreen(playerName: widget.playerName),
                            ),
                          );
                        }
                      : null,
                ),
                const SizedBox(height: 12),
                GizmoButton(
                  label: 'Leaderboard',
                  filled: false,
                  onPressed: _settled
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LeaderboardScreen(
                                playerName: widget.playerName,
                                client: _client,
                              ),
                            ),
                          );
                        }
                      : null,
                ),
                const SizedBox(height: 12),
                GizmoButton(
                  label: 'Home',
                  filled: false,
                  onPressed: _settled ? _home : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GizmoScope extends InheritedWidget {
  const GizmoScope({super.key, required this.client, required super.child});

  final GizmoClient client;

  static GizmoScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GizmoScope>();
    assert(scope != null, 'GizmoScope is missing.');
    return scope!;
  }

  @override
  bool updateShouldNotify(GizmoScope oldWidget) => client != oldWidget.client;
}
