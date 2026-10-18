import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String channelId = 'fuchur_operational_alerts';
  static const String channelName = 'Peringatan Operasional FuchurHost';
  static const String channelDesc =
      'Notifikasi jatuh tempo layanan VPS, tagihan overdue, dan pencatatan kas keluar.';

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Buka Notifikasi');

      final initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );

      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification clicked with payload: ${response.payload}');
        },
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('LocalNotificationService initialize error: $e');
    }
  }

  /// Meminta izin notifikasi dari sistem operasi (Android 13+ & Windows/Desktop)
  Future<bool> requestPermission() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      if (!kIsWeb && Platform.isAndroid) {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          final granted = await androidImpl.requestNotificationsPermission();
          return granted ?? false;
        }
      } else if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        final darwinImpl = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        if (darwinImpl != null) {
          final granted = await darwinImpl.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          return granted ?? false;
        }
      } else if (!kIsWeb && Platform.isWindows) {
        // Pada Windows desktop, notifikasi toast aktif secara default pada OS jika terdaftar
        return true;
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }

    return true;
  }

  /// Memeriksa apakah izin notifikasi telah diberikan
  Future<bool> areNotificationsEnabled() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      if (!kIsWeb && Platform.isAndroid) {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          final enabled = await androidImpl.areNotificationsEnabled();
          return enabled ?? false;
        }
      }
    } catch (_) {}

    return true;
  }

  /// Menampilkan notifikasi sistem ke OS (Status Bar Android / Toast Windows)
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  /// Mengirim notifikasi uji coba sistem
  Future<void> showTestNotification() async {
    await showNotification(
      id: 999999,
      title: 'Fuchur Agent • Notifikasi Aktif',
      body: 'Izin notifikasi sistem dan latar belakang berhasil diaktifkan untuk perangkat ini!',
      payload: '/notifications',
    );
  }
}
