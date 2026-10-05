import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/settings/application/default_settings_provider.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/settings/domain/default_settings.dart';
import 'package:quitepaper/features/settings/presentation/default_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DefaultSettings Domain Model', () {
    test('default constructor initializes all toggles to true and compression defaults', () {
      const settings = DefaultSettings();
      expect(settings.swipeToSearchEditor, isTrue);
      expect(settings.swipeDownToSearchNotes, isTrue);
      expect(settings.interactiveChecklistsInPreview, isTrue);
      expect(settings.imageCompressionAction, ImageCompressionAction.ask);
      expect(settings.imageCompressionPreset, ImageCompressionPreset.balanced);
    });

    test('copyWith updates specified properties correctly', () {
      const settings = DefaultSettings();
      final updated = settings.copyWith(swipeToSearchEditor: false);
      expect(updated.swipeToSearchEditor, isFalse);
      expect(updated.swipeDownToSearchNotes, isTrue);
      expect(updated.interactiveChecklistsInPreview, isTrue);
      expect(updated.imageCompressionAction, ImageCompressionAction.ask);
      expect(updated.imageCompressionPreset, ImageCompressionPreset.balanced);

      final updated2 = updated.copyWith(swipeDownToSearchNotes: false);
      expect(updated2.swipeToSearchEditor, isFalse);
      expect(updated2.swipeDownToSearchNotes, isFalse);
      expect(updated2.interactiveChecklistsInPreview, isTrue);

      final updated3 = updated2.copyWith(interactiveChecklistsInPreview: false);
      expect(updated3.swipeToSearchEditor, isFalse);
      expect(updated3.swipeDownToSearchNotes, isFalse);
      expect(updated3.interactiveChecklistsInPreview, isFalse);

      final updated4 = updated3.copyWith(
        imageCompressionAction: ImageCompressionAction.alwaysCompress,
        imageCompressionPreset: ImageCompressionPreset.compact,
      );
      expect(updated4.imageCompressionAction, ImageCompressionAction.alwaysCompress);
      expect(updated4.imageCompressionPreset, ImageCompressionPreset.compact);
    });

    test('equality and hashCode work as expected', () {
      const s1 = DefaultSettings(
        swipeToSearchEditor: true,
        swipeDownToSearchNotes: false,
        interactiveChecklistsInPreview: true,
        imageCompressionAction: ImageCompressionAction.ask,
        imageCompressionPreset: ImageCompressionPreset.balanced,
      );
      const s2 = DefaultSettings(
        swipeToSearchEditor: true,
        swipeDownToSearchNotes: false,
        interactiveChecklistsInPreview: true,
        imageCompressionAction: ImageCompressionAction.ask,
        imageCompressionPreset: ImageCompressionPreset.balanced,
      );
      const s3 = DefaultSettings(
        swipeToSearchEditor: false,
        swipeDownToSearchNotes: false,
        interactiveChecklistsInPreview: true,
      );
      const s4 = DefaultSettings(
        swipeToSearchEditor: true,
        swipeDownToSearchNotes: false,
        interactiveChecklistsInPreview: false,
      );
      const s5 = DefaultSettings(
        swipeToSearchEditor: true,
        swipeDownToSearchNotes: false,
        interactiveChecklistsInPreview: true,
        imageCompressionAction: ImageCompressionAction.keepOriginal,
      );

      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));
      expect(s1, isNot(equals(s3)));
      expect(s1, isNot(equals(s4)));
      expect(s1, isNot(equals(s5)));
    });

    test('enums parse from identifiers correctly with fallback', () {
      expect(ImageCompressionAction.fromIdentifier('ask'), ImageCompressionAction.ask);
      expect(ImageCompressionAction.fromIdentifier('always_compress'), ImageCompressionAction.alwaysCompress);
      expect(ImageCompressionAction.fromIdentifier('keep_original'), ImageCompressionAction.keepOriginal);
      expect(ImageCompressionAction.fromIdentifier('unknown'), ImageCompressionAction.ask);
      expect(ImageCompressionAction.fromIdentifier(null), ImageCompressionAction.ask);

      expect(ImageCompressionPreset.fromIdentifier('balanced'), ImageCompressionPreset.balanced);
      expect(ImageCompressionPreset.fromIdentifier('high_quality'), ImageCompressionPreset.highQuality);
      expect(ImageCompressionPreset.fromIdentifier('compact'), ImageCompressionPreset.compact);
      expect(ImageCompressionPreset.fromIdentifier('unknown'), ImageCompressionPreset.balanced);
      expect(ImageCompressionPreset.fromIdentifier(null), ImageCompressionPreset.balanced);
    });
  });

  group('DefaultSettingsNotifier & Persistence', () {
    test('loads default true values when SharedPreferences has no keys', () {
      SharedPreferences.setMockInitialValues({});
      final notifier = DefaultSettingsNotifier(null);
      expect(notifier.state.swipeToSearchEditor, isTrue);
      expect(notifier.state.swipeDownToSearchNotes, isTrue);
      expect(notifier.state.interactiveChecklistsInPreview, isTrue);
      expect(notifier.state.imageCompressionAction, ImageCompressionAction.ask);
      expect(notifier.state.imageCompressionPreset, ImageCompressionPreset.balanced);
    });

    test('loads saved false values from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        DefaultSettingsNotifier.swipeToSearchEditorKey: false,
        DefaultSettingsNotifier.swipeDownToSearchNotesKey: false,
        DefaultSettingsNotifier.interactiveChecklistsInPreviewKey: false,
        DefaultSettingsNotifier.imageCompressionActionKey: 'always_compress',
        DefaultSettingsNotifier.imageCompressionPresetKey: 'compact',
      });
      final prefs = await SharedPreferences.getInstance();
      final notifier = DefaultSettingsNotifier(prefs);

      expect(notifier.state.swipeToSearchEditor, isFalse);
      expect(notifier.state.swipeDownToSearchNotes, isFalse);
      expect(notifier.state.interactiveChecklistsInPreview, isFalse);
      expect(notifier.state.imageCompressionAction, ImageCompressionAction.alwaysCompress);
      expect(notifier.state.imageCompressionPreset, ImageCompressionPreset.compact);
    });

    test('setSwipeToSearchEditor updates state and persists to SharedPreferences',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = DefaultSettingsNotifier(prefs);

      await notifier.setSwipeToSearchEditor(false);
      expect(notifier.state.swipeToSearchEditor, isFalse);
      expect(
        prefs.getBool(DefaultSettingsNotifier.swipeToSearchEditorKey),
        isFalse,
      );

      await notifier.setSwipeToSearchEditor(true);
      expect(notifier.state.swipeToSearchEditor, isTrue);
      expect(
        prefs.getBool(DefaultSettingsNotifier.swipeToSearchEditorKey),
        isTrue,
      );
    });

    test(
        'setSwipeDownToSearchNotes updates state and persists to SharedPreferences',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = DefaultSettingsNotifier(prefs);

      await notifier.setSwipeDownToSearchNotes(false);
      expect(notifier.state.swipeDownToSearchNotes, isFalse);
      expect(
        prefs.getBool(DefaultSettingsNotifier.swipeDownToSearchNotesKey),
        isFalse,
      );

      await notifier.setSwipeDownToSearchNotes(true);
      expect(notifier.state.swipeDownToSearchNotes, isTrue);
      expect(
        prefs.getBool(DefaultSettingsNotifier.swipeDownToSearchNotesKey),
        isTrue,
      );
    });

    test(
        'setInteractiveChecklistsInPreview updates state and persists to SharedPreferences',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = DefaultSettingsNotifier(prefs);

      await notifier.setInteractiveChecklistsInPreview(false);
      expect(notifier.state.interactiveChecklistsInPreview, isFalse);
      expect(
        prefs.getBool(DefaultSettingsNotifier.interactiveChecklistsInPreviewKey),
        isFalse,
      );

      await notifier.setInteractiveChecklistsInPreview(true);
      expect(notifier.state.interactiveChecklistsInPreview, isTrue);
      expect(
        prefs.getBool(DefaultSettingsNotifier.interactiveChecklistsInPreviewKey),
        isTrue,
      );
    });

    test('setImageCompressionAction updates state and persists to SharedPreferences',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = DefaultSettingsNotifier(prefs);

      await notifier.setImageCompressionAction(ImageCompressionAction.alwaysCompress);
      expect(notifier.state.imageCompressionAction, ImageCompressionAction.alwaysCompress);
      expect(
        prefs.getString(DefaultSettingsNotifier.imageCompressionActionKey),
        'always_compress',
      );

      await notifier.setImageCompressionAction(ImageCompressionAction.keepOriginal);
      expect(notifier.state.imageCompressionAction, ImageCompressionAction.keepOriginal);
      expect(
        prefs.getString(DefaultSettingsNotifier.imageCompressionActionKey),
        'keep_original',
      );
    });

    test('setImageCompressionPreset updates state and persists to SharedPreferences',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = DefaultSettingsNotifier(prefs);

      await notifier.setImageCompressionPreset(ImageCompressionPreset.compact);
      expect(notifier.state.imageCompressionPreset, ImageCompressionPreset.compact);
      expect(
        prefs.getString(DefaultSettingsNotifier.imageCompressionPresetKey),
        'compact',
      );

      await notifier.setImageCompressionPreset(ImageCompressionPreset.highQuality);
      expect(notifier.state.imageCompressionPreset, ImageCompressionPreset.highQuality);
      expect(
        prefs.getString(DefaultSettingsNotifier.imageCompressionPresetKey),
        'high_quality',
      );
    });
  });

  group('DefaultSettingsScreen Widget Tests', () {
    Widget buildScreen({required SharedPreferences prefs}) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [AppColors.light],
          ),
          home: const DefaultSettingsScreen(),
        ),
      );
    }

    testWidgets('renders all headers, titles, subtitles, and switches',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(buildScreen(prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.text('Default Settings'), findsOneWidget);
      expect(find.text('EDITOR & PREVIEW'), findsOneWidget);
      expect(find.text('Interactive Checklists in Preview'), findsOneWidget);
      expect(
        find.text(
            'Allow checking and unchecking to-do items while in preview mode'),
        findsOneWidget,
      );
      expect(find.text('GESTURES & SEARCH'), findsOneWidget);
      expect(find.text('Swipe to Search in Editor'), findsOneWidget);
      expect(
        find.text('Pull down at the top of a note to reveal in-note search'),
        findsOneWidget,
      );
      expect(find.text('Swipe Down to Search in Notes List'), findsOneWidget);
      expect(
        find.text('Pull down at the top of the notes list to reveal search'),
        findsOneWidget,
      );

      // Scroll to view Image attachments section
      await tester.scrollUntilVisible(find.text('IMAGE ATTACHMENTS'), 100);
      await tester.pumpAndSettle();

      expect(find.text('IMAGE ATTACHMENTS'), findsOneWidget);
      expect(find.text('Image Compression'), findsOneWidget);
      expect(find.text('Ask every time'), findsOneWidget);
      expect(find.text('Compression Quality'), findsOneWidget);
      expect(
        find.text('1920px max, 80% quality (Recommended)'),
        findsOneWidget,
      );

      // Scroll back up to verify switches
      await tester.scrollUntilVisible(find.text('EDITOR & PREVIEW'), -100);
      await tester.pumpAndSettle();

      final switches = find.byType(CupertinoSwitch);
      expect(switches, findsNWidgets(3));
      expect(tester.widget<CupertinoSwitch>(switches.at(0)).value, isTrue);
      expect(tester.widget<CupertinoSwitch>(switches.at(1)).value, isTrue);
      expect(tester.widget<CupertinoSwitch>(switches.at(2)).value, isTrue);
    });

    testWidgets('toggling switches updates values in provider and SharedPreferences',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(buildScreen(prefs: prefs));
      await tester.pumpAndSettle();

      final switches = find.byType(CupertinoSwitch);

      // Toggle first switch (Interactive Checklists)
      await tester.tap(switches.at(0));
      await tester.pumpAndSettle();

      expect(tester.widget<CupertinoSwitch>(switches.at(0)).value, isFalse);
      expect(
        prefs.getBool(DefaultSettingsNotifier.interactiveChecklistsInPreviewKey),
        isFalse,
      );

      // Toggle second switch (Editor Swipe)
      await tester.tap(switches.at(1));
      await tester.pumpAndSettle();

      expect(tester.widget<CupertinoSwitch>(switches.at(1)).value, isFalse);
      expect(
        prefs.getBool(DefaultSettingsNotifier.swipeToSearchEditorKey),
        isFalse,
      );

      // Toggle third switch (Notes Swipe)
      await tester.tap(switches.at(2));
      await tester.pumpAndSettle();

      expect(tester.widget<CupertinoSwitch>(switches.at(2)).value, isFalse);
      expect(
        prefs.getBool(DefaultSettingsNotifier.swipeDownToSearchNotesKey),
        isFalse,
      );
    });

    testWidgets('selecting compression action and preset via bottom sheet updates provider and SharedPreferences',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(buildScreen(prefs: prefs));
      await tester.pumpAndSettle();

      // Scroll to Image Compression and open sheet
      await tester.scrollUntilVisible(find.text('Image Compression'), 100);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Image Compression'));
      await tester.pumpAndSettle();

      expect(find.text('Default Compression'), findsOneWidget);
      expect(find.text('Always compress'), findsOneWidget);

      // Select 'Always compress'
      await tester.tap(find.text('Always compress'));
      await tester.pumpAndSettle();

      expect(
        prefs.getString(DefaultSettingsNotifier.imageCompressionActionKey),
        'always_compress',
      );
      expect(find.text('Always compress'), findsOneWidget);

      // Scroll to Compression Quality and open sheet
      await tester.scrollUntilVisible(find.text('Compression Quality'), 100);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compression Quality'));
      await tester.pumpAndSettle();

      expect(find.text('1280px max, 70% quality'), findsOneWidget);

      // Select Compact preset
      await tester.tap(find.text('Compact'));
      await tester.pumpAndSettle();

      expect(
        prefs.getString(DefaultSettingsNotifier.imageCompressionPresetKey),
        'compact',
      );
      expect(find.text('1280px max, 70% quality'), findsOneWidget);
    });
  });
}
