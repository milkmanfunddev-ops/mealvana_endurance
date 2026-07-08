import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Thrown when a picked file's extension isn't a supported document type.
class UnsupportedDocumentException implements Exception {
  const UnsupportedDocumentException(this.extension);
  final String extension;
  @override
  String toString() => 'UnsupportedDocumentException: .$extension';
}

/// Thrown when a supported document can't be decoded (corrupt/encrypted/etc.).
class DocumentExtractionException implements Exception {
  const DocumentExtractionException(this.extension, this.detail);
  final String extension;
  final String detail;
  @override
  String toString() => 'DocumentExtractionException(.$extension): $detail';
}

/// Extracts plain text from a meal-plan document entirely on-device.
///
/// Supports PDF (via Syncfusion), DOCX (a zip — we read `word/document.xml`
/// directly), and plain text (`txt`/`md`). The file itself is never uploaded or
/// stored; only the extracted text is later sent to the AI.
///
/// A scanned / image-only PDF has no text layer and yields little or no text —
/// callers should treat a near-empty result as "no readable text found".
class MealPlanTextExtractor {
  const MealPlanTextExtractor._();

  /// Extensions we can pull text from — also used to filter the file picker.
  static const supportedExtensions = ['pdf', 'docx', 'txt', 'md', 'markdown'];

  /// Extract text from [bytes] given its (case-insensitive) file [extension].
  ///
  /// Runs on the calling isolate. It is CPU-bound for large PDFs; call it after
  /// a busy indicator is on screen. Throws [UnsupportedDocumentException] for an
  /// unknown extension and [DocumentExtractionException] when decoding fails.
  static String extract({
    required Uint8List bytes,
    required String extension,
  }) {
    final ext = extension.toLowerCase();
    try {
      switch (ext) {
        case 'pdf':
          return _extractPdf(bytes);
        case 'docx':
          return _extractDocx(bytes);
        case 'txt':
        case 'md':
        case 'markdown':
          return utf8.decode(bytes, allowMalformed: true);
        default:
          throw UnsupportedDocumentException(ext);
      }
    } on UnsupportedDocumentException {
      rethrow;
    } catch (e) {
      throw DocumentExtractionException(ext, e.toString());
    }
  }

  static String _extractPdf(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      return PdfTextExtractor(document).extractText();
    } finally {
      document.dispose();
    }
  }

  static String _extractDocx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final docXml = archive.findFile('word/document.xml')?.readBytes();
    if (docXml == null) return '';

    var xml = utf8.decode(docXml, allowMalformed: true);
    // Preserve document structure before stripping tags: paragraph and line
    // breaks become newlines, tab elements become tabs.
    xml = xml
        .replaceAll(RegExp(r'<w:tab\b[^>]*/?>'), '\t')
        .replaceAll(RegExp(r'<w:br\b[^>]*/?>'), '\n')
        .replaceAll('</w:p>', '\n');
    // Strip every remaining tag, then unescape XML entities. `&amp;` is
    // unescaped LAST so an escaped entity like `&amp;lt;` isn't double-decoded.
    final stripped = xml.replaceAll(RegExp(r'<[^>]+>'), '');
    return stripped
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&');
  }
}
