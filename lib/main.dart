import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'app.dart';
import 'data/database/app_database.dart';
import 'presentation/providers/database_providers.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress transient build errors — show blank instead of red error screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('ErrorWidget suppressed: ${details.exception}');
    return const SizedBox.shrink();
  };

  // Initialize timezone
  tz.initializeTimeZones();

  // Initialize AdMob
  await MobileAds.instance.initialize();

  // Initialize notification service
  await NotificationService.instance.initialize();

  // Load SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Fix incorrect ETF names stored in DB
  final db = AppDatabase();
  await db.assetDao.updateNameBySymbol('411060', 'ACE KRX금현물');
  await db.assetDao.updateNameBySymbol('148070', 'KIWOOM 국고채10년');
  await db.close();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const App(),
    ),
  );
}
