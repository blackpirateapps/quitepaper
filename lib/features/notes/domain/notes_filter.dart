import 'package:flutter/foundation.dart';

/// Context in which notes are being viewed
enum NotesContext {
  active,
  archive,
  trash;

  String get displayName {
    switch (this) {
      case NotesContext.active:
        return 'Notes';
      case NotesContext.archive:
        return 'Archive';
      case NotesContext.trash:
        return 'Trash';
    }
  }

  static NotesContext fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'archive':
      case 'archived':
        return NotesContext.archive;
      case 'trash':
      case 'trashed':
        return NotesContext.trash;
      case 'active':
      default:
        return NotesContext.active;
    }
  }
}

/// Tag matching strategy when multiple tags are selected
enum TagMatchMode {
  all,
  any;

  String get displayName => this == TagMatchMode.all ? 'All (AND)' : 'Any (OR)';

  static TagMatchMode fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'any':
      case 'or':
        return TagMatchMode.any;
      case 'all':
      case 'and':
      default:
        return TagMatchMode.all;
    }
  }
}

/// Pre-configured and custom date filter presets
enum DateFilterType {
  today,
  yesterday,
  last7Days,
  last30Days,
  thisYear,
  custom;

  String get displayName {
    switch (this) {
      case DateFilterType.today:
        return 'Today';
      case DateFilterType.yesterday:
        return 'Yesterday';
      case DateFilterType.last7Days:
        return 'Last 7 days';
      case DateFilterType.last30Days:
        return 'Last 30 days';
      case DateFilterType.thisYear:
        return 'This year';
      case DateFilterType.custom:
        return 'Custom range';
    }
  }

  static DateFilterType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'today':
        return DateFilterType.today;
      case 'yesterday':
        return DateFilterType.yesterday;
      case 'last7days':
      case 'last_7_days':
        return DateFilterType.last7Days;
      case 'last30days':
      case 'last_30_days':
        return DateFilterType.last30Days;
      case 'thisyear':
      case 'this_year':
        return DateFilterType.thisYear;
      case 'custom':
      default:
        return DateFilterType.custom;
    }
  }
}

/// Typed date range specification calculating half-open `[start, endExclusive)` boundaries
@immutable
class DateFilterRange {
  const DateFilterRange({
    required this.type,
    this.customFrom,
    this.customTo,
  });

  final DateFilterType type;
  final DateTime? customFrom;
  final DateTime? customTo;

  /// Returns half-open interval `[start, endExclusive)` respecting local calendar boundaries
  ({DateTime start, DateTime endExclusive}) getBounds([DateTime? referenceTime]) {
    final now = referenceTime ?? DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final tomorrowMidnight = todayMidnight.add(const Duration(days: 1));

    switch (type) {
      case DateFilterType.today:
        return (
          start: todayMidnight,
          endExclusive: tomorrowMidnight,
        );
      case DateFilterType.yesterday:
        final yesterdayMidnight = todayMidnight.subtract(const Duration(days: 1));
        return (
          start: yesterdayMidnight,
          endExclusive: todayMidnight,
        );
      case DateFilterType.last7Days:
        final sevenDaysAgo = todayMidnight.subtract(const Duration(days: 6));
        return (
          start: sevenDaysAgo,
          endExclusive: tomorrowMidnight,
        );
      case DateFilterType.last30Days:
        final thirtyDaysAgo = todayMidnight.subtract(const Duration(days: 29));
        return (
          start: thirtyDaysAgo,
          endExclusive: tomorrowMidnight,
        );
      case DateFilterType.thisYear:
        final startOfYear = DateTime(now.year, 1, 1);
        final startOfNextYear = DateTime(now.year + 1, 1, 1);
        return (
          start: startOfYear,
          endExclusive: startOfNextYear,
        );
      case DateFilterType.custom:
        final from = customFrom ?? DateTime(1970, 1, 1);
        final to = customTo ?? now;
        final start = DateTime(from.year, from.month, from.day);
        final endExclusive = DateTime(to.year, to.month, to.day).add(const Duration(days: 1));
        return (
          start: start,
          endExclusive: endExclusive,
        );
    }
  }

  String get displayName {
    if (type == DateFilterType.custom) {
      final f = customFrom != null ? '${customFrom!.year}-${customFrom!.month.toString().padLeft(2, '0')}-${customFrom!.day.toString().padLeft(2, '0')}' : 'start';
      final t = customTo != null ? '${customTo!.year}-${customTo!.month.toString().padLeft(2, '0')}-${customTo!.day.toString().padLeft(2, '0')}' : 'now';
      return '$f – $t';
    }
    return type.displayName;
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      if (customFrom != null) 'customFrom': customFrom!.toIso8601String(),
      if (customTo != null) 'customTo': customTo!.toIso8601String(),
    };
  }

  factory DateFilterRange.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DateFilterRange(type: DateFilterType.last30Days);
    return DateFilterRange(
      type: DateFilterType.fromString(json['type'] as String?),
      customFrom: json['customFrom'] != null ? DateTime.tryParse(json['customFrom'] as String) : null,
      customTo: json['customTo'] != null ? DateTime.tryParse(json['customTo'] as String) : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateFilterRange &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          customFrom == other.customFrom &&
          customTo == other.customTo;

  @override
  int get hashCode => type.hashCode ^ customFrom.hashCode ^ customTo.hashCode;
}

