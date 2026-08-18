import 'package:flutter/material.dart';

abstract final class AppTypography {
  // Base font family - system default
  static const String? fontFamily = null;

  // General UI Typography
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 38 / 32,
    letterSpacing: -0.5,
  );

  static const TextStyle title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 30 / 24,
    letterSpacing: -0.3,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 26 / 20,
    letterSpacing: -0.2,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 28 / 18,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 25 / 16,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 25 / 16,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
  );

  static const TextStyle bodySmallMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 17 / 12,
    letterSpacing: 0.2,
  );

  // Editor Typography
  static const TextStyle editorTitle = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 36 / 30,
    letterSpacing: -0.5,
  );

  static const TextStyle editorH1 = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 33 / 26,
    letterSpacing: -0.3,
  );

  static const TextStyle editorH2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 29 / 22,
    letterSpacing: -0.2,
  );

  static const TextStyle editorH3 = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w600,
    height: 26 / 19,
  );

  static const TextStyle editorBody = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 29 / 18,
  );

  static const TextStyle editorQuote = TextStyle(
    fontSize: 18,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w400,
    height: 29 / 18,
  );

  static const TextStyle editorCode = TextStyle(
    fontSize: 15,
    fontFamily: 'monospace',
    fontWeight: FontWeight.w400,
    height: 23 / 15,
  );

  // Tag styling
  static const TextStyle tag = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 18 / 13,
    letterSpacing: 0.1,
  );
}
