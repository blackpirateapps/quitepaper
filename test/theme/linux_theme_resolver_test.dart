import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/theme/linux_theme_resolver.dart';

void main() {
  group('LinuxThemeResolver Tests', () {
    test('resolves Brightness.dark when portal returns uint32 1', () async {
      final resolver = LinuxThemeResolver(
        processRunner: (executable, arguments) async {
          if (executable == 'gdbus') {
            return ProcessResult(0, 0, '(<<uint32 1>>,)\n', '');
          }
          return ProcessResult(1, 1, '', 'not found');
        },
      );

      final brightness = await resolver.resolveBrightness();
      expect(brightness, Brightness.dark);
    });

    test('resolves Brightness.light when portal returns uint32 2 (prefer-light)', () async {
      final resolver = LinuxThemeResolver(
        processRunner: (executable, arguments) async {
          if (executable == 'gdbus') {
            return ProcessResult(0, 0, '(<<uint32 2>>,)\n', '');
          }
          return ProcessResult(1, 1, '', 'not found');
        },
      );

      final brightness = await resolver.resolveBrightness();
      expect(brightness, Brightness.light);
    });

    test('resolves Brightness.light when portal returns uint32 0 (no preference)', () async {
      final resolver = LinuxThemeResolver(
        processRunner: (executable, arguments) async {
          if (executable == 'gdbus') {
            return ProcessResult(0, 0, '(<<uint32 0>>,)\n', '');
          }
          return ProcessResult(1, 1, '', 'not found');
        },
      );

      final brightness = await resolver.resolveBrightness();
      expect(brightness, Brightness.light);
    });

    test('falls back to gsettings when portal fails with prefer-dark', () async {
      final resolver = LinuxThemeResolver(
        processRunner: (executable, arguments) async {
          if (executable == 'gdbus') {
            return ProcessResult(1, 1, '', 'portal error');
          }
          if (executable == 'gsettings') {
            return ProcessResult(0, 0, "'prefer-dark'\n", '');
          }
          return ProcessResult(1, 1, '', 'not found');
        },
      );

      final brightness = await resolver.resolveBrightness();
      expect(brightness, Brightness.dark);
    });

    test('falls back to gsettings when portal fails with default/light', () async {
      final resolver = LinuxThemeResolver(
        processRunner: (executable, arguments) async {
          if (executable == 'gdbus') {
            return ProcessResult(1, 1, '', 'portal error');
          }
          if (executable == 'gsettings') {
            return ProcessResult(0, 0, "'default'\n", '');
          }
          return ProcessResult(1, 1, '', 'not found');
        },
      );

      final brightness = await resolver.resolveBrightness();
      expect(brightness, Brightness.light);
    });

    test('returns null when all queries fail', () async {
      final resolver = LinuxThemeResolver(
        processRunner: (executable, arguments) async {
          return ProcessResult(1, 127, '', 'command not found');
        },
      );

      final brightness = await resolver.resolveBrightness();
      expect(brightness, isNull);
    });
  });
}
