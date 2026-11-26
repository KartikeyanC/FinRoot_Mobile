import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import '../domain/pdf_statement.dart';

/// Why a PDF gave no words.
enum PdfReadProblem {
  /// Protected, and no password was given.
  needsPassword,

  /// Protected, and the password given didn't open it.
  wrongPassword,

  /// No text at all: a scan or a photo of a statement.
  noText,

  /// Not a PDF, or damaged.
  unreadable,
}

class PdfReadException implements Exception {
  const PdfReadException(this.problem);
  final PdfReadProblem problem;

  @override
  String toString() => 'PdfReadException($problem)';
}

/// Reads every word of a PDF with its position. Throws [PdfReadException].
typedef PdfWordReader = Future<List<PdfWord>> Function(
  List<int> bytes, {
  String? password,
});

/// The PDFium-backed reader (pdfrx). Text-based PDFs only; nothing leaves
/// the phone.
Future<List<PdfWord>> readPdfWords(List<int> bytes, {String? password}) async {
  await pdfrxFlutterInitialize();
  final PdfDocument doc;
  try {
    doc = await PdfDocument.openData(
      Uint8List.fromList(bytes),
      // Tried with no password first; then [password] once.
      passwordProvider: createSimplePasswordProvider(password),
    );
  } on PdfPasswordException {
    throw PdfReadException(
      password == null
          ? PdfReadProblem.needsPassword
          : PdfReadProblem.wrongPassword,
    );
  } on Object {
    throw const PdfReadException(PdfReadProblem.unreadable);
  }
  try {
    final words = <PdfWord>[];
    for (final page in doc.pages) {
      final text = await page.loadText();
      if (text == null) continue;
      words.addAll(
        wordsFromChars(
          text.fullText,
          [for (final r in text.charRects) (r.left, r.top, r.right, r.bottom)],
          pageHeight: page.height,
          page: page.pageNumber,
        ),
      );
    }
    if (words.isEmpty) throw const PdfReadException(PdfReadProblem.noText);
    return words;
  } finally {
    await doc.dispose();
  }
}

/// PDFium's characters (boxes in PDF space, y up) to words (y down). A
/// space, a line break or a gap wider than half the text height ends a word.
List<PdfWord> wordsFromChars(
  String text,
  List<(double, double, double, double)> boxes, {
  required double pageHeight,
  required int page,
}) {
  final words = <PdfWord>[];
  final buf = StringBuffer();
  double l = 0, t = 0, r = 0, b = 0;
  void flush() {
    if (buf.isEmpty) return;
    words.add(
      PdfWord(
        buf.toString(),
        left: l,
        right: r,
        top: pageHeight - t,
        bottom: pageHeight - b,
        page: page,
      ),
    );
    buf.clear();
  }

  // One box per character (rune), as PDFium counts them.
  final runes = text.runes.toList();
  for (var i = 0; i < runes.length && i < boxes.length; i++) {
    final ch = String.fromCharCode(runes[i]);
    if (ch.trim().isEmpty || runes[i] == 0xFFFE) {
      flush();
      continue;
    }
    final (cl, ct, cr, cb) = boxes[i];
    if (buf.isNotEmpty) {
      final wh = (t - b).abs();
      final ch2 = (ct - cb).abs();
      final h = wh > ch2 ? wh : ch2;
      final sameLine = (((ct + cb) / 2) - ((t + b) / 2)).abs() < h * 0.6;
      // A character that starts back over the last one is new text placed
      // on top (a clipped cell running under the next column).
      if (!sameLine || cl - r > h * 0.5 || cl < r - h * 0.25) {
        flush();
      }
    }
    if (buf.isEmpty) {
      l = cl;
      t = ct;
      r = cr;
      b = cb;
    } else {
      r = cr > r ? cr : r;
      t = ct > t ? ct : t;
      b = cb < b ? cb : b;
    }
    buf.write(ch);
  }
  flush();
  return words;
}
