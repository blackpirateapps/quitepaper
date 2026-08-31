import 'package:flutter/foundation.dart';

/// Performance snapshot and metrics report for scanner operations.
@immutable
class ScannerPerformanceReport {
  const ScannerPerformanceReport({
    required this.previewCreationMs,
    required this.thumbnailCreationMs,
    required this.pageSwitchMs,
    required this.pdfCompilationMs,
    required this.highResProcessingMs,
    required this.discardedStaleJobsCount,
    required this.activeGenerationsCount,
  });

  final double previewCreationMs;
  final double thumbnailCreationMs;
  final double pageSwitchMs;
  final double pdfCompilationMs;
  final double highResProcessingMs;
  final int discardedStaleJobsCount;
  final int activeGenerationsCount;

  @override
  String toString() {
    return 'ScannerPerformanceReport(preview: ${previewCreationMs.toStringAsFixed(1)}ms, '
        'thumbnail: ${thumbnailCreationMs.toStringAsFixed(1)}ms, '
        'switch: ${pageSwitchMs.toStringAsFixed(1)}ms, '
        'pdf: ${pdfCompilationMs.toStringAsFixed(1)}ms, '
        'highRes: ${highResProcessingMs.toStringAsFixed(1)}ms, '
        'discardedStaleJobs: $discardedStaleJobsCount)';
  }
}

/// Lightweight runtime performance and race condition instrumentation tracker for document scanning.
class ScannerPerformanceTracker {
  ScannerPerformanceTracker();

  final List<double> _previewCreationTimes = [];
  final List<double> _thumbnailCreationTimes = [];
  final List<double> _pageSwitchTimes = [];
  final List<double> _pdfCompilationTimes = [];
  final List<double> _highResProcessingTimes = [];

  int _discardedStaleJobs = 0;
  int _currentGeneration = 0;

  /// Starts a new generation token for asynchronous jobs.
  int nextGeneration() => ++_currentGeneration;

  /// Returns the current active generation token.
  int get currentGeneration => _currentGeneration;

  /// Total count of stale out-of-order asynchronous results safely discarded.
  int get discardedStaleJobsCount => _discardedStaleJobs;

  /// Validates whether a finished async [generation] matches the current active token.
  /// If not current, increments the discarded count and returns `false`.
  bool isGenerationCurrent(int generation) {
    if (generation != _currentGeneration) {
      _discardedStaleJobs++;
      return false;
    }
    return true;
  }

  void recordPreviewCreation(double ms) {
    _previewCreationTimes.add(ms);
  }

  void recordThumbnailCreation(double ms) {
    _thumbnailCreationTimes.add(ms);
  }

  void recordPageSwitch(double ms) {
    _pageSwitchTimes.add(ms);
  }

  void recordPdfCompilation(double ms) {
    _pdfCompilationTimes.add(ms);
  }

  void recordHighResProcessing(double ms) {
    _highResProcessingTimes.add(ms);
  }

  void recordDiscardedJob() {
    _discardedStaleJobs++;
  }

  ScannerPerformanceReport getReport() {
    double avg(List<double> list) =>
        list.isEmpty ? 0.0 : list.reduce((a, b) => a + b) / list.length;

    return ScannerPerformanceReport(
      previewCreationMs: avg(_previewCreationTimes),
      thumbnailCreationMs: avg(_thumbnailCreationTimes),
      pageSwitchMs: avg(_pageSwitchTimes),
      pdfCompilationMs: avg(_pdfCompilationTimes),
      highResProcessingMs: avg(_highResProcessingTimes),
      discardedStaleJobsCount: _discardedStaleJobs,
      activeGenerationsCount: _currentGeneration,
    );
  }

  void reset() {
    _previewCreationTimes.clear();
    _thumbnailCreationTimes.clear();
    _pageSwitchTimes.clear();
    _pdfCompilationTimes.clear();
    _highResProcessingTimes.clear();
    _discardedStaleJobs = 0;
    _currentGeneration = 0;
  }
}
