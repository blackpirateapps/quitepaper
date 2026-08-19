import 'package:flutter/foundation.dart';
import 'quiet_paper_uri.dart';

/// Resolution state for an internal Quiet Paper resource.
enum ResourceStatus {
  /// The resource is resolved and immediately available locally.
  available,

  /// The resource exists in metadata but needs to be downloaded from remote cloud storage.
  downloadRequired,

  /// The resource download is currently in progress.
  downloading,

  /// The resource record is missing, deleted, or cannot be found.
  missing,

  /// The resource failed decryption or cryptographic MAC verification failed.
  corrupted,

  /// Access to the resource is locked (e.g. password protected or keys locked).
  locked,

  /// General resolution or network failure.
  error,
}

/// Generic container for resource resolution outcome.
@immutable
class ResourceResolution<T> {
  const ResourceResolution({
    required this.uri,
    required this.status,
    this.data,
    this.errorMessage,
  });

  final QuietPaperUri uri;
  final ResourceStatus status;
  final T? data;
  final String? errorMessage;

  bool get isAvailable => status == ResourceStatus.available && data != null;
  bool get isMissing => status == ResourceStatus.missing;
  bool get isCorrupted => status == ResourceStatus.corrupted;
  bool get isLocked => status == ResourceStatus.locked;

  factory ResourceResolution.available(QuietPaperUri uri, T data) =>
      ResourceResolution(uri: uri, status: ResourceStatus.available, data: data);

  factory ResourceResolution.downloadRequired(QuietPaperUri uri, {T? data}) =>
      ResourceResolution(
          uri: uri, status: ResourceStatus.downloadRequired, data: data);

  factory ResourceResolution.downloading(QuietPaperUri uri) =>
      ResourceResolution(uri: uri, status: ResourceStatus.downloading);

  factory ResourceResolution.missing(QuietPaperUri uri, [String? message]) =>
      ResourceResolution(
          uri: uri, status: ResourceStatus.missing, errorMessage: message);

  factory ResourceResolution.corrupted(QuietPaperUri uri, [String? message]) =>
      ResourceResolution(
          uri: uri, status: ResourceStatus.corrupted, errorMessage: message);

  factory ResourceResolution.locked(QuietPaperUri uri, [String? message]) =>
      ResourceResolution(
          uri: uri, status: ResourceStatus.locked, errorMessage: message);

  factory ResourceResolution.error(QuietPaperUri uri, String message) =>
      ResourceResolution(
          uri: uri, status: ResourceStatus.error, errorMessage: message);
}

/// Abstract contract for resolving binary asset resources (`qp://asset/<UUID>`).
abstract class AssetResolver {
  /// Resolves an asset by [assetId] and returns its plaintext decrypted bytes or state.
  Future<ResourceResolution<Uint8List>> resolveAsset(
    String assetId, {
    String variant = 'original',
  });

  /// Checks whether the decrypted or local encrypted asset is cached on device.
  Future<bool> isAssetAvailableLocally(String assetId);
}

/// Abstract contract for resolving note resources (`qp://note/<UUID>`).
/// Reserved for future note-to-note linking architecture.
abstract class NoteResolver {
  /// Resolves a note by [noteId] and returns its metadata/title info without coupling to UI.
  Future<ResourceResolution<ResolvedNoteInfo>> resolveNote(String noteId);
}

/// Lightweight container for resolved note link metadata.
@immutable
class ResolvedNoteInfo {
  const ResolvedNoteInfo({
    required this.noteId,
    required this.title,
    this.isArchived = false,
    this.isTrashed = false,
    this.isLocked = false,
  });

  final String noteId;
  final String title;
  final bool isArchived;
  final bool isTrashed;
  final bool isLocked;
}

/// Unified resource resolver that coordinates dispatching between asset and note resolvers.
class QuietPaperResourceResolver {
  QuietPaperResourceResolver({
    this.assetResolver,
    this.noteResolver,
  });

  final AssetResolver? assetResolver;
  final NoteResolver? noteResolver;

  /// Resolves any [QuietPaperUri] polymorphically.
  Future<ResourceResolution<dynamic>> resolve(QuietPaperUri uri) async {
    switch (uri.resourceType) {
      case QuietPaperResourceType.asset:
        if (assetResolver == null) {
          return ResourceResolution.error(
            uri,
            'No AssetResolver registered in QuietPaperResourceResolver',
          );
        }
        final variant = uri.parameters['variant'] ?? 'original';
        return assetResolver!.resolveAsset(uri.resourceId, variant: variant);
      case QuietPaperResourceType.note:
        if (noteResolver == null) {
          return ResourceResolution.error(
            uri,
            'No NoteResolver registered in QuietPaperResourceResolver',
          );
        }
        return noteResolver!.resolveNote(uri.resourceId);
      case QuietPaperResourceType.unknown:
        return ResourceResolution.error(
          uri,
          'Unsupported resource type: ${uri.resourceType.identifier}',
        );
    }
  }
}
