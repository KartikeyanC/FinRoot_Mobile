import 'import_rows.dart';

/// PDF bank statements, the layout half: words with positions (from
/// `data/pdf_text_reader.dart`) to the table [parseImportTable] reads, so a
/// PDF goes through exactly the same date / amount / credit-as-income rules
/// as a CSV or Excel file. Pure Dart, unit-tested on its own.
///
/// A PDF has no cells, only text placed on a page. Words on one baseline
/// form a line; words close together on a line form a cell. The header is
/// the line (or two lines) naming a date and an amount / debit / credit
/// column; every later cell goes to the header column it sits under. A line
/// with a date starts a transaction, and text-only lines straight below it
/// (a narration that wraps) are joined onto it.
class PdfWord {
  const PdfWord(
    this.text, {
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    this.page = 1,
  });

  final String text;

  /// Points from the page's left edge.
  final double left;
  final double right;

  /// Points from the page's TOP edge (y grows downwards).
  final double top;
  final double bottom;
  final int page;

  double get height => bottom - top;
  double get charWidth => text.isEmpty ? 0 : (right - left) / text.runes.length;

  @override
  String toString() => 'PdfWord($text, $left-$right, $top-$bottom, p$page)';
}

/// One line of text on a page, its words left to right.
class PdfLine {
  PdfLine(this.page, this.words)
    : top = words.map((w) => w.top).reduce(_min),
      bottom = words.map((w) => w.bottom).reduce(_max);
  final int page;
  final List<PdfWord> words;
  final double top;
  final double bottom;
  double get height => bottom - top;

  @override
  String toString() => words.map((w) => w.text).join(' ');
}

double _min(double a, double b) => a < b ? a : b;
double _max(double a, double b) => a > b ? a : b;

/// Words to lines: per page, top to bottom; a word joins a line when their
/// vertical middles are within half a line height.
List<PdfLine> pdfLines(Iterable<PdfWord> words) {
  final sorted = words.where((w) => w.text.trim().isNotEmpty).toList()
    ..sort((a, b) {
      final p = a.page.compareTo(b.page);
      if (p != 0) return p;
      return (a.top + a.bottom).compareTo(b.top + b.bottom);
    });
  final lines = <PdfLine>[];
  var current = <PdfWord>[];
  double? mid;
  double? h;
  int? page;
  void flush() {
    if (current.isEmpty) return;
    current.sort((a, b) => a.left.compareTo(b.left));
    lines.add(PdfLine(page!, current));
    current = [];
  }

  for (final w in sorted) {
    final m = (w.top + w.bottom) / 2;
    if (page != w.page ||
        mid == null ||
        (m - mid).abs() > _max(h!, w.height) * 0.5) {
      flush();
      page = w.page;
      mid = m;
      h = w.height;
    }
    current.add(w);
  }
  flush();
  return lines;
}

/// A run of words on one line close enough to be one cell.
class _Cell {
  _Cell(this.words);
  final List<PdfWord> words;
  double get left => words.first.left;
  double get right => words.last.right;
  String get text => words.map((w) => w.text).join(' ');
}

/// Words closer than about one and a half characters stay one cell; a wider
/// gap is a column break.
List<_Cell> _cells(PdfLine line) {
  final out = <_Cell>[];
  for (final w in line.words) {
    if (out.isNotEmpty) {
      final prev = out.last.words.last;
      final cw = _max(prev.charWidth, w.charWidth);
      final gap = w.left - prev.right;
      if (gap <= _max(cw * 1.5, 1.0)) {
        out.last.words.add(w);
        continue;
      }
    }
    out.add(_Cell([w]));
  }
  return out;
}

/// A header line's cells. Header words are often printed as close together
/// as words inside one name ("Withdrawal Amt. Deposit Amt."), so each run of
/// close words is split where it reads best as known column names: words in
/// a cell that is exactly a known name score most, any other cell costs a
/// little, so unknown words ("Closing Balance") stay together.
List<_Cell> _headerCells(PdfLine line) {
  final out = <_Cell>[];
  for (final run in _cells(line)) {
    final w = run.words;
    double score(int from, int to) {
      final text = w.sublist(from, to).map((x) => x.text).join(' ');
      // Per word, so "Withdrawal Amt." beats "Withdrawal" + "Amt.".
      if (isExactImportHeader(text)) return 3.0 * (to - from);
      return importColumnOf(text) != null ? 0.5 : -0.5;
    }

    // best[i]: the best score for the first i words; cut[i]: where the last
    // cell of that best split starts.
    final best = List<double>.filled(w.length + 1, double.negativeInfinity);
    final cut = List<int>.filled(w.length + 1, 0);
    best[0] = 0;
    for (var i = 1; i <= w.length; i++) {
      for (var j = i - 1; j >= 0 && i - j <= 4; j--) {
        final s = best[j] + score(j, i) - 0.5;
        if (s > best[i]) {
          best[i] = s;
          cut[i] = j;
        }
      }
    }
    final cells = <_Cell>[];
    for (var i = w.length; i > 0; i = cut[i]) {
      cells.insert(0, _Cell(w.sublist(cut[i], i)));
    }
    out.addAll(cells);
  }
  return out;
}

class _Column {
  _Column(this.name, this.left, this.right);
  String name;
  double left;
  double right;
}

double _overlap(double l1, double r1, double l2, double r2) =>
    _min(r1, r2) - _max(l1, l2);

double _distance(double l1, double r1, double l2, double r2) =>
    l1 > r2 ? l1 - r2 : (l2 > r1 ? l2 - r1 : 0);

