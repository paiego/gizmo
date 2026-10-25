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
    final mine = parsePlayerName(widget.playerName)?.key;
    return Scaffold(
      backgroundColor: boardColor,
      appBar: AppBar(
        backgroundColor: boardColor,
        foregroundColor: inkColor,
        elevation: 0,
        title: const Text('Leaderboard'),
      ),
      body: _buildBody(mine),
    );
  }

  Widget _buildBody(String? mine) {
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: mutedColor)),
      );
    }
    final entries = _entries;
    if (entries == null) {
      return const Center(child: CircularProgressIndicator(color: inkColor));
    }
    if (entries.isEmpty) {
      return const Center(
        child: Text('No scores yet.', style: TextStyle(color: mutedColor)),
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
            color: marked ? const Color(0xFFE2E2E2) : paperColor,
            borderRadius: BorderRadius.circular(12),
            border: marked
                ? const Border(left: BorderSide(color: inkColor, width: 4))
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '${entry.rank}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: Text(
                  entry.playerName,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              Text(
                '${entry.bestScore}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
