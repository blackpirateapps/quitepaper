import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/web_clipper/share_intent_handler.dart';
import '../features/notes/presentation/notes_screen.dart';
import '../features/settings/application/settings_provider.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

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
  }

  @override
  void dispose() {
    ShareIntentHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Quiet Paper',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const NotesScreen(),
    );
  }
}
