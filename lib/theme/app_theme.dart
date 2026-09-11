import 'package:flutter/material.dart';

class AppTheme {
  static const ink = Color(0xff25313a);
  static const muted = Color(0xff7c8790);
  static const line = Color(0xffe6eaed);
  static const soft = Color(0xfff7f8f8);
  static const accent = Color(0xff2f7d72);

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
}
