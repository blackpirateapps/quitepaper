import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';

class PasswordUnlockView extends StatefulWidget {
  const PasswordUnlockView({
    super.key,
    this.title,
    this.hint,
    required this.onUnlock,
  });

  final String? title;
  final String? hint;
  final Future<bool> Function(String password) onUnlock;

  @override
  State<PasswordUnlockView> createState() => _PasswordUnlockViewState();
}

class _PasswordUnlockViewState extends State<PasswordUnlockView> {
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleUnlock() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _error = 'Please enter note password');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final success = await widget.onUnlock(password);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (!success) {
          _error = 'Incorrect password. Please try again.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: 32,
                  color: colors.accent,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title != null && widget.title!.trim().isNotEmpty
                    ? widget.title!.trim()
                    : 'Password Protected Note',
                textAlign: TextAlign.center,
                style: AppTypography.title.copyWith(
                  color: colors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the password to decrypt and view this note.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textSecondary,
                  height: 1.4,
                ),
              ),
              if (widget.hint != null && widget.hint!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(
                      color: colors.divider.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.help_outline_rounded,
                          size: 14, color: colors.textTertiary),
                      const SizedBox(width: 6),
                      Flexible(
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
              ],
              const SizedBox(height: 24),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                autofocus: true,
                cursorColor: colors.accent,
                style: TextStyle(color: colors.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: colors.textSecondary),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: colors.textTertiary,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  filled: true,
                  fillColor: colors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    borderSide: BorderSide(
                      color: colors.divider.withValues(alpha: 0.6),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    borderSide: BorderSide(
                      color: colors.divider.withValues(alpha: 0.6),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    borderSide: BorderSide(
                      color: colors.accent,
                      width: 1.5,
                    ),
                  ),
                ),
                onSubmitted: (_) => _handleUnlock(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : _handleUnlock,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Unlock Note',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
