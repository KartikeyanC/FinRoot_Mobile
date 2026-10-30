import '../../../domain/constants.dart';
import '../../transactions/domain/transaction.dart';

/// Quote one CSV field (RFC 4180): wrap in double quotes when it holds a comma,
/// quote, CR or LF, doubling any inner quotes.
String csvField(String value) {
  if (value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// Free text from a person could start with `=`, `+`, `-` or `@` and be run as
/// a formula by a spreadsheet; a leading apostrophe neutralises that.
String _safeText(String? value) {
  final v = value ?? '';
  if (v.isEmpty) return v;
  return switch (v[0]) {
    '=' || '+' || '-' || '@' || '\t' || '\r' => "'$v",
    _ => v,
  };
}

const csvHeader = [
  'Date',
  'Type',
  'Category',
  'Description',
  'Amount',
  'Currency',
  'Payment mode',
  'Account',
  'To account',
];

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Transactions as CSV text (CRLF line ends, header row first). [accountNames]
/// maps account id to its name; an unknown id exports blank.
String transactionsToCsv(
  List<TransactionEntity> transactions, {
  Map<String, String> accountNames = const {},
}) {
  final rows = <String>[csvHeader.map(csvField).join(',')];
  for (final t in transactions) {
    rows.add(
      [
        _date(t.occurredAt.toLocal()),
        t.type.name,
        _safeText(t.category),
        _safeText(t.description?.trim()),
        t.amount.toStorageString(),
        t.amount.currency,
        _safeText(t.paymentMode),
        _safeText(accountNames[t.accountId]),
        _safeText(accountNames[t.transferToAccountId]),
      ].map(csvField).join(','),
    );
  }
  return '${rows.join('\r\n')}\r\n';
}

/// Keep [TxnType]s selected (null = all).
List<TransactionEntity> filterByType(
  List<TransactionEntity> all,
  TxnType? type,
) => type == null ? all : all.where((t) => t.type == type).toList();
