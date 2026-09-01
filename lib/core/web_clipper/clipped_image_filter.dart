import 'dart:typed_data';
import 'dart:ui';
import 'package:html/dom.dart' as dom;
import '../attachments/presentation/image_dimension_reader.dart';

/// Pure Dart multi-signal heuristic engine for discerning meaningful article content
/// images (photos, technical diagrams, infographics, illustrations across AVIF, WebP, SVG, PNG, JPEG)
/// from noisy UI artifacts (small icons, navigation chevrons, 1x1 tracking pixels, avatar badges, social buttons).
abstract final class ClippedImageFilter {
  static final RegExp _trackerUrlRegex = RegExp(
    r'(1x1|pixel\.gif|beacon|telemetry|tracker\.|ad-delivery|adsct|doubleclick|google-analytics\.com\/collect|facebook\.com\/tr\/|quantserve|scorecardresearch|bat\.bing\.com)',
    caseSensitive: false,
  );

  static final RegExp _iconClassOrIdRegex = RegExp(
    r'(icon|btn-icon|nav-arrow|chevron|avatar-small|badge-icon|spinner|rating-star|emoji-reaction|logo-small|social-link|social-icon|share-btn|favicon)',
    caseSensitive: false,
  );

  static final RegExp _decorativeAltRegex = RegExp(
    r'(icon|arrow|chevron|menu|close|spinner|spacer|bullet|divider|separator|star|avatar|logo|hamburger|logostack|favicon)',
    caseSensitive: false,
  );

  static const Set<String> _noisyParentTags = {
    'nav',
    'button',
    'header',
    'footer',
    'dialog',
    'form',
    'select',
    'textarea',
  };

  /// Evaluates whether an HTML DOM [el] represents a meaningful content image.
  static bool isUsefulContentImage(dom.Element el, {Uri? baseUri}) {
    // 1. Ancestor container check
    var parent = el.parent;
    while (parent != null) {
      final parentTag = parent.localName?.toLowerCase() ?? '';
      if (_noisyParentTags.contains(parentTag)) {
        return false;
      }
      final parentClass = parent.className.toLowerCase();
      if (parentClass.contains('social-share') ||
          parentClass.contains('share-bar') ||
          parentClass.contains('author-avatar') ||
          parentClass.contains('reactions') ||
          parentClass.contains('comments-section') ||
          parentClass.contains('advertisement') ||
          parentClass.contains('widget-social')) {
        return false;
      }
      parent = parent.parent;
    }

    // 2. Class and ID heuristics
    final className = el.className;
    final id = el.id;
    if (_iconClassOrIdRegex.hasMatch(className) || _iconClassOrIdRegex.hasMatch(id)) {
      // Allow if explicit hero or main image class overrides
      if (!className.toLowerCase().contains('hero') &&
          !className.toLowerCase().contains('featured') &&
          !className.toLowerCase().contains('article-image')) {
        return false;
      }
    }

    // 3. Explicit attribute dimension heuristics
    final widthAttr = el.attributes['width'];
    final heightAttr = el.attributes['height'];
    if (widthAttr != null && heightAttr != null) {
      final width = double.tryParse(widthAttr.replaceAll(RegExp(r'[^0-9.]'), ''));
      final height = double.tryParse(heightAttr.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (width != null && height != null) {
        // Tracking / spacer pixel
        if (width <= 1 || height <= 1) {
          return false;
        }
        // Small decorative icon
        if (width <= 40 && height <= 40) {
          return false;
        }
      }
    }

    // 4. Inline style dimension heuristics
    final style = el.attributes['style']?.toLowerCase() ?? '';
    if (style.isNotEmpty) {
      final widthMatch = RegExp(r'width\s*:\s*([0-9.]+)px').firstMatch(style);
      final heightMatch = RegExp(r'height\s*:\s*([0-9.]+)px').firstMatch(style);
      if (widthMatch != null && heightMatch != null) {
        final w = double.tryParse(widthMatch.group(1)!) ?? 0;
        final h = double.tryParse(heightMatch.group(1)!) ?? 0;
        if ((w > 0 && w <= 1) || (h > 0 && h <= 1)) return false;
        if (w > 0 && h > 0 && w <= 40 && h <= 40) return false;
      }
    }

    // 5. Alt text check
    final alt = el.attributes['alt']?.trim() ?? '';
    if (alt.isNotEmpty && _decorativeAltRegex.hasMatch(alt)) {
      return false;
    }

    // 6. Source URL evaluation
    final src = extractBestImageSource(el, baseUri ?? Uri());
    if (src == null || src.isEmpty) {
      return false;
    }

    return isUsefulImageUrl(src, altText: alt);
  }

  /// Evaluates whether an image [url] is a valid, non-tracker content URL.
  static bool isUsefulImageUrl(String url, {String? altText, int? byteSize}) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;

    // 1. Data URI evaluation
    if (trimmed.startsWith('data:image/')) {
      // Ignore tiny base64 1x1 GIF / empty SVG spacers (< 200 chars)
      if (trimmed.length < 200) {
        return false;
      }
      return true;
    }

    // 2. Tracker & analytics pattern check
    if (_trackerUrlRegex.hasMatch(trimmed)) {
      return false;
    }

    // 3. Known icon path / logo patterns
    final lower = trimmed.toLowerCase();
    if (lower.contains('/favicon.') ||
        lower.contains('/apple-touch-icon') ||
        lower.contains('/icons/share-') ||
        lower.contains('/social-icons/')) {
      return false;
    }

    // 4. Alt text check
    if (altText != null && altText.trim().isNotEmpty) {
      if (_decorativeAltRegex.hasMatch(altText.trim())) {
        return false;
      }
    }

    // 5. Size check if known
    if (byteSize != null && byteSize > 0 && byteSize <= 68) {
      return false;
    }

    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }

