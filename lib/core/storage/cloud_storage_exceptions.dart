import 'cloud_storage_models.dart';
import 'storage_formatter.dart';

/// Exception thrown when an upload is blocked because the user's cloud storage quota is exceeded.
class StorageQuotaExceededException implements Exception {
  const StorageQuotaExceededException({
    required this.message,
    this.plan = StoragePlan.free,
    this.usedBytes = 0,
    this.reservedBytes = 0,
    this.limitBytes = CloudStorageConstants.freePlanLimitBytes,
    this.remainingBytes = 0,
    this.requiredBytes = 0,
  });

  final String message;
  final StoragePlan plan;
  final int usedBytes;
  final int reservedBytes;
  final int limitBytes;
  final int remainingBytes;
  final int requiredBytes;

  /// User-friendly explanation adapted to Quiet Paper's calm editorial style.
  String get userFriendlyMessage {
    if (requiredBytes > 0 && remainingBytes >= 0) {
      final remStr = StorageFormatter.formatBytes(remainingBytes);
      final reqStr = StorageFormatter.formatBytes(requiredBytes);
      return 'Not enough cloud storage. You have $remStr remaining, but this file needs $reqStr.';
    }
    final limitStr = StorageFormatter.formatBytes(limitBytes);
    return 'Cloud storage is full. You\'ve used all $limitStr available on your ${plan.displayName} plan.';
  }

  factory StorageQuotaExceededException.fromJson(Map<String, dynamic> json, {String? defaultMessage}) {
    final details = (json['error'] is Map<String, dynamic> ? json['error']['details'] : null) ??
        (json['details'] is Map<String, dynamic> ? json['details'] : null);

    final msg = json['error']?['message'] as String? ??
        json['message'] as String? ??
        defaultMessage ??
        'Storage quota exceeded.';

    final planStr = details?['plan'] as String?;
    final used = details?['usedBytes'] as int? ?? 0;
    final reserved = details?['reservedBytes'] as int? ?? 0;
    final limit = details?['limitBytes'] as int? ?? CloudStorageConstants.freePlanLimitBytes;
    final remaining = details?['remainingBytes'] as int? ?? 0;
    final required = details?['requiredBytes'] as int? ?? 0;

    return StorageQuotaExceededException(
      message: msg,
      plan: StoragePlan.fromIdentifier(planStr),
      usedBytes: used,
      reservedBytes: reserved,
      limitBytes: limit,
      remainingBytes: remaining,
      requiredBytes: required,
    );
  }

  @override
  String toString() => message;
}

/// Exception thrown when a file exceeds the maximum individual file size limit (10 MB).
class FileTooLargeException implements Exception {
  const FileTooLargeException({
    required this.message,
    this.maxBytes = CloudStorageConstants.maxUploadSizeBytes,
    this.providedBytes = 0,
  });

  final String message;
  final int maxBytes;
  final int providedBytes;

  /// User-friendly explanation adapted to Quiet Paper's calm editorial style.
  String get userFriendlyMessage {
    final maxStr = StorageFormatter.formatBytes(maxBytes);
    if (providedBytes > 0) {
      final provStr = StorageFormatter.formatBytes(providedBytes);
      return 'This file is $provStr. Quiet Paper supports files up to $maxStr.';
    }
    return 'File exceeds maximum upload limit of $maxStr.';
  }

  factory FileTooLargeException.fromJson(Map<String, dynamic> json, {String? defaultMessage}) {
    final details = (json['error'] is Map<String, dynamic> ? json['error']['details'] : null) ??
        (json['details'] is Map<String, dynamic> ? json['details'] : null);

    final msg = json['error']?['message'] as String? ??
        json['message'] as String? ??
        defaultMessage ??
        'File too large.';

    final max = details?['maxBytes'] as int? ?? CloudStorageConstants.maxUploadSizeBytes;
    final provided = details?['providedBytes'] as int? ?? 0;

    return FileTooLargeException(
      message: msg,
      maxBytes: max,
      providedBytes: provided,
    );
  }

  @override
  String toString() => message;
}
