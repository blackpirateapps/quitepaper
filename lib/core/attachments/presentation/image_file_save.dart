import 'dart:io';
import 'package:flutter/foundation.dart';

/// Desktop pickers return a destination; mobile pickers consume supplied bytes.
Future<void> writePickedImageFile(String path, Uint8List bytes) async {
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows)) {
    await File(path).writeAsBytes(bytes, flush: true);
  }
}
