import 'dart:convert';

/// The web dashboard's expense head groups and their built-in subcategories
/// (`src/lib/expenseSubcategories.ts`, `EXPENSE_CATEGORY_GROUPS`). Kept
/// identical so a transaction reads the same on both clients.
class ExpenseGroup {
  const ExpenseGroup(this.name, this.subs);
  final String name;
  final List<String> subs;
}

const List<ExpenseGroup> kExpenseGroups = [
  ExpenseGroup('Food & Dining', [
    'Outside Food',
    'Room Cooking / Groceries',
    'Snacks',
    'Sweets',
    'Nuts & Dry Fruits',
    'Ice Creams',
    'Beverages / Cafe',
  ]),
  ExpenseGroup('Travel & Transport', [
    'Commute (Home to Office)',
    'Event/Leisure Travel',
    'Temple Visits',
    'Hill Stations',
    'International Travel',
    'Fuel',
    'Vehicle Maintenance',
  ]),
  ExpenseGroup('Entertainment & Leisure', [
    'Streaming Services',
    'Movies / Theater',
    'Gaming',
    'Sports / Gym',
    'Hobbies',
    'Books & Magazines',
  ]),
  ExpenseGroup('Housing & Utilities', [
    'Rent',
    'Electricity',
    'Water',
    'Internet',
    'Gas',
    'Home Maintenance',
    'Furniture',
  ]),
  ExpenseGroup('Healthcare & Wellness', [
    'Doctor Consultations',
    'Medicines',
    'Health Insurance',
    'Gym / Fitness',
    'Wellness / Spa',
    'Mental Health',
  ]),
  ExpenseGroup('Shopping & Personal', [
    'Clothing',
    'Footwear',
    'Accessories',
    'Personal Care',
    'Grooming',
    'Electronics',
    'Gadgets',
  ]),
  ExpenseGroup('Education & Development', [
    'Course Fees',
    'Online Courses',
    'Books',
    'Certifications',
    'Workshops',
    'Study Materials',
  ]),
  ExpenseGroup('Debt & Shared Tabs', [
    'Loan EMI',
    'Credit Card Bills',
    'Shared Bills (Friends)',
    'Family Support',
    'Money Owed to Others',
  ]),
  ExpenseGroup('Social & Celebrations', [
    'Marriage Functions',
    'Birthday Parties',
    'Friend Meetups',
    'Gifts',
    'Donations',
    'Festival Celebrations',
  ]),
  ExpenseGroup('Subscriptions & Memberships', [
    'Software / Tools',
    'Cloud Storage',
    'Music / Streaming',
    'News / Publications',
    'Professional Memberships',
    'Club Memberships',
  ]),
];

/// The group that lists [sub] as a built-in, if any (web `findGroupForSub`).
ExpenseGroup? findGroupForSub(String sub) {
  for (final g in kExpenseGroups) {
    if (g.subs.contains(sub)) return g;
  }
  return null;
}

/// Mobile expense categories whose name is not a web group name.
const Map<String, String> _kCategoryToGroup = {
  'Transport': 'Travel & Transport',
  'Travel': 'Travel & Transport',
  'Shopping': 'Shopping & Personal',
  'Personal Care': 'Shopping & Personal',
  'Healthcare': 'Healthcare & Wellness',
  'Education': 'Education & Development',
  'Entertainment': 'Entertainment & Leisure',
  'Utilities': 'Housing & Utilities',
  'Rent': 'Housing & Utilities',
  'Subscriptions': 'Subscriptions & Memberships',
};

/// The web group a mobile expense [category] files its subcategories under.
/// A custom head category is its own group (the web does the same); "Other"
/// has none.
String? groupNameForCategory(String category) {
  final c = category.trim();
  if (c.isEmpty || c == 'Other') return null;
  return _kCategoryToGroup[c] ?? c;
}

/// Built-in subs for a mobile [category] (empty for custom heads / Other).
List<String> builtInSubsFor(String category) {
  final g = groupNameForCategory(category);
  if (g == null) return const [];
  for (final group in kExpenseGroups) {
    if (group.name == g) return group.subs;
  }
  return const [];
}

/// The workspace's custom subs: `{groupName: [sub, ...]}` (tenant_settings key
/// `custom_subcategories`). Anything malformed reads as none.
Map<String, List<String>> parseCustomSubcategories(Object? value) {
  var v = value;
  if (v is String) {
    try {
      v = jsonDecode(v);
    } catch (_) {
      return const {};
    }
  }
  if (v is! Map) return const {};
  final out = <String, List<String>>{};
  v.forEach((k, list) {
    if (k is! String || list is! List) return;
    final subs = [
      for (final s in list)
        if (s is String && s.trim().isNotEmpty) s.trim(),
    ];
    if (subs.isNotEmpty) out[k] = subs;
  });
  return out;
}

/// The person's own subs for [category]: looked up under the category name and
/// its web group name, merged and de-duplicated case-insensitively.
List<String> customSubsFor(String category, Map<String, List<String>> store) {
  final g = groupNameForCategory(category);
  return _dedupe([
    ...?store[category],
    if (g != null && g != category) ...?store[g],
  ]);
}

/// Chips to show for [category]: the person's own subs first, then built-ins,
/// de-duplicated case-insensitively (first wins).
List<String> subOptionsFor(String category, Map<String, List<String>> store) =>
    groupNameForCategory(category) == null
    ? const []
    : _dedupe([...customSubsFor(category, store), ...builtInSubsFor(category)]);

List<String> _dedupe(Iterable<String> items) {
  final seen = <String>{};
  return [
    for (final s in items)
      if (seen.add(s.toLowerCase())) s,
  ];
}

/// Web `composeDescription` for an expense: `Sub · note`, or just `Sub`.
String composeDescription(String? sub, String note) {
  final n = note.trim();
  if (sub == null || sub.isEmpty) return n;
  return n.isEmpty ? sub : '$sub · $n';
}

/// Web `hydrateFromTransaction`: a leading `Sub · ` is a subcategory only when
/// it names one of [known]; otherwise the whole text is the note.
({String? sub, String note}) splitDescription(
  String? description,
  Iterable<String> known,
) {
  final d = (description ?? '').trim();
  if (d.isEmpty) return (sub: null, note: '');
  final i = d.indexOf(' · ');
  final candidate = i > -1 ? d.substring(0, i) : d;
  if (candidate.isNotEmpty && known.contains(candidate)) {
    return (sub: candidate, note: i > -1 ? d.substring(i + 3) : '');
  }
  return (sub: null, note: d);
}
