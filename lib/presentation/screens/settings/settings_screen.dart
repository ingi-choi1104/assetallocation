import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../services/backup_service.dart';
import '../../providers/database_providers.dart';
import '../../providers/price_providers.dart';
import '../../providers/settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyCtrl = TextEditingController();
  bool _apiKeyVisible = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final key =
        await ref.read(settingsRepositoryProvider).getFssApiKey();
    if (key != null && mounted) {
      _apiKeyCtrl.text = key;
    }
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  // ── 내보내기 ──────────────────────────────────────────────────────────────

  Future<void> _exportBackup(BuildContext context) async {
    try {
      await ref.read(backupServiceProvider).exportAndShare();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('내보내기 실패: $e')),
      );
    }
  }

  // ── 가져오기 ──────────────────────────────────────────────────────────────

  Future<void> _importBackup(BuildContext context) async {
    // 1. 파일 선택
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('파일을 읽을 수 없습니다')),
        );
      }
      return;
    }

    // 2. 파싱
    final service = ref.read(backupServiceProvider);
    Map<String, dynamic> backup;
    try {
      final jsonStr = utf8.decode(bytes);
      backup = service.parseBackup(jsonStr);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('파일 형식 오류: $e')),
      );
      return;
    }

    // 3. 확인 다이얼로그
    if (!context.mounted) return;
    final summary = BackupService.backupSummary(backup);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('데이터 가져오기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(summary),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '현재 모든 데이터가 삭제되고 백업 데이터로 대체됩니다.\n이 작업은 되돌릴 수 없습니다.',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('가져오기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // 4. 복원
    try {
      await service.restore(backup);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('데이터 복원이 완료되었습니다. 앱을 재시작해주세요.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('가져오기 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifEnabled = ref.watch(notificationsEnabledProvider);
    final lastSync = ref.watch(lastSyncTimeProvider);
    final syncState = ref.watch(syncNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          _SectionHeader('알림'),
          notifEnabled.when(
            data: (enabled) => SwitchListTile(
              title: const Text('알림 활성화'),
              subtitle: const Text('비중 이탈 및 리밸런싱 날짜 알림'),
              value: enabled,
              onChanged: (v) async {
                if (v) {
                  final status =
                      await Permission.notification.request();
                  if (!status.isGranted) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('알림 권한이 필요합니다'),
                        ),
                      );
                    }
                    return;
                  }
                }
                await ref
                    .read(settingsActionsProvider)
                    .setNotificationsEnabled(v);
              },
            ),
            loading: () => const ListTile(
              title: Text('알림 활성화'),
              trailing: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
          ListTile(
            title: const Text('알람 권한 설정'),
            subtitle: const Text('정확한 알람을 위해 권한이 필요합니다'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              final status =
                  await Permission.scheduleExactAlarm.request();
              if (!status.isGranted && context.mounted) {
                openAppSettings();
              }
            },
          ),

          const Divider(),

          _SectionHeader('데이터 동기화'),
          lastSync.when(
            data: (time) => ListTile(
              title: const Text('마지막 동기화'),
              subtitle: Text(time != null
                  ? '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
                      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                  : '없음'),
            ),
            loading: () =>
                const ListTile(title: Text('마지막 동기화')),
            error: (_, __) => const SizedBox.shrink(),
          ),
          ListTile(
            title: const Text('수동 동기화'),
            subtitle: syncState.error != null
                ? Text('오류: ${syncState.error}',
                    style: const TextStyle(color: Colors.red))
                : null,
            trailing: syncState.isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onTap: syncState.isSyncing
                ? null
                : () =>
                    ref.read(syncNotifierProvider.notifier).syncAll(),
          ),

          const Divider(),

          _SectionHeader('데이터 백업 / 복원'),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('데이터 내보내기'),
            subtitle: const Text('포트폴리오·거래 내역을 JSON 파일로 저장'),
            onTap: () => _exportBackup(context),
          ),
          ListTile(
            leading: const Icon(Icons.download_for_offline_outlined),
            title: const Text('데이터 가져오기'),
            subtitle: const Text('백업 JSON 파일을 선택하면 기존 데이터를 대체합니다'),
            onTap: () => _importBackup(context),
          ),

          const Divider(),

          _SectionHeader('FSS API 키 (한국 펀드)'),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            child: TextFormField(
              controller: _apiKeyCtrl,
              decoration: InputDecoration(
                labelText: 'FSS 공공데이터 API 키',
                hintText: 'openapi.fss.or.kr에서 발급',
                suffixIcon: IconButton(
                  icon: Icon(_apiKeyVisible
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _apiKeyVisible = !_apiKeyVisible),
                ),
              ),
              obscureText: !_apiKeyVisible,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton(
              onPressed: () async {
                await ref
                    .read(settingsActionsProvider)
                    .setFssApiKey(_apiKeyCtrl.text.trim());
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('API 키가 저장되었습니다')),
                  );
                }
              },
              child: const Text('저장'),
            ),
          ),

          const Divider(),

          _SectionHeader('앱 정보'),
          const ListTile(
            title: Text('버전'),
            trailing: Text('1.0.0'),
          ),
          const ListTile(
            title: Text('데이터 소스'),
            subtitle: Text(
                'Yahoo Finance · Naver Finance · CoinGecko · FSS'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}
