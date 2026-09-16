import 'package:flutter/foundation.dart';
import 'storage_formatter.dart';

/// Supported user storage and entitlement plans.
enum StoragePlan {
  free('free', 'Free', 1000000000), // 1 GB = 1,000,000,000 bytes
  premium('premium', 'Premium', 10000000000); // 10 GB = 10,000,000,000 bytes

  const StoragePlan(this.identifier, this.displayName, this.defaultLimitBytes);

  final String identifier;
  final String displayName;
  final int defaultLimitBytes;

  static StoragePlan fromIdentifier(String? id) {
    if (id == null) return StoragePlan.free;
    final normalized = id.trim().toLowerCase();
    for (final plan in StoragePlan.values) {
      if (plan.identifier == normalized || plan.name == normalized) {
        return plan;
      }
    }
    return StoragePlan.free;
  }
}

/// Authoritative storage capacity constants.
/// Decimal units: 1 MB = 1,000,000 B, 1 GB = 1,000,000,000 B.
abstract class CloudStorageConstants {
  static const int bytesPerMb = 1000000;
  static const int bytesPerGb = 1000000000;

  /// Canonical maximum upload limit for an individual file (10 MB).
  /// Enforced client-side for UX preflight; backend remains authoritative.
  static const int maxUploadSizeBytes = 10 * bytesPerMb; // 10,000,000 bytes

  /// Free plan quota limit (1 GB).
  static const int freePlanLimitBytes = 1 * bytesPerGb; // 1,000,000,000 bytes

  /// Premium plan quota limit (10 GB).
  static const int premiumPlanLimitBytes = 10 * bytesPerGb; // 10,000,000,000 bytes

  /// Near-quota threshold ratio (80%).
  static const double nearQuotaThresholdRatio = 0.8;
}

/// Breakdown of cloud-backed encrypted resources.
@immutable
class StorageBreakdown {
  const StorageBreakdown({
    this.imageBytes = 0,
    this.imageCount = 0,
    this.documentBytes = 0,
    this.documentCount = 0,
    this.otherBytes = 0,
    this.otherCount = 0,
  });

  final int imageBytes;
  final int imageCount;
  final int documentBytes;
  final int documentCount;
  final int otherBytes;
  final int otherCount;

  int get totalBytes => imageBytes + documentBytes + otherBytes;
  int get totalCount => imageCount + documentCount + otherCount;

  String get imageFormatted => StorageFormatter.formatBytes(imageBytes);
  String get documentFormatted => StorageFormatter.formatBytes(documentBytes);
  String get otherFormatted => StorageFormatter.formatBytes(otherBytes);
  String get totalFormatted => StorageFormatter.formatBytes(totalBytes);

  Map<String, dynamic> toJson() => {
        'imageBytes': imageBytes,
        'imageCount': imageCount,
        'documentBytes': documentBytes,
        'documentCount': documentCount,
        'otherBytes': otherBytes,
        'otherCount': otherCount,
      };

