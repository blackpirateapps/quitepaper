import 'package:flutter/material.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../editor/presentation/editor_screen.dart';
import 'widgets/template_browser.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key, this.activeTag});
  final String? activeTag;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.appColors.background,
    appBar: AppBar(
      backgroundColor: context.appColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: QuietIconButton(
        icon: PhosphorIconsRegular.arrowLeft,
        tooltip: 'Back',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(
        'Templates',
        style: AppTypography.title.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: context.appColors.textPrimary,
        ),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: TemplateBrowser(
            management: true,
            activeTag: activeTag,
            onCreated: (note) => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EditorScreen(note: note, autoFocusBody: true),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
