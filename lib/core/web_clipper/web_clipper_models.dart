import 'package:flutter/foundation.dart';
import 'web_capture_payload.dart';

/// Metadata extracted from a web page or article.
@immutable
class ExtractedArticleMetadata {
  const ExtractedArticleMetadata({
    required this.sourceUrl,
    required this.title,
    this.author,
    this.publishedDate,
    this.description,
    this.leadImageUrl,
    required this.domain,
    this.siteName,
  });

  final String sourceUrl;
  final String title;
  final String? author;
  final DateTime? publishedDate;
  final String? description;
  final String? leadImageUrl;
  final String domain;
  final String? siteName;

  ExtractedArticleMetadata copyWith({
    String? sourceUrl,
    String? title,
    String? author,
    DateTime? publishedDate,
    String? description,
    String? leadImageUrl,
    String? domain,
    String? siteName,
  }) {
    return ExtractedArticleMetadata(
      sourceUrl: sourceUrl ?? this.sourceUrl,
      title: title ?? this.title,
      author: author ?? this.author,
      publishedDate: publishedDate ?? this.publishedDate,
      description: description ?? this.description,
      leadImageUrl: leadImageUrl ?? this.leadImageUrl,
      domain: domain ?? this.domain,
      siteName: siteName ?? this.siteName,
    );
  }
}

/// Image found in an article body or header candidate for local encrypted vault download.
@immutable
class ClippedImageCandidate {
  const ClippedImageCandidate({
    required this.rawUrl,
    required this.resolvedUrl,
    this.altText = '',
    this.caption = '',
    this.estimatedSizeBytes = 0,
    this.isLeadImage = false,
    this.isSelected = true,
  });

  final String rawUrl;
  final String resolvedUrl;
  final String altText;
  final String caption;
  final int estimatedSizeBytes;
  final bool isLeadImage;
  final bool isSelected;

  ClippedImageCandidate copyWith({
    String? rawUrl,
    String? resolvedUrl,
    String? altText,
    String? caption,
    int? estimatedSizeBytes,
    bool? isLeadImage,
    bool? isSelected,
  }) {
    return ClippedImageCandidate(
      rawUrl: rawUrl ?? this.rawUrl,
      resolvedUrl: resolvedUrl ?? this.resolvedUrl,
      altText: altText ?? this.altText,
      caption: caption ?? this.caption,
      estimatedSizeBytes: estimatedSizeBytes ?? this.estimatedSizeBytes,
      isLeadImage: isLeadImage ?? this.isLeadImage,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// Pre-scan result for an article URL containing metadata, raw/clean HTML,
/// preliminary Markdown conversion, and storage size estimates.
@immutable
class WebClipScanResult {
  const WebClipScanResult({
    required this.metadata,
    required this.rawHtml,
    required this.cleanedArticleHtml,
    required this.markdownBody,
    required this.markdownSizeEstimate,
    required this.htmlSnapshotSizeEstimate,
    required this.images,
    this.isPageContentFallback = false,
    this.acquisitionMethod = WebAcquisitionMethod.directHttp,
  });

  final ExtractedArticleMetadata metadata;
  final String rawHtml;
  final String cleanedArticleHtml;
  final String markdownBody;
  final int markdownSizeEstimate;
  final int htmlSnapshotSizeEstimate;
  final List<ClippedImageCandidate> images;
  final bool isPageContentFallback;
  final WebAcquisitionMethod acquisitionMethod;

  int get totalImagesSizeEstimate => images
      .where((img) => img.isSelected)
      .fold(0, (sum, img) => sum + img.estimatedSizeBytes);

  int get effectiveTotalSize =>
      markdownSizeEstimate + htmlSnapshotSizeEstimate + totalImagesSizeEstimate;

  WebClipScanResult copyWith({
    ExtractedArticleMetadata? metadata,
    String? rawHtml,
    String? cleanedArticleHtml,
    String? markdownBody,
    int? markdownSizeEstimate,
    int? htmlSnapshotSizeEstimate,
    List<ClippedImageCandidate>? images,
    bool? isPageContentFallback,
    WebAcquisitionMethod? acquisitionMethod,
  }) {
    return WebClipScanResult(
      metadata: metadata ?? this.metadata,
      rawHtml: rawHtml ?? this.rawHtml,
      cleanedArticleHtml: cleanedArticleHtml ?? this.cleanedArticleHtml,
      markdownBody: markdownBody ?? this.markdownBody,
      markdownSizeEstimate: markdownSizeEstimate ?? this.markdownSizeEstimate,
      htmlSnapshotSizeEstimate:
          htmlSnapshotSizeEstimate ?? this.htmlSnapshotSizeEstimate,
      images: images ?? this.images,
      isPageContentFallback:
          isPageContentFallback ?? this.isPageContentFallback,
      acquisitionMethod: acquisitionMethod ?? this.acquisitionMethod,
    );
  }
}

/// User options for committing a web clip to the notebook.
@immutable
class WebClipperOptions {
  const WebClipperOptions({
    this.customTitle,
    this.saveHtmlSnapshot = true,
    this.downloadImages = true,
    this.tags = const <String>[],
    this.selectedImages = const <String>{},
  });

  final String? customTitle;
  final bool saveHtmlSnapshot;
  final bool downloadImages;
  final List<String> tags;
  final Set<String> selectedImages;

  WebClipperOptions copyWith({
    String? customTitle,
    bool? saveHtmlSnapshot,
    bool? downloadImages,
    List<String>? tags,
    Set<String>? selectedImages,
  }) {
    return WebClipperOptions(
      customTitle: customTitle ?? this.customTitle,
      saveHtmlSnapshot: saveHtmlSnapshot ?? this.saveHtmlSnapshot,
      downloadImages: downloadImages ?? this.downloadImages,
      tags: tags ?? this.tags,
      selectedImages: selectedImages ?? this.selectedImages,
    );
  }
}

/// Stage in the web clipping pipeline.
enum WebClipProgressStep {
  fetching('Fetching webpage…'),
  extracting('Extracting article content…'),
  probingImages('Analyzing media…'),
  downloadingImages('Downloading article images…'),
  encrypting('Encrypting local vault assets…'),
  saving('Saving encrypted note…'),
  complete('Article clipped successfully!'),
  failed('Clipping failed');

  const WebClipProgressStep(this.label);
  final String label;
}

/// Progress notification for clipping jobs.
@immutable
class WebClipProgress {
  const WebClipProgress({
    required this.step,
    this.currentImageIndex = 0,
    this.totalImagesCount = 0,
    this.message,
  });

  final WebClipProgressStep step;
  final int currentImageIndex;
  final int totalImagesCount;
  final String? message;

  String get displayMessage {
    if (message != null && message!.isNotEmpty) return message!;
    if (step == WebClipProgressStep.downloadingImages && totalImagesCount > 0) {
      return 'Downloading images ($currentImageIndex/$totalImagesCount)…';
    }
    return step.label;
  }
}