/// Content-derived predicates
enum ContentFilter {
  hasCode,
  hasChecklist,
  hasIncompleteTasks,
  hasCompletedTasks,
  hasLinks;

  String get displayName {
    switch (this) {
      case ContentFilter.hasCode:
        return 'Code';
      case ContentFilter.hasChecklist:
        return 'Checklists';
      case ContentFilter.hasIncompleteTasks:
        return 'Incomplete tasks';
      case ContentFilter.hasCompletedTasks:
        return 'Completed tasks';
      case ContentFilter.hasLinks:
        return 'Links';
    }
  }

  static ContentFilter? fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'hascode':
      case 'has_code':
        return ContentFilter.hasCode;
      case 'haschecklist':
      case 'has_checklist':
        return ContentFilter.hasChecklist;
      case 'hasincompletetasks':
      case 'has_incomplete_tasks':
        return ContentFilter.hasIncompleteTasks;
      case 'hascompletedtasks':
      case 'has_completed_tasks':
        return ContentFilter.hasCompletedTasks;
      case 'haslinks':
      case 'has_links':
        return ContentFilter.hasLinks;
      default:
        return null;
    }
  }
}

/// Attachment and media relationship predicates
enum AttachmentFilter {
  hasAttachments,
  hasImages,
  hasDocuments,
  hasOcr;

  String get displayName {
    switch (this) {
      case AttachmentFilter.hasAttachments:
        return 'Attachments';
      case AttachmentFilter.hasImages:
        return 'Images';
      case AttachmentFilter.hasDocuments:
        return 'Documents';
      case AttachmentFilter.hasOcr:
        return 'OCR text';
    }
  }

  static AttachmentFilter? fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'hasattachments':
      case 'has_attachments':
        return AttachmentFilter.hasAttachments;
      case 'hasimages':
      case 'has_images':
        return AttachmentFilter.hasImages;
      case 'hasdocuments':
      case 'has_documents':
        return AttachmentFilter.hasDocuments;
      case 'hasocr':
      case 'has_ocr':
        return AttachmentFilter.hasOcr;
      default:
        return null;
    }
  }
}

/// Security state predicate
enum SecurityFilter {
  all,
  protectedOnly,
  unprotectedOnly;

  String get displayName {
    switch (this) {
      case SecurityFilter.all:
        return 'All notes';
      case SecurityFilter.protectedOnly:
        return 'Protected only';
      case SecurityFilter.unprotectedOnly:
        return 'Unprotected only';
    }
  }

  static SecurityFilter fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'protectedonly':
      case 'protected_only':
      case 'protected':
        return SecurityFilter.protectedOnly;
      case 'unprotectedonly':
      case 'unprotected_only':
      case 'unprotected':
        return SecurityFilter.unprotectedOnly;
      case 'all':
      default:
        return SecurityFilter.all;
    }
  }
}

/// Immutable collection of structured filtering predicates
@immutable
class NotesFilter {
  const NotesFilter({
    this.tags = const {},
    this.tagMatchMode = TagMatchMode.all,
    this.untaggedOnly = false,
    this.pinnedOnly = false,
    this.createdRange,
    this.modifiedRange,
    this.contentFilters = const {},
    this.attachmentFilters = const {},
    this.securityFilter = SecurityFilter.all,
  });

  final Set<String> tags;
  final TagMatchMode tagMatchMode;
  final bool untaggedOnly;
  final bool pinnedOnly;
  final DateFilterRange? createdRange;
  final DateFilterRange? modifiedRange;
  final Set<ContentFilter> contentFilters;
  final Set<AttachmentFilter> attachmentFilters;
  final SecurityFilter securityFilter;

  /// Clean empty filter state
  static const empty = NotesFilter();

  /// Whether no filter predicates are currently active
  bool get isEmpty =>
      tags.isEmpty &&
      !untaggedOnly &&
      !pinnedOnly &&
      createdRange == null &&
      modifiedRange == null &&
      contentFilters.isEmpty &&
      attachmentFilters.isEmpty &&
      securityFilter == SecurityFilter.all;

  /// Whether any advanced filter predicate is active (excluding the single active tag from the tag bar)
  bool get hasAdvancedFilters =>
      tags.length > 1 ||
      untaggedOnly ||
      pinnedOnly ||
      createdRange != null ||
      modifiedRange != null ||
      contentFilters.isNotEmpty ||
      attachmentFilters.isNotEmpty ||
      securityFilter != SecurityFilter.all;

  /// Count of active advanced filter categories (excluding standard single tag-bar selection)
  int get advancedFilterCount {
    var count = 0;
    if (tags.length > 1) count += (tags.length - 1);
    if (untaggedOnly) count++;
    if (pinnedOnly) count++;
    if (createdRange != null) count++;
    if (modifiedRange != null) count++;
    count += contentFilters.length;
    count += attachmentFilters.length;
    if (securityFilter != SecurityFilter.all) count++;
    return count;
  }

