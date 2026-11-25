import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../sharing/incoming_share_coordinator.dart';
import '../security/sensitive_preview_registry.dart';
import '../../features/email_import/application/email_import_gateway.dart';
import '../../features/email_import/application/email_input.dart';
import '../../features/email_import/presentation/email_import_launcher.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../features/quick_capture/application/quick_capture_coordinator.dart';
import '../../features/quick_capture/application/quick_capture_normalizer.dart';
import '../../features/quick_capture/domain/quick_capture_payload.dart';
import '../sharing/shared_file_importer.dart';

/// Handler for content received from other apps via Android share / "Open with"
/// intents: shared URLs are routed to the web clipper, while opened PDF, text,
/// and Markdown files are imported into a new note by [SharedFileImporter].
class ShareIntentHandler {
  static StreamSubscription<List<SharedMediaFile>>? _intentSub;
  static bool _initialized = false;
  static const _native = MethodChannel(
    'com.blackpiratex.quietpaper/incoming_share',
  );
  static IncomingShareCoordinator? _coordinator;
  static void _clearSensitiveShares() {
    _coordinator?.clear();
    _native.invokeMethod<void>('clear').catchError((_) {});
  }

  static Future<void> _handleNative(
    Map<String, dynamic> request,
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    // Let the active draft/preview finish before displaying another request.
    await QuickCaptureCoordinator.whenIdle;
    await EmailImportLauncher.whenIdle;
    if (request['invalidated'] == true) return;
    if (navigatorKey.currentState == null) {
      WidgetsBinding.instance.scheduleFrame();
      await WidgetsBinding.instance.endOfFrame;
    }
    final context = navigatorKey.currentState?.overlay?.context;
    if (context == null) return;
    void message(String value) => ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(value)));
    if (request['error'] is String) {
      message(request['error'] as String);
      return;
    }
    final files = (request['files'] as List? ?? []).whereType<Map>().toList();
    final inputs = <EmailInput>[];
    for (final file in files) {
      if (file['error'] is String) {
        message(file['error'] as String);
        inputs.add(
          const EmailInput(
            path: 'unavailable-shared-file',
            name: 'Unavailable shared file',
          ),
        );
        continue;
      }
      if (file['path'] is String) {
        inputs.add(
          EmailInput(
            path: file['path'] as String,
            name: file['name'] as String?,
            mimeType: file['mimeType'] as String?,
          ),
        );
      }
    }
    var email = false;
    for (final input in inputs) {
      if (await input.isEmailCandidate()) {
        email = true;
        break;
      }
    }
    if (request['invalidated'] == true) return;
    if (email && context.mounted) {
      await EmailImportLauncher.open(
        context,
        EmailImportRequest(inputs: inputs),
      );
    } else {
      for (final input in inputs) {
        await SharedFileImporter.importFile(
          path: input.localPath,
          mimeType: input.mimeType,
          displayName: input.name,
          navigatorKey: navigatorKey,
        );
      }
    }
    final text = request['text'] as String?;
    if (inputs.isEmpty &&
        request['invalidated'] != true &&
        text != null &&
        text.trim().isNotEmpty &&
        context.mounted) {
      final payload = QuickCaptureNormalizer.normalize(
        origin: CaptureOrigin.share,
        rawText: text,
        rawSubject: request['subject'] as String?,
        rawIsHtml: request['isHtml'] == true,
        explicitSessionId: request['id'] as String,
      );
      QuickCaptureCoordinator.openCapture(payload);
      await QuickCaptureCoordinator.whenIdle;
    }
  }

  /// Initializes share intent listeners and checks initial share intent on launch.
  static void initialize(GlobalKey<NavigatorState> navigatorKey) {
    if (_initialized ||
        kIsWeb ||
        Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    _initialized = true;

    try {
      if (Platform.isAndroid) {
        _coordinator = IncomingShareCoordinator(
          handle: (request) => _handleNative(request, navigatorKey),
          onFailure: () {
            final ctx = navigatorKey.currentContext;
            if (ctx != null) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Could not receive this share. Try sharing it again.',
                  ),
                ),
              );
            }
          },
          acknowledge: (id) async {
            try {
              await _native.invokeMethod<void>('acknowledge', {'id': id});
            } catch (_) {}
          },
        );
        SensitivePreviewRegistry.revision.addListener(_clearSensitiveShares);
        _native.setMethodCallHandler((call) async {
          if (call.method == 'onIncomingShare' && call.arguments is Map) {
            _coordinator?.add(Map<String, dynamic>.from(call.arguments as Map));
          }
        });
        _native
            .invokeListMethod<dynamic>('drain')
            .then((requests) {
              for (final request in requests ?? []) {
                if (request is Map) {
                  _coordinator?.add(Map<String, dynamic>.from(request));
                }
              }
            })
            .catchError((_) {});
        return;
      }
      // 1. Listen to incoming shared media while app is running
      _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
        (files) {
          _handleSharedFiles(files, navigatorKey);
        },
        onError: (err) {
          debugPrint('Share intent stream unavailable.');
        },
      );

      // 2. Check initial share intent when app is opened from closed state
      ReceiveSharingIntent.instance
          .getInitialMedia()
          .then((files) {
            _handleSharedFiles(files, navigatorKey);
            ReceiveSharingIntent.instance.reset();
          })
          .catchError((err) {
            debugPrint('Initial share intent unavailable.');
          });
    } catch (e) {
      debugPrint('Share receiving unavailable on this platform.');
    }
  }

  static void dispose() {
    SensitivePreviewRegistry.revision.removeListener(_clearSensitiveShares);
    _coordinator?.dispose();
    _coordinator = null;
    _native.setMethodCallHandler(null);
    _intentSub?.cancel();
    _intentSub = null;
    _initialized = false;
  }

  static void _handleSharedFiles(
    List<SharedMediaFile> files,
    GlobalKey<NavigatorState> navigatorKey,
  ) {
    if (files.isEmpty) return;

    for (final file in files) {
      final raw = file.path.trim();
      if (raw.isEmpty) continue;

      // A real on-disk file means the user opened or shared a document
      // (PDF, text or Markdown); otherwise `path` carries shared text/URL.
      final isFile = _isExistingFile(raw);
      final mimeType = file.mimeType;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = navigatorKey.currentContext;
        if (context == null) return;
        if (isFile) {
          SharedFileImporter.importFile(
            path: raw,
            mimeType: mimeType,
            navigatorKey: navigatorKey,
          );
        } else {
          final payload = QuickCaptureNormalizer.normalize(
            origin: CaptureOrigin.share,
            rawText: raw,
          );
          QuickCaptureCoordinator.openCapture(payload);
        }
      });
      return; // Handle only the first shareable item.
    }
  }

  static bool _isExistingFile(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }
}