  factory StorageBreakdown.fromJson(Map<String, dynamic> json) {
    return StorageBreakdown(
      imageBytes: json['imageBytes'] as int? ?? 0,
      imageCount: json['imageCount'] as int? ?? 0,
      documentBytes: json['documentBytes'] as int? ?? 0,
      documentCount: json['documentCount'] as int? ?? 0,
      otherBytes: json['otherBytes'] as int? ?? 0,
      otherCount: json['otherCount'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StorageBreakdown &&
          runtimeType == other.runtimeType &&
          imageBytes == other.imageBytes &&
          imageCount == other.imageCount &&
          documentBytes == other.documentBytes &&
          documentCount == other.documentCount &&
          otherBytes == other.otherBytes &&
          otherCount == other.otherCount;

  @override
  int get hashCode =>
      imageBytes.hashCode ^
      imageCount.hashCode ^
      documentBytes.hashCode ^
      documentCount.hashCode ^
      otherBytes.hashCode ^
      otherCount.hashCode;
}

/// Authoritative account storage quota and plan usage returned by the backend.
@immutable
class CloudStorageQuota {
  const CloudStorageQuota({
    required this.plan,
    required this.usedBytes,
    this.reservedBytes = 0,
    required this.limitBytes,
    this.serverRemainingBytes,
    this.serverIsOverQuota,
    this.serverOverQuotaBytes,
    this.serverUsageFraction,
    this.maxFileSizeBytes = CloudStorageConstants.maxUploadSizeBytes,
    this.lastFetchedAt,
    this.breakdown,
  });

  /// Default quota for free tier accounts.
  factory CloudStorageQuota.defaultFree({
    int usedBytes = 0,
    StorageBreakdown? breakdown,
  }) {
    return CloudStorageQuota(
      plan: StoragePlan.free,
      usedBytes: usedBytes,
      limitBytes: CloudStorageConstants.freePlanLimitBytes,
      breakdown: breakdown,
    );
  }

  /// Default quota for premium tier accounts.
  factory CloudStorageQuota.defaultPremium({
    int usedBytes = 0,
    StorageBreakdown? breakdown,
  }) {
    return CloudStorageQuota(
      plan: StoragePlan.premium,
      usedBytes: usedBytes,
      limitBytes: CloudStorageConstants.premiumPlanLimitBytes,
      breakdown: breakdown,
    );
  }

  final StoragePlan plan;
  final int usedBytes;
  final int reservedBytes;
  final int limitBytes;
  final int? serverRemainingBytes;
  final bool? serverIsOverQuota;
  final int? serverOverQuotaBytes;
  final double? serverUsageFraction;
  final int maxFileSizeBytes;
  final DateTime? lastFetchedAt;
  final StorageBreakdown? breakdown;

  /// Effective bytes remaining for new uploads before reaching capacity.
  int get remainingBytes {
    if (serverRemainingBytes != null) return serverRemainingBytes!;
    final totalCommittedAndReserved = usedBytes + reservedBytes;
    return totalCommittedAndReserved >= limitBytes
        ? 0
        : limitBytes - totalCommittedAndReserved;
  }

  /// True if committed usage strictly exceeds plan allowance (e.g. post-downgrade).
  bool get isOverQuota {
    if (serverIsOverQuota != null) return serverIsOverQuota!;
    return usedBytes > limitBytes;
  }

  /// Number of bytes exceeding plan limit if over quota; 0 otherwise.
  int get overQuotaBytes {
    if (serverOverQuotaBytes != null) return serverOverQuotaBytes!;
    return isOverQuota ? usedBytes - limitBytes : 0;
  }

  /// True if user is near capacity (>= 80%).
  bool get isNearQuota => rawUsageFraction >= CloudStorageConstants.nearQuotaThresholdRatio;

  /// True if storage is exactly full or over capacity (>= 100%).
  bool get isFull => usedBytes >= limitBytes;

  /// True if the user is on the Premium plan.
  bool get isPremium => plan == StoragePlan.premium;

  /// True if the user is on the Free plan.
  bool get isFree => plan == StoragePlan.free;

  /// Unclamped usage fraction (can exceed 1.0 if over quota).
  double get rawUsageFraction {
    if (serverUsageFraction != null) return serverUsageFraction!;
    if (limitBytes <= 0) return 1.0;
    return usedBytes / limitBytes;
  }

  /// Convenience alias for rawUsageFraction.
  double get usageFraction => rawUsageFraction;

  /// Visual progress clamped to [0.0, 1.0] for progress bars and gauges.
  double get visualProgress => rawUsageFraction.clamp(0.0, 1.0);

  /// User-facing formatted strings
  String get usedFormatted => StorageFormatter.formatBytes(usedBytes);
  String get limitFormatted => StorageFormatter.formatBytes(limitBytes);
  String get remainingFormatted => StorageFormatter.formatBytes(remainingBytes);
  String get overQuotaFormatted => StorageFormatter.formatBytes(overQuotaBytes);
  String get maxFileFormatted => StorageFormatter.formatBytes(maxFileSizeBytes);

  /// User-facing summary description (e.g. "342 MB of 1 GB used").
  String get usageSummary {
    final usedStr = usedFormatted;
    final limitStr = limitFormatted;
    return '$usedStr of $limitStr used';
  }

  /// User-facing remaining description (e.g. "658 MB remaining" or "8.2 GB over limit").
  String get remainingSummary {
    if (isOverQuota) {
      return '$overQuotaFormatted over your limit';
    }
    return '$remainingFormatted remaining';
  }

  CloudStorageQuota copyWith({
    StoragePlan? plan,
    int? usedBytes,
    int? reservedBytes,
    int? limitBytes,
    int? remainingBytes,
    bool? isOverQuota,
    int? overQuotaBytes,
    double? usageFraction,
    int? maxFileSizeBytes,
    DateTime? lastFetchedAt,
    StorageBreakdown? breakdown,
  }) {
    return CloudStorageQuota(
      plan: plan ?? this.plan,
      usedBytes: usedBytes ?? this.usedBytes,
      reservedBytes: reservedBytes ?? this.reservedBytes,
      limitBytes: limitBytes ?? this.limitBytes,
      serverRemainingBytes: remainingBytes ?? serverRemainingBytes,
      serverIsOverQuota: isOverQuota ?? serverIsOverQuota,
      serverOverQuotaBytes: overQuotaBytes ?? serverOverQuotaBytes,
      serverUsageFraction: usageFraction ?? serverUsageFraction,
      maxFileSizeBytes: maxFileSizeBytes ?? this.maxFileSizeBytes,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
      breakdown: breakdown ?? this.breakdown,
    );
  }

  Map<String, dynamic> toJson() => {
        'plan': plan.identifier,
        'usedBytes': usedBytes,
        'reservedBytes': reservedBytes,
        'limitBytes': limitBytes,
        'remainingBytes': remainingBytes,
        'isOverQuota': isOverQuota,
        'overQuotaBytes': overQuotaBytes,
        'usageFraction': rawUsageFraction,
        'maxFileSizeBytes': maxFileSizeBytes,
        if (lastFetchedAt != null) 'lastFetchedAt': lastFetchedAt!.toIso8601String(),
        if (breakdown != null) 'breakdown': breakdown!.toJson(),
      };

  factory CloudStorageQuota.fromJson(
    Map<String, dynamic> json, {
    DateTime? fetchedAt,
    StorageBreakdown? breakdown,
  }) {
    final plan = StoragePlan.fromIdentifier(json['plan'] as String?);
    final usedBytes = json['usedBytes'] as int? ?? 0;
    final reservedBytes = json['reservedBytes'] as int? ?? 0;
    final limitBytes = json['limitBytes'] as int? ?? plan.defaultLimitBytes;

    return CloudStorageQuota(
      plan: plan,
      usedBytes: usedBytes,
      reservedBytes: reservedBytes,
      limitBytes: limitBytes,
      serverRemainingBytes: json['remainingBytes'] as int?,
      serverIsOverQuota: json['isOverQuota'] as bool?,
      serverOverQuotaBytes: json['overQuotaBytes'] as int?,
      serverUsageFraction: (json['usageFraction'] as num?)?.toDouble(),
      maxFileSizeBytes: json['maxFileSizeBytes'] as int? ?? CloudStorageConstants.maxUploadSizeBytes,
      lastFetchedAt: fetchedAt ??
          (json['lastFetchedAt'] != null
              ? DateTime.tryParse(json['lastFetchedAt'] as String)
              : null),
      breakdown: breakdown ??
          (json['breakdown'] is Map<String, dynamic>
              ? StorageBreakdown.fromJson(json['breakdown'] as Map<String, dynamic>)
              : null),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CloudStorageQuota &&
          runtimeType == other.runtimeType &&
          plan == other.plan &&
          usedBytes == other.usedBytes &&
          reservedBytes == other.reservedBytes &&
          limitBytes == other.limitBytes &&
          remainingBytes == other.remainingBytes &&
          isOverQuota == other.isOverQuota &&
          overQuotaBytes == other.overQuotaBytes &&
          maxFileSizeBytes == other.maxFileSizeBytes &&
          breakdown == other.breakdown;

  @override
  int get hashCode =>
      plan.hashCode ^
      usedBytes.hashCode ^
      reservedBytes.hashCode ^
      limitBytes.hashCode ^
      remainingBytes.hashCode ^
      isOverQuota.hashCode ^
      overQuotaBytes.hashCode ^
      maxFileSizeBytes.hashCode ^
      breakdown.hashCode;
}

/// Client-side preflight evaluation result for a file upload.
enum PreflightStatus {
  allowed,
  fileTooLarge,
  insufficientStorage,
  storageStateUnknown,
}

@immutable
class UploadPreflightResult {
  const UploadPreflightResult._({
    required this.status,
    required this.fileSizeBytes,
    this.errorMessage,
    this.maxFileSizeBytes = CloudStorageConstants.maxUploadSizeBytes,
    this.remainingBytes,
  });

  final PreflightStatus status;
  final int fileSizeBytes;
  final String? errorMessage;
  final int maxFileSizeBytes;
  final int? remainingBytes;

  bool get isAllowed => status == PreflightStatus.allowed || status == PreflightStatus.storageStateUnknown;
  bool get isFileTooLarge => status == PreflightStatus.fileTooLarge;
  bool get isInsufficientStorage => status == PreflightStatus.insufficientStorage;
  String? get userMessage => errorMessage;

  factory UploadPreflightResult.allowed(int fileSizeBytes, {int? remainingBytes}) {
    return UploadPreflightResult._(
      status: PreflightStatus.allowed,
      fileSizeBytes: fileSizeBytes,
      remainingBytes: remainingBytes,
    );
  }

  factory UploadPreflightResult.fileTooLarge(int fileSizeBytes, {int maxBytes = CloudStorageConstants.maxUploadSizeBytes}) {
    final sizeStr = StorageFormatter.formatBytes(fileSizeBytes);
    final maxStr = StorageFormatter.formatBytes(maxBytes);
    return UploadPreflightResult._(
      status: PreflightStatus.fileTooLarge,
      fileSizeBytes: fileSizeBytes,
      maxFileSizeBytes: maxBytes,
      errorMessage: 'This file is $sizeStr. Quiet Paper supports files up to $maxStr.',
    );
  }

  factory UploadPreflightResult.insufficientStorage({
    required int fileSizeBytes,
    required int remainingBytes,
  }) {
    final sizeStr = StorageFormatter.formatBytes(fileSizeBytes);
    final remainingStr = StorageFormatter.formatBytes(remainingBytes);
    return UploadPreflightResult._(
      status: PreflightStatus.insufficientStorage,
      fileSizeBytes: fileSizeBytes,
      remainingBytes: remainingBytes,
      errorMessage: 'Not enough cloud storage. You have $remainingStr remaining, but this file needs $sizeStr.',
    );
  }

  factory UploadPreflightResult.storageStateUnknown(int fileSizeBytes) {
    return UploadPreflightResult._(
      status: PreflightStatus.storageStateUnknown,
      fileSizeBytes: fileSizeBytes,
    );
  }
}
