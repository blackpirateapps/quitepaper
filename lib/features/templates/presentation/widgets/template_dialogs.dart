import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_adaptive_modal.dart';
import '../../domain/note_template.dart';
import '../../application/template_content.dart';

String templateErrorMessage(Object error) {
  debugPrint('[Templates] Operation failed (${error.runtimeType})');
  return error is TemplateException
      ? error.message
      : 'Could not complete this template operation. Please try again.';
}

class TemplateModalFrame extends StatelessWidget {
  const TemplateModalFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Material(
      color: context.appColors.surface,
      borderRadius: AppRadii.borderLg,
      clipBehavior: Clip.antiAlias,
      child: SafeArea(top: false, child: child),
    ),
  );
}

Future<void> showTemplateNameDialog({
  required BuildContext context,
  required String initialName,
  required Future<void> Function(String) onSave,
  bool rename = false,
}) async {
  final saved = await QuietAdaptiveModal.show<bool>(
    context: context,
    showCloseButton: false,
    enableDrag: false,
    barrierDismissible: false,
    builder: (_) => TemplateNameDialog(
      initialName: initialName,
      onSave: onSave,
      rename: rename,
    ),
  );
  if (saved == true && context.mounted && !rename) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Template saved')));
  }
}

class TemplateNameDialog extends StatefulWidget {
  const TemplateNameDialog({
    super.key,
    required this.initialName,
    required this.onSave,
    this.rename = false,
  });
  final String initialName;
  final Future<void> Function(String) onSave;
  final bool rename;
  @override
  State<TemplateNameDialog> createState() => _TemplateNameDialogState();
}

class _TemplateNameDialogState extends State<TemplateNameDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || templateNameError(_name.text) != null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_name.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      final message = templateErrorMessage(error);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = message;
      });
      if (message == unsupportedTemplateContent) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: const Text(unsupportedTemplateContent),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!_saving) Navigator.pop(context);
        },
      },
      child: TemplateModalFrame(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.rename ? 'Rename Template' : 'Save as Template',
                style: AppTypography.title,
              ),
              if (!widget.rename) ...[
                const SizedBox(height: 12),
                const Text(
                  "Create a reusable template from this note. The original note won't change.",
                ),
              ],
              const SizedBox(height: 20),
              TextField(
                controller: _name,
                autofocus: true,
                enabled: !_saving,
                decoration: InputDecoration(
                  labelText: 'Template name',
                  errorText: templateNameError(_name.text),
                ),
                onChanged: (_) => setState(() {
                  _error = null;
                }),
                onSubmitted: (_) => _save(),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: context.appColors.error),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving || templateNameError(_name.text) != null
                        ? null
                        : _save,
                    child: Text(
                      _saving
                          ? 'Saving…'
                          : widget.rename
                          ? 'Save'
                          : 'Save Template',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<bool> confirmDeleteTemplate(BuildContext context) async =>
    await QuietAdaptiveModal.show<bool>(
      context: context,
      showCloseButton: false,
      builder: (ctx) => TemplateModalFrame(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Delete Template?', style: AppTypography.title),
              const SizedBox(height: 16),
              const Text(
                "This template will be deleted. Notes created from it won't be affected.",
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(
                      foregroundColor: ctx.appColors.error,
                    ),
                    child: const Text('Delete Template'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ) ??
    false;
