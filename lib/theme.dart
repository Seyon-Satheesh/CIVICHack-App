import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colours from the CivicSpeak mockups: soft blue / green / orange tabs, serif type, red pin.
class C {
  static const page = Color(0xFFE8E9EB);
  static const card = Color(0xFFEDF4F7);
  static const ink = Color(0xFF1D1F22);
  static const muted = Color(0xFF56616B);
  static const mutedStrong = Color(0xFF2C343B); // used in audio mode for stronger contrast
  static const line = Color(0xFFDBE3E8);

  static const blue = Color(0xFFB9DCF3);
  static const blueSoft = Color(0xFFE3F1F8);
  static const blueLine = Color(0xFFC6E1F1);
  static const green = Color(0xFFA9DCC0);
  static const greenSoft = Color(0xFFE2F1EA);
  static const greenLine = Color(0xFFBFE3CF);
  static const orange = Color(0xFFF6DFBD);
  static const orangeSoft = Color(0xFFF3EFE6);
  static const orangeLine = Color(0xFFECDCC2);
  static const purple = Color(0xFFD9D2EC);

  static const navy = Color(0xFF1D3B52);
  static const pin = Color(0xFFE5211F);
  static const focus = Color(0xFF1F5F8B);
  static const ok = Color(0xFF2F7A48);
  static const forYou = Color(0xFFFFF4D6);

  static const statusOngoing = Color(0xFF4F8FD6);
  static const statusCompleted = Color(0xFF3F9A5E);
  static const statusAbandoned = Color(0xFFC98A2B);
}

/// Tab colours, in order, like the mock (blue, green, orange, purple).
const tabColors = [C.blue, C.green, C.orange, C.purple];
const panelColors = [
  (C.blueSoft, C.blueLine),
  (C.greenSoft, C.greenLine),
  (C.orangeSoft, C.orangeLine),
];

ThemeData buildTheme({required bool highContrast}) {
  final serif = GoogleFonts.libreBaskervilleTextTheme();
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: C.navy, primary: C.navy, surface: Colors.white),
    scaffoldBackgroundColor: C.page,
    textTheme: serif.apply(bodyColor: C.ink, displayColor: C.ink),
  );
  return base.copyWith(
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCDD8DF))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: highContrast ? const Color(0xFF7D8A95) : const Color(0xFFCDD8DF))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.focus, width: 2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.navy,
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.ink,
        backgroundColor: Colors.white,
        minimumSize: const Size(44, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        side: const BorderSide(color: Color(0xFFCFD6DC)),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: C.focus)),
  );
}

TextStyle sans({double size = 12, FontWeight weight = FontWeight.w600, Color color = C.ink}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);
