import 'package:flutter/foundation.dart';

/// Visibility tier for a public note share.
enum ShareVisibility {
  /// Reachable by URL; intended to be discoverable/indexable.
  public('public', 'Public'),

  /// Reachable only by the unguessable URL; not intended for indexing.
  unlisted('unlisted', 'Unlisted'),

  /// Page text is encrypted at rest; visitors must enter a password to read it.
  password('password', 'Password protected');

  const ShareVisibility(this.wireValue, this.label);

  /// Value sent to / received from the backend.
  final String wireValue;

  /// Human-readable label for the UI.
  final String label;

  static ShareVisibility fromWire(String? value) {
    for (final v in ShareVisibility.values) {
      if (v.wireValue == value) return v;
    }
    return ShareVisibility.public;
  }
}

/// An active public share of a note, as surfaced in the management UI.
@immutable
class NoteShare {
  const NoteShare({
    required this.shareId,
    required this.noteId,
    required this.title,
    required this.visibility,
    required this.url,
    required this.viewCount,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  final String shareId;
  final String noteId;
  final String title;
  final ShareVisibility visibility;
  final String url;
  final int viewCount;
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// Whether this share still has an active, unexpired window.
  bool get isActive => status == 'active' && expiresAt.isAfter(DateTime.now());

  /// Days remaining before the share auto-expires (clamped at 0).
  int get daysRemaining {
    final diff = expiresAt.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  NoteShare copyWith({
    ShareVisibility? visibility,
    String? status,
  }) {
    return NoteShare(
      shareId: shareId,
      noteId: noteId,
      title: title,
      visibility: visibility ?? this.visibility,
      url: url,
      viewCount: viewCount,
      status: status ?? this.status,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

  static DateTime _parseDate(String value) {
    return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
  }

  /// Builds a domain [NoteShare] from an API list item.
  factory NoteShare.fromListItem({
    required String shareId,
    required String noteId,
    required String title,
    required String visibility,
    required String url,
    required int viewCount,
    required String status,
    required String createdAt,
    required String expiresAt,
  }) {
    return NoteShare(
      shareId: shareId,
      noteId: noteId,
      title: title,
      visibility: ShareVisibility.fromWire(visibility),
      url: url,
      viewCount: viewCount,
      status: status,
      createdAt: _parseDate(createdAt),
      expiresAt: _parseDate(expiresAt),
    );
  }
}
