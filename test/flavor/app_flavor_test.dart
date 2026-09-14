import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/flavor/app_flavor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppDistributionFlavor Tests', () {
    test('Defaults to github flavor when no runtime flavor is set', () {
      expect(AppDistributionFlavor.current, AppDistributionFlavor.github);
      expect(AppDistributionFlavor.github.isGitHub, isTrue);
      expect(AppDistributionFlavor.github.isPlayStore, isFalse);
    });

    test('Play flavor properties are correct', () {
      expect(AppDistributionFlavor.play.isPlayStore, isTrue);
      expect(AppDistributionFlavor.play.isGitHub, isFalse);
      expect(AppDistributionFlavor.playStoreUrl, contains('com.blackpiratex.quietpaper'));
    });

    test('appFlavorProvider yields current flavor and supports override', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(appFlavorProvider), AppDistributionFlavor.github);

      final playContainer = ProviderContainer(
        overrides: [
          appFlavorProvider.overrideWithValue(AppDistributionFlavor.play),
        ],
      );
      addTearDown(playContainer.dispose);

      expect(playContainer.read(appFlavorProvider), AppDistributionFlavor.play);
      expect(playContainer.read(appFlavorProvider).isPlayStore, isTrue);
    });
  });
}
