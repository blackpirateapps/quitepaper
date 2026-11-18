import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/widgets/quiet_adaptive_modal.dart';
import '../../notes/domain/note_model.dart';
import 'templates_screen.dart';
import 'widgets/template_browser.dart';
import 'widgets/template_dialogs.dart';

class _PickerResult {
  const _PickerResult({this.note, this.manage = false});
  final Note? note;
  final bool manage;
}

Future<Note?> showTemplatePicker(
  BuildContext context, {
  String? activeTag,
}) async {
  final result = await QuietAdaptiveModal.show<_PickerResult>(
    context: context,
    maxWidth: 560,
    showCloseButton: false,
    builder: (ctx) => TemplateModalFrame(
      child: SizedBox(
        height: math
            .min(
              680,
              MediaQuery.sizeOf(ctx).height -
                  MediaQuery.viewInsetsOf(ctx).bottom -
                  32,
            )
            .clamp(0, 680)
            .toDouble(),
        child: TemplateBrowser(
          activeTag: activeTag,
          onCreated: (note) => Navigator.pop(ctx, _PickerResult(note: note)),
          onManage: () => Navigator.pop(ctx, const _PickerResult(manage: true)),
        ),
      ),
    ),
  );
  if (result?.manage == true && context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TemplatesScreen(activeTag: activeTag)),
    );
  }
  return result?.note;
}
