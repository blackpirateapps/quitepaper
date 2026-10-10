import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'scan_mode.dart';

/// Pure-Dart implementations of the scanner [ScanMode] pipelines.
///
/// These are **spatial** operations (illumination flatten, adaptive threshold,
/// gray-world white balance): they cannot be expressed as a GPU colour matrix or
/// a global contrast curve, which is exactly why the old "fake presets" could
/// not make a photo look scanned.
///
/// Everything here is a pure function of its inputs so it is safe to run inside
/// a `compute()` isolate. Heavy blurs are estimated on a small downscaled copy
/// and upscaled back, so cost is roughly independent of the source resolution.
///
/// This is the always-available baseline. A future `OpenCvImageProcessor` can
/// replace these with native equivalents behind the same `ImageProcessor` seam
/// for extra speed/quality; the mode contract stays identical.
class ScanPipelines {
  const ScanPipelines._();

  /// Max dimension of the downscaled copy used to estimate the background /
  /// local mean. Larger = finer illumination map but slower.
  static const int _estimateMaxDim = 320;

  /// Applies the colour/tone pipeline for [mode] to an already
  /// geometry-corrected (oriented/rotated/cropped/resized) image.
  ///
  /// Returns a 3-channel image suitable for PDF embedding. Does **not** apply
  /// the [ImageAdjustments] knobs — those compose on top afterwards.
  static img.Image apply(img.Image src, ScanMode mode) {
    switch (mode) {
      case ScanMode.original:
        return src;
      case ScanMode.grayscale:
        return _grayscalePipeline(src);
      case ScanMode.blackAndWhite:
        return _blackAndWhitePipeline(src);
      case ScanMode.document:
        return _documentPipeline(src);
      case ScanMode.auto:
        return _autoPipeline(src);
      case ScanMode.whiteboard:
        return _whiteboardPipeline(src);
    }
  }

  // ----------------------------------------------------------------- pipelines

  static img.Image _grayscalePipeline(img.Image src) {
    final gray = img.grayscale(src.clone());
    // Mild contrast lift for legibility without the harshness of thresholding.
    return img.adjustColor(gray, contrast: 1.08);
  }

  static img.Image _blackAndWhitePipeline(img.Image src) {
    final gray = img.grayscale(src.clone());
    final flat = illuminationFlatten(gray, strength: 1.0);
    final bw = adaptiveThreshold(flat, cOffset: 10);
    return despeckle(bw);
  }

  static img.Image _documentPipeline(img.Image src) {
    final flat = illuminationFlatten(src.clone(), strength: 0.7);
    // Gentle contrast; keep colours faithful (no white balance, no saturation).
    return img.adjustColor(flat, contrast: 1.06);
  }

  static img.Image _autoPipeline(img.Image src) {
    var out = illuminationFlatten(src.clone(), strength: 1.0);
    out = grayWorldWhiteBalance(out);
    out = img.adjustColor(out, contrast: 1.1, saturation: 1.08);
    out = unsharpMask(out, amount: 0.5);
    return out;
  }

  static img.Image _whiteboardPipeline(img.Image src) {
    var out = illuminationFlatten(src.clone(), strength: 1.0, whitePush: 0.35);
    out = grayWorldWhiteBalance(out);
    out = img.adjustColor(out, saturation: 1.3, contrast: 1.05);
    return out;
  }

  // --------------------------------------------------------- building blocks