/// The header from one line, or from it and the line below when the
/// header wraps ("Withdrawal" over "Amount").
List<_Column>? _headerFrom(PdfLine line, PdfLine? next) {
  final cols = [
    for (final c in _headerCells(line)) _Column(c.text, c.left, c.right),
  ];
  if (isImportHeader(cols.map((c) => c.name))) return cols;
  if (next == null ||
      next.page != line.page ||
      next.top - line.bottom > _max(line.height, next.height)) {
    return null;
  }
  final merged = [for (final c in cols) _Column(c.name, c.left, c.right)];
  for (final c in _headerCells(next)) {
    final hit = merged.where(
      (m) => _overlap(m.left, m.right, c.left, c.right) > 0,
    );
    if (hit.isEmpty) {
      merged.add(_Column(c.text, c.left, c.right));
    } else {
      final m = hit.first;
      m
        ..name = '${m.name} ${c.text}'
        ..left = _min(m.left, c.left)
        ..right = _max(m.right, c.right);
    }
  }
  merged.sort((a, b) => a.left.compareTo(b.left));
  return isImportHeader(merged.map((c) => c.name)) ? merged : null;
}

/// The column a span sits under: the one it overlaps most, else the
/// nearest.
int _columnFor(List<_Column> cols, double left, double right) {
  var best = -1;
  var bestOverlap = 0.0;
  for (var i = 0; i < cols.length; i++) {
    final o = _overlap(cols[i].left, cols[i].right, left, right);
    if (o > bestOverlap) {
      bestOverlap = o;
      best = i;
    }
  }
  if (best >= 0) return best;
  var bestDistance = double.infinity;
  for (var i = 0; i < cols.length; i++) {
    final d = _distance(cols[i].left, cols[i].right, left, right);
    if (d < bestDistance) {
      bestDistance = d;
      best = i;
    }
  }
  return best;
}

/// A line's text spread over the header's columns. A cell that overlaps
/// more than one column (two columns printed close together) is split back
/// into its words. A money column ([money]) takes one value only — the one
/// sitting most squarely under it — so two amounts are never run together
/// into one number.
List<String> _spread(List<_Column> cols, PdfLine line, Set<int> money) {
  final parts = List.generate(
    cols.length,
    (_) => <({String text, double fit})>[],
  );
  void put(String text, double left, double right) {
    final i = _columnFor(cols, left, right);
    final fit = _overlap(cols[i].left, cols[i].right, left, right);
    if (money.contains(i) && parseImportAmount(text) != null) {
      // "Dr" / "Cr" beside the number may stay; a second number may not.
      final other = parts[i].indexWhere(
        (p) => parseImportAmount(p.text) != null,
      );
      if (other >= 0) {
        if (fit <= parts[i][other].fit) return;
        parts[i].removeAt(other);
      }
    }
    parts[i].add((text: text, fit: fit));
  }

  for (final c in _cells(line)) {
    final hits = cols
        .where((k) => _overlap(k.left, k.right, c.left, c.right) > 0)
        .length;
    final numbers = c.words
        .where((w) => parseImportAmount(w.text) != null)
        .length;
    if (hits <= 1 && numbers <= 1) {
      put(c.text, c.left, c.right);
    } else {
      for (final w in c.words) {
        put(w.text, w.left, w.right);
      }
    }
  }
  return [for (final p in parts) p.map((x) => x.text).join(' ')];
}

/// Lines of a PDF statement to a table: the header row, then one row per
/// transaction. Empty when no header line is found.
List<List<Object?>> pdfStatementTable(List<PdfLine> lines) {
  List<_Column>? cols;
  var at = -1;
  for (var i = 0; i < lines.length; i++) {
    final h = _headerFrom(lines[i], i + 1 < lines.length ? lines[i + 1] : null);
    if (h != null) {
      cols = h;
      at = i;
      break;
    }
  }
  if (cols == null) return const [];

  final kinds = [for (final c in cols) importColumnOf(c.name)];
  final cDate = kinds.indexOf(ImportColumn.date);
  bool isMoney(int i) =>
      kinds[i] == ImportColumn.amount ||
      kinds[i] == ImportColumn.debit ||
      kinds[i] == ImportColumn.credit;

  final money = {
    for (var i = 0; i < kinds.length; i++)
      if (isMoney(i)) i,
  };
  final table = <List<Object?>>[
    [for (final c in cols) c.name],
  ];
  List<String>? row;
  PdfLine? rowLine;
  for (var i = at + 1; i < lines.length; i++) {
    final line = lines[i];
    // The header again at the top of a later page: take its positions. (A
    // header has no figures, so a "Debit card" narration can't pass.)
    final again = RegExp(r'\d').hasMatch('$line')
        ? null
        : _headerFrom(line, null);
    if (again != null) {
      if (again.length == cols!.length) cols = again;
      row = null;
      continue;
    }
    final cells = _spread(cols!, line, money);
    final dated = parseImportDate(cells[cDate]) != null;
    final hasMoney = money.any((c) => parseImportAmount(cells[c]) != null);
    if (dated || (hasMoney && cells[cDate].isNotEmpty)) {
      // A transaction (one with an unreadable date is still passed on, so
      // the parser counts it as left out).
      row = cells;
      rowLine = line;
      table.add(row);
    } else if (hasMoney) {
      // Totals, opening / closing balance: not a transaction.
      row = null;
    } else if (row != null &&
        rowLine != null &&
        line.page == rowLine.page &&
        line.top - rowLine.bottom <= _max(line.height, rowLine.height) * 1.2) {
      // A wrapped narration: join it onto the transaction above.
      for (var c = 0; c < cells.length; c++) {
        if (cells[c].isEmpty) continue;
        row[c] = row[c].isEmpty ? cells[c] : '${row[c]} ${cells[c]}';
      }
      rowLine = line;
    }
  }
  return table;
}
