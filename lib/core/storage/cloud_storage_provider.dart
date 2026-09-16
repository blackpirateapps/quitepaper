import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/notes/application/notes_provider.dart';
import '../auth/auth_service.dart';
import '../database/app_database.dart';
import '../sync/sync_api_client.dart';
import '../sync/sync_provider.dart';
import 'cloud_storage_models.dart';

/// State of the user's cloud storage quota and plan entitlements.
@immutable
class CloudStorageState {
  const CloudStorageState({
    this.quota,
    this.isLoading = false,
    this.errorMessage,
    this.lastFetchedAt,
    this.isOffline = false,
  });

  final CloudStorageQuota? quota;
  final bool isLoading;
  final String? errorMessage;
  final DateTime? lastFetchedAt;
  final bool isOffline;

  bool get hasData => quota != null;
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;

  /// True if data was fetched more than 1 hour ago.
  bool get isStale {
    if (lastFetchedAt == null) return true;
    return DateTime.now().difference(lastFetchedAt!) > const Duration(hours: 1);
  }

  CloudStorageState copyWith({
    CloudStorageQuota? quota,
    bool? isLoading,
    String? errorMessage,
    DateTime? lastFetchedAt,
    bool? isOffline,
    bool clearError = false,
  }) {
    return CloudStorageState(
      quota: quota ?? this.quota,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
      isOffline: isOffline ?? this.isOffline,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CloudStorageState &&
          runtimeType == other.runtimeType &&
          quota == other.quota &&
          isLoading == other.isLoading &&
          errorMessage == other.errorMessage &&
          lastFetchedAt == other.lastFetchedAt &&
          isOffline == other.isOffline;

  @override
  int get hashCode =>
      quota.hashCode ^
      isLoading.hashCode ^
      errorMessage.hashCode ^
      lastFetchedAt.hashCode ^
      isOffline.hashCode;
}

/// Notifier managing cloud storage account quota state, breakdown calculations, and preflight validation.
class CloudStorageNotifier extends StateNotifier<CloudStorageState> {
  CloudStorageNotifier({
    required this.apiClient,
    required this.database,
    required this.authService,
  }) : super(const CloudStorageState()) {
    _init();
  }

  final SyncApiClient apiClient;
  final AppDatabase database;
  final AuthService authService;
  StreamSubscription<AuthUser?>? _authSub;

  void _init() {
    _authSub = authService.authStateChanges.listen((user) {
      if (!mounted) return;
      if (user == null) {
        state = const CloudStorageState();
      } else {
        fetchQuota();
      }
    });

    if (authService.currentUser != null) {
      scheduleMicrotask(() {
        if (mounted && authService.currentUser != null && state.quota == null && !state.isLoading) {
          fetchQuota();
        }
      });
    }
  }

  /// Calculates storage breakdown by resource category directly from the local SQLite database.
  Future<StorageBreakdown> calculateLocalBreakdown() async {
    if (!mounted) return const StorageBreakdown();
    try {
      final attachments = await database.getAllAttachmentsRaw();
      final documents = await database.getAllDocumentsRaw();

      var imgBytes = 0;
      var imgCount = 0;
      var docBytes = 0;
      var docCount = 0;
      var otherBytes = 0;
      var otherCount = 0;

      for (final a in attachments) {
        if (a.isDeleted) continue;
        final k = a.kind.toLowerCase();
        final m = a.mimeType.toLowerCase();
        if (k == 'image' || m.startsWith('image/')) {
          imgCount++;
          imgBytes += a.byteSize;
        } else if (k == 'document' || m == 'application/pdf') {
          docCount++;
          docBytes += a.byteSize;
        } else {
          otherCount++;
          otherBytes += a.byteSize;
        }
      }

      for (final d in documents) {
        if (d.isDeleted) continue;
        docCount++;
        docBytes += d.byteSize;
      }

      return StorageBreakdown(
        imageBytes: imgBytes,
        imageCount: imgCount,
        documentBytes: docBytes,
        documentCount: docCount,
        otherBytes: otherBytes,
        otherCount: otherCount,
      );
    } catch (e) {
      debugPrint('[CloudStorage] Error calculating local breakdown: $e');
      return const StorageBreakdown();
    }
  }

  /// Fetches authoritative storage quota from backend and enriches with local breakdown metrics.
  Future<void> fetchQuota({bool force = false}) async {
    if (!mounted) return;
    if (authService.currentUser == null) {
      state = const CloudStorageState();
      return;
    }

    if (state.isLoading && !force) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final serverQuota = await apiClient.getCloudStorageQuota();
      if (!mounted) return;
      final localBreakdown = await calculateLocalBreakdown();
      if (!mounted) return;
      final now = DateTime.now();

      final effectiveBreakdown = (localBreakdown.totalCount > 0)
          ? localBreakdown
          : (serverQuota.breakdown ?? localBreakdown);

      final completeQuota = serverQuota.copyWith(
        breakdown: effectiveBreakdown,
        lastFetchedAt: now,
      );

      state = CloudStorageState(
        quota: completeQuota,
        isLoading: false,
        lastFetchedAt: now,
        isOffline: false,
      );
    } catch (e) {
      if (!mounted) return;
      final errStr = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      final isOffline = errStr.contains('SocketException') ||
          errStr.contains('ClientException') ||
          errStr.contains('Network is unreachable') ||
          errStr.contains('Connection refused');

      debugPrint('[CloudStorage] Failed to fetch cloud storage quota: $errStr');

      // Preserve previously cached quota if available
      state = state.copyWith(
        isLoading: false,
        isOffline: isOffline,
        errorMessage: errStr,
      );
    }
  }

  /// Evaluates client-side preflight rules for a file upload of size [fileSizeBytes].
  UploadPreflightResult preflightCheck(int fileSizeBytes) {
    if (fileSizeBytes > CloudStorageConstants.maxUploadSizeBytes) {
      return UploadPreflightResult.fileTooLarge(fileSizeBytes);
    }

    final currentQuota = state.quota;
    if (currentQuota == null) {
      return UploadPreflightResult.storageStateUnknown(fileSizeBytes);
    }

    if (fileSizeBytes > currentQuota.remainingBytes) {
      return UploadPreflightResult.insufficientStorage(
        fileSizeBytes: fileSizeBytes,
        remainingBytes: currentQuota.remainingBytes,
      );
    }

    return UploadPreflightResult.allowed(
      fileSizeBytes,
      remainingBytes: currentQuota.remainingBytes,
    );
  }

  /// Clears state upon sign-out.
  void clear() {
    state = const CloudStorageState();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

/// Provider managing the CloudStorageNotifier.
final cloudStorageProvider =
    StateNotifierProvider<CloudStorageNotifier, CloudStorageState>((ref) {
  final api = ref.watch(syncApiClientProvider);
  final db = ref.watch(databaseProvider);
  final auth = ref.watch(authServiceProvider);

  return CloudStorageNotifier(
    apiClient: api,
    database: db,
    authService: auth,
  );
});

/// Convenience provider returning the current user's CloudStorageQuota (or null if unauthenticated / not yet loaded).
final cloudStorageQuotaProvider = Provider<CloudStorageQuota?>((ref) {
  final state = ref.watch(cloudStorageProvider);
  return state.quota;
});

/// Convenience provider returning formatted subtitle summary for Settings row (e.g. "342 MB of 1 GB used").
final cloudStorageSubtitleProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return '1 GB Cloud Quota • Sign in to sync';
  }

  final state = ref.watch(cloudStorageProvider);
  final quota = state.quota;

  if (quota != null) {
    return quota.usageSummary;
  }

  if (state.isLoading) {
    return 'Loading storage...';
  }

  if (state.isOffline) {
    return 'Offline • Storage profile cached';
  }

  return 'Encrypted Cloud Storage';
});
