import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../features/notes/data/notes_repository.dart';
import '../../features/notes/domain/note_model.dart';
import '../attachments/attachment_service.dart';
import '../documents/document_service.dart';
import 'html_to_markdown_converter.dart';
import 'web_capture_payload.dart';
import 'web_clipper_models.dart';
import 'web_clipper_scanner.dart';
import 'web_image_downloader.dart';
import 'web_snapshot_generator.dart';

/// Main orchestrator for web clipping in Quiet Paper.
class WebClipperService {
  WebClipperService({
    required this.notesRepository,
    this.attachmentService,
    this.documentService,
    WebClipperScanner? scanner,
    WebImageDownloader? imageDownloader,
    HtmlToMarkdownConverter? markdownConverter,
    WebSnapshotGenerator? snapshotGenerator,
  })  : _scanner = scanner ?? WebClipperScanner(),
        _imageDownloader = imageDownloader ??
            (attachmentService != null
                ? WebImageDownloader(attachmentService: attachmentService)
                : null),
        _markdownConverter = markdownConverter ?? const HtmlToMarkdownConverter(),
        _snapshotGenerator = snapshotGenerator ?? WebSnapshotGenerator();

  final NotesRepository notesRepository;
  final AttachmentService? attachmentService;
  final DocumentService? documentService;
  final WebClipperScanner _scanner;
  final WebImageDownloader? _imageDownloader;
  final HtmlToMarkdownConverter _markdownConverter;
  final WebSnapshotGenerator _snapshotGenerator;

  static const _uuid = Uuid();

  /// Scans a target webpage URL and returns metadata, content, and size estimates via direct HTTP.
  Future<WebClipScanResult> scanUrl(String url) async {
    return _scanner.scanUrl(url);
  }

  /// Ingests a pre-captured [WebCapturePayload] (from in-app browser or native bridge),
  /// extracts structured article content and metadata, probes images, and returns a [WebClipScanResult].
  Future<WebClipScanResult> scanPayload(
    WebCapturePayload payload, {
    bool allowFallback = true,
  }) async {
    return _scanner.scanPayload(payload, allowFallback: allowFallback);
  }

