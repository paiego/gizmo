import 'package:flutter/material.dart';
import 'package:gizmo_rules/gizmo_rules.dart';

import '../debug/icon_log_store.dart';
import '../theme.dart';

/// Hidden admin view of numeric icon vectors and decoded fields.
class IconLogScreen extends StatelessWidget {
  const IconLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final look = GizmoLook.of(context);
    final entries = IconLogStore.instance.entries.reversed.toList();
    return Scaffold(
      backgroundColor: look.board,
      appBar: AppBar(
        backgroundColor: look.board,
        foregroundColor: look.ink,
        elevation: 0,
        title: const Text('Icon log'),
        actions: [
          TextButton(
            onPressed: () {
              IconLogStore.instance.clear();
              Navigator.of(context).pop();
            },
            child: Text('Clear', style: TextStyle(color: look.muted)),
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Text(
                'No rounds logged yet. Play with Icon debug log enabled.',
                style: TextStyle(color: look.muted),
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                return _RoundCard(entry: entries[index]);
              },
            ),
    );
  }
}

class _RoundCard extends StatelessWidget {
  const _RoundCard({required this.entry});

  final IconRoundLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final look = GizmoLook.of(context);
    final baselineVec = encodeIconSnapshot(entry.baseline);
    final originalVec = encodeAssembly(entry.original);
    return Card(
      color: look.paper,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Level ${entry.level}'
              '${entry.incorrectTapIndex != null ? ' · miss tap #${entry.incorrectTapIndex}' : ''}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: look.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text('Baseline snapshot', style: TextStyle(color: look.muted)),
            Text(formatCodecVector(baselineVec),
                style: TextStyle(fontSize: 12, color: look.ink)),
            Text(describeIconSnapshot(entry.baseline),
                style: TextStyle(fontSize: 12, color: look.muted)),
            const SizedBox(height: 6),
            Text('Original assembly', style: TextStyle(color: look.muted)),
            Text(formatCodecVector(originalVec),
                style: TextStyle(fontSize: 12, color: look.ink)),
            Text(describeAssembly(entry.original),
                style: TextStyle(fontSize: 12, color: look.muted)),
            const Divider(height: 20),
            for (final row in entry.choices) ...[
              _ChoiceRow(row: row),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.row});

  final IconChoiceLog row;

  @override
  Widget build(BuildContext context) {
    final look = GizmoLook.of(context);
    final choice = row.choice;
    final payload = encodeRoundChoicePayload(
      assembly: choice.assembly,
      appearance: choice.appearance,
      singleDiffKind: choice.singleDiffKind,
    );
    final labels = <String>[
      '#${row.boardIndex}',
      if (row.isBaselineAppearance) 'BASELINE',
      if (!row.isBaselineAppearance) 'decoy',
      if (choice.singleDiffKind != null)
        'Δ ${describeSingleDiffKind(choice.singleDiffKind)}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(labels.join(' · '),
            style: TextStyle(fontWeight: FontWeight.w500, color: look.ink)),
        Text(formatCodecVector(payload),
            style: TextStyle(fontSize: 11, color: look.ink)),
        Text(
          '${describeAssembly(choice.assembly)} → ${describeIconSnapshot(choice.appearance)}',
          style: TextStyle(fontSize: 11, color: look.muted),
        ),
      ],
    );
  }
}