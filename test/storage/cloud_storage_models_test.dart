import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/storage/cloud_storage_exceptions.dart';
import 'package:quitepaper/core/storage/cloud_storage_models.dart';

void main() {
  group('CloudStorageModels Tests', () {
    test('StoragePlan enum parses identifiers and defaults correctly', () {
      expect(StoragePlan.fromIdentifier('free'), StoragePlan.free);
      expect(StoragePlan.fromIdentifier('FREE'), StoragePlan.free);
      expect(StoragePlan.fromIdentifier('premium'), StoragePlan.premium);
      expect(StoragePlan.fromIdentifier('Premium'), StoragePlan.premium);
      expect(StoragePlan.fromIdentifier(null), StoragePlan.free);
      expect(StoragePlan.fromIdentifier('unknown'), StoragePlan.free);

      expect(StoragePlan.free.defaultLimitBytes, 1000000000);
      expect(StoragePlan.premium.defaultLimitBytes, 10000000000);
    });

    test('CloudStorageConstants holds canonical decimal sizes', () {
      expect(CloudStorageConstants.bytesPerMb, 1000000);
      expect(CloudStorageConstants.bytesPerGb, 1000000000);
      expect(CloudStorageConstants.maxUploadSizeBytes, 10000000); // 10 MB
      expect(CloudStorageConstants.freePlanLimitBytes, 1000000000); // 1 GB
      expect(CloudStorageConstants.premiumPlanLimitBytes, 10000000000); // 10 GB
      expect(CloudStorageConstants.nearQuotaThresholdRatio, 0.8);
    });

    test('StorageBreakdown calculates totals and serializes to/from JSON', () {
      const breakdown = StorageBreakdown(
        imageBytes: 284000000,
        imageCount: 23,
        documentBytes: 42000000,
        documentCount: 4,
        otherBytes: 16000000,
        otherCount: 7,
      );

      expect(breakdown.totalBytes, 342000000);
      expect(breakdown.totalCount, 34);
      expect(breakdown.imageFormatted, '284 MB');
      expect(breakdown.documentFormatted, '42 MB');
      expect(breakdown.otherFormatted, '16 MB');
      expect(breakdown.totalFormatted, '342 MB');

      final json = breakdown.toJson();
      final fromJson = StorageBreakdown.fromJson(json);
      expect(fromJson, equals(breakdown));
    });

    test('CloudStorageQuota normal usage state (342 MB of 1 GB)', () {
      final quota = CloudStorageQuota(
        plan: StoragePlan.free,
        usedBytes: 342000000,
        limitBytes: 1000000000,
      );

      expect(quota.isFree, isTrue);
      expect(quota.isPremium, isFalse);
      expect(quota.remainingBytes, 658000000);
      expect(quota.isOverQuota, isFalse);
      expect(quota.overQuotaBytes, 0);
      expect(quota.isNearQuota, isFalse);
      expect(quota.isFull, isFalse);
      expect(quota.usageFraction, closeTo(0.342, 0.001));
      expect(quota.visualProgress, closeTo(0.342, 0.001));
      expect(quota.usedFormatted, '342 MB');
      expect(quota.limitFormatted, '1 GB');
      expect(quota.remainingFormatted, '658 MB');
      expect(quota.usageSummary, '342 MB of 1 GB used');
      expect(quota.remainingSummary, '658 MB remaining');
    });

    test('CloudStorageQuota near quota state (>= 80%)', () {
      final quota = CloudStorageQuota(
        plan: StoragePlan.free,
        usedBytes: 824000000,
        limitBytes: 1000000000,
      );

      expect(quota.isNearQuota, isTrue);
      expect(quota.isFull, isFalse);
      expect(quota.isOverQuota, isFalse);
      expect(quota.remainingBytes, 176000000);
      expect(quota.remainingFormatted, '176 MB');
    });

    test('CloudStorageQuota full quota state (1 GB of 1 GB)', () {
      final quota = CloudStorageQuota(
        plan: StoragePlan.free,
        usedBytes: 1000000000,
        limitBytes: 1000000000,
      );

      expect(quota.isFull, isTrue);
      expect(quota.isOverQuota, isFalse);
      expect(quota.remainingBytes, 0);
      expect(quota.remainingFormatted, '0 B');
    });

    test('CloudStorageQuota over quota state after downgrade (9.2 GB of 1 GB)', () {
      final quota = CloudStorageQuota(
        plan: StoragePlan.free,
        usedBytes: 9200000000,
        limitBytes: 1000000000,
      );

      expect(quota.isOverQuota, isTrue);
      expect(quota.isFull, isTrue);
      expect(quota.overQuotaBytes, 8200000000);
      expect(quota.remainingBytes, 0);
      expect(quota.visualProgress, 1.0);
      expect(quota.usageFraction, closeTo(9.2, 0.01));
      expect(quota.overQuotaFormatted, '8.2 GB');
      expect(quota.remainingSummary, '8.2 GB over your limit');
    });

    test('CloudStorageQuota Premium tier default & JSON serialization', () {
      final quota = CloudStorageQuota.defaultPremium(usedBytes: 2400000000);

      expect(quota.isPremium, isTrue);
      expect(quota.limitBytes, 10000000000);
      expect(quota.remainingBytes, 7600000000);
      expect(quota.usageSummary, '2.4 GB of 10 GB used');
      expect(quota.remainingSummary, '7.6 GB remaining');

      final json = quota.toJson();
      final fromJson = CloudStorageQuota.fromJson(json);
      expect(fromJson.plan, StoragePlan.premium);
      expect(fromJson.usedBytes, 2400000000);
      expect(fromJson.limitBytes, 10000000000);
    });

    test('UploadPreflightResult validation rules', () {
      // 1. Allowed within quota
      final resAllowed = UploadPreflightResult.allowed(5000000, remainingBytes: 10000000);
      expect(resAllowed.isAllowed, isTrue);
      expect(resAllowed.status, PreflightStatus.allowed);

      // 2. File too large (> 10 MB)
      final resTooLarge = UploadPreflightResult.fileTooLarge(14200000);
      expect(resTooLarge.isAllowed, isFalse);
      expect(resTooLarge.status, PreflightStatus.fileTooLarge);
      expect(resTooLarge.userMessage, contains('supports files up to 10 MB'));
      expect(resTooLarge.userMessage, contains('14.2 MB'));

      // 3. Insufficient storage
      final resNoSpace = UploadPreflightResult.insufficientStorage(
        fileSizeBytes: 42000000,
        remainingBytes: 18000000,
      );
      expect(resNoSpace.isAllowed, isFalse);
      expect(resNoSpace.status, PreflightStatus.insufficientStorage);
      expect(resNoSpace.userMessage, contains('Not enough cloud storage'));
      expect(resNoSpace.userMessage, contains('18 MB remaining'));
      expect(resNoSpace.userMessage, contains('needs 42 MB'));
    });

    test('Domain Exceptions provide calm, clear user messages', () {
      final quotaEx = StorageQuotaExceededException(
        message: 'Storage full',
        usedBytes: 1000000000,
        limitBytes: 1000000000,
        requiredBytes: 5000000,
        remainingBytes: 0,
      );
      expect(quotaEx.userFriendlyMessage, contains('Not enough cloud storage'));

      final sizeEx = FileTooLargeException(
        message: 'Too big',
        providedBytes: 15000000,
        maxBytes: 10000000,
      );
      expect(sizeEx.userFriendlyMessage, contains('15 MB'));
      expect(sizeEx.userFriendlyMessage, contains('10 MB'));
    });
  });
}
