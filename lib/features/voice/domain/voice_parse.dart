import '../../../core/money/money.dart';
import '../../../domain/constants.dart';
import '../../quick_add/domain/quick_add_draft.dart';

/// A Quick Add draft parsed from a spoken sentence.
///
/// The parser is a **local grammar** — no server, no NLU model. It aims to get
/// the common cases right ("spent 400 on groceries with card yesterday") and
/// leave anything it is unsure about null, so the review step can fill it in.
class VoiceDraft {
  const VoiceDraft({
    required this.transcript,
    required this.kind,
    required this.occurredAt,
    this.amount,
    this.category,
    this.paymentMode,
    this.note,
  });

  final String transcript;
  final QuickAddKind kind;
  final DateTime occurredAt;
  final Money? amount;
  final String? category;
  final String? paymentMode;
  final String? note;

  /// The one thing the parser must find for the draft to be usable.
  bool get understood => amount != null && amount!.isPositive;

  VoiceDraft copyWith({
    QuickAddKind? kind,
    DateTime? occurredAt,
    Money? amount,
    String? category,
    String? paymentMode,
    String? note,
  }) => VoiceDraft(
    transcript: transcript,
    kind: kind ?? this.kind,
    occurredAt: occurredAt ?? this.occurredAt,
    amount: amount ?? this.amount,
    category: category ?? this.category,
    paymentMode: paymentMode ?? this.paymentMode,
    note: note ?? this.note,
  );
}

/// Parse [transcript] into a [VoiceDraft]. [now] is injectable for tests.
VoiceDraft parseUtterance(String transcript, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final text = transcript.toLowerCase().trim();

  final kind = _parseKind(text);
  final amount = _parseAmount(text);
  final paymentMode = _firstMatch(text, _paymentModeWords);
  final category = _parseCategory(text, kind);
  final occurredAt = _parseDate(text, ref);
  final note = _parseNote(text, category);

  return VoiceDraft(
    transcript: transcript.trim(),
    kind: kind,
    amount: amount,
    category: category,
    paymentMode: paymentMode,
    occurredAt: occurredAt,
    note: note,
  );
}

// ---------------------------------------------------------------------------
// Kind
// ---------------------------------------------------------------------------

QuickAddKind _parseKind(String text) {
  if (RegExp(r'\b(transfer|transferred|moved|move)\b').hasMatch(text)) {
    return QuickAddKind.transfer;
  }
  if (RegExp(
    r'\b(got|received|earned|income|salary|credited|refund|refunded|deposited|paid me)\b',
  ).hasMatch(text)) {
    return QuickAddKind.income;
  }
  return QuickAddKind.expense;
}

// ---------------------------------------------------------------------------
// Amount
// ---------------------------------------------------------------------------

Money? _parseAmount(String text) {
  // e.g. "rs 1,200", "₹2.5k", "500 rupees", "1.2 lakh"
  final m = RegExp(
    r'(?:₹|rs\.?|inr)?\s*([0-9][0-9,]*(?:\.[0-9]+)?)\s*'
    r'(k|thousand|lakh|lakhs|lac|lacs|crore|crores)?',
  ).firstMatch(text);
  if (m == null) return null;

  final digits = m.group(1)!.replaceAll(',', '');
  final base = double.tryParse(digits);
  if (base == null || base <= 0) return null;

  final multiplier = switch (m.group(2)) {
    'k' || 'thousand' => 1000,
    'lakh' || 'lakhs' || 'lac' || 'lacs' => 100000,
    'crore' || 'crores' => 10000000,
    _ => 1,
  };

  final value = base * multiplier;
  // numeric(14,2) headroom.
  if (value > 999999999999.99) return null;
  return Money.tryParse(value.toStringAsFixed(2));
}

// ---------------------------------------------------------------------------
// Category
// ---------------------------------------------------------------------------

String? _parseCategory(String text, QuickAddKind kind) {
  final table = kind == QuickAddKind.income
      ? _incomeCategoryWords
      : _expenseCategoryWords;
  for (final entry in table.entries) {
    for (final word in entry.value) {
      if (RegExp('\\b${RegExp.escape(word)}\\b').hasMatch(text)) {
        return entry.key;
      }
    }
  }
  return null;
}

const Map<String, List<String>> _expenseCategoryWords = {
  'Food & Dining': [
    'groceries', 'grocery', 'supermarket', 'vegetables', 'food', 'lunch',
    'dinner', 'breakfast', 'restaurant', 'coffee', 'cafe', 'tea', 'snacks',
    'snack', 'zomato', 'swiggy', 'takeout', 'meal',
  ],
  'Transport': [
    'fuel', 'petrol', 'diesel', 'gas', 'uber', 'ola', 'cab', 'taxi', 'auto',
    'bus', 'train', 'metro', 'flight ticket', 'parking', 'toll', 'transport',
    'rickshaw',
  ],
  'Rent': ['rent'],
  'Shopping': [
    'shopping', 'clothes', 'clothing', 'shoes', 'amazon', 'flipkart', 'myntra',
    'electronics', 'gadget',
  ],
  'Healthcare': [
    'medicine', 'medicines', 'pharmacy', 'doctor', 'hospital', 'medical',
    'clinic', 'dentist', 'checkup',
  ],
  'Education': [
    'school', 'college', 'tuition', 'course', 'class', 'books', 'exam fee',
    'coaching',
  ],
  'Travel': ['flight', 'hotel', 'trip', 'travel', 'holiday', 'vacation', 'airbnb'],
  'Subscriptions': [
    'netflix', 'spotify', 'subscription', 'prime', 'hotstar', 'youtube premium',
  ],
  'Utilities': [
    'electricity', 'water bill', 'gas bill', 'internet', 'wifi', 'broadband',
    'phone bill', 'recharge', 'utility', 'utilities', 'dth',
  ],
  'Personal Care': [
    'salon', 'haircut', 'spa', 'gym', 'grooming', 'cosmetics', 'skincare',
  ],
  'Entertainment': [
    'movie', 'movies', 'cinema', 'concert', 'game', 'games', 'entertainment',
  ],
};

