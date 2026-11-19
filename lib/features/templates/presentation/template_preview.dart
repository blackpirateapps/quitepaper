import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/markdown/markdown_preview.dart';
import '../application/template_providers.dart';
import '../domain/note_template.dart';
import 'widgets/template_dialogs.dart';

final templatePreviewProvider = FutureProvider.autoDispose
    .family<String, String>(
      (ref, id) => ref.watch(templateServiceProvider).preview(id),
    );

class TemplatePreview extends ConsumerWidget {
  const TemplatePreview({super.key, required this.template});
  final NoteTemplate template;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(templatePreviewProvider(template.id))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(templateErrorMessage(error)),
          ),
        ),
        data: (body) => QuietMarkdownPreview(
          markdownData: body,
          interactiveChecklists: false,
          // Selection of a link must never start navigation or an editor in preview.
          onTapLink: (_, _, _) {},
          padding: const EdgeInsets.all(24),
        ),
      );
}
