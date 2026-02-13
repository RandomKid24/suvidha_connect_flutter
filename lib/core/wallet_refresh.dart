import 'package:flutter/material.dart';

/// Notifier for wallet balance displayed in app header and payment methods.
/// Call [notifyRefresh] when booking is completed (or wallet changes) so
/// the wallet balance is refetched from the API.
class WalletRefreshNotifier {
  static final ValueNotifier<int> trigger = ValueNotifier<int>(0);
  static void notifyRefresh() => trigger.value++;
}
