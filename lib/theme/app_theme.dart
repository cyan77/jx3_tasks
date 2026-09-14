import 'package:flutter/material.dart';

class AppTheme {
  static const ink = Color(0xff25313a);
  static const muted = Color(0xff7c8790);
  static const line = Color(0xffe6eaed);
  static const soft = Color(0xfff7f8f8);
  static const accent = Color(0xff4d7180);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
                seedColor: accent, brightness: Brightness.light)
            .copyWith(primary: accent, surface: Colors.white),
        fontFamily: 'Arial',
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: ink,
              height: 1.2),
          titleLarge:
              TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
          titleMedium:
              TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ink),
          bodyLarge: TextStyle(fontSize: 14, color: ink),
          bodyMedium: TextStyle(fontSize: 13, color: ink),
          labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: soft,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: line)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: line)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: accent, width: 1.2)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          isDense: true,
        ),
        dividerTheme:
            const DividerThemeData(color: line, space: 1, thickness: 1),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          titleSpacing: 24,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: const NavigationBarThemeData(
            height: 62,
            labelTextStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            indicatorColor: Color(0xffe4f0ee)),
        chipTheme: ChipThemeData(
            backgroundColor: soft,
            side: const BorderSide(color: line),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            labelStyle: const TextStyle(fontSize: 12, color: ink)),
      );

  static ThemeData get dark {
    const darkSurface = Color(0xff171d1f);
    const darkRaised = Color(0xff20282b);
    const darkLine = Color(0xff354044);
    const darkText = Color(0xffe5ebec);
    const darkMuted = Color(0xffa7b2b5);
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: darkSurface,
    ).copyWith(
      primary: const Color(0xff72b9ad),
      surface: darkSurface,
      surfaceContainerLow: darkRaised,
      surfaceContainer: darkRaised,
      outlineVariant: darkLine,
      onSurface: darkText,
      onSurfaceVariant: darkMuted,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkSurface,
      colorScheme: scheme,
      fontFamily: 'Arial',
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: darkText,
            height: 1.2),
        titleLarge: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700, color: darkText),
        titleMedium: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, color: darkText),
        bodyLarge: TextStyle(fontSize: 14, color: darkText),
        bodyMedium: TextStyle(fontSize: 13, color: darkText),
        labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: darkLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: darkLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: Color(0xff72b9ad), width: 1.2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        isDense: true,
      ),
      dividerTheme:
          const DividerThemeData(color: darkLine, space: 1, thickness: 1),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        titleSpacing: 24,
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 62,
        backgroundColor: darkRaised,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        indicatorColor: Color(0xff29433f),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkRaised,
        side: const BorderSide(color: darkLine),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        labelStyle: const TextStyle(fontSize: 12, color: darkText),
      ),
      cardColor: darkRaised,
      dialogTheme: const DialogThemeData(backgroundColor: darkRaised),
    );
  }
}
