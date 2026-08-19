import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';

class SetNotePasswordResult {
  final String password;
  final String? hint;

  const SetNotePasswordResult({
    required this.password,
    this.hint,
  });
}

class SetNotePasswordDialog extends StatefulWidget {
  const SetNotePasswordDialog({
    super.key,
    this.isChangingPassword = false,
  });

  final bool isChangingPassword;

  static Future<SetNotePasswordResult?> show(
    BuildContext context, {
    bool isChangingPassword = false,
  }) {
    return showDialog<SetNotePasswordResult>(
      context: context,
      builder: (_) => SetNotePasswordDialog(isChangingPassword: isChangingPassword),
    );
  }

  @override
  State<SetNotePasswordDialog> createState() => _SetNotePasswordDialogState();
}

class _SetNotePasswordDialogState extends State<SetNotePasswordDialog> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _hintController = TextEditingController();

  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    final hint = _hintController.text.trim();

    if (password.isEmpty) {
      setState(() => _error = 'Password cannot be empty');
      return;
    }
    if (password.length < 4) {
      setState(() => _error = 'Password must be at least 4 characters');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    Navigator.of(context).pop(
      SetNotePasswordResult(
        password: password,
        hint: hint.isNotEmpty ? hint : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(AppRadii.rLg),
      ),
      title: Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: colors.accent, size: 22),
          const SizedBox(width: 8),
          Text(
            widget.isChangingPassword ? 'Change Password' : 'Lock Note with Password',
            style: AppTypography.headline.copyWith(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'This note will be encrypted on device. You will need this password to view or edit this note.',
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              cursorColor: colors.accent,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(color: colors.textSecondary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    color: colors.textTertiary,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: _obscure,
              cursorColor: colors.accent,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                labelStyle: TextStyle(color: colors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hintController,
              cursorColor: colors.accent,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Password Hint (Optional)',
                labelStyle: TextStyle(color: colors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: colors.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
          ),
          onPressed: _submit,
          child: const Text('Set Password'),
        ),
      ],
    );
  }
}

class PromptPasswordDialog extends StatefulWidget {
  const PromptPasswordDialog({
    super.key,
    required this.title,
    this.hint,
    this.actionLabel = 'Unlock',
  });

  final String title;
  final String? hint;
  final String actionLabel;

  static Future<String?> show(
    BuildContext context, {
    String title = 'Unlock Note',
    String? hint,
    String actionLabel = 'Unlock',
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => PromptPasswordDialog(
        title: title,
        hint: hint,
        actionLabel: actionLabel,
      ),
    );
  }

  @override
  State<PromptPasswordDialog> createState() => _PromptPasswordDialogState();
}

class _PromptPasswordDialogState extends State<PromptPasswordDialog> {
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(AppRadii.rLg),
      ),
      title: Row(
        children: [
          Icon(Icons.lock_rounded, color: colors.accent, size: 22),
          const SizedBox(width: 8),
          Text(
            widget.title,
            style: AppTypography.headline.copyWith(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.hint != null && widget.hint!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: colors.textTertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Hint: ${widget.hint}',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _passwordController,
            obscureText: _obscure,
            autofocus: true,
            cursorColor: colors.accent,
            style: TextStyle(color: colors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Enter Password',
              labelStyle: TextStyle(color: colors.textSecondary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: colors.textTertiary,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
            ),
            onSubmitted: (val) {
              if (val.isNotEmpty) {
                Navigator.of(context).pop(val);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
          ),
          onPressed: () {
            if (_passwordController.text.isNotEmpty) {
              Navigator.of(context).pop(_passwordController.text);
            }
          },
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
