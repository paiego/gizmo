import 'package:flutter/material.dart';
import 'package:gizmo_rules/gizmo_rules.dart';

import '../account/account.dart';
import '../account/account_repository.dart';
import '../account/firebase_auth.dart';
import '../account/profile_pictures.dart';
import '../theme.dart';
import '../widgets/gizmo_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.account,
    required this.repository,
    required this.onAccount,
  });

  final GizmoAccount account;
  final AccountRepository repository;
  final ValueChanged<GizmoAccount> onAccount;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _username;
  late GizmoAccount _account;
  String? _nameError;
  String? _signInError;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _account = widget.account;
    _username = TextEditingController(text: _account.username ?? '');
  }

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _apply(GizmoAccount next) async {
    await widget.repository.save(next);
    if (!mounted) return;
    setState(() => _account = next);
    widget.onAccount(next);
  }

  Future<void> _saveUsername() async {
    final parsed = parsePlayerName(_username.text);
    if (parsed == null) {
      setState(() {
        _nameError = 'Use 1–20 letters, digits, or spaces.';
      });
      return;
    }
    setState(() => _nameError = null);
    await _apply(_account.copyWith(username: parsed.display));
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _signInError = null;
    });
    try {
      final next = await widget.repository.signIn(_account);
      if (!mounted) return;
      setState(() => _account = next);
      widget.onAccount(next);
    } on GoogleSignInCanceled catch (error) {
      if (!mounted) return;
      setState(() => _signInError = error.toString());
    } catch (error) {
      if (!mounted) return;
      setState(() => _signInError = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    final next = await widget.repository.signOut(_account);
    if (!mounted) return;
    setState(() {
      _account = next;
      _signInError = null;
    });
    widget.onAccount(next);
  }

  @override
  Widget build(BuildContext context) {
    final look = GizmoLook.of(context);
    return Scaffold(
      backgroundColor: look.board,
      appBar: AppBar(
        backgroundColor: look.board,
        foregroundColor: look.ink,
        elevation: 0,
        title: const Text('Profile'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Text(
              _account.signedIn ? 'Signed in' : 'Not signed in',
              style: TextStyle(color: look.muted),
            ),
            const SizedBox(height: 4),
            Text(
              _account.signedIn ? _account.firebaseId! : 'No Firebase id yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: look.ink,
              ),
            ),
            const SizedBox(height: 20),
            Text('Picture', style: TextStyle(color: look.muted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final picture in profilePictures)
                  _PictureChoice(
                    picture: picture,
                    selected: picture.id == _account.pictureId,
                    onSelected: () => _apply(
                      _account.copyWith(pictureId: picture.id),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Username', style: TextStyle(color: look.muted)),
            const SizedBox(height: 8),
            TextField(
              controller: _username,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              maxLength: 20,
              onSubmitted: (_) => _saveUsername(),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: look.paper,
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: 8),
            GizmoButton(
              label: 'Save username',
              filled: false,
              onPressed: _saveUsername,
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Admin'),
              subtitle: Text(
                'Allows admin mode. This does not check a server.',
                style: TextStyle(color: look.muted),
              ),
              value: _account.admin,
              activeThumbColor: look.ink,
              onChanged: (value) {
                _apply(
                  _account.copyWith(
                    admin: value,
                    adminMode: value && _account.adminMode,
                  ),
                );
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Admin mode'),
              subtitle: Text(
                'Keep playing after misses so later rounds stay on screen.',
                style: TextStyle(color: look.muted),
              ),
              value: _account.playingAdmin,
              activeThumbColor: look.ink,
              onChanged: _account.admin
                  ? (value) => _apply(_account.copyWith(adminMode: value))
                  : null,
            ),
            const SizedBox(height: 12),
            Text('Theme', style: TextStyle(fontSize: 16, color: look.muted)),
            const SizedBox(height: 8),
            _ThemePicker(
              selectedId: _account.themeId,
              onSelected: (look) => _apply(_account.copyWith(themeId: look.id)),
            ),
            if (_signInError != null) ...[
              const SizedBox(height: 16),
              Text(
                'Could not sign in.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: look.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(_signInError!, style: TextStyle(color: look.muted)),
            ],
            const SizedBox(height: 20),
            GizmoButton(
              label: _busy ? 'Signing in…' : 'Sign in',
              onPressed: _busy ? null : _signIn,
            ),
            const SizedBox(height: 12),
            GizmoButton(
              label: 'Sign out',
              filled: false,
              onPressed: _account.signedIn ? _signOut : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PictureChoice extends StatelessWidget {
  const _PictureChoice({
    required this.picture,
    required this.selected,
    required this.onSelected,
  });

  final ProfilePicture picture;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final look = GizmoLook.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: picture.label,
      child: InkWell(
        onTap: onSelected,
        customBorder: const CircleBorder(),
        child: Container(
          key: ValueKey('picture-${picture.id}'),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: picture.color,
            border: Border.all(
              color: selected ? look.ink : look.line,
              width: selected ? 3 : 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.selectedId, required this.onSelected});

  final String selectedId;
  final ValueChanged<GizmoLook> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < gizmoLooks.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _ThemeChoice(
              look: gizmoLooks[i],
              selected: gizmoLooks[i].id == selectedId,
              onSelected: onSelected,
            ),
          ),
        ],
      ],
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.look,
    required this.selected,
    required this.onSelected,
  });

  final GizmoLook look;
  final bool selected;
  final ValueChanged<GizmoLook> onSelected;

  @override
  Widget build(BuildContext context) {
    final chrome = GizmoLook.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: look.label,
      child: InkWell(
        onTap: () => onSelected(look),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          key: ValueKey('palette-${look.id}'),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: look.board,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? chrome.ink : chrome.line,
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
                            color: Color(look.icons.values[color]!),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                look.label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? chrome.ink : chrome.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
