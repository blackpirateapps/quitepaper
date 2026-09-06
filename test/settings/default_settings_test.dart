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
    test('default constructor initializes all toggles to true', () {
      const settings = DefaultSettings();
      expect(settings.swipeToSearchEditor, isTrue);
      expect(settings.swipeDownToSearchNotes, isTrue);
      expect(settings.interactiveChecklistsInPreview, isTrue);
    });

    test('copyWith updates specified properties correctly', () {
      const settings = DefaultSettings();
      final updated = settings.copyWith(swipeToSearchEditor: false);
      expect(updated.swipeToSearchEditor, isFalse);
      expect(updated.swipeDownToSearchNotes, isTrue);
      expect(updated.interactiveChecklistsInPreview, isTrue);

      final updated2 = updated.copyWith(swipeDownToSearchNotes: false);
      expect(updated2.swipeToSearchEditor, isFalse);
      expect(updated2.swipeDownToSearchNotes, isFalse);
      expect(updated2.interactiveChecklistsInPreview, isTrue);

      final updated3 = updated2.copyWith(interactiveChecklistsInPreview: false);
      expect(updated3.swipeToSearchEditor, isFalse);
      expect(updated3.swipeDownToSearchNotes, isFalse);
      expect(updated3.interactiveChecklistsInPreview, isFalse);
    });

    test('equality and hashCode work as expected', () {
      const s1 = DefaultSettings(
        swipeToSearchEditor: true,
        swipeDownToSearchNotes: false,
        interactiveChecklistsInPreview: true,
      );
      const s2 = DefaultSettings(
        swipeToSearchEditor: true,
        swipeDownToSearchNotes: false,
        interactiveChecklistsInPreview: true,
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

      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));
      expect(s1, isNot(equals(s3)));
      expect(s1, isNot(equals(s4)));
    });
  });

  group('DefaultSettingsNotifier & Persistence', () {
    test('loads default true values when SharedPreferences has no keys', () {
      SharedPreferences.setMockInitialValues({});
      final notifier = DefaultSettingsNotifier(null);
      expect(notifier.state.swipeToSearchEditor, isTrue);
      expect(notifier.state.swipeDownToSearchNotes, isTrue);
      expect(notifier.state.interactiveChecklistsInPreview, isTrue);
    });

    test('loads saved false values from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        DefaultSettingsNotifier.swipeToSearchEditorKey: false,
        DefaultSettingsNotifier.swipeDownToSearchNotesKey: false,
        DefaultSettingsNotifier.interactiveChecklistsInPreviewKey: false,
      });
      final prefs = await SharedPreferences.getInstance();
      final notifier = DefaultSettingsNotifier(prefs);

      expect(notifier.state.swipeToSearchEditor, isFalse);
      expect(notifier.state.swipeDownToSearchNotes, isFalse);
      expect(notifier.state.interactiveChecklistsInPreview, isFalse);
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

      // All 3 switches should be present and ON
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
  });
}
