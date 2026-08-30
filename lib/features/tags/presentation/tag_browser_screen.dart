import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/application/notes_query_provider.dart';
import 'widgets/tag_browser_view.dart';

/// Tag Browser Screen for Quiet Paper, hosting TagBrowserView.
class TagBrowserScreen extends StatelessWidget {
  const TagBrowserScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => const TagBrowserScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: TagBrowserView(
          onClose: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          onTagSelected: (tag) {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            final container = ProviderScope.containerOf(context, listen: false);
            container.read(currentDestinationProvider.notifier).state = AppDestination.tag;
            container.read(selectedTagFilterProvider.notifier).state = tag.name;
            container.read(selectedTagIdProvider.notifier).state = tag.id;
            container.read(notesQueryProvider.notifier).setTag(tag.name);
          },
        ),
      ),
    );
  }
}
