import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFF7F9FC);
  static const ink = Color(0xFF1D2F4D);
  static const primary = Color(0xFF2463AA);
  static const yellow = Color(0xFFFFCB05);
  static const red = Color(0xFFE3350D);
  static const muted = Color(0xFF69788E);
  static const line = Color(0xFFE2E8F1);
  static const soft = Color(0xFFEDF2FA);
}

abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
      secondary: AppColors.yellow,
      onSecondary: AppColors.ink,
      tertiary: AppColors.red,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFFFECAA),
      onPrimaryContainer: const Color(0xFF193E73),
      surface: Colors.white,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      outline: const Color(0xFFB9C7DA),
      outlineVariant: AppColors.line,
      surfaceContainerHighest: AppColors.soft,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = base.textTheme
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink)
        .copyWith(
          displaySmall: const TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -1.2,
          ),
          headlineLarge: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: -0.8,
          ),
          headlineSmall: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.3,
            letterSpacing: -0.5,
          ),
          titleLarge: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            height: 1.35,
            letterSpacing: -0.5,
          ),
          titleMedium: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.4,
            letterSpacing: -0.2,
          ),
          titleSmall: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
          bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
          bodyMedium: const TextStyle(fontSize: 14, height: 1.5),
          labelLarge: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
          labelSmall: const TextStyle(
            fontSize: 11,
            color: AppColors.muted,
            height: 1.4,
          ),
        )
        .apply(
          fontFamily: 'Roboto',
          bodyColor: AppColors.ink,
          displayColor: AppColors.ink,
        );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.line),
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: text,
      dividerColor: AppColors.line,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 64,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleLarge,
        iconTheme: const IconThemeData(size: 23, color: AppColors.ink),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: border,
        enabledBorder: border,
        disabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
        floatingLabelStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: shape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: shape,
          side: const BorderSide(color: AppColors.line),
          foregroundColor: AppColors.ink,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: shape,
          textStyle: text.labelLarge,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: scheme.primaryContainer,
        side: const BorderSide(color: AppColors.line),
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: text.labelLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.muted,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: shape,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodyMedium?.copyWith(color: AppColors.muted),
        iconColor: AppColors.muted,
        minVerticalPadding: 12,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 24,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
    );
  }
}
