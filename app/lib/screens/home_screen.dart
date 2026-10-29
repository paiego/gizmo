import 'package:flutter/material.dart';

import '../account/account.dart';
import '../account/account_repository.dart';
import '../account/firebase_auth.dart';
import '../account/local_score.dart';
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
    this.scores = const LocalScoreStore(),
  });

  final GizmoAccount account;
  final GizmoClient client;
  final AccountRepository repository;
  final ValueChanged<GizmoAccount> onAccount;
  final LocalScoreStore scores;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  PlayerSummary? _summary;
  String? _error;
  String? _playError;
  var _loading = true;
  var _starting = false;
  var _subscribed = false;
  var _localBest = false;

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
      _localBest = false;
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
      final id = widget.account.firebaseId;
      final local =
          id == null || id.isEmpty ? null : await widget.scores.read(id);
      if (!mounted) return;
      setState(() {
        _summary = local == null
            ? null
            : PlayerSummary(
                playerName: widget.account.username!,
                bestScore: local.best,
                runCount: local.runs,
              );
        _localBest = local != null;
        _loading = false;
        _error = local == null ? 'The scoreboard is unreachable.' : null;
      });
    }
  }

  Future<void> _play() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _playError = null;
    });
    try {
      final ticket = await widget.repository.preparePlay(widget.account);
      if (!mounted) return;
      widget.onAccount(ticket.account);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayScreen(
            playerName: ticket.account.username!,
            adminMode: ticket.account.playingAdmin,
            userId: ticket.userId,
            localOnly: ticket.localOnly,
            scores: widget.scores,
          ),
        ),
      );
    } on PlayRequiresSignIn catch (error) {
      if (!mounted) return;
      setState(() => _playError = error.toString());
    } on GoogleSignInCanceled catch (error) {
      if (!mounted) return;
      setState(() => _playError = error.toString());
    } catch (error) {
      if (!mounted) return;
      setState(() => _playError = error.toString());
    } finally {
      if (mounted) setState(() => _starting = false);
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
              if (_error != null || _localBest) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    _localBest ? 'Saved on this device' : _error!,
                    style: TextStyle(color: look.muted),
                  ),
                ),
              ],
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    if (_playError != null) ...[
                      Text(
                        _playError!,
                        style: TextStyle(color: look.muted),
                      ),
                      const SizedBox(height: 12),
                    ],
                    GizmoButton(
                      label: 'Play',
                      onPressed: _starting ? null : _play,
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
