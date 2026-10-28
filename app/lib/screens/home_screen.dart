import 'package:flutter/material.dart';

import '../account/account.dart';
import '../account/account_repository.dart';
import '../account/profile_pictures.dart';
import '../api/gizmo_client.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/gizmo_button.dart';
import 'leaderboard_screen.dart';
import 'play_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.account,
    required this.client,
    required this.repository,
    required this.onAccount,
  });

  final GizmoAccount account;
  final GizmoClient client;
  final AccountRepository repository;
  final ValueChanged<GizmoAccount> onAccount;

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
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account.username != widget.account.username) {
      _load();
    }
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
      final summary = await widget.client.fetchBest(widget.account.username!);
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

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          account: widget.account,
          repository: widget.repository,
          onAccount: widget.onAccount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final look = GizmoLook.of(context);
    final picture = pictureById(widget.account.pictureId);
    final best = _summary?.bestScore;
    final runs = _summary?.runCount;
    return Scaffold(
      backgroundColor: look.board,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 8, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Gizmo',
                      style: TextStyle(fontSize: 16, color: look.muted),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('open-profile'),
                    tooltip: 'Profile',
                    onPressed: _openProfile,
                    icon: Icon(Icons.settings, color: look.ink),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: picture.color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.account.username ?? '',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.6,
                          color: look.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
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
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(_error!, style: TextStyle(color: look.muted)),
                ),
              ],
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    GizmoButton(
                      label: 'Play',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PlayScreen(
                              playerName: widget.account.username!,
                              adminMode: widget.account.playingAdmin,
                            ),
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
                              playerName: widget.account.username!,
                              client: widget.client,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
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
    final look = GizmoLook.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: look.paper,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: look.muted)),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: look.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