  /// Extracts the highest quality image candidate from an `<img>`, `<picture>`, or `<source>` element.
  /// Prioritizes modern formats (AVIF > WebP > SVG > PNG > JPEG) and parses `srcset` densities.
  static String? extractBestImageSource(dom.Element el, Uri baseUri) {
    // 1. If element is inside a <picture>, inspect child <source> elements first
    dom.Element? pictureEl;
    if (el.localName?.toLowerCase() == 'picture') {
      pictureEl = el;
    } else if (el.parent?.localName?.toLowerCase() == 'picture') {
      pictureEl = el.parent;
    }

    if (pictureEl != null) {
      final sources = pictureEl.querySelectorAll('source');
      dom.Element? bestSource;

      for (final source in sources) {
        final type = source.attributes['type']?.toLowerCase().trim() ?? '';
        final srcset = source.attributes['srcset'] ??
            source.attributes['data-srcset'] ??
            source.attributes['data-src'] ??
            source.attributes['src'];

        if (srcset != null && srcset.trim().isNotEmpty) {
          if (type.contains('avif')) {
            bestSource = source;
            break; // Highest priority format
          } else if (type.contains('webp') && (bestSource == null || !bestSource.attributes['type']!.contains('avif'))) {
            bestSource = source;
          } else {
            bestSource ??= source;
          }
        }
      }

      if (bestSource != null) {
        final rawSet = bestSource.attributes['srcset'] ??
            bestSource.attributes['data-srcset'] ??
            bestSource.attributes['data-src'] ??
            bestSource.attributes['src'];
        final candidate = parseSrcsetFirstOrBest(rawSet);
        if (candidate != null && candidate.isNotEmpty) {
          return resolveUrl(candidate, baseUri);
        }
      }

      final innerImg = pictureEl.querySelector('img');
      if (innerImg != null && innerImg != el) {
        final innerSrc = extractBestImageSource(innerImg, baseUri);
        if (innerSrc != null && innerSrc.isNotEmpty) {
          return innerSrc;
        }
      }
    }

    // 2. Check element's own srcset / data-srcset
    final rawSrcset = el.attributes['srcset'] ?? el.attributes['data-srcset'];
    if (rawSrcset != null && rawSrcset.trim().isNotEmpty) {
      final candidate = parseSrcsetFirstOrBest(rawSrcset);
      if (candidate != null && candidate.isNotEmpty && (!candidate.startsWith('data:image/') || candidate.length >= 200)) {
        return resolveUrl(candidate, baseUri);
      }
    }

    // 3. Check lazy data attributes (high-res candidates)
    final dataSrc = el.attributes['data-src'] ??
        el.attributes['data-original'] ??
        el.attributes['data-lazy-src'] ??
        el.attributes['data-actualsrc'] ??
        el.attributes['data-hires'] ??
        el.attributes['data-high-res-src'] ??
        el.attributes['data-large-file'] ??
        el.attributes['data-url'];

    if (dataSrc != null && dataSrc.trim().isNotEmpty) {
      final trimmed = dataSrc.trim();
      if (!trimmed.startsWith('data:image/') || trimmed.length >= 200) {
        return resolveUrl(trimmed, baseUri);
      }
    }

    // 4. Check direct src
    final src = el.attributes['src']?.trim();
    if (src != null && src.isNotEmpty) {
      if (!src.startsWith('data:image/') || src.length >= 200) {
        return resolveUrl(src, baseUri);
      }
    }

    return null;
  }

