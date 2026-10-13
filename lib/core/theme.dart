import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFFD33A31); // 网易云红
  static const bg = Color(0xFF141518);
  static const card = Color(0xFF1F2025);
  static const divider = Color(0xFF2A2B31);
  static const textSecondary = Color(0xFF9A9BA0);
}

/// 默认深色 M3 配色（网易云红品牌色；动态取色不可用或关闭时使用）
const _defaultDarkScheme = ColorScheme.dark(
  primary: AppColors.primary,
  onPrimary: Colors.white,
  primaryContainer: Color(0xFF7A231D),
  onPrimaryContainer: Color(0xFFFFDAD6),
  surface: AppColors.bg,
  surfaceContainerLowest: Color(0xFF0E0F12),
  surfaceContainerLow: AppColors.bg,
  surfaceContainer: Color(0xFF1B1C21),
  surfaceContainerHigh: Color(0xFF232429),
  surfaceContainerHighest: AppColors.divider,
);

/// 构建深色 M3 主题。
/// [dynamicScheme] 为系统动态取色（Android 12+ 壁纸取色），提供时优先使用。
ThemeData buildTheme({ColorScheme? dynamicScheme}) {
  // M3 tonal 配色（参考 Border-Player 的质感风格： tonal 容器 + 大圆角）
  final scheme = dynamicScheme ?? _defaultDarkScheme;
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: scheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.bg,
      elevation: 8,
      indicatorColor: scheme.primary.withValues(alpha: 0.25),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          color: selected ? scheme.primary : Colors.grey,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? scheme.primary : Colors.grey);
      }),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.card,
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 0.5,
      space: 0,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: Colors.white24,
      thumbColor: AppColors.primary,
      overlayColor: AppColors.primary.withValues(alpha: 0.2),
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
