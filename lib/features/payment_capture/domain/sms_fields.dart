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

// A month name, short or full, as a whole word — "7 MARKETS" is not a date.
const _mon =
    r'(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|'
    r'aug(?:ust)?|sep(?:t|tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)'
    r'(?![a-z])\.?';

// A year that is not the start of a clock ("12 Dec 10:30" has no year).
const _year = r'(\d{4}|\d{2})(?![\d:])';

// dd-mm-yy(yy) / dd/mm/yyyy / dd.mm.yy — day first, the Indian way.
final _numericDate = _re([r'\b(\d{1,2})[-/.](\d{1,2})[-/.]', _year].join());
// 31Oct26 / 31-Oct-2026 / 31 Oct 2026 / 12th Nov 2026 / 12-Nov (no year).
final _namedDate = _re(
  [
    r'\b(\d{1,2})(?:st|nd|rd|th)?[-/ ]?',
    _mon,
    r'(?:[-/ ,]*',
    _year,
    ')?',
  ].join(),
);
// Nov 12, 2026 / November 12 2026 / Nov 12 (no year) — month first.
final _monthFirstDate = _re(
  [
    r'\b',
    _mon,
    r'[ -]?(\d{1,2})(?:st|nd|rd|th)?(?![\d:])',
    r'(?:,?[ -]*',
    _year,
    ')?',
  ].join(),
);
// 2026-10-31 / 2026/10/31 / 2026.10.31
final _isoDate = _re(r'\b(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?!\d)');
// 14:05 / 14:05:12 / 2:05 PM / 02:05pm / 2:05 p.m.
final _clock = _re(
  r'\b(\d{1,2}):(\d{2})(?::(\d{2}))?(?:\s*([ap])\.?\s?m(?![a-z])\.?)?',
);

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
  final date = _dateIn(text, ref: receivedAt);
  if (date == null) return null;
  final clock = _clockNear(text, date);
  if (clock == null) return null;

  final at = DateTime(
    date.year,
    date.month,
    date.day,
    clock.hour,
    clock.minute,
    clock.second,
  );
  if (at.isAfter(receivedAt.add(_maxAhead))) return null;
  if (at.isBefore(receivedAt.subtract(_maxDelay))) return null;
  return at;
}

/// The date a message carries, with its time when one is printed next to it
/// (midnight otherwise), or null when it names no date.
///
/// For messages pasted into Import: unlike [alertTimeIn] there is no arrival
/// time to check against — an alert copied from last month keeps last
/// month's date. Only a date more than a day in the future is distrusted.
DateTime? messageDateIn(String text, {required DateTime now}) {
  final date = _dateIn(text, ref: now);
  if (date == null) return null;
  final day = DateTime(date.year, date.month, date.day);
  if (day.isAfter(now.add(const Duration(days: 1)))) return null;
  final clock = _clockNear(text, date);
  return DateTime(
    date.year,
    date.month,
    date.day,
    clock?.hour ?? 0,
    clock?.minute ?? 0,
    clock?.second ?? 0,
  );
}

typedef _Date = ({
  int year,
  int month,
  int day,
  int start,
  int end,
  bool hasYear,
});
typedef _Clock = ({int hour, int minute, int second});

/// The first real calendar date in [text]. A date with no year takes [ref]'s
/// year — or the year before, when that would put it more than a day after
/// [ref] ("28 Dec" read on 2 Jan is last December).
_Date? _dateIn(String text, {required DateTime ref}) {
  int fullYear(String y) => y.length == 2 ? 2000 + int.parse(y) : int.parse(y);
  int month(String m) => _months[m.toLowerCase().substring(0, 3)]!;

  _Date? best;
  void consider(RegExpMatch m, int? y, int mo, int d) {
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return;
    var year = y ?? ref.year;
    if (y == null &&
        DateTime(year, mo, d).isAfter(ref.add(const Duration(days: 1)))) {
      year--;
    }
    if (year < 2000 || year > 2100) return;
    final real = DateTime(year, mo, d);
    if (real.month != mo || real.day != d) return; // 31-02
    final b = best;
    final hasYear = y != null;
    // A date that prints its year beats one that doesn't; then the earliest
    // wins; at the same place, the longer reading ("12 Nov 26" over "Nov 26").
    final better =
        b == null ||
        (hasYear && !b.hasYear) ||
        (hasYear == b.hasYear &&
            (m.start < b.start || (m.start == b.start && m.end > b.end)));
    if (better) {
      best = (
        year: year,
        month: mo,
        day: d,
        start: m.start,
        end: m.end,
        hasYear: hasYear,
      );
    }
  }

  for (final m in _numericDate.allMatches(text)) {
    consider(
      m,
      fullYear(m.group(3)!),
      int.parse(m.group(2)!),
      int.parse(m.group(1)!),
    );
  }
  for (final m in _namedDate.allMatches(text)) {
    final y = m.group(3);
    consider(
      m,
      y == null ? null : fullYear(y),
      month(m.group(2)!),
      int.parse(m.group(1)!),
    );
  }
  for (final m in _monthFirstDate.allMatches(text)) {
    final y = m.group(3);
    consider(
      m,
      y == null ? null : fullYear(y),
      month(m.group(1)!),
      int.parse(m.group(2)!),
    );
  }
  for (final m in _isoDate.allMatches(text)) {
    consider(
      m,
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }
  return best;
}

/// The clock printed right next to [date]: just after it ("31-10-26 14:05",
/// "on 31Oct26 at 2:05 PM") or just before it ("14:05 on 31-10-26"). A time
/// elsewhere in the text is something else.
_Clock? _clockNear(String text, _Date date) {
  final after = _clock.firstMatch(text.substring(date.end));
  if (after != null && after.start <= 12) return _clockOf(after);

  final before = text.substring(0, date.start);
  final lead = _clock.allMatches(before).lastOrNull;
  if (lead != null && before.length - lead.end <= 12) return _clockOf(lead);
  return null;
}

_Clock? _clockOf(RegExpMatch c) {
  var hour = int.parse(c.group(1)!);
  final minute = int.parse(c.group(2)!);
  final second = int.tryParse(c.group(3) ?? '') ?? 0;
  final ampm = c.group(4)?.toLowerCase();
  if (ampm != null) {
    if (hour < 1 || hour > 12) return null;
    if (ampm == 'p' && hour != 12) hour += 12;
    if (ampm == 'a' && hour == 12) hour = 0;
  }
  if (hour > 23 || minute > 59 || second > 59) return null;
  return (hour: hour, minute: minute, second: second);
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
