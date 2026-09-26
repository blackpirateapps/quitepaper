/// Data-transfer models for the public note-sharing API.
///
/// These mirror the JSON shapes returned by the backend `shareService`
/// endpoints (`/api/v1/shares*`). Visibility is carried as a raw string here;
/// the share feature layer maps it to its `ShareVisibility` enum.
library;

/// Result of creating a share (`POST /api/v1/shares`).
class CreatedShare {
  const CreatedShare({
    required this.shareId,
    required this.url,
    required this.visibility,
    required this.title,
    required this.createdAt,
    required this.expiresAt,
  });

  final String shareId;
  final String url;
  final String visibility;
  final String title;
  final String createdAt;
  final String expiresAt;

  factory CreatedShare.fromJson(Map<String, dynamic> json) {
    return CreatedShare(
      shareId: json['shareId'] as String,
      url: json['url'] as String,
      visibility: json['visibility'] as String? ?? 'public',
      title: json['title'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      expiresAt: json['expiresAt'] as String? ?? '',
    );
  }
}

/// A single share as returned by `GET /api/v1/shares` (management list).
class ShareListItem {
  const ShareListItem({
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
  final String visibility;
  final String url;
  final int viewCount;
  final String status;
  final String createdAt;
  final String expiresAt;

  factory ShareListItem.fromJson(Map<String, dynamic> json) {
    return ShareListItem(
      shareId: json['shareId'] as String,
      noteId: json['noteId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      visibility: json['visibility'] as String? ?? 'public',
      url: json['url'] as String? ?? '',
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'active',
      createdAt: json['createdAt'] as String? ?? '',
      expiresAt: json['expiresAt'] as String? ?? '',
    );
  }
}

/// A public (plaintext) Cloudinary attachment reference sent when creating a
/// share, so the backend can track it for garbage collection.
class ShareAttachmentRef {
  const ShareAttachmentRef({
    required this.cloudPublicId,
    required this.cloudUrl,
    this.resourceType = 'image',
    this.byteSize = 0,
  });

  final String cloudPublicId;
  final String cloudUrl;
  final String resourceType;
  final int byteSize;

  Map<String, dynamic> toJson() => {
        'cloudPublicId': cloudPublicId,
        'cloudUrl': cloudUrl,
        'resourceType': resourceType,
        'byteSize': byteSize,
      };
}

/// Result of updating a share (`PATCH /api/v1/shares/:id`).
class ShareUpdateResult {
  const ShareUpdateResult({
    required this.shareId,
    required this.visibility,
  });

  final String shareId;
  final String visibility;

  factory ShareUpdateResult.fromJson(Map<String, dynamic> json) {
    return ShareUpdateResult(
      shareId: json['shareId'] as String? ?? '',
      visibility: json['visibility'] as String? ?? 'public',
    );
  }
}
