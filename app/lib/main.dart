import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gizmo_rules/gizmo_rules.dart';

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
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const GizmoApp());
}

class GizmoApp extends StatefulWidget {
  const GizmoApp({super.key, this.client, this.names, this.palettes});

  final GizmoClient? client;
  final NameStore? names;
  final PaletteStore? palettes;

  @override
  State<GizmoApp> createState() => _GizmoAppState();
}

class _GizmoAppState extends State<GizmoApp> {
  late final GizmoClient _client = widget.client ?? GizmoClient();
  late final NameStore _names = widget.names ?? NameStore();
  late final PaletteStore _palettes = widget.palettes ?? PaletteStore();
  String? _name;
  IconPalette _palette = warmPalette;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await _names.read();
    final paletteId = await _palettes.read();
    if (!mounted) return;
    setState(() {
      _name = name;
      _palette = paletteById(paletteId);
      _ready = true;
    });
  }

  Future<void> _save(String name) async {
    await _names.write(name);
    if (!mounted) return;
    setState(() => _name = name);
  }

  Future<void> _selectPalette(IconPalette palette) async {
    await _palettes.write(palette.id);
    if (!mounted) return;
    setState(() => _palette = palette);
  }

  @override
  Widget build(BuildContext context) {
    final name = _name;
    return PaletteScope(
      palette: _palette,
      child: GizmoScope(
        client: _client,
        child: MaterialApp(
          title: 'Gizmo',
          debugShowCheckedModeBanner: false,
          theme: buildGizmoTheme(),
          navigatorObservers: [gizmoRouteObserver],
          home: !_ready
              ? const Scaffold(backgroundColor: boardColor)
              : name == null
                  ? NameScreen(onSubmit: _save)
                  : HomeScreen(
                      playerName: name,
                      client: _client,
                      names: _names,
                      palette: _palette,
                      onPlayerName: (value) => setState(() => _name = value),
                      onPalette: _selectPalette,
                    ),
        ),
      ),
    );
  }
}
