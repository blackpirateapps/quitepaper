import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:quitepaper/core/web_clipper/clipped_image_filter.dart';

void main() {
  group('ClippedImageFilter', () {
    final baseUri = Uri.parse('https://example.com/blog/article');

    test('skips tiny decorative icons by dimension attributes', () {
      final doc = html_parser.parseFragment('''
        <div>
          <img id="icon1" src="https://example.com/icon.png" width="16" height="16" />
          <img id="icon2" src="https://example.com/bullet.png" width="32" height="32" />
          <img id="pixel" src="https://example.com/spacer.gif" width="1" height="1" />
          <img id="content" src="https://example.com/diagram.avif" width="800" height="600" />
        </div>
      ''');

      final icon1 = doc.querySelector('#icon1')!;
      final icon2 = doc.querySelector('#icon2')!;
      final pixel = doc.querySelector('#pixel')!;
      final content = doc.querySelector('#content')!;

      expect(ClippedImageFilter.isUsefulContentImage(icon1, baseUri: baseUri), isFalse);
      expect(ClippedImageFilter.isUsefulContentImage(icon2, baseUri: baseUri), isFalse);
      expect(ClippedImageFilter.isUsefulContentImage(pixel, baseUri: baseUri), isFalse);
      expect(ClippedImageFilter.isUsefulContentImage(content, baseUri: baseUri), isTrue);
    });

    test('skips icons by CSS style dimensions and icon classes', () {
      final doc = html_parser.parseFragment('''
        <div>
          <img id="styled-icon" src="https://example.com/share.png" style="width: 24px; height: 24px;" />
          <img id="class-icon" class="btn-icon chevron" src="https://example.com/arrow.png" />
          <img id="hero-img" class="article-hero featured-image" src="https://example.com/hero.webp" />
        </div>
      ''');

      final styledIcon = doc.querySelector('#styled-icon')!;
      final classIcon = doc.querySelector('#class-icon')!;
      final heroImg = doc.querySelector('#hero-img')!;

      expect(ClippedImageFilter.isUsefulContentImage(styledIcon, baseUri: baseUri), isFalse);
      expect(ClippedImageFilter.isUsefulContentImage(classIcon, baseUri: baseUri), isFalse);
      expect(ClippedImageFilter.isUsefulContentImage(heroImg, baseUri: baseUri), isTrue);
    });

    test('skips images in noisy parent containers (nav, button, share-bar)', () {
      final doc = html_parser.parseFragment('''
        <div>
          <nav>
            <img id="nav-logo" src="https://example.com/nav-logo.svg" />
          </nav>
          <button>
            <img id="btn-img" src="https://example.com/btn.png" />
          </button>
          <div class="social-share">
            <img id="share-img" src="https://example.com/twitter.png" />
          </div>
          <article>
            <img id="article-chart" src="https://example.com/architecture-chart.svg" />
          </article>
        </div>
      ''');

      final navLogo = doc.querySelector('#nav-logo')!;
      final btnImg = doc.querySelector('#btn-img')!;
      final shareImg = doc.querySelector('#share-img')!;
      final articleChart = doc.querySelector('#article-chart')!;

      expect(ClippedImageFilter.isUsefulContentImage(navLogo, baseUri: baseUri), isFalse);
      expect(ClippedImageFilter.isUsefulContentImage(btnImg, baseUri: baseUri), isFalse);
      expect(ClippedImageFilter.isUsefulContentImage(shareImg, baseUri: baseUri), isFalse);
      expect(ClippedImageFilter.isUsefulContentImage(articleChart, baseUri: baseUri), isTrue);
    });

    test('skips tracking and beacon URLs while keeping AVIF, WebP, SVG and JPEG', () {
      expect(ClippedImageFilter.isUsefulImageUrl('https://google-analytics.com/collect?v=1'), isFalse);
      expect(ClippedImageFilter.isUsefulImageUrl('https://example.com/track/1x1.gif'), isFalse);
      expect(ClippedImageFilter.isUsefulImageUrl('https://example.com/telemetry/beacon'), isFalse);

      expect(ClippedImageFilter.isUsefulImageUrl('https://cdn.example.com/photo.avif'), isTrue);
      expect(ClippedImageFilter.isUsefulImageUrl('https://cdn.example.com/photo.webp'), isTrue);
      expect(ClippedImageFilter.isUsefulImageUrl('https://cdn.example.com/diagram.svg'), isTrue);
      expect(ClippedImageFilter.isUsefulImageUrl('https://cdn.example.com/photo.jpg'), isTrue);
    });

    test('evaluates data URIs by payload length (skips 1x1 spacer, keeps rich diagram)', () {
      // Tiny 1x1 transparent GIF spacer (< 200 chars)
      const tinySpacer = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';
      expect(ClippedImageFilter.isUsefulImageUrl(tinySpacer), isFalse);

      // Rich SVG diagram data URI (> 200 chars)
      final encodedSvg = Uri.encodeComponent(
        '<svg width="800" height="400"><rect width="800" height="400" fill="#f0f0f0"/><text x="20" y="40">System Architecture</text></svg>' * 3,
      );
      final richSvgDataUri = 'data:image/svg+xml;utf8,$encodedSvg';
      expect(ClippedImageFilter.isUsefulImageUrl(richSvgDataUri), isTrue);
    });

    test('extracts best image source from <picture> with AVIF, WebP, and fallback', () {
      final doc = html_parser.parseFragment('''
        <picture id="pic1">
          <source type="image/avif" srcset="https://example.com/hero-800.avif 800w, https://example.com/hero-1600.avif 1600w">
          <source type="image/webp" srcset="https://example.com/hero.webp">
          <img src="https://example.com/hero-fallback.jpg" alt="Hero Banner">
        </picture>
      ''');

      final pic1 = doc.querySelector('#pic1')!;
      final bestSource = ClippedImageFilter.extractBestImageSource(pic1, baseUri);

      // Should prioritize the highest resolution AVIF source
      expect(bestSource, 'https://example.com/hero-1600.avif');
    });

    test('extracts best image from responsive srcset on <img> tag', () {
      final doc = html_parser.parseFragment('''
        <img id="img1" srcset="https://example.com/photo-400.webp 400w, https://example.com/photo-1200.avif 1200w" src="https://example.com/fallback.jpg" />
      ''');

      final img1 = doc.querySelector('#img1')!;
      final bestSource = ClippedImageFilter.extractBestImageSource(img1, baseUri);

      expect(bestSource, 'https://example.com/photo-1200.avif');
    });

    test('isMeaningfulImageBytes skips empty bytes or tiny dimensions', () {
      final emptyBytes = Uint8List(0);
      expect(ClippedImageFilter.isMeaningfulImageBytes(emptyBytes), isFalse);

      // 1x1 tracker dimension
      final trackerBytes = Uint8List(50);
      expect(
        ClippedImageFilter.isMeaningfulImageBytes(trackerBytes, intrinsicSize: const Size(1, 1)),
        isFalse,
      );

      // 16x16 icon dimension
      final iconBytes = Uint8List(50);
      expect(
        ClippedImageFilter.isMeaningfulImageBytes(iconBytes, intrinsicSize: const Size(16, 16)),
        isFalse,
      );

      // 800x600 content image
      final contentBytes = Uint8List(5000);
      expect(
        ClippedImageFilter.isMeaningfulImageBytes(contentBytes, intrinsicSize: const Size(800, 600)),
        isTrue,
      );
    });
  });
}
