import 'package:flutter/material.dart';
import 'package:gizmo_rules/gizmo_rules.dart';

import '../api/gizmo_client.dart';
import '../theme.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    required this.playerName,
    required this.client,
  });

  final String playerName;
  final GizmoClient client;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<BoardEntry>? _entries;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await widget.client.fetchLeaderboard();
      if (!mounted) return;
      setState(() => _entries = entries);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'The scoreboard is unreachable.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final look = GizmoLook.of(context);
    final mine = parsePlayerName(widget.playerName)?.key;
    return Scaffold(
      backgroundColor: look.board,
      appBar: AppBar(
        backgroundColor: look.board,
        foregroundColor: look.ink,
        elevation: 0,
        title: const Text('Leaderboard'),
      ),
      body: _buildBody(mine, look),
    );
  }

  Widget _buildBody(String? mine, GizmoLook look) {
    if (_error != null) {
      return Center(
        child: Text(_error!, style: TextStyle(color: look.muted)),
      );
    }
    final entries = _entries;
    if (entries == null) {
      return Center(child: CircularProgressIndicator(color: look.ink));
    }
    if (entries.isEmpty) {
      return Center(
        child: Text('No scores yet.', style: TextStyle(color: look.muted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: entries.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final marked =
            mine != null && parsePlayerName(entry.playerName)?.key == mine;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: marked ? look.line : look.paper,
            borderRadius: BorderRadius.circular(12),
            border: marked
                ? Border(left: BorderSide(color: look.ink, width: 4))
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '${entry.rank}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: look.ink,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  entry.playerName,
                  style: TextStyle(fontSize: 16, color: look.ink),
                ),
              ),
              Text(
                '${entry.bestScore}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: look.ink,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
