import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  runApp(const PullTubeApp());
}

class PullTubeApp extends StatelessWidget {
  const PullTubeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PullTube',
      debugShowCheckedModeBanner: false,
      theme: PullTubeTheme.theme,
      home: const HomeScreen(),
    );
  }
}

abstract final class PullTubeTheme {
  static ThemeData get theme {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(
      base.textTheme,
    ).apply(bodyColor: Colors.white, displayColor: Colors.white);

    return base.copyWith(
      scaffoldBackgroundColor: PullTubeColors.background,
      colorScheme: const ColorScheme.dark(
        primary: PullTubeColors.videoAccent,
        secondary: PullTubeColors.audioAccent,
        surface: PullTubeColors.surface,
        onSurface: Colors.white,
        error: PullTubeColors.error,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PullTubeColors.surfaceSecondary,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: PullTubeColors.textMuted,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: PullTubeColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(
            color: PullTubeColors.videoAccent,
            width: 1.4,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: PullTubeColors.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: PullTubeColors.surfaceSecondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerColor: PullTubeColors.border,
    );
  }
}

abstract final class PullTubeColors {
  static const background = Color(0xFF0A0A0A);
  static const surface = Color(0xFF141414);
  static const surfaceSecondary = Color(0xFF1C1C1C);
  static const border = Color(0xFF2A2A2A);
  static const borderStrong = Color(0xFF353535);
  static const videoAccent = Color(0xFFFF2D2D);
  static const videoAccentDeep = Color(0xFFFF5A4A);
  static const audioAccent = Color(0xFFF3B24F);
  static const audioAccentDeep = Color(0xFFFFD06A);
  static const textMuted = Color(0xFF6C6C6C);
  static const textSecondary = Color(0xFFA1A1A1);
  static const success = Color(0xFF53D38A);
  static const error = Color(0xFFFF7B7B);
}
