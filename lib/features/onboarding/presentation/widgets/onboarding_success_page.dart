import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_button.dart';

enum OnboardingSuccessKind {
  none,
  sync,
  restore,
}

class OnboardingSuccessPage extends StatelessWidget {
  const OnboardingSuccessPage({
    super.key,
    required this.kind,
    this.email,
    this.restoredCount = 0,
    required this.onContinue,
  });

  final OnboardingSuccessKind kind;
  final String? email;
  final int restoredCount;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    String title;
    String body;
    String? caption;

    if (kind == OnboardingSuccessKind.sync) {
      title = 'You’re in.';
      body =
          'Your notes will sync quietly in the background. Pick up on another device whenever you like.';
      if (email != null && email!.isNotEmpty) {
        caption = 'Signed in as $email.';
      }
    } else {
      title = 'Welcome back.';
      if (restoredCount > 0) {
        final noteWord = restoredCount == 1 ? 'note' : 'notes';
        body =
            'Your backup is home. We put back $restoredCount $noteWord and their tags.';
      } else {
        body = 'Your backup is home. Everything is right where you left it.';
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          onContinue();
        }
      },
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 72dp circle with accentSoft background
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colors.accentSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 38,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'ALL SET',
                  style: AppTypography.caption.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(height: 10),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTypography.display.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      letterSpacing: -0.5,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.55,
                    color: colors.textSecondary,
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    caption,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: QuietButton(
                    key: const Key('onboarding-primary'),
                    label: 'Continue',
                    isFullWidth: true,
                    variant: QuietButtonVariant.primary,
                    onPressed: onContinue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
