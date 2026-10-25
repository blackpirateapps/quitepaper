import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/platform_layout_helper.dart';
import '../core/web_clipper/share_intent_handler.dart';
import 'app_root.dart';
import '../features/notes/application/notes_provider.dart';
import '../features/quick_capture/application/quick_capture_coordinator.dart';
import '../features/settings/application/settings_provider.dart';
import '../features/settings/application/typography_provider.dart';
import 'theme/app_theme.dart';
import 'theme/theme_family.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class DesktopAppScrollBehavior extends MaterialScrollBehavior {
  const DesktopAppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    if (PlatformLayoutHelper.isDesktopPlatform) {
      return const ClampingScrollPhysics();
    }
    return const BouncingScrollPhysics();
  }
}

class QuietPaperApp extends ConsumerStatefulWidget {
  const QuietPaperApp({super.key});

  @override
  ConsumerState<QuietPaperApp> createState() => _QuietPaperAppState();
}

class _QuietPaperAppState extends ConsumerState<QuietPaperApp> {
  @override
  void initState() {
    super.initState();
    ShareIntentHandler.initialize(rootNavigatorKey);
    QuickCaptureCoordinator.initialize(rootNavigatorKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSearchIndexIntegrity();
    });
  }

  void _checkSearchIndexIntegrity() async {
    try {
      final db = ref.read(databaseProvider);
      if (db.needsSearchIndexRebuild) {
        db.clearSearchIndexRebuildFlag();
        debugPrint('[QuietPaper FTS] Triggering background auto-repair for search index...');
        await db.rebuildSearchIndex(batchSize: 500);
        debugPrint('[QuietPaper FTS] Background search index auto-repair complete.');
      }
    } catch (e) {
      debugPrint('[QuietPaper FTS] Background search index auto-repair error: $e');
    }
  }

  @override
  void dispose() {
    QuickCaptureCoordinator.dispose();
    ShareIntentHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = ref.watch(themeSettingsProvider);
    final typographySettings = ref.watch(typographySettingsProvider);
    final linuxBrightnessAsync = ref.watch(linuxSystemBrightnessProvider);

    ThemeMode effectiveThemeMode = themeSettings.appearance.toThemeMode();
    // On Linux desktop when appearance is set to system default, if LinuxThemeResolver
    // detected an authoritative system brightness preference from the FreeDesktop Portal
    // or GSettings, use it so the UI instantly respects dark mode.
    if (themeSettings.appearance == AppearanceMode.system &&
        linuxBrightnessAsync.hasValue &&
        linuxBrightnessAsync.value != null) {
      effectiveThemeMode = linuxBrightnessAsync.value == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light;
    }

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Quiet Paper',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const DesktopAppScrollBehavior(),
      theme: AppTheme.light(
        family: themeSettings.family,
        typography: typographySettings,
      ),
      darkTheme: AppTheme.dark(
        family: themeSettings.family,
        typography: typographySettings,
      ),
      themeMode: effectiveThemeMode,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.35,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AppRoot(),
    );
  }
}
