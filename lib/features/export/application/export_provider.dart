import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/attachments/attachment_provider.dart';
import '../../../core/documents/document_provider.dart';
import '../../../core/ocr/ocr_provider.dart';
import '../../../core/sync/sync_provider.dart';
import '../../notes/application/notes_provider.dart';
import '../../settings/application/settings_provider.dart';
import '../domain/export_models.dart';
import 'export_service.dart';

/// Provider for the centralized [ExportService] singleton.
final exportServiceProvider = Provider<ExportService>((ref) {
  final db = ref.watch(databaseProvider);
  final keyManager = ref.watch(keyManagerProvider);
  final attachmentService = ref.watch(attachmentServiceProvider);
  final documentService = ref.watch(documentServiceProvider);
  final docProcessingService = ref.watch(documentProcessingServiceProvider);

  return ExportService(
    database: db,
    keyManager: keyManager,
    attachmentService: attachmentService,
    documentService: documentService,
    docProcessingService: docProcessingService,
  );
});

/// Export user preferences state model.
class ExportPreferences {
  const ExportPreferences({
    this.lastFormat = ExportFormat.markdown,
    this.includeMetadata = true,
    this.includeAttachments = true,
    this.includeOcr = false,
    this.attachmentStrategy = AttachmentExportStrategy.embedLocally,
    this.noteLinkStrategy = NoteLinkStrategy.preserveQuietPaperUri,
  });

  final ExportFormat lastFormat;
  final bool includeMetadata;
  final bool includeAttachments;
  final bool includeOcr;
  final AttachmentExportStrategy attachmentStrategy;
  final NoteLinkStrategy noteLinkStrategy;

  ExportPreferences copyWith({
    ExportFormat? lastFormat,
    bool? includeMetadata,
    bool? includeAttachments,
    bool? includeOcr,
    AttachmentExportStrategy? attachmentStrategy,
    NoteLinkStrategy? noteLinkStrategy,
  }) {
    return ExportPreferences(
      lastFormat: lastFormat ?? this.lastFormat,
      includeMetadata: includeMetadata ?? this.includeMetadata,
      includeAttachments: includeAttachments ?? this.includeAttachments,
      includeOcr: includeOcr ?? this.includeOcr,
      attachmentStrategy: attachmentStrategy ?? this.attachmentStrategy,
      noteLinkStrategy: noteLinkStrategy ?? this.noteLinkStrategy,
    );
  }
}

/// Notifier managing persisted export preferences in [SharedPreferences].
class ExportPreferencesNotifier extends StateNotifier<ExportPreferences> {
  ExportPreferencesNotifier(this._prefs) : super(const ExportPreferences()) {
    _loadPreferences();
  }

  final SharedPreferences? _prefs;

  static const _kLastFormat = 'quietpaper_export_last_format';
  static const _kIncludeMetadata = 'quietpaper_export_include_metadata';
  static const _kIncludeAttachments = 'quietpaper_export_include_attachments';
  static const _kIncludeOcr = 'quietpaper_export_include_ocr';
  static const _kAttachmentStrategy = 'quietpaper_export_attachment_strategy';
  static const _kNoteLinkStrategy = 'quietpaper_export_link_strategy';

  void _loadPreferences() {
    if (_prefs == null) return;

    final formatExt = _prefs.getString(_kLastFormat);
    final lastFormat = formatExt != null
        ? ExportFormat.fromExtension(formatExt)
        : ExportFormat.markdown;

    final includeMetadata = _prefs.getBool(_kIncludeMetadata) ?? true;
    final includeAttachments = _prefs.getBool(_kIncludeAttachments) ?? true;
    final includeOcr = _prefs.getBool(_kIncludeOcr) ?? false;

    final attStratStr = _prefs.getString(_kAttachmentStrategy);
    final attachmentStrategy = AttachmentExportStrategy.fromIdentifier(attStratStr);

    final linkStratStr = _prefs.getString(_kNoteLinkStrategy);
    final noteLinkStrategy = NoteLinkStrategy.fromIdentifier(linkStratStr);

    state = ExportPreferences(
      lastFormat: lastFormat,
      includeMetadata: includeMetadata,
      includeAttachments: includeAttachments,
      includeOcr: includeOcr,
      attachmentStrategy: attachmentStrategy,
      noteLinkStrategy: noteLinkStrategy,
    );
  }

  Future<void> updatePreferences({
    ExportFormat? lastFormat,
    bool? includeMetadata,
    bool? includeAttachments,
    bool? includeOcr,
    AttachmentExportStrategy? attachmentStrategy,
    NoteLinkStrategy? noteLinkStrategy,
  }) async {
    state = state.copyWith(
      lastFormat: lastFormat,
      includeMetadata: includeMetadata,
      includeAttachments: includeAttachments,
      includeOcr: includeOcr,
      attachmentStrategy: attachmentStrategy,
      noteLinkStrategy: noteLinkStrategy,
    );

    if (_prefs != null) {
      if (lastFormat != null) {
        await _prefs.setString(_kLastFormat, lastFormat.extension);
      }
      if (includeMetadata != null) {
        await _prefs.setBool(_kIncludeMetadata, includeMetadata);
      }
      if (includeAttachments != null) {
        await _prefs.setBool(_kIncludeAttachments, includeAttachments);
      }
      if (includeOcr != null) {
        await _prefs.setBool(_kIncludeOcr, includeOcr);
      }
      if (attachmentStrategy != null) {
        await _prefs.setString(_kAttachmentStrategy, attachmentStrategy.identifier);
      }
      if (noteLinkStrategy != null) {
        await _prefs.setString(_kNoteLinkStrategy, noteLinkStrategy.identifier);
      }
    }
  }
}

/// Provider for export user preferences.
final exportPreferencesProvider =
    StateNotifierProvider<ExportPreferencesNotifier, ExportPreferences>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {}
  return ExportPreferencesNotifier(prefs);
});
