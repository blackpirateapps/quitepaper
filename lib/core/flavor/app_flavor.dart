import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents the distribution channel / flavor for Quiet Paper.
enum AppDistributionFlavor {
  /// Distributed via GitHub Releases / direct APK downloads.
  /// Includes background update checking, in-app APK downloading,
  /// and Android package installer triggers.
  github,

  /// Distributed via Google Play Store (AAB).
  /// Excludes REQUEST_INSTALL_PACKAGES and direct APK self-updates.
  /// "Check for updates" opens the Google Play Store listing.
  play;

  bool get isPlayStore => this == AppDistributionFlavor.play;
  bool get isGitHub => this == AppDistributionFlavor.github;

  /// Google Play Store listing URL for Quiet Paper.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.blackpiratex.quietpaper';

  /// Returns the active runtime distribution flavor.
  /// Defaults to [github] when running in tests or local dev without `--flavor`.
  static AppDistributionFlavor get current {
    if (appFlavor == 'play') {
      return AppDistributionFlavor.play;
    }
    return AppDistributionFlavor.github;
  }
}

/// Riverpod provider for the active distribution flavor.
final appFlavorProvider = Provider<AppDistributionFlavor>((ref) {
  return AppDistributionFlavor.current;
});
