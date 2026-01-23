import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/intl.dart';

class NotificationSchedulerService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap here
      },
    );
  }

  static Future<void> scheduleBookingReminders(Map<String, dynamic> booking) async {
    final bookingId = booking['id'];
    final scheduledDateStr = booking['scheduled_date'];
    final serviceName = booking['service_name'] ?? booking['service_category']?['name'] ?? 'Service';
    final providerName = booking['provider_name'] ?? booking['provider']?['name'] ?? 'Provider';

    if (bookingId == null || scheduledDateStr == null) return;

    try {
      final scheduledDate = DateTime.parse(scheduledDateStr);
      final now = DateTime.now();

      // Reminder 30 minutes before
      final thirtyMinBefore = scheduledDate.subtract(const Duration(minutes: 30));
      if (thirtyMinBefore.isAfter(now)) {
        await _scheduleNotification(
          id: bookingId * 10 + 1, // Unique ID for 30min reminder
          title: 'Provider coming soon!',
          body: '$providerName is scheduled to arrive in 30 minutes for your $serviceName.',
          scheduledDate: thirtyMinBefore,
        );
      }

      // Reminder 15 minutes before
      final fifteenMinBefore = scheduledDate.subtract(const Duration(minutes: 15));
      if (fifteenMinBefore.isAfter(now)) {
        await _scheduleNotification(
          id: bookingId * 10 + 2, // Unique ID for 15min reminder
          title: 'Provider arriving shortly',
          body: '$providerName will be there in 15 minutes for your $serviceName.',
          scheduledDate: fifteenMinBefore,
        );
      }
    } catch (e) {
      print('❌ Error scheduling reminders for booking $bookingId: $e');
    }
  }

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'booking_reminders_channel',
          'Booking Reminders',
          channelDescription: 'Notifications for upcoming service bookings',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> cancelReminders(int bookingId) async {
    await _notificationsPlugin.cancel(bookingId * 10 + 1);
    await _notificationsPlugin.cancel(bookingId * 10 + 2);
  }
}