  /// Ingests a web clip, downloads selected images, generates an optional offline HTML snapshot,
  /// compiles Markdown, and creates the Note in SQLite.
  Future<({Note note, DocumentEntity? snapshotDocument})> clipArticle({
    required WebClipScanResult scanResult,
    required WebClipperOptions options,
    void Function(WebClipProgress progress)? onProgress,
  }) async {
    final noteId = _uuid.v4();
    final now = DateTime.now();
    final effectiveTitle = (options.customTitle != null && options.customTitle!.trim().isNotEmpty)
        ? options.customTitle!.trim()
        : scanResult.metadata.title;

    final metadata = scanResult.metadata.copyWith(title: effectiveTitle);
    final fragment = html_parser.parseFragment(scanResult.cleanedArticleHtml);
    final cleanedElement = fragment.children.isNotEmpty
        ? fragment.children.first
        : html_parser.parse(scanResult.cleanedArticleHtml).body!;

    // 1. Download & encrypt candidate images
    final imageSnippetsMap = <String, String>{};
    final downloader = _imageDownloader;

    if (options.downloadImages && downloader != null && scanResult.images.isNotEmpty) {
      final selectedCandidates = scanResult.images.where((img) {
        if (options.selectedImages.isNotEmpty) {
          return options.selectedImages.contains(img.resolvedUrl) ||
              options.selectedImages.contains(img.rawUrl);
        }
        return img.isSelected;
      }).toList();

      if (selectedCandidates.isNotEmpty) {
        onProgress?.call(WebClipProgress(
          step: WebClipProgressStep.downloadingImages,
          currentImageIndex: 0,
          totalImagesCount: selectedCandidates.length,
        ));

        final downloadedMap = await downloader.downloadAndEncryptImages(
          candidates: selectedCandidates,
          noteId: noteId,
          onProgress: (completed, total) {
            onProgress?.call(WebClipProgress(
              step: WebClipProgressStep.downloadingImages,
              currentImageIndex: completed,
              totalImagesCount: total,
            ));
          },
        );

        imageSnippetsMap.addAll(downloadedMap);
      }
    }

    // 2. Generate and encrypt offline Web Snapshot document
    DocumentEntity? snapshotDoc;
    String? snapshotDocId;
    int? snapshotSizeBytes;

    if (options.saveHtmlSnapshot && documentService != null) {
      onProgress?.call(const WebClipProgress(
        step: WebClipProgressStep.encrypting,
        message: 'Generating encrypted web snapshot…',
      ));

      try {
        final snapshotBytes = await _snapshotGenerator.generateSnapshotBytes(
          rawHtml: scanResult.rawHtml,
          metadata: metadata,
          cleanedElement: cleanedElement,
          localImageSources: imageSnippetsMap,
        );

        final docResult = await documentService!.createWebSnapshotDocument(
          htmlBytes: snapshotBytes,
          noteId: noteId,
          title: '$effectiveTitle (Web Snapshot)',
        );

        snapshotDoc = docResult.document;
        snapshotDocId = docResult.document.id;
        snapshotSizeBytes = snapshotBytes.length;
      } catch (e) {
        debugPrint('Failed to create web snapshot document: $e');
      }
    }

    // 3. Compile Markdown with frontmatter and rewritten image links
    onProgress?.call(const WebClipProgress(
      step: WebClipProgressStep.saving,
      message: 'Compiling editorial markdown note…',
    ));

    // Handle lead hero image
    String? leadImageMarkdown;
    String? leadAssetUri;
    if (metadata.leadImageUrl != null && metadata.leadImageUrl!.isNotEmpty) {
      leadAssetUri = _resolveAssetUri(metadata.leadImageUrl, imageSnippetsMap);
      if (leadAssetUri != null) {
        leadImageMarkdown = '![$effectiveTitle]($leadAssetUri)';
      } else {
        leadImageMarkdown = '![$effectiveTitle](${metadata.leadImageUrl})';
      }
    }

    // Rewrite inline image tags in DOM
    final imgNodes = cleanedElement.querySelectorAll('img');
    for (final img in imgNodes) {
      final src = img.attributes['src'] ??
          img.attributes['data-src'] ??
          img.attributes['data-original'] ??
          img.attributes['data-lazy-src'];
      if (src != null && src.isNotEmpty) {
        final assetUri = _resolveAssetUri(src, imageSnippetsMap);
        if (assetUri != null) {
          img.attributes['src'] = assetUri;
        }
      }
    }

    // Deduplicate lead image if it appears as the first image in body
    if (leadImageMarkdown != null && imgNodes.isNotEmpty) {
      final firstImg = imgNodes.first;
      final firstImgSrc = firstImg.attributes['src'];
      if (firstImgSrc != null &&
          (firstImgSrc == leadAssetUri ||
              firstImgSrc == metadata.leadImageUrl ||
              (leadAssetUri != null && _resolveAssetUri(firstImgSrc, imageSnippetsMap) == leadAssetUri))) {
        if (firstImg.parent?.localName == 'figure') {
          firstImg.parent!.remove();
        } else {
          firstImg.remove();
        }
      }
    }

    final tags = <String>{
      'clipped',
      if (metadata.domain.isNotEmpty) metadata.domain,
      ...options.tags,
    }.toList();

    final markdownContent = _markdownConverter.convert(
      cleanedElement: cleanedElement,
      metadata: metadata,
      tags: tags,
      snapshotDocumentId: snapshotDocId,
      snapshotSizeBytes: snapshotSizeBytes,
      leadImageMarkdown: leadImageMarkdown,
    );

    // 4. Save Note in database repository
    final note = Note(
      id: noteId,
      title: effectiveTitle,
      content: markdownContent,
      createdAt: now,
      updatedAt: now,
      isPinned: false,
      isArchived: false,
      isTrashed: false,
      tags: tags,
    );

    await notesRepository.saveNote(note);

    onProgress?.call(const WebClipProgress(
      step: WebClipProgressStep.complete,
    ));

    return (note: note, snapshotDocument: snapshotDoc);
  }

  String? _resolveAssetUri(String? url, Map<String, String> snippetsMap) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();

    String? extractUri(String snippet) {
      final match = RegExp(r'\((qp:\/\/asset\/[a-zA-Z0-9_\-]+)\)').firstMatch(snippet);
      return match?.group(1);
    }

    // 1. Direct match
    if (snippetsMap.containsKey(trimmed)) {
      final uri = extractUri(snippetsMap[trimmed]!);
      if (uri != null) return uri;
    }

    // 2. Encoded / Decoded URI match
    try {
      final decoded = Uri.decodeFull(trimmed);
      if (snippetsMap.containsKey(decoded)) {
        final uri = extractUri(snippetsMap[decoded]!);
        if (uri != null) return uri;
      }
      final encoded = Uri.encodeFull(trimmed);
      if (snippetsMap.containsKey(encoded)) {
        final uri = extractUri(snippetsMap[encoded]!);
        if (uri != null) return uri;
      }
    } catch (_) {}

    // 3. Query stripped match
    if (trimmed.contains('?')) {
      final base = trimmed.split('?').first;
      if (snippetsMap.containsKey(base)) {
        final uri = extractUri(snippetsMap[base]!);
        if (uri != null) return uri;
      }
    }

    // 4. Fallback scan entries
    for (final entry in snippetsMap.entries) {
      if (entry.key == trimmed ||
          (trimmed.contains('?') && entry.key.split('?').first == trimmed.split('?').first) ||
          (entry.key.contains('?') && entry.key.split('?').first == trimmed)) {
        final uri = extractUri(entry.value);
        if (uri != null) return uri;
      }
    }

    return null;
  }
}
