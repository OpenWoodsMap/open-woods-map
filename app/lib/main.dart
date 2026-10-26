import 'package:flutter/material.dart';

import 'map/map_shell.dart';
import 'settings/coordinate_format.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OpenWoodsMapApp());
}

class OpenWoodsMapApp extends StatefulWidget {
  const OpenWoodsMapApp({super.key});

  @override
  State<OpenWoodsMapApp> createState() => _OpenWoodsMapAppState();
}

class _OpenWoodsMapAppState extends State<OpenWoodsMapApp> {
  final _coordinateFormat = ValueNotifier(CoordinateFormat.fallback);

  @override
  void initState() {
    super.initState();
    CoordinateFormatScope.load().then((format) {
      if (mounted) _coordinateFormat.value = format;
    });
  }

  @override
  void dispose() {
    _coordinateFormat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const forest = Color(0xFF1B4332);
    const cream = Color(0xFFFFFBF0);
    final scheme = ColorScheme.fromSeed(
      seedColor: forest,
      brightness: Brightness.light,
      surface: cream,
    ).copyWith(
      primary: forest,
      secondary: const Color(0xFF52796F),
      surface: cream,
    );
    return MaterialApp(
      title: 'OpenWoodsMap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: cream,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: forest,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFFFFFDF7),
          elevation: 1,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(),
        ),
      ),
      builder: (context, child) => CoordinateFormatScope(
        notifier: _coordinateFormat,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const MapShell(),
    );
  }
}
