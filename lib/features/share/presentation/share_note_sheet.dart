import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/quiet_button.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../notes/application/note_security_service.dart';
import '../../notes/domain/note_model.dart';
import '../../notes/presentation/widgets/note_password_dialogs.dart';
import '../application/share_providers.dart';
import '../application/share_service.dart';
import '../domain/note_share.dart';
import 'manage_shares_screen.dart';

/// Modal bottom sheet for sharing a note as a public URL, or managing an
/// already-created share for the note.
class ShareNoteSheet extends ConsumerStatefulWidget {
  const ShareNoteSheet({super.key, required this.note});

  final Note note;

  static Future<void> show(BuildContext context, {required Note note}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareNoteSheet(note: note),
    );
  }

  @override
  ConsumerState<ShareNoteSheet> createState() => _ShareNoteSheetState();
}

class _ShareNoteSheetState extends ConsumerState<ShareNoteSheet> {
  ShareVisibility _visibility = ShareVisibility.public;
  final TextEditingController _passwordController = TextEditingController();

  bool _isCreating = false;
  ShareProgressPhase? _phase;
  String? _errorMessage;
  String? _createdUrl;

  // PLACEHOLDER_BODY

  @override
  void initState() {
    super.initState();
    if (widget.note.isShared && widget.note.shareUrl != null) {
      _createdUrl = widget.note.shareUrl;
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  String _phaseLabel(ShareProgressPhase phase) {
    switch (phase) {
      case ShareProgressPhase.preparing:
        return 'Preparing note…';
      case ShareProgressPhase.uploadingAttachments:
        return 'Uploading attachments…';
      case ShareProgressPhase.creatingShare:
        return 'Creating share link…';
      case ShareProgressPhase.done:
        return 'Done';
    }
  }

  Future<void> _handleCreate() async {
    setState(() {
      _isCreating = true;
      _errorMessage = null;
      _phase = ShareProgressPhase.preparing;
    });

    // Resolve the plaintext content, unlocking the note first if needed.
    String content = widget.note.content;
    if (widget.note.isPasswordProtected) {
      final password = await PromptPasswordDialog.show(
        context,
        title: 'Unlock Note to Share',
        hint: 'Enter note password',
        actionLabel: 'Unlock',
      );
      if (password == null || password.isEmpty) {
        if (mounted) setState(() { _isCreating = false; _phase = null; });
        return;
      }
      try {
        final payload = await NoteSecurityService.decryptNote(
          encryptedContent: widget.note.content,
          password: password,
        );
        content = payload.content;
      } catch (e) {
        if (mounted) {
          setState(() {
            _isCreating = false;
            _phase = null;
            _errorMessage = 'Could not unlock note: $e';
          });
        }
        return;
      }
    }

    try {
      final service = ref.read(shareServiceProvider);
      final created = await service.createShare(
        note: widget.note,
        decryptedContent: content,
        visibility: _visibility,
        password: _visibility == ShareVisibility.password
            ? _passwordController.text
            : null,
        onProgress: (p) {
          if (mounted) setState(() => _phase = p);
        },
      );
      ref.invalidate(sharesListProvider);
      if (mounted) {
        setState(() {
          _isCreating = false;
          _phase = null;
          _createdUrl = created.url;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreating = false;
          _phase = null;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _copyLink() async {
    final url = _createdUrl;
    if (url == null) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard')),
      );
    }
  }

  Future<void> _openLink() async {
    final url = _createdUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareLink() async {
    final url = _createdUrl;
    if (url == null) return;
    await Share.share(url);
  }

  // PLACEHOLDER_BUILD

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final displayTitle = widget.note.displayTitle;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: const BorderRadius.vertical(top: AppRadii.rLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(
                        top: AppSpacing.xs, bottom: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: colors.textTertiary.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  _buildHeader(colors, displayTitle),
                  const SizedBox(height: AppSpacing.md),
                  if (_createdUrl != null)
                    ..._buildSharedState(colors)
                  else
                    ..._buildCreateForm(colors),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppColors colors, String displayTitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.link_rounded, color: colors.accent, size: 17),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _createdUrl != null ? 'Note shared' : 'Share as URL',
                style: AppTypography.title.copyWith(
                  color: colors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: colors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        QuietIconButton(
          icon: Icons.close_rounded,
          tooltip: 'Close',
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  // PLACEHOLDER_STATES

  List<Widget> _buildSharedState(AppColors colors) {
    final url = _createdUrl ?? '';
    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.divider.withValues(alpha: 0.6), width: 0.8),
        ),
        child: Row(
          children: [
            Icon(Icons.public_rounded, size: 18, color: colors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                url,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: colors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.compact),
      Text(
        'This link expires automatically after 30 days. Manage or delete it '
        'from Shared links in Settings.',
        style: AppTypography.caption.copyWith(color: colors.textTertiary, height: 1.4),
      ),
      const SizedBox(height: AppSpacing.lg),
      Row(
        children: [
          Expanded(
            child: QuietButton(
              label: 'Copy link',
              icon: Icons.copy_rounded,
              variant: QuietButtonVariant.secondary,
              onPressed: _copyLink,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: QuietButton(
              label: 'Share',
              icon: Icons.ios_share_rounded,
              variant: QuietButtonVariant.primary,
              onPressed: _shareLink,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          Expanded(
            child: QuietButton(
              label: 'Open',
              icon: Icons.open_in_new_rounded,
              variant: QuietButtonVariant.ghost,
              onPressed: _openLink,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: QuietButton(
              label: 'Manage',
              icon: Icons.settings_outlined,
              variant: QuietButtonVariant.ghost,
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ManageSharesScreen()),
                );
              },
            ),
          ),
        ],
      ),
    ];
  }

  // PLACEHOLDER_FORM

  List<Widget> _buildCreateForm(AppColors colors) {
    return [
      Padding(
        padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
        child: Text(
          'VISIBILITY',
          style: AppTypography.caption.copyWith(
            color: colors.textTertiary,
            fontSize: 11.0,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ),
      Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: colors.divider.withValues(alpha: 0.6), width: 0.8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _visibilityRow(colors, ShareVisibility.public,
                Icons.public_rounded, 'Anyone with the link can read it', isFirst: true),
            _divider(colors),
            _visibilityRow(colors, ShareVisibility.unlisted,
                Icons.link_off_rounded, 'Only people with the link, not indexed'),
            _divider(colors),
            _visibilityRow(colors, ShareVisibility.password,
                Icons.lock_outline_rounded, 'Page text requires a password', isLast: true),
          ],
        ),
      ),
      if (_visibility == ShareVisibility.password) ...[
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _passwordController,
          obscureText: true,
          enabled: !_isCreating,
          style: AppTypography.bodyMedium.copyWith(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Set a password for this page',
            filled: true,
            fillColor: colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.divider.withValues(alpha: 0.6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.divider.withValues(alpha: 0.6)),
            ),
          ),
        ),
      ],
      if (_errorMessage != null) ...[
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.error.withValues(alpha: 0.25), width: 0.8),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 18, color: colors.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: AppTypography.caption.copyWith(color: colors.error, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
      if (_isCreating && _phase != null) ...[
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.accent.withValues(alpha: 0.2), width: 0.8),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _phaseLabel(_phase!),
                  style: AppTypography.caption.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      QuietButton(
        label: 'Create share link',
        icon: Icons.link_rounded,
        variant: QuietButtonVariant.primary,
        isFullWidth: true,
        isLoading: _isCreating,
        onPressed: _isCreating ? null : _handleCreate,
      ),
    ];
  }

  Widget _visibilityRow(
    AppColors colors,
    ShareVisibility visibility,
    IconData icon,
    String subtitle, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    final selected = _visibility == visibility;
    return Material(
      color: selected ? colors.accent.withValues(alpha: 0.08) : Colors.transparent,
      child: InkWell(
        onTap: _isCreating ? null : () => setState(() => _visibility = visibility),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Icon(icon, size: 20, color: selected ? colors.accent : colors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      visibility.label,
                      style: AppTypography.bodyMedium.copyWith(
                        color: selected ? colors.accent : colors.textPrimary,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 15.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: colors.textTertiary,
                        fontSize: 12.0,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, size: 20, color: colors.accent)
              else
                const SizedBox(width: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider(AppColors colors) {
    return Divider(
      color: colors.divider.withValues(alpha: 0.45),
      height: 1,
      thickness: 0.8,
      indent: 48,
    );
  }
}




