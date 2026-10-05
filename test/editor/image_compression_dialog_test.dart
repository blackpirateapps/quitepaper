import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/editor/presentation/widgets/image_compression_dialog.dart';
import 'package:quitepaper/features/settings/domain/default_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ImageCompressionDialog displays metadata and returns decision on confirm', (tester) async {
    ImageCompressionDecision? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: const [AppColors.light],
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await ImageCompressionDialog.show(
                    context,
                    fileName: 'vacation_photo.jpg',
                    byteSize: 3 * 1024 * 1024, // 3.0 MB
                    width: 4000,
                    height: 3000,
                    preset: ImageCompressionPreset.balanced,
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Verify metadata
    expect(find.text('Optimize Image'), findsOneWidget);
    expect(find.text('vacation_photo.jpg'), findsOneWidget);
    expect(find.text('3.0 MB • 4000 × 3000 px'), findsOneWidget);
    expect(find.text('Compress & Optimize'), findsOneWidget);
    expect(find.text('Keep Original'), findsOneWidget);
    expect(find.text('Remember my choice'), findsOneWidget);

    // Check remember choice
    await tester.tap(find.text('Remember my choice'));
    await tester.pumpAndSettle();

    // Confirm default compress choice
    await tester.tap(find.text('Insert Image'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.choice, ImageCompressionDialogChoice.compress);
    expect(result!.rememberChoice, isTrue);
  });

  testWidgets('ImageCompressionDialog allows selecting Keep Original', (tester) async {
    ImageCompressionDecision? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: const [AppColors.light],
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await ImageCompressionDialog.show(
                    context,
                    fileName: 'raw_capture.png',
                    byteSize: 1500 * 1024,
                    width: 1920,
                    height: 1080,
                    preset: ImageCompressionPreset.compact,
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Select Keep Original
    await tester.tap(find.text('Keep Original'));
    await tester.pumpAndSettle();

    // Confirm
    await tester.tap(find.text('Insert Image'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.choice, ImageCompressionDialogChoice.keepOriginal);
    expect(result!.rememberChoice, isFalse);
  });

  testWidgets('ImageCompressionDialog returns null when Cancel is pressed', (tester) async {
    ImageCompressionDecision? result = const ImageCompressionDecision(
      choice: ImageCompressionDialogChoice.compress,
      rememberChoice: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: const [AppColors.light],
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await ImageCompressionDialog.show(
                    context,
                    fileName: 'photo.jpg',
                    byteSize: 1024 * 1024,
                    width: 800,
                    height: 600,
                    preset: ImageCompressionPreset.balanced,
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Press Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
