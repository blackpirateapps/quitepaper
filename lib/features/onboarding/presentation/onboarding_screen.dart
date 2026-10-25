import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/backup/presentation/restore_backup_dialog.dart';
import 'package:quitepaper/core/sync/sync_provider.dart';
import 'package:quitepaper/core/widgets/quiet_button.dart';
import 'package:quitepaper/features/notes/application/notes_query_provider.dart';
import 'package:quitepaper/features/onboarding/application/onboarding_provider.dart';
import 'package:quitepaper/features/sync/presentation/sync_auth_screen.dart';
import 'widgets/onboarding_page_layout.dart';
import 'widgets/onboarding_personalize_page.dart';
import 'widgets/onboarding_success_page.dart';
import 'widgets/onboarding_vignettes.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.isReplay = false});

  final bool isReplay;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final FocusNode _keyboardFocusNode = FocusNode();
  int _pageIndex = 0;
  OnboardingSuccessKind _successKind = OnboardingSuccessKind.none;
  int _restoredCount = 0;
  bool _isFinishing = false;

  @override
  void dispose() {
    _pageController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_pageIndex < 7) {
      final disableAnimations = MediaQuery.disableAnimationsOf(context);
      _pageController.animateToPage(
        _pageIndex + 1,
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_pageIndex > 0) {
      final disableAnimations = MediaQuery.disableAnimationsOf(context);
      _pageController.animateToPage(
        _pageIndex - 1,
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeAndLeave({required bool showTour}) async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);

    if (showTour) {
      await ref.read(onboardingStatusProvider.notifier).finishWithTour();
    } else {
      await ref.read(onboardingStatusProvider.notifier).finishWithoutTour();
    }

    if (!mounted) return;

    if (widget.isReplay) {
      if (showTour) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _finishSuccess() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);

    await ref.read(onboardingStatusProvider.notifier).finishWithoutTour();

    if (!mounted) return;

    if (widget.isReplay) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _openAuth(SyncAuthInitialView view) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SyncAuthScreen(initialView: view),
      ),
    );

    if (!mounted) return;

    final signedIn = ref.read(currentUserProvider) != null;
    if (result == true || signedIn) {
      setState(() {
        _successKind = OnboardingSuccessKind.sync;
      });
    }
  }

  Future<void> _restoreBackup() async {
    final count = await RestoreBackupDialog.show(
      context,
      showSuccessSnackBar: false,
    );

    if (!mounted || count == null) return;

    ref.read(notesCollectionProvider.notifier).refresh();
    setState(() {
      _restoredCount = count;
      _successKind = OnboardingSuccessKind.restore;
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.pageDown ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      if (_pageIndex < 7) {
        _nextPage();
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.pageUp) {
      if (_pageIndex > 0) {
        _prevPage();
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_successKind == OnboardingSuccessKind.none) {
        _completeAndLeave(showTour: false);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currentUser = ref.watch(currentUserProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 700;

    if (_successKind != OnboardingSuccessKind.none) {
      return Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: OnboardingSuccessPage(
            kind: _successKind,
            email: currentUser?.email,
            restoredCount: _restoredCount,
            onContinue: _finishSuccess,
          ),
        ),
      );
    }

    return PopScope(
      canPop: _pageIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _pageIndex > 0) {
          _prevPage();
        }
      },
      child: Focus(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          backgroundColor: colors.background,
          body: SafeArea(
            child: Column(
              children: [
                // 1. Top bar (48dp)
                _buildTopBar(colors, isTablet),

                // 2. PageView (8 pages)
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const PageScrollPhysics(),
                    onPageChanged: (idx) {
                      setState(() => _pageIndex = idx);
                    },
                    children: [
                      // Page 1: Welcome
                      _buildWelcomePage(colors, currentUser != null),
                      // Page 2: Privacy + local-first
                      _buildPrivacyPage(),
                      // Page 3: Voice notes + transcription
                      _buildVoicePage(),
                      // Page 4: One list, one way
                      _buildSimplicityPage(),
                      // Page 5: Offline OCR
                      _buildOcrPage(),
                      // Page 6: Optional sync
                      _buildSyncPage(colors, currentUser),
                      // Page 7: Make it yours
                      _buildPersonalizePage(),
                      // Page 8: Ready when you are
                      _buildReadyPage(),
                    ],
                  ),
                ),

                // 3. Fixed Footer
                _buildFooter(colors, currentUser != null),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(AppColors colors, bool isTablet) {
    return Container(
      height: 48,
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: back arrow or spacer
          if (_pageIndex > 0)
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 22),
                color: colors.textPrimary,
                tooltip: 'Back',
                onPressed: _prevPage,
              ),
            )
          else
            const SizedBox(width: 44, height: 44),

          // Right: Skip button
          TextButton(
            key: const Key('onboarding-skip'),
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              foregroundColor: colors.textSecondary,
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            onPressed: () => _completeAndLeave(showTour: false),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(AppColors colors, bool isUserSignedIn) {
    String primaryLabel;
    VoidCallback onPrimaryPressed;

    if (_pageIndex == 0) {
      primaryLabel = 'Come on in';
      onPrimaryPressed = _nextPage;
    } else if (_pageIndex == 5) {
      primaryLabel = isUserSignedIn ? 'Continue' : 'Keep it local';
      onPrimaryPressed = _nextPage;
    } else if (_pageIndex == 7) {
      primaryLabel = 'Show me around';
      onPrimaryPressed = () => _completeAndLeave(showTour: true);
    } else {
      primaryLabel = 'Continue';
      onPrimaryPressed = _nextPage;
    }

    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 12,
            bottom: 16 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress dots (8 dots)
              Semantics(
                liveRegion: true,
                label: 'Page ${_pageIndex + 1} of 8',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < 8; i++) ...[
                      AnimatedContainer(
                        duration: disableAnimations
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        width: i == _pageIndex ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _pageIndex
                              ? colors.accent
                              : colors.divider,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      if (i < 7) const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Primary Button
              QuietButton(
                key: const Key('onboarding-primary'),
                label: primaryLabel,
                isFullWidth: true,
                variant: QuietButtonVariant.primary,
                onPressed: onPrimaryPressed,
              ),
              // Optional secondary button on page 8
              if (_pageIndex == 7) ...[
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('onboarding-secondary'),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textSecondary,
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () => _completeAndLeave(showTour: false),
                  child: const Text("I'll find my way"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // CAROUSEL PAGES
  // ==========================================

  Widget _buildWelcomePage(AppColors colors, bool isUserSignedIn) {
    return OnboardingPageLayout(
      title: 'A quiet place to think.',
      body:
          'No feeds. No algorithms. No one reading over your shoulder. Just your words, a warm page, and a little breathing room.',
      visual: const WelcomeVignette(),
      visualFirst: true,
      belowBody: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Divider(height: 1, thickness: 1, color: colors.divider),
          const SizedBox(height: 16),
          Text(
            'Already have a library?',
            style: TextStyle(
              fontSize: 13,
              color: colors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              TextButton(
                key: const Key('onboarding-welcome-restore'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                  foregroundColor: colors.textSecondary,
                ),
                onPressed: _restoreBackup,
                child: const Text('Restore a backup'),
              ),
              if (!isUserSignedIn) ...[
                Text('·', style: TextStyle(color: colors.textTertiary)),
                TextButton(
                  key: const Key('onboarding-welcome-sign-in'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                    foregroundColor: colors.textSecondary,
                  ),
                  onPressed: () => _openAuth(SyncAuthInitialView.signIn),
                  child: const Text('Sign in'),
                ),
                Text('·', style: TextStyle(color: colors.textTertiary)),
                TextButton(
                  key: const Key('onboarding-welcome-create-account'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                    foregroundColor: colors.textSecondary,
                  ),
                  onPressed: () => _openAuth(SyncAuthInitialView.createAccount),
                  child: const Text('Create account'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPage() {
    return const OnboardingPageLayout(
      eyebrow: 'PRIVATE BY DEFAULT',
      title: 'Your words. Your business.',
      body:
          'Notes live on your device first, so Quiet Paper works on planes, in cafés with questionable Wi-Fi, and anywhere else ideas show up. If you turn on sync, everything is end-to-end encrypted before it leaves. The server gets ciphertext—not a peek.',
      footnote: 'No account needed to start.',
      visual: PrivacyVignette(),
    );
  }

  Widget _buildVoicePage() {
    return const OnboardingPageLayout(
      eyebrow: 'VOICE NOTES',
      title: 'Talk. We’ll take notes.',
      body:
          'Record a voice memo and turn it into text with on-device transcription. Download the small model once, then it works offline. Your voice never leaves your device.',
      footnote: 'One-time language-model download required.',
      visual: VoiceVignette(),
    );
  }

  Widget _buildSimplicityPage() {
    return const OnboardingPageLayout(
      eyebrow: 'ONE LIST, ONE WAY',
      title: 'No folders. No filing. No guilt.',
      body:
          'Every note lives in one calm list. Tag what matters with #anything, pin the keepers, and search the rest. That’s the whole system.',
      visual: SimplicityVignette(),
    );
  }

  Widget _buildOcrPage() {
    return const OnboardingPageLayout(
      eyebrow: 'OFFLINE OCR',
      title: 'Paper in. Words out.',
      body:
          'Scan a page, import a PDF, and pull out searchable text right on your device. Receipts, recipes, scribbled ideas—all findable later. No upload required.',
      visual: OcrVignette(),
    );
  }

  Widget _buildSyncPage(AppColors colors, dynamic currentUser) {
    if (currentUser != null) {
      final email = currentUser.email;
      final body = email != null && email.isNotEmpty
          ? 'Signed in as $email. Your notes sync quietly in the background.'
          : 'You’re signed in. Your notes sync quietly in the background.';

      return OnboardingPageLayout(
        eyebrow: 'SYNC IS ON',
        title: 'You’re already connected.',
        body: body,
        footnote: 'Manage sync in Settings.',
        visual: const SyncVignette(isConnected: true),
        belowBody: Container(
          margin: const EdgeInsets.only(top: 20),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.divider),
          ),
          child: Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 22,
                color: colors.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  email ?? 'Connected',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return OnboardingPageLayout(
      eyebrow: 'OPTIONAL SYNC',
      title: 'Same notes. Every device. Still private.',
      body:
          'Quiet Paper is perfectly happy staying local. If you’d like your library on more than one device, sign in or create an account. Your encryption password never leaves your device.',
      footnote: 'You can set this up later in Settings.',
      visual: const SyncVignette(isConnected: false),
      belowBody: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          QuietButton(
            key: const Key('onboarding-sync-create-account'),
            label: 'Create account',
            variant: QuietButtonVariant.primary,
            isFullWidth: true,
            onPressed: () => _openAuth(SyncAuthInitialView.createAccount),
          ),
          const SizedBox(height: 8),
          QuietButton(
            key: const Key('onboarding-sync-sign-in'),
            label: 'Sign in',
            variant: QuietButtonVariant.secondary,
            isFullWidth: true,
            onPressed: () => _openAuth(SyncAuthInitialView.signIn),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalizePage() {
    return const OnboardingPageLayout(
      eyebrow: 'MAKE IT YOURS',
      title: 'A desk that feels like yours.',
      body:
          'Pick a paper tone and a brightness. Then, if you’d like a few notes to poke around in, we’ll leave some on the desk.',
      extra: OnboardingPersonalizeControls(),
    );
  }

  Widget _buildReadyPage() {
    return const OnboardingPageLayout(
      eyebrow: 'ONE LAST THING',
      title: 'Ready when you are.',
      body:
          'We’ll point out where your first note begins. There’s no wrong way to start—even one word counts.',
      visual: ReadyVignette(),
    );
  }
}
