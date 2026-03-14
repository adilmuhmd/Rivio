import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'screens/gateway_screen.dart';
import 'providers/media_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const ProviderScope(child: RivioApp()));
}

// ============================================================================
// MATERIAL 3 EXPRESSIVE THEME BUILDER
// ============================================================================
ThemeData buildExpressiveTheme(Color dynamicAccent) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: dynamicAccent,
      brightness: Brightness.dark,
      primary: dynamicAccent,
      surface: const Color(0xFF0F0F13),
      background: const Color(0xFF0F0F13),
      onPrimary: dynamicAccent.computeLuminance() > 0.5 ? Colors.black : Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFF0F0F13),
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displayLarge: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -2.0, height: 1.1),
      displayMedium: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1.0),
      headlineLarge: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
      titleLarge: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: dynamicAccent,
        foregroundColor: dynamicAccent.computeLuminance() > 0.5 ? Colors.black : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
        elevation: 12,
        shadowColor: dynamicAccent.withOpacity(0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

// ============================================================================
// MAIN APP COMPONENT
// ============================================================================
class RivioApp extends ConsumerWidget {
  const RivioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Now it safely reads from media_provider.dart
    final dynamicAccent = ref.watch(accentColorProvider);

    return MaterialApp(
      title: 'Rivio',
      theme: buildExpressiveTheme(dynamicAccent),
      home: const RivioGateway(),
      debugShowCheckedModeBanner: false,
    );
  }
}