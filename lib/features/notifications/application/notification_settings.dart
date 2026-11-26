import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/device/device_prefs.dart';
import '../domain/due_notifications.dart';
import '../domain/planned_notification.dart';

/// Settings → Notifications: which kinds of reminder this phone schedules,
/// how early renewals and premiums are flagged, and the time of day they all
/// arrive.
///
/// Per device by design (SharedPreferences, like the theme): a person may
/// want reminders on their phone but not on a shared tablet. Recurring items
/// keep their own "days before" on each item's bell; only the on/off and the
/// time of day apply to them here.
class NotificationSettings {
  const NotificationSettings({
    this.recurring = true,
    this.reminders = true,
    this.subscriptions = true,
    this.insurance = true,
    this.subscriptionLeadDays = kDueNoticeDaysBefore,
    this.insuranceLeadDays = kDueNoticeDaysBefore,
    this.hour = kNotifyHour,
    this.minute = 0,
  });

  final bool recurring;
  final bool reminders;
  final bool subscriptions;
  final bool insurance;

  /// Days before a renewal / premium due date the heads-up fires, one of
  /// [kNotifyLeadOptions]. 0 means only on the day.
  final int subscriptionLeadDays;
  final int insuranceLeadDays;

  /// Local time of day every scheduled notification fires at.
  final int hour;
  final int minute;

  TimeOfDay get time => TimeOfDay(hour: hour, minute: minute);

  bool get anyOn => recurring || reminders || subscriptions || insurance;

  NotificationSettings copyWith({
    bool? recurring,
    bool? reminders,
    bool? subscriptions,
    bool? insurance,
    int? subscriptionLeadDays,
    int? insuranceLeadDays,
    int? hour,
    int? minute,
  }) => NotificationSettings(
    recurring: recurring ?? this.recurring,
    reminders: reminders ?? this.reminders,
    subscriptions: subscriptions ?? this.subscriptions,
    insurance: insurance ?? this.insurance,
    subscriptionLeadDays: subscriptionLeadDays ?? this.subscriptionLeadDays,
    insuranceLeadDays: insuranceLeadDays ?? this.insuranceLeadDays,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
  );

  @override
  bool operator ==(Object other) =>
      other is NotificationSettings &&
      other.recurring == recurring &&
      other.reminders == reminders &&
      other.subscriptions == subscriptions &&
      other.insurance == insurance &&
      other.subscriptionLeadDays == subscriptionLeadDays &&
      other.insuranceLeadDays == insuranceLeadDays &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(
    recurring,
    reminders,
    subscriptions,
    insurance,
    subscriptionLeadDays,
    insuranceLeadDays,
    hour,
    minute,
  );
}

/// The "Remind me" choices for renewals and premiums, in days before.
const List<int> kNotifyLeadOptions = [0, 1, 3];

String notifyLeadLabel(int days) => switch (days) {
  0 => 'On the day',
  1 => '1 day before',
  _ => '$days days before',
};

/// A stored lead outside [kNotifyLeadOptions] (an older build, a hand-edited
/// prefs file) falls back to the default rather than scheduling oddly.
int _lead(int? stored) => stored != null && kNotifyLeadOptions.contains(stored)
    ? stored
    : kDueNoticeDaysBefore;

const _kRecurring = 'finroot.notify.recurring';
const _kReminders = 'finroot.notify.reminders';
const _kSubscriptions = 'finroot.notify.subscriptions';
const _kInsurance = 'finroot.notify.insurance';
const _kSubscriptionLead = 'finroot.notify.subscription_lead';
const _kInsuranceLead = 'finroot.notify.insurance_lead';
const _kTime = 'finroot.notify.time'; // minutes after midnight

class NotificationSettingsController extends Notifier<NotificationSettings> {
  @override
  NotificationSettings build() {
    final p = _prefs();
    if (p == null) return const NotificationSettings();
    final time = p.getInt(_kTime);
    final validTime = time != null && time >= 0 && time < 24 * 60;
    return NotificationSettings(
      recurring: p.getBool(_kRecurring) ?? true,
      reminders: p.getBool(_kReminders) ?? true,
      subscriptions: p.getBool(_kSubscriptions) ?? true,
      insurance: p.getBool(_kInsurance) ?? true,
      subscriptionLeadDays: _lead(p.getInt(_kSubscriptionLead)),
      insuranceLeadDays: _lead(p.getInt(_kInsuranceLead)),
      hour: validTime ? time ~/ 60 : kNotifyHour,
      minute: validTime ? time % 60 : 0,
    );
  }

  /// Device prefs, or null where none were provided (widget tests, the
  /// quick-add pop-up engine): choices then last for this run only.
  SharedPreferences? _prefs() {
    try {
      return ref.read(sharedPreferencesProvider);
    } on Object {
      return null;
    }
  }

  Future<void> setRecurring(bool on) async {
    state = state.copyWith(recurring: on);
    await _prefs()?.setBool(_kRecurring, on);
  }

  Future<void> setReminders(bool on) async {
    state = state.copyWith(reminders: on);
    await _prefs()?.setBool(_kReminders, on);
  }

  Future<void> setSubscriptions(bool on) async {
    state = state.copyWith(subscriptions: on);
    await _prefs()?.setBool(_kSubscriptions, on);
  }

  Future<void> setInsurance(bool on) async {
    state = state.copyWith(insurance: on);
    await _prefs()?.setBool(_kInsurance, on);
  }

  Future<void> setSubscriptionLead(int days) async {
    final d = _lead(days);
    state = state.copyWith(subscriptionLeadDays: d);
    await _prefs()?.setInt(_kSubscriptionLead, d);
  }

  Future<void> setInsuranceLead(int days) async {
    final d = _lead(days);
    state = state.copyWith(insuranceLeadDays: d);
    await _prefs()?.setInt(_kInsuranceLead, d);
  }

  Future<void> setTime(TimeOfDay t) async {
    state = state.copyWith(hour: t.hour, minute: t.minute);
    await _prefs()?.setInt(_kTime, t.hour * 60 + t.minute);
  }
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsController, NotificationSettings>(
      NotificationSettingsController.new,
      name: 'notificationSettings',
    );
