import 'package:flutter/foundation.dart';

/// Lock/logout/cache-clear boundary for ephemeral sensitive previews.
class SensitivePreviewRegistry {
  static final revision = ValueNotifier<int>(0);
  static void invalidate() => revision.value++;
}
