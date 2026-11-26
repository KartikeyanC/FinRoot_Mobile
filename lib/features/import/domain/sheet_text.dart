import 'dart:convert';

/// A "spreadsheet" that is really text: many banks' .xls downloads are an
/// HTML table or tab-separated text with an .xls name. Null when [bytes]
/// look like neither.
List<List<Object?>>? textTableFromXlsName(List<int> bytes) {
  final text = utf8.decode(bytes.take(1 << 22).toList(), allowMalformed: true);
  final lower = text.toLowerCase();
  if (lower.contains('<table')) return htmlTable(text);
  if (text.contains('\t')) {
    return [
      for (final line in const LineSplitter().convert(text))
        [for (final c in line.split('\t')) c.trim()],
    ];
  }
  return null;
}

/// The rows of the first HTML `<table>` that has any, cell text only.
List<List<Object?>> htmlTable(String html) {
  String clean(String s) => s
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final rows = <List<Object?>>[];
  final tr = RegExp(r'<tr[^>]*>(.*?)</tr>', caseSensitive: false, dotAll: true);
  final td = RegExp(
    r'<t[dh][^>]*>(.*?)</t[dh]>',
    caseSensitive: false,
    dotAll: true,
  );
  for (final r in tr.allMatches(html)) {
    rows.add([for (final c in td.allMatches(r[1]!)) clean(c[1]!)]);
  }
  return rows;
}