  /// Parses `srcset` (e.g. `url 1x, url 2x` or `url 400w, url 800w`) and selects the widest / highest quality candidate.
  static String? parseSrcsetFirstOrBest(String? srcset) {
    if (srcset == null || srcset.trim().isEmpty) return null;
    final candidates = srcset.split(',');
    String? largestUrl;
    double maxDensity = 0;

    for (final candidate in candidates) {
      final parts = candidate.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty || parts.first.isEmpty) continue;
      final url = parts.first.trim();
      if (url.isEmpty || (url.startsWith('data:image/') && url.length < 200)) continue;

      if (parts.length > 1) {
        final descriptor = parts[1].toLowerCase().trim();
        if (descriptor.endsWith('w')) {
          final width = double.tryParse(descriptor.replaceAll('w', '')) ?? 0;
          if (width > maxDensity) {
            maxDensity = width;
            largestUrl = url;
          }
        } else if (descriptor.endsWith('x')) {
          final density = double.tryParse(descriptor.replaceAll('x', '')) ?? 0;
          if (density > maxDensity) {
            maxDensity = density;
            largestUrl = url;
          }
        }
      } else {
        largestUrl ??= url;
      }
    }

    return largestUrl ?? (candidates.isNotEmpty ? candidates.last.trim().split(RegExp(r'\s+')).first : null);
  }

  /// Validates whether downloaded [bytes] represent a meaningful image and not an empty spacer or icon.
  static bool isMeaningfulImageBytes(Uint8List bytes, {Size? intrinsicSize}) {
    if (bytes.isEmpty) {
      return false;
    }

    final size = intrinsicSize ?? ImageDimensionReader.extractDimensions(bytes);
    if (size != null) {
      if (size.width <= 1 || size.height <= 1) {
        return false; // Tracking pixel
      }
      if (size.width <= 32 && size.height <= 32) {
        return false; // Tiny decorative icon
      }
    }

    return true;
  }

  /// Resolves relative URLs (including protocol-relative `//`) against [baseUri].
  static String resolveUrl(String url, Uri baseUri) {
    final trimmed = url.trim();
    if (trimmed.startsWith('data:')) {
      return trimmed;
    }
    if (trimmed.startsWith('//')) {
      return '${baseUri.scheme.isNotEmpty ? baseUri.scheme : "https"}:$trimmed';
    }
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null) return trimmed;
    if (parsed.hasScheme) return trimmed;
    return baseUri.resolveUri(parsed).toString();
  }
}