  /// Estimates the lighting/background on a small blurred copy and divides the
  /// source by it, flattening soft shadows and uneven illumination and driving
  /// paper toward white. The core "scanner" trick.
  ///
  /// [strength] blends the flattened result with the original (0 = none, 1 =
  /// full). [whitePush] additionally lifts near-white pixels toward pure white
  /// (used by the whiteboard mode).
  static img.Image illuminationFlatten(
    img.Image src, {
    double strength = 1.0,
    double whitePush = 0.0,
  }) {
    final bg = _estimateBackground(src);
    final out = img.Image(
      width: src.width,
      height: src.height,
      numChannels: 3,
    );

    final whiteCut = 255.0 * 0.80;
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final s = src.getPixel(x, y);
        final b = bg.getPixel(x, y);
        final r = _flattenChannel(s.r.toDouble(), b.r.toDouble(), strength);
        final g = _flattenChannel(s.g.toDouble(), b.g.toDouble(), strength);
        final bl = _flattenChannel(s.b.toDouble(), b.b.toDouble(), strength);
        if (whitePush > 0) {
          out.setPixelRgb(
            x,
            y,
            _pushWhite(r, whiteCut, whitePush),
            _pushWhite(g, whiteCut, whitePush),
            _pushWhite(bl, whiteCut, whitePush),
          );
        } else {
          out.setPixelRgb(x, y, r, g, bl);
        }
      }
    }
    return out;
  }

  static double _flattenChannel(double v, double bg, double strength) {
    final flat = bg <= 1.0 ? 255.0 : (v / bg) * 255.0;
    final blended = v + (flat - v) * strength;
    return blended.clamp(0.0, 255.0);
  }

  static int _pushWhite(double v, double cut, double amount) {
    if (v < cut) return v.round();
    final t = (v - cut) / (255.0 - cut);
    return (v + (255.0 - v) * amount * t).clamp(0.0, 255.0).round();
  }

  /// Builds a smooth background estimate by heavily blurring a downscaled copy
  /// and upscaling it back — cheap and resolution-independent.
  static img.Image _estimateBackground(img.Image src) {
    final maxDim = math.max(src.width, src.height);
    img.Image small = src;
    if (maxDim > _estimateMaxDim) {
      if (src.width >= src.height) {
        small = img.copyResize(src, width: _estimateMaxDim, interpolation: img.Interpolation.average);
      } else {
        small = img.copyResize(src, height: _estimateMaxDim, interpolation: img.Interpolation.average);
      }
    } else {
      small = src.clone();
    }
    final radius = math.max(3, (math.max(small.width, small.height) / 8).round());
    final blurred = img.gaussianBlur(small, radius: radius);
    return img.copyResize(
      blurred,
      width: src.width,
      height: src.height,
      interpolation: img.Interpolation.linear,
    );
  }

  /// Gaussian adaptive threshold: compares each pixel to the local mean
  /// (estimated as a blurred downscaled copy) offset by [cOffset] in the
  /// 0–255 range. Produces clean black-on-white on uneven lighting.
  static img.Image adaptiveThreshold(img.Image src, {double cOffset = 10}) {
    final gray = src.numChannels == 1 ? src : img.grayscale(src.clone());
    final mean = _estimateBackground(gray);
    final out = img.Image(width: src.width, height: src.height, numChannels: 3);
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final v = gray.getPixel(x, y).r.toDouble();
        final m = mean.getPixel(x, y).r.toDouble();
        final on = v > (m - cOffset);
        final c = on ? 255 : 0;
        out.setPixelRgb(x, y, c, c, c);
      }
    }
    return out;
  }

  /// 3×3 median filter to remove salt-and-pepper speckle from a binary image.
  static img.Image despeckle(img.Image src) {
    final out = img.Image(width: src.width, height: src.height, numChannels: 3);
    final window = <int>[];
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        window.clear();
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final nx = (x + dx).clamp(0, src.width - 1);
            final ny = (y + dy).clamp(0, src.height - 1);
            window.add(src.getPixel(nx, ny).r.toInt());
          }
        }
        window.sort();
        final m = window[4];
        out.setPixelRgb(x, y, m, m, m);
      }
    }
    return out;
  }

  /// Gray-world white balance: scales each channel so the average colour is
  /// neutral gray. Removes colour casts from ambient light.
  static img.Image grayWorldWhiteBalance(img.Image src) {
    double sumR = 0, sumG = 0, sumB = 0;
    final n = src.width * src.height;
    if (n == 0) return src;
    for (final p in src) {
      sumR += p.r;
      sumG += p.g;
      sumB += p.b;
    }
    final meanR = sumR / n;
    final meanG = sumG / n;
    final meanB = sumB / n;
    final gray = (meanR + meanG + meanB) / 3.0;
    final scaleR = (meanR <= 0.5 ? 1.0 : gray / meanR).clamp(0.5, 2.0);
    final scaleG = (meanG <= 0.5 ? 1.0 : gray / meanG).clamp(0.5, 2.0);
    final scaleB = (meanB <= 0.5 ? 1.0 : gray / meanB).clamp(0.5, 2.0);

    final out = img.Image(width: src.width, height: src.height, numChannels: 3);
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        out.setPixelRgb(
          x,
          y,
          (p.r * scaleR).clamp(0.0, 255.0).round(),
          (p.g * scaleG).clamp(0.0, 255.0).round(),
          (p.b * scaleB).clamp(0.0, 255.0).round(),
        );
      }
    }
    return out;
  }

  /// Unsharp mask: `out = src*(1+amount) - blur*amount`, lifting local detail.
  static img.Image unsharpMask(img.Image src, {double amount = 0.5}) {
    final blur = img.gaussianBlur(src.clone(), radius: 2);
    final out = img.Image(width: src.width, height: src.height, numChannels: 3);
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final s = src.getPixel(x, y);
        final b = blur.getPixel(x, y);
        out.setPixelRgb(
          x,
          y,
          (s.r * (1 + amount) - b.r * amount).clamp(0.0, 255.0).round(),
          (s.g * (1 + amount) - b.g * amount).clamp(0.0, 255.0).round(),
          (s.b * (1 + amount) - b.b * amount).clamp(0.0, 255.0).round(),
        );
      }
    }
    return out;
  }
}
