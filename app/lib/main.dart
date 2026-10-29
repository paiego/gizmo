import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'account/account.dart';
import 'firebase_options.dart';
import 'account/account_repository.dart';
import 'api/gizmo_client.dart';
import 'name_store.dart';
import 'nav.dart';
import 'palette_scope.dart';
import 'palette_store.dart';
import 'screens/home_screen.dart';
import 'screens/name_screen.dart';
import 'screens/result_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const GizmoApp());
}

class GizmoApp extends StatefulWidget {
  const GizmoApp({
    super.key,
    this.client,
    this.names,
    this.palettes,
    this.accounts,
  });

  final GizmoClient? client;
  final NameStore? names;
  final PaletteStore? palettes;
  final AccountRepository? accounts;

  @override
  State<GizmoApp> createState() => _GizmoAppState();
}

class _GizmoAppState extends State<GizmoApp> {
  late final GizmoClient _client = widget.client ?? GizmoClient();
  late final AccountRepository _accounts = widget.accounts ??
      AccountRepository(names: widget.names, palettes: widget.palettes);
  GizmoAccount _account = const GizmoAccount();
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = await _accounts.read();
    if (!mounted) return;
    setState(() {
      _account = account;
      _ready = true;
    });
  }

  Future<void> _saveName(String name) async {
    final next = _account.copyWith(username: name);
    await _accounts.save(next);
    if (!mounted) return;
    setState(() => _account = next);
  }

  @override
  Widget build(BuildContext context) {
    final look = lookById(_account.themeId);
    final name = _account.username;
    return PaletteScope(
      palette: look.icons,
      child: GizmoScope(
        client: _client,
        child: MaterialApp(
          title: 'Gizmo',
          debugShowCheckedModeBanner: false,
          theme: buildGizmoTheme(look),
          navigatorObservers: [gizmoRouteObserver],
          home: !_ready
              ? Scaffold(backgroundColor: look.board)
              : name == null
                  ? NameScreen(onSubmit: _saveName)
                  : HomeScreen(
                      account: _account,
                      client: _client,
                      repository: _accounts,
                      onAccount: (value) => setState(() => _account = value),
                    ),
        ),
      ),
    );
  }
}
