import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Pure Dart utility to synchronously extract intrinsic dimensions (width, height)
/// from common image format binary byte headers (PNG, JPEG, GIF, WebP, BMP).
///
/// Running synchronously prevents async engine thread stalls and eliminates UI layout shifts.
abstract final class ImageDimensionReader {
  /// Attempts to extract intrinsic [Size] from raw image [bytes].
  /// Returns `null` if the format is unrecognized or corrupted.
  static Size? extractDimensions(Uint8List bytes) {
    if (bytes.length < 10) return null;

    try {
      // 1. PNG format: 8-byte magic (\x89PNG\r\n\x1a\n) + IHDR chunk at offset 12 (width at 16, height at 20)
      if (bytes.length >= 24 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        final byteData = ByteData.sublistView(bytes);
        final width = byteData.getUint32(16, Endian.big);
        final height = byteData.getUint32(20, Endian.big);
        if (width > 0 && height > 0) {
          return Size(width.toDouble(), height.toDouble());
        }
      }

      // 2. GIF format: "GIF87a" or "GIF89a" (width at 6, height at 8, little-endian 16-bit)
      if (bytes.length >= 10 &&
          bytes[0] == 0x47 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46) {
        final byteData = ByteData.sublistView(bytes);
        final width = byteData.getUint16(6, Endian.little);
        final height = byteData.getUint16(8, Endian.little);
        if (width > 0 && height > 0) {
          return Size(width.toDouble(), height.toDouble());
        }
      }

      // 3. BMP format: "BM" (width at 18, height at 22, little-endian 32-bit)
      if (bytes.length >= 26 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
        final byteData = ByteData.sublistView(bytes);
        final width = byteData.getInt32(18, Endian.little).abs();
        final height = byteData.getInt32(22, Endian.little).abs();
        if (width > 0 && height > 0) {
          return Size(width.toDouble(), height.toDouble());
        }
      }

      // 4. WebP format: "RIFF" .... "WEBP"
      if (bytes.length >= 30 &&
          bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        // VP8 (lossy): "VP8 " at offset 12, dimensions at offset 26
        if (bytes[12] == 0x56 && bytes[13] == 0x50 && bytes[14] == 0x38 && bytes[15] == 0x20) {
          if (bytes.length >= 30) {
            final byteData = ByteData.sublistView(bytes);
            final width = byteData.getUint16(26, Endian.little) & 0x3FFF;
            final height = byteData.getUint16(28, Endian.little) & 0x3FFF;
            if (width > 0 && height > 0) {
              return Size(width.toDouble(), height.toDouble());
            }
          }
        }
        // VP8L (lossless): "VP8L" at offset 12
        if (bytes[12] == 0x56 && bytes[13] == 0x50 && bytes[14] == 0x38 && bytes[15] == 0x4C) {
          if (bytes.length >= 25) {
            final b1 = bytes[21];
            final b2 = bytes[22];
            final b3 = bytes[23];
            final b4 = bytes[24];
            final width = 1 + (((b2 & 0x3F) << 8) | b1);
            final height = 1 + (((b4 & 0xF) << 10) | (b3 << 2) | ((b2 & 0xC0) >> 6));
            if (width > 0 && height > 0) {
              return Size(width.toDouble(), height.toDouble());
            }
          }
        }
        // VP8X (extended): "VP8X" at offset 12, canvas width at 24 (24-bit), height at 27 (24-bit)
        if (bytes[12] == 0x56 && bytes[13] == 0x50 && bytes[14] == 0x38 && bytes[15] == 0x58) {
          if (bytes.length >= 30) {
            final width = 1 + (bytes[24] | (bytes[25] << 8) | (bytes[26] << 16));
            final height = 1 + (bytes[27] | (bytes[28] << 8) | (bytes[29] << 16));
            if (width > 0 && height > 0) {
              return Size(width.toDouble(), height.toDouble());
            }
          }
        }
      }

      // 5. JPEG format: scan for SOF marker (0xFF, 0xC0..0xCF except 0xC4/0xC8/0xCC)
      if (bytes.length >= 4 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
        var offset = 2;
        final byteData = ByteData.sublistView(bytes);
        while (offset < bytes.length - 8) {
          if (bytes[offset] != 0xFF) {
            offset++;
            continue;
          }
          final marker = bytes[offset + 1];
          if (marker == 0xD9 || marker == 0xDA) {
            // End of image or start of scan
            break;
          }

          final length = byteData.getUint16(offset + 2, Endian.big);
          if (length < 2) break;

          // SOF0 (0xC0), SOF1 (0xC1), SOF2 (0xC2), SOF3 (0xC3), SOF5..SOF7, SOF9..SOF11, SOF13..SOF15
          if ((marker >= 0xC0 && marker <= 0xC3) ||
              (marker >= 0xC5 && marker <= 0xC7) ||
              (marker >= 0xC9 && marker <= 0xCB) ||
              (marker >= 0xCD && marker <= 0xCF)) {
            final height = byteData.getUint16(offset + 5, Endian.big);
            final width = byteData.getUint16(offset + 7, Endian.big);
            if (width > 0 && height > 0) {
              return Size(width.toDouble(), height.toDouble());
            }
          }

          offset += 2 + length;
        }
      }
    } catch (_) {}

    return null;
  }
}
