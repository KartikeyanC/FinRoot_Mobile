/// The greeting at the top of Home, by the hour of [now]: 05:00–11:59
/// morning, 12:00–16:59 afternoon, 17:00–20:59 evening, 21:00–04:59 night.
/// Same boundaries as the web's `timeGreeting` (`src/lib/greeting.ts`).
String timeGreeting(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) return 'Good morning';
  if (h >= 12 && h < 17) return 'Good afternoon';
  if (h >= 17 && h < 21) return 'Good evening';
  return 'Good night';
}
