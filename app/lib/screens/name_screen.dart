import 'package:flutter/material.dart';
import 'package:gizmo_rules/gizmo_rules.dart';

import '../theme.dart';
import '../widgets/gizmo_button.dart';

class NameScreen extends StatefulWidget {
  const NameScreen({
    super.key,
    this.initialName,
    required this.onSubmit,
    this.popOnSave = false,
  });

  final String? initialName;
  final Future<void> Function(String name) onSubmit;
  final bool popOnSave;

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  late final TextEditingController _controller;
  String? _error;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final parsed = parsePlayerName(_controller.text);
    if (parsed == null) {
      setState(() {
        _error = 'Use 1–20 letters, digits, or spaces.';
      });
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await widget.onSubmit(parsed.display);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted || !widget.popOnSave) return;
    Navigator.pop(context, parsed.display);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: boardColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gizmo',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.8,
                  color: inkColor,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'What should we call you?',
                style: TextStyle(fontSize: 18, color: mutedColor),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _controller,
                autofocus: widget.initialName == null,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                maxLength: 20,
                onSubmitted: (_) => _continue(),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Name',
                  errorText: _error,
                  filled: true,
                  fillColor: paperColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const Spacer(),
              GizmoButton(
                label: 'Continue',
                onPressed: _saving ? null : _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
