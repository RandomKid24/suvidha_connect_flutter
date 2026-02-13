import 'package:flutter/material.dart';

/// Notifier for the floating booking card above the nav bar.
/// Call [notifyRefresh] when any screen does pull-to-refresh so the card
/// reloads from the API and shows the latest status (Accept / Negotiate / Mark Complete).
class BookingCardRefreshNotifier {
  static final ValueNotifier<int> trigger = ValueNotifier<int>(0);
  static void notifyRefresh() => trigger.value++;
}
