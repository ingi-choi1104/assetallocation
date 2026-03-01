import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap - navigate to portfolio
  }

  Future<bool> requestPermission() async {
    final result = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return result ?? false;
  }

  static const _channelId = 'asset_allocation_channel';
  static const _channelName = '자산배분 알림';

  AndroidNotificationDetails get _androidDetails =>
      const AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: '포트폴리오 비중 이탈 및 리밸런싱 알림',
        importance: Importance.high,
        priority: Priority.high,
      );

  NotificationDetails get _details =>
      NotificationDetails(android: _androidDetails);

  /// 비중 이탈 알림
  Future<void> showDeviationAlert({
    required int portfolioId,
    required String portfolioName,
    required List<String> deviatingAssets,
  }) async {
    if (!_initialized) await initialize();

    final notificationId = portfolioId * 1000 + 1;
    final assetList = deviatingAssets.join(', ');

    await _plugin.show(
      notificationId,
      '비중 이탈 경고',
      '$portfolioName: $assetList 비중이 목표치를 벗어났습니다',
      _details,
    );
  }

  /// 리밸런싱 날짜 알림 예약
  Future<void> scheduleRebalanceReminder({
    required int portfolioId,
    required String portfolioName,
    required DateTime scheduledDate,
  }) async {
    if (!_initialized) await initialize();

    final notificationId = portfolioId * 1000 + 2;

    try {
      final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

      await _plugin.zonedSchedule(
        notificationId,
        '리밸런싱 알림',
        '$portfolioName 리밸런싱 날짜가 되었습니다',
        tzDate,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      // Exact alarm permission not granted
      await _plugin.show(
        notificationId,
        '리밸런싱 알림 설정 실패',
        '정확한 알람 권한을 허용해주세요',
        _details,
      );
    }
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelPortfolioNotifications(int portfolioId) async {
    await _plugin.cancel(portfolioId * 1000 + 1);
    await _plugin.cancel(portfolioId * 1000 + 2);
  }

  Future<void> checkAndFireDeviationAlert({
    required int portfolioId,
    required String portfolioName,
    required Map<String, double> currentWeights,
    required Map<String, double> targetWeights,
    required double threshold,
  }) async {
    final deviatingAssets = <String>[];

    for (final entry in targetWeights.entries) {
      final current = currentWeights[entry.key] ?? 0;
      final target = entry.value;
      if ((current - target).abs() >= threshold) {
        deviatingAssets.add(entry.key);
      }
    }

    if (deviatingAssets.isNotEmpty) {
      await showDeviationAlert(
        portfolioId: portfolioId,
        portfolioName: portfolioName,
        deviatingAssets: deviatingAssets,
      );
    }
  }
}