const Map<String, List<String>> _incomeCategoryWords = {
  'Salary': ['salary', 'paycheck', 'pay check', 'wages'],
  'Freelance': ['freelance', 'freelancing', 'gig', 'client payment'],
  'Business': ['business', 'sales'],
  'Rental': ['rental', 'rent income'],
  'Dividend': ['dividend', 'dividends'],
  'Interest': ['interest'],
  'Investment': ['investment', 'capital gain', 'capital gains'],
};

// ---------------------------------------------------------------------------
// Payment mode
// ---------------------------------------------------------------------------

const Map<String, List<String>> _paymentModeWords = {
  'UPI': ['upi', 'gpay', 'google pay', 'phonepe', 'phone pe', 'paytm', 'bhim'],
  'Card': ['card', 'credit card', 'debit card', 'visa', 'mastercard'],
  'Cash': ['cash'],
  'Net Banking': [
    'net banking', 'netbanking', 'bank transfer', 'imps', 'neft', 'rtgs',
  ],
  'Wallet': ['wallet'],
  'Cheque': ['cheque', 'check'],
};

String? _firstMatch(String text, Map<String, List<String>> table) {
  for (final entry in table.entries) {
    for (final word in entry.value) {
      if (RegExp('\\b${RegExp.escape(word)}\\b').hasMatch(text)) {
        return entry.key;
      }
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Date
// ---------------------------------------------------------------------------

DateTime _parseDate(String text, DateTime now) {
  final today = DateTime(now.year, now.month, now.day, now.hour, now.minute);

  if (RegExp(r'\bday before yesterday\b').hasMatch(text)) {
    return today.subtract(const Duration(days: 2));
  }
  if (RegExp(r'\byesterday\b').hasMatch(text)) {
    return today.subtract(const Duration(days: 1));
  }
  if (RegExp(r'\btoday\b').hasMatch(text)) return today;

  final ago = RegExp(r'\b(\d{1,2})\s*days?\s*ago\b').firstMatch(text);
  if (ago != null) {
    return today.subtract(Duration(days: int.parse(ago.group(1)!)));
  }

  const weekdays = {
    'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4,
    'friday': 5, 'saturday': 6, 'sunday': 7,
  };
  for (final e in weekdays.entries) {
    if (RegExp('\\b(last |on )?${e.key}\\b').hasMatch(text)) {
      var d = today;
      // Walk back to the most recent past occurrence (never today/future).
      do {
        d = d.subtract(const Duration(days: 1));
      } while (d.weekday != e.value);
      return d;
    }
  }
  return today;
}

// ---------------------------------------------------------------------------
// Note
// ---------------------------------------------------------------------------

String? _parseNote(String text, String? category) {
  // The object of "on"/"for": "bought coffee for 250" → "coffee".
  final m = RegExp(
    r'\b(?:on|for)\s+([a-z][a-z ]*?)(?=\s+(?:with|by|using|via|from|worth|'
    r'yesterday|today|last |\d)|$)',
  ).firstMatch(text);
  var candidate = m?.group(1)?.trim();
  candidate ??= _leftoverNoun(text);
  if (candidate == null || candidate.isEmpty) return null;

  // Drop it only if it is literally the category name — the object of
  // "for"/"bought" (e.g. "coffee", "parking") is kept as a useful note even
  // when it also drove the category.
  if (category != null && candidate.toLowerCase() == category.toLowerCase()) {
    return null;
  }
  if (candidate.length < 2 || candidate.length > 60) return null;
  // Title-case the first letter for a tidy note.
  return candidate[0].toUpperCase() + candidate.substring(1);
}

String? _leftoverNoun(String text) {
  final m = RegExp(
    r'\b(?:bought|paid for|got)\s+([a-z][a-z ]*?)(?=\s+(?:for|with|by|\d)|$)',
  ).firstMatch(text);
  return m?.group(1)?.trim();
}

// ---------------------------------------------------------------------------
// Convenience — turn a confirmed draft into the QuickAdd submit args.
// ---------------------------------------------------------------------------

/// The category the draft should carry when submitted (never null — the
/// server requires one for non-transfers).
String resolvedCategory(VoiceDraft draft) {
  if (draft.category != null) return draft.category!;
  return draft.kind == QuickAddKind.income
      ? kIncomeCategories.last // 'Other'
      : kExpenseCategories.last; // 'Other'
}
