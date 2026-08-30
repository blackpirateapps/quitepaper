import 'package:flutter/foundation.dart';

/// Type of maintenance task being executed.
enum MaintenanceTaskType {
  downloadAttachments,
  rerunOcr,
  rebuildSearchIndex,
}

/// Lifecycle phase of an active maintenance task.
enum MaintenancePhase {
  idle,
  preparing,
  downloading,
  runningOcr,
  rebuildingIndex,
  completed,
  cancelled,
  failed,
}

/// Live progress snapshot of a maintenance operation.
@immutable
class MaintenanceProgress {
  const MaintenanceProgress({
    required this.taskType,
    required this.phase,
    this.totalItems = 0,
    this.completedItems = 0,
    this.failedItems = 0,
    this.currentItemName = '',
    this.currentPage = 0,
    this.totalPages = 0,
    this.statusMessage = '',
    this.errorMessages = const [],
  });

  final MaintenanceTaskType taskType;
  final MaintenancePhase phase;
  final int totalItems;
  final int completedItems;
  final int failedItems;
  final String currentItemName;
  final int currentPage;
  final int totalPages;
  final String statusMessage;
  final List<String> errorMessages;

  double get progressFraction {
    if (totalItems > 0) {
      return (completedItems / totalItems).clamp(0.0, 1.0);
    }
    if (phase == MaintenancePhase.completed) return 1.0;
    return 0.0;
  }

  bool get isRunning =>
      phase == MaintenancePhase.preparing ||
      phase == MaintenancePhase.downloading ||
      phase == MaintenancePhase.runningOcr ||
      phase == MaintenancePhase.rebuildingIndex;

  bool get isFinished =>
      phase == MaintenancePhase.completed ||
      phase == MaintenancePhase.cancelled ||
      phase == MaintenancePhase.failed;

  bool get hasErrors => failedItems > 0 || errorMessages.isNotEmpty;

  MaintenanceProgress copyWith({
    MaintenanceTaskType? taskType,
    MaintenancePhase? phase,
    int? totalItems,
    int? completedItems,
    int? failedItems,
    String? currentItemName,
    int? currentPage,
    int? totalPages,
    String? statusMessage,
    List<String>? errorMessages,
  }) {
    return MaintenanceProgress(
      taskType: taskType ?? this.taskType,
      phase: phase ?? this.phase,
      totalItems: totalItems ?? this.totalItems,
      completedItems: completedItems ?? this.completedItems,
      failedItems: failedItems ?? this.failedItems,
      currentItemName: currentItemName ?? this.currentItemName,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessages: errorMessages ?? this.errorMessages,
    );
  }
}

/// Cancellation token to cooperatively stop long-running maintenance tasks.
class MaintenanceCancellationToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}
