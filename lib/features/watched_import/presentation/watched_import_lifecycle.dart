import 'dart:async';
import 'package:flutter/widgets.dart';
import 'dart:ui' show AppExitResponse;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/watched_import_provider.dart';

class WatchedImportLifecycle extends ConsumerStatefulWidget {
  const WatchedImportLifecycle({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<WatchedImportLifecycle> createState() =>
      _WatchedImportLifecycleState();
}

class _WatchedImportLifecycleState
    extends ConsumerState<WatchedImportLifecycle> {
  AppLifecycleListener? _lifecycle;
  @override
  void initState() {
    super.initState();
    if (supportsWatchedImport) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(ref.read(watchedImportControllerProvider).initialize());
        }
      });
      _lifecycle = AppLifecycleListener(
        onResume: () {
          unawaited(ref.read(watchedImportControllerProvider).rescan());
        },
        onExitRequested: () async {
          await ref.read(watchedImportControllerProvider).close();
          return AppExitResponse.exit;
        },
      );
    }
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