  /// Count of active filter categories
  int get activeFilterCount {
    var count = 0;
    if (tags.isNotEmpty) count += tags.length;
    if (untaggedOnly) count++;
    if (pinnedOnly) count++;
    if (createdRange != null) count++;
    if (modifiedRange != null) count++;
    count += contentFilters.length;
    count += attachmentFilters.length;
    if (securityFilter != SecurityFilter.all) count++;
    return count;
  }

  /// Returns a copy with all advanced predicates cleared, preserving tag selection if requested
  NotesFilter clearAdvancedFilters({bool keepTags = false}) {
    return NotesFilter(
      tags: keepTags ? tags : const {},
      tagMatchMode: TagMatchMode.all,
      untaggedOnly: false,
      pinnedOnly: false,
      createdRange: null,
      modifiedRange: null,
      contentFilters: const {},
      attachmentFilters: const {},
      securityFilter: SecurityFilter.all,
    );
  }

  NotesFilter copyWith({
    Set<String>? tags,
    TagMatchMode? tagMatchMode,
    bool? untaggedOnly,
    bool? pinnedOnly,
    DateFilterRange? createdRange,
    bool clearCreatedRange = false,
    DateFilterRange? modifiedRange,
    bool clearModifiedRange = false,
    Set<ContentFilter>? contentFilters,
    Set<AttachmentFilter>? attachmentFilters,
    SecurityFilter? securityFilter,
  }) {
    return NotesFilter(
      tags: tags ?? this.tags,
      tagMatchMode: tagMatchMode ?? this.tagMatchMode,
      untaggedOnly: untaggedOnly ?? this.untaggedOnly,
      pinnedOnly: pinnedOnly ?? this.pinnedOnly,
      createdRange: clearCreatedRange ? null : (createdRange ?? this.createdRange),
      modifiedRange: clearModifiedRange ? null : (modifiedRange ?? this.modifiedRange),
      contentFilters: contentFilters ?? this.contentFilters,
      attachmentFilters: attachmentFilters ?? this.attachmentFilters,
      securityFilter: securityFilter ?? this.securityFilter,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tags': tags.toList(),
      'tagMatchMode': tagMatchMode.name,
      'untaggedOnly': untaggedOnly,
      'pinnedOnly': pinnedOnly,
      if (createdRange != null) 'createdRange': createdRange!.toJson(),
      if (modifiedRange != null) 'modifiedRange': modifiedRange!.toJson(),
      'contentFilters': contentFilters.map((e) => e.name).toList(),
      'attachmentFilters': attachmentFilters.map((e) => e.name).toList(),
      'securityFilter': securityFilter.name,
    };
  }

  factory NotesFilter.fromJson(Map<String, dynamic>? json) {
    if (json == null) return empty;

    final tagsList = (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toSet() ?? const {};
    final contentList = (json['contentFilters'] as List<dynamic>?)
            ?.map((e) => ContentFilter.fromString(e.toString()))
            .whereType<ContentFilter>()
            .toSet() ??
        const {};
    final attachmentList = (json['attachmentFilters'] as List<dynamic>?)
            ?.map((e) => AttachmentFilter.fromString(e.toString()))
            .whereType<AttachmentFilter>()
            .toSet() ??
        const {};

    return NotesFilter(
      tags: tagsList,
      tagMatchMode: TagMatchMode.fromString(json['tagMatchMode'] as String?),
      untaggedOnly: json['untaggedOnly'] as bool? ?? false,
      pinnedOnly: json['pinnedOnly'] as bool? ?? false,
      createdRange: json['createdRange'] != null
          ? DateFilterRange.fromJson(json['createdRange'] as Map<String, dynamic>)
          : null,
      modifiedRange: json['modifiedRange'] != null
          ? DateFilterRange.fromJson(json['modifiedRange'] as Map<String, dynamic>)
          : null,
      contentFilters: contentList,
      attachmentFilters: attachmentList,
      securityFilter: SecurityFilter.fromString(json['securityFilter'] as String?),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotesFilter &&
          runtimeType == other.runtimeType &&
          setEquals(tags, other.tags) &&
          tagMatchMode == other.tagMatchMode &&
          untaggedOnly == other.untaggedOnly &&
          pinnedOnly == other.pinnedOnly &&
          createdRange == other.createdRange &&
          modifiedRange == other.modifiedRange &&
          setEquals(contentFilters, other.contentFilters) &&
          setEquals(attachmentFilters, other.attachmentFilters) &&
          securityFilter == other.securityFilter;

  @override
  int get hashCode =>
      Object.hashAll(tags) ^
      tagMatchMode.hashCode ^
      untaggedOnly.hashCode ^
      pinnedOnly.hashCode ^
      createdRange.hashCode ^
      modifiedRange.hashCode ^
      Object.hashAll(contentFilters) ^
      Object.hashAll(attachmentFilters) ^
      securityFilter.hashCode;
}
