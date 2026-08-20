import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/notes/application/notes_provider.dart';
import '../image_processing/image_processor.dart';
import '../pdf/pdf_generator.dart';
import '../pdf/pdf_page_renderer.dart';
import '../pdf/pdf_text_extractor.dart';
import '../sync/sync_provider.dart';
import 'document_processing_service.dart';
import 'ocr_crypto.dart';
import 'ocr_service.dart';

/// Provider for image processing operations (adjustments, crop, rotate, normalize).
final imageProcessorProvider = Provider<ImageProcessor>((ref) {
  return const DartImageProcessor();
});

/// Provider for compiling scanned pages to PDF documents.
final pdfGeneratorProvider = Provider<PdfGenerator>((ref) {
  return const DefaultPdfGenerator();
});

/// Provider for rendering PDF pages to image bitmaps.
final pdfPageRendererProvider = Provider<PdfPageRenderer>((ref) {
  return const DefaultPdfPageRenderer();
});

/// Provider for extracting embedded text layer from PDF documents.
final pdfTextExtractorProvider = Provider<PdfTextExtractor>((ref) {
  return const DefaultPdfTextExtractor();
});

/// Provider for on-device OCR recognition engine.
final ocrServiceProvider = Provider<OcrService>((ref) {
  final renderer = ref.watch(pdfPageRendererProvider);
  return DefaultOcrService(pageRenderer: renderer);
});

/// Provider for client-side authenticated OCR payload encryption.
final ocrCryptoProvider = Provider<OcrCrypto>((ref) {
  final cryptoService = ref.watch(cryptoServiceProvider);
  return OcrCrypto(cryptoService: cryptoService);
});

/// Provider for background document text extraction and OCR processing service.
final documentProcessingServiceProvider = Provider<DocumentProcessingService>((ref) {
  final database = ref.watch(databaseProvider);
  final keyManager = ref.watch(keyManagerProvider);
  final ocrCrypto = ref.watch(ocrCryptoProvider);
  final textExtractor = ref.watch(pdfTextExtractorProvider);
  final pageRenderer = ref.watch(pdfPageRendererProvider);
  final ocrService = ref.watch(ocrServiceProvider);

  return DocumentProcessingService(
    database: database,
    keyManager: keyManager,
    ocrCrypto: ocrCrypto,
    textExtractor: textExtractor,
    pageRenderer: pageRenderer,
    ocrService: ocrService,
  );
});
