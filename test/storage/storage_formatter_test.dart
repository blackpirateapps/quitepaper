import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/storage/storage_formatter.dart';

void main() {
  group('StorageFormatter Tests (Decimal Accounting Units)', () {
    test('Formats zero and negative bytes correctly', () {
      expect(StorageFormatter.formatBytes(0), '0 B');
      expect(StorageFormatter.formatBytes(-50), '0 B');
    });

    test('Formats bytes under 1 KB without decimal', () {
      expect(StorageFormatter.formatBytes(1), '1 B');
      expect(StorageFormatter.formatBytes(500), '500 B');
      expect(StorageFormatter.formatBytes(999), '999 B');
    });

    test('Formats exact kilobytes and fractional kilobytes', () {
      expect(StorageFormatter.formatBytes(1000), '1 KB');
      expect(StorageFormatter.formatBytes(8000), '8 KB');
      expect(StorageFormatter.formatBytes(842000), '842 KB');
      expect(StorageFormatter.formatBytes(1500), '1.5 KB');
      expect(StorageFormatter.formatBytes(1234), '1.2 KB');
    });

    test('Formats megabytes with sensible precision', () {
      expect(StorageFormatter.formatBytes(1000000), '1 MB');
      expect(StorageFormatter.formatBytes(1200000), '1.2 MB');
      expect(StorageFormatter.formatBytes(10000000), '10 MB');
      expect(StorageFormatter.formatBytes(342000000), '342 MB');
      expect(StorageFormatter.formatBytes(824000000), '824 MB');
    });

    test('Formats gigabytes correctly', () {
      expect(StorageFormatter.formatBytes(1000000000), '1 GB');
      expect(StorageFormatter.formatBytes(1400000000), '1.4 GB');
      expect(StorageFormatter.formatBytes(2400000000), '2.4 GB');
      expect(StorageFormatter.formatBytes(10000000000), '10 GB');
      expect(StorageFormatter.formatBytes(9200000000), '9.2 GB');
    });

    test('formatBytesDetailed formats with precise decimal points', () {
      expect(StorageFormatter.formatBytesDetailed(0), '0 B');
      expect(StorageFormatter.formatBytesDetailed(1234), '1.23 KB');
      expect(StorageFormatter.formatBytesDetailed(1234567), '1.23 MB');
      expect(StorageFormatter.formatBytesDetailed(1234567890), '1.23 GB');
    });
  });
}
