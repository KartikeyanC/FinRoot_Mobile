/// Field extractors for Indian bank alert text — the parts
/// `parsePaymentNotice` did not read before Stage 7: which of your accounts
/// moved, when the bank says it happened, and which bank sent it.
///
/// Pure functions over the alert text; everything runs on the phone and
/// nothing leaves it until the person adds the payment.
library;

RegExp _re(String p) => RegExp(p, caseSensitive: false);

// ---------------------------------------------------------------------------
// Account / card last four

final _accountPatterns = <RegExp>[
  // "A/c XX5678", "a/c no. XXXXXX5678", "Acct *5678", "card no. XX4321",
  // "A/C **5678", "AC X5678", "Card xx4321"
  _re(
    r'\b(?:a/?c|acct|account|card|ac)\b(?:\s*(?:no|number)\.?)?'
    r'[\s:.-]*[x*•]+[\s-]*(\d{4})\b',
  ),
  // "card ending 4321", "A/c ending with 1234", "Card ending in XX4321"
  _re(
    r'\b(?:card|a/?c|acct|account)\b(?:\s*(?:no|number)\.?)?\s+ending'
    r'(?:\s+(?:with|in))?[\s:]*[x*•]*(\d{4})\b',
  ),
  // An unmasked account number: keep only its last four.
  _re(
    r'\b(?:a/?c|acct|account)\b(?:\s*(?:no|number)\.?)?[\s:.-]*\d{5,14}(\d{4})\b',
  ),
];

/// The last four digits of YOUR account or card named in the alert, or null.
/// Takes the first one mentioned — banks name the account that moved first
/// ("A/c XX5678 debited … to A/c XX9999").
String? accountLast4In(String text) {
  int? best;
  String? digits;
  for (final re in _accountPatterns) {
    final m = re.firstMatch(text);
    if (m != null && (best == null || m.start < best)) {
      best = m.start;
      digits = m.group(1);
    }
  }
  return digits;
}

// ---------------------------------------------------------------------------
// The time printed in the alert

const _months = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

// dd-mm-yy(yy) / dd/mm/yyyy / dd.mm.yy
final _numericDate = _re(r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2}|\d{4})\b');
// 31Oct26 / 31-Oct-2026 / 31 Oct 2026 / 31-OCT-26
final _namedDate = _re(
  r'\b(\d{1,2})[-/ ]?(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*'
  r'[-/ ,]*(\d{2}|\d{4})\b',
);
// 2026-10-31
final _isoDate = _re(r'\b(\d{4})-(\d{2})-(\d{2})\b');
// 14:05 / 14:05:12 / 2:05 PM / 02:05pm
final _clock = _re(r'\b(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(am|pm)?\b');

/// How far the printed time may sit from when the alert arrived before it is
/// distrusted (a typo'd year, a "valid till" date, a reference that looks like
/// a date). Banks send within seconds; an outage can delay an SMS by hours.
const _maxDelay = Duration(days: 3);
const _maxAhead = Duration(minutes: 10);

/// The date AND time the bank printed, in the device's zone, or null.
///
/// Null whenever there is no time of day: a date alone cannot place a payment
/// in a minute, and the minute is part of the de-dup key — the arrival time is
/// the better guess then, and the caller falls back to it.
DateTime? alertTimeIn(String text, {required DateTime receivedAt}) {
  final date = _dateIn(text);
  if (date == null) return null;

  // The clock must follow the date closely ("31-10-26 14:05", "on 31Oct26 at
  // 2:05 PM"); a time elsewhere in the text is something else.
  final after = text.substring(date.end);
  final c = _clock.firstMatch(after);
  if (c == null || c.start > 12) return null;

  var hour = int.parse(c.group(1)!);
  final minute = int.parse(c.group(2)!);
  final second = int.tryParse(c.group(3) ?? '') ?? 0;
  final ampm = c.group(4)?.toLowerCase();
  if (ampm != null) {
    if (hour < 1 || hour > 12) return null;
    if (ampm == 'pm' && hour != 12) hour += 12;
    if (ampm == 'am' && hour == 12) hour = 0;
  }
  if (hour > 23 || minute > 59 || second > 59) return null;

  final at = DateTime(date.year, date.month, date.day, hour, minute, second);
  if (at.month != date.month || at.day != date.day) return null; // 31-02
  if (at.isAfter(receivedAt.add(_maxAhead))) return null;
  if (at.isBefore(receivedAt.subtract(_maxDelay))) return null;
  return at;
}

typedef _Date = ({int year, int month, int day, int end});

_Date? _dateIn(String text) {
  _Date? pick(_Date? a, _Date? b) =>
      a == null ? b : (b == null ? a : (a.end <= b.end ? a : b));
  int year(String y) => y.length == 2 ? 2000 + int.parse(y) : int.parse(y);

  _Date? numeric;
  final n = _numericDate.firstMatch(text);
  if (n != null) {
    final d = int.parse(n.group(1)!), m = int.parse(n.group(2)!);
    if (d >= 1 && d <= 31 && m >= 1 && m <= 12) {
      numeric = (year: year(n.group(3)!), month: m, day: d, end: n.end);
    }
  }

  _Date? named;
  final w = _namedDate.firstMatch(text);
  if (w != null) {
    final d = int.parse(w.group(1)!);
    if (d >= 1 && d <= 31) {
      named = (
        year: year(w.group(3)!),
        month: _months[w.group(2)!.toLowerCase().substring(0, 3)]!,
        day: d,
        end: w.end,
      );
    }
  }

  _Date? iso;
  final i = _isoDate.firstMatch(text);
  if (i != null) {
    final m = int.parse(i.group(2)!), d = int.parse(i.group(3)!);
    if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
      iso = (year: int.parse(i.group(1)!), month: m, day: d, end: i.end);
    }
  }
  return pick(pick(numeric, named), iso);
}

// ---------------------------------------------------------------------------
// The bank, from the DLT sender id ("AD-HDFCBK", "VM-SBIINB", "JD-ICICIT")

const _senderBanks = <String, String>{
  'HDFC': 'HDFC Bank',
  'SBI': 'SBI',
  'ICICI': 'ICICI Bank',
  'AXIS': 'Axis Bank',
  'KOTAK': 'Kotak',
  'KOTK': 'Kotak',
  'YESB': 'Yes Bank',
  'IDFC': 'IDFC FIRST',
  'INDUS': 'IndusInd',
  'PNB': 'PNB',
  'BOB': 'Bank of Baroda',
  'BARODA': 'Bank of Baroda',
  'CANBNK': 'Canara Bank',
  'CNRB': 'Canara Bank',
  'UNIONB': 'Union Bank',
  'UBOI': 'Union Bank',
  'FEDBNK': 'Federal Bank',
  'AUBANK': 'AU Bank',
  'IOB': 'Indian Overseas Bank',
  'SCBANK': 'Standard Chartered',
  'PAYTMB': 'Paytm Payments Bank',
  'AIRBNK': 'Airtel Payments Bank',
};

/// "HDFC Bank" for "AD-HDFCBK", or null for a sender that is not a known bank.
String? bankFromSender(String sender) {
  final id = sender.toUpperCase().replaceFirst(RegExp(r'^[A-Z]{2}-'), '');
  for (final e in _senderBanks.entries) {
    if (id.contains(e.key)) return e.value;
  }
  return null;
}
