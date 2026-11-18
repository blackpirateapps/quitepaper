import 'package:flutter/material.dart';
import '../../editor/presentation/editor_screen.dart';
import 'widgets/template_browser.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key, this.activeTag});
  final String? activeTag;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Templates')),
    body: TemplateBrowser(
      management: true,
      activeTag: activeTag,
      onCreated: (note) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EditorScreen(note: note, autoFocusBody: true),
        ),
      ),
    ),
  );
}
