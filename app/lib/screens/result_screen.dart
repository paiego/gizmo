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
    this.adminMode = false,
  });

  final String playerName;
  final SubmittedRun transcript;
  final GizmoClient? client;
  final bool adminMode;

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
    final look = GizmoLook.of(context);
    return PopScope(
      canPop: _settled,
      child: Scaffold(
        backgroundColor: look.board,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Score',
                  style: TextStyle(fontSize: 16, color: look.muted),
                ),
                Text(
                  '${widget.transcript.score}',
                  style: TextStyle(
                    fontSize: 72,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.5,
                    color: look.ink,
                  ),
                ),
                const SizedBox(height: 16),
                if (!_settled)
                  Text('Saving…', style: TextStyle(color: look.muted))
                else if (_error != null)
                  Text(_error!, style: TextStyle(color: look.muted))
                else if (saved != null) ...[
                  if (saved.isNewPersonalBest)
                    Text(
                      'New personal best',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: look.ink,
                      ),
                    ),
                  if (saved.isNewPersonalBest) const SizedBox(height: 6),
                  Text(
                    'Rank ${saved.rank}',
                    style: TextStyle(fontSize: 18, color: look.muted),
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
                              builder: (context) => PlayScreen(
                                playerName: widget.playerName,
                                adminMode: widget.adminMode,
                              ),
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
