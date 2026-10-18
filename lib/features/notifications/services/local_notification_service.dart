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

  // Primary Operational Channel (VPS & Expirations)
  static const String channelId = 'fuchur_operational_alerts';
  static const String channelName = 'Peringatan Operasional VPS & Layanan';
  static const String channelDesc =
      'Notifikasi jatuh tempo layanan VPS, masa aktif server, dan perpanjangan operasional.';

  // Financial Channel (Invoices, Payments, Expenses)
  static const String financialChannelId = 'fuchur_financial_alerts';
  static const String financialChannelName = 'Transaksi Tagihan & Pembayaran';
  static const String financialChannelDesc =
      'Pemberitahuan invoice baru, verifikasi pembayaran lunas, dan pencatatan kas keluar.';

  // System & Backup Channel
  static const String systemChannelId = 'fuchur_system_alerts';
  static const String systemChannelName = 'Pemberitahuan Sistem & Backup Data';
  static const String systemChannelDesc =
      'Informasi sinkronisasi Google Sheets, log audit keamanan, dan pemeliharaan sistem.';

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

      // Register Android Notification Channels to register them with the Android OS System Settings
      if (!kIsWeb && Platform.isAndroid) {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          const operationalChannel = AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          );

          const financialChannel = AndroidNotificationChannel(
            financialChannelId,
            financialChannelName,
            description: financialChannelDesc,
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          );

          const systemChannel = AndroidNotificationChannel(
            systemChannelId,
            systemChannelName,
            description: systemChannelDesc,
            importance: Importance.defaultImportance,
            playSound: true,
            enableVibration: false,
            showBadge: false,
          );

          await androidImpl.createNotificationChannel(operationalChannel);
          await androidImpl.createNotificationChannel(financialChannel);
          await androidImpl.createNotificationChannel(systemChannel);

          // Proactively request runtime permission for Android 13+ (API 33+)
          await androidImpl.requestNotificationsPermission();
        }
      }

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
    String? targetChannelId,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final effChannelId = targetChannelId ?? channelId;
    String effChannelName = channelName;
    String effChannelDesc = channelDesc;

    if (effChannelId == financialChannelId) {
      effChannelName = financialChannelName;
      effChannelDesc = financialChannelDesc;
    } else if (effChannelId == systemChannelId) {
      effChannelName = systemChannelName;
      effChannelDesc = systemChannelDesc;
    }

    final androidDetails = AndroidNotificationDetails(
      effChannelId,
      effChannelName,
      channelDescription: effChannelDesc,
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

    final notificationDetails = NotificationDetails(
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

  /// Mengirim notifikasi uji coba sistem ke status bar Android
  Future<void> showTestNotification() async {
    // Pastikan channel dan permission sudah aktif
    await initialize();
    await requestPermission();

    await showNotification(
      id: 999999,
      title: 'Fuchur Agent • Notifikasi Aktif',
      body: 'Izin notifikasi sistem dan latar belakang berhasil diaktifkan untuk perangkat ini!',
      payload: '/notifications',
      targetChannelId: channelId,
    );
  }
}
