import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/notes/presentation/notes_screen.dart';
import '../features/settings/application/settings_provider.dart';
import 'theme/app_theme.dart';

class QuietPaperApp extends ConsumerWidget {
  const QuietPaperApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Quiet Paper',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const NotesScreen(),
    );
  }
}
