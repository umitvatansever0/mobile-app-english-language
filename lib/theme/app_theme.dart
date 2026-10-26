import 'package:flutter/material.dart';

/// "Turkuaz Yolculuk" renk paleti.
/// Doğru/yanlış renkleri DeutschStep (weblearningapp) ile aynı aileden: zümrüt / gül.
class AppColors {
  static const teal = Color(0xFF0E9F94);
  static const tealDeep = Color(0xFF0B6E69);
  static const tealSoft = Color(0xFFD5F1EE);
  static const sun = Color(0xFFFFC845);
  static const sunDeep = Color(0xFFE0A800);
  static const sunInk = Color(0xFF6B4300);
  static const emerald = Color(0xFF10B981);
  static const emeraldDeep = Color(0xFF0A8F63);
  static const emeraldBg = Color(0xFFE7FBF2);
  static const rose = Color(0xFFE5484D);
  static const roseDeep = Color(0xFFB8333A);
  static const roseBg = Color(0xFFFFF0F1);
  static const ink = Color(0xFF1D2B36);

  // Eski adlar (bazı ekranlar hâlâ kullanıyor)
  static const primary = teal;
  static const primaryDark = tealDeep;
  static const accent = teal;
  static const success = emerald;
  static const danger = rose;
  static const warning = Color(0xFFEA7A00);
  static const streakBg = sun;
  static const lilac = tealSoft;
}

/// Açık/koyu temaya göre değişen yüzey renkleri.
class Pal {
  const Pal._(this.dark);
  final bool dark;

  static Pal of(BuildContext context) => Pal._(Theme.of(context).brightness == Brightness.dark);

  Color get bg => dark ? const Color(0xFF0D1B1C) : const Color(0xFFF3FAF8);
  Color get card => dark ? const Color(0xFF16292A) : Colors.white;
  Color get border => dark ? const Color(0xFF274442) : const Color(0xFFDDEBE8);
  Color get ink => dark ? const Color(0xFFE9F4F2) : AppColors.ink;
  Color get muted => dark ? const Color(0xFF8FA6A3) : const Color(0xFF6B7C80);
  Color get track => dark ? const Color(0xFF213937) : const Color(0xFFE1ECEA);
  Color get lockBg => dark ? const Color(0xFF1E3332) : const Color(0xFFE3ECEA);
  Color get lockLip => dark ? const Color(0xFF142625) : const Color(0xFFCCDAD7);
  Color get lockInk => dark ? const Color(0xFF5E7774) : const Color(0xFF9AABA8);
  Color get okBg => dark ? const Color(0xFF0F2E24) : AppColors.emeraldBg;
  Color get okInk => dark ? const Color(0xFF7FE3BA) : const Color(0xFF07875C);
  Color get badBg => dark ? const Color(0xFF3A1A1D) : AppColors.roseBg;
  Color get badInk => dark ? const Color(0xFFFF9EA2) : AppColors.roseDeep;
}

class AppTheme {
  static const font = 'Nunito';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final pal = Pal._(b == Brightness.dark);
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: b,
      primary: AppColors.teal,
      onPrimary: Colors.white,
      secondary: AppColors.sun,
      surface: pal.card,
      onSurface: pal.ink,
      onSurfaceVariant: pal.muted,
      outlineVariant: pal.border,
      error: AppColors.rose,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b, fontFamily: font);
    final text = base.textTheme.apply(fontFamily: font, bodyColor: pal.ink, displayColor: pal.ink);
    return base.copyWith(
      scaffoldBackgroundColor: pal.bg,
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        bodyLarge: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: pal.bg,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: pal.ink,
        titleTextStyle: const TextStyle(fontFamily: font, fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.tealDeep)
            .copyWith(color: pal.dark ? AppColors.sun : AppColors.tealDeep),
      ),
      cardTheme: CardThemeData(
        color: pal.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: pal.border, width: 2)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontFamily: font, fontSize: 17, fontWeight: FontWeight.w900),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          foregroundColor: pal.dark ? pal.ink : AppColors.tealDeep,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          side: BorderSide(color: pal.border, width: 3),
          textStyle: const TextStyle(fontFamily: font, fontSize: 17, fontWeight: FontWeight.w900),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: pal.dark ? AppColors.sun : AppColors.tealDeep,
          textStyle: const TextStyle(fontFamily: font, fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pal.card,
        labelStyle: TextStyle(color: pal.muted, fontWeight: FontWeight.w700),
        floatingLabelStyle: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w800),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: pal.border, width: 3),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.teal, width: 3),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: pal.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: pal.dark ? const Color(0xFF1C3A38) : AppColors.tealSoft,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? AppColors.teal : pal.lockInk, size: 26)),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontFamily: font,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: s.contains(WidgetState.selected) ? AppColors.teal : pal.lockInk,
            )),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: pal.border, width: 2),
        backgroundColor: pal.card,
        selectedColor: AppColors.tealSoft,
        labelStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w800, color: pal.ink),
        secondaryLabelStyle: const TextStyle(fontFamily: font, fontWeight: FontWeight.w800, color: AppColors.tealDeep),
        checkmarkColor: AppColors.tealDeep,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.tealSoft,
          selectedForegroundColor: AppColors.tealDeep,
          side: BorderSide(color: pal.border, width: 2),
          textStyle: const TextStyle(fontFamily: font, fontWeight: FontWeight.w800),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.teal : null),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.teal),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentTextStyle: const TextStyle(fontFamily: font, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: pal.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        titleTextStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w900, fontSize: 22, color: pal.ink),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: pal.card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
    );
  }
}
