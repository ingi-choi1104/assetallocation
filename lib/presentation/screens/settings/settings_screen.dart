import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../services/backup_service.dart';
import '../../../services/firebase_service.dart';
import '../../../services/share_code.dart';
import '../../widgets/login_required_dialog.dart';
import '../../providers/auth_providers.dart';
import '../../providers/database_providers.dart';
import '../../providers/price_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/tutorial_overlay.dart';
import '../../../domain/entities/asset_trend.dart';
import '../../providers/asset_trend_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onShowTutorial;
  final GlobalKey? backupSectionKey;
  const SettingsScreen({super.key, this.onShowTutorial, this.backupSectionKey});

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

  Future<void> _showShareCodeDialog(BuildContext context) async {
    // 공유 포트폴리오는 로그인한 사용자만 볼 수 있다. 코드를 입력하게 해놓고
    // 다음 화면에서 막으면 사용자는 코드가 틀린 줄 안다.
    if (FirebaseService.instance.currentUser == null) {
      await showLoginRequiredDialog(context,
          what: '공유받은 포트폴리오를 보려면');
      return;
    }

    final ctrl = TextEditingController();
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('공유 코드 입력'),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: '6자리 공유 코드',
            border: OutlineInputBorder(),
            hintText: 'ABCDEF',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              // 길이만 보던 검사를 형식 검사로 바꾼다 — 'ABCDE0'처럼
              // 쓰이지 않는 문자가 섞인 코드는 조회해도 없다.
              if (!ShareCode.isValid(ctrl.text)) return;
              Navigator.pop(ctx);
              context.push('/shared/${ShareCode.normalize(ctrl.text)}');
            },
            child: const Text('열기'),
          ),
        ],
      ),
    );
  }

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

  // ── 클라우드 동기화 ───────────────────────────────────────────────────────────

  Future<void> _cloudUpload(BuildContext context) async {
    final result =
        await ref.read(cloudSyncProvider.notifier).upload();
    if (!context.mounted) return;
    final msg = result == CloudSyncResult.uploaded
        ? '클라우드에 업로드했습니다'
        : '업로드 실패. 다시 시도해 주세요.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _cloudDownload(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('클라우드에서 복원'),
        content: const Text(
          '클라우드 데이터를 다운로드하면 현재 모든 데이터가 삭제됩니다.\n'
          '계속하시겠습니까?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('다운로드'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result =
        await ref.read(cloudSyncProvider.notifier).download();
    if (!context.mounted) return;
    String msg;
    switch (result) {
      case CloudSyncResult.downloaded:
        msg = '복원 완료. 앱을 재시작해 주세요.';
      case CloudSyncResult.noData:
        msg = '클라우드에 저장된 데이터가 없습니다.';
      default:
        msg = '다운로드 실패. 다시 시도해 주세요.';
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final notifEnabled = ref.watch(notificationsEnabledProvider);
    final lastSync = ref.watch(lastSyncTimeProvider);
    final syncState = ref.watch(syncNotifierProvider);
    final authState = ref.watch(authStateProvider);
    final cloudSync = ref.watch(cloudSyncProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          // ── 증권사 계좌 가져오기 ──────────────────────────────────────────────
          _SectionHeader('증권사 계좌 가져오기'),
          ListTile(
            leading: const Icon(Icons.account_balance),
            title: Row(
              children: [
                const Text('계좌 가져오기'),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Beta',
                      style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            subtitle: const Text('한국투자증권 계좌번호로 보유 종목을 불러옵니다'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/kis-import'),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('파일에서 가져오기'),
            subtitle: const Text('CSV·엑셀 표 파일로 보유 종목을 불러옵니다'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/file-import'),
          ),
          // ── 포트폴리오 공유 ──────────────────────────────────────────────
          _SectionHeader('포트폴리오 공유'),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner_outlined),
            title: const Text('공유받은 포트폴리오 보기'),
            subtitle: const Text('공유 코드를 입력하여 다른 사람의 포트폴리오를 조회합니다'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showShareCodeDialog(context),
          ),
          // ── 클라우드 동기화 ────────────────────────────────────────────────
          _SectionHeader('클라우드 동기화'),
          Consumer(builder: (context, ref, _) {
            final at = ref.watch(lastUnexpectedSignOutProvider);
            if (at == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: Colors.orange.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '마지막 자동 로그아웃: '
                      '${at.year}.${at.month.toString().padLeft(2, '0')}.'
                      '${at.day.toString().padLeft(2, '0')} '
                      '${at.hour.toString().padLeft(2, '0')}:'
                      '${at.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            );
          }),
          authState.when(
            data: (user) => user == null
                ? ListTile(
                    leading: const Icon(Icons.cloud_outlined),
                    title: const Text('Google로 로그인'),
                    subtitle: const Text('로그인하면 포트폴리오를 다른 기기에서도 사용할 수 있습니다'),
                    onTap: () async {
                      try {
                        final user = await FirebaseService.instance
                            .signInWithGoogle();
                        // 로그인 후 동기화 — 어느 쪽을 쓸지는 사용자가 고른다.
                        if (user != null && context.mounted) {
                          await _syncAfterLogin(context, ref);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('로그인 실패: $e')),
                          );
                        }
                      }
                    },
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: user.photoURL != null
                            ? CircleAvatar(
                                backgroundImage:
                                    NetworkImage(user.photoURL!),
                                radius: 18,
                              )
                            : const CircleAvatar(
                                radius: 18,
                                child: Icon(Icons.person, size: 18),
                              ),
                        title: Text(user.displayName ?? ''),
                        subtitle: Text(user.email ?? ''),
                        trailing: TextButton(
                          onPressed: () async {
                            // 직접 누른 로그아웃은 자동 로그아웃 기록에서 뺀다.
                            markDeliberateSignOut();
                            await FirebaseService.instance.signOut();
                          },
                          child: const Text('로그아웃'),
                        ),
                      ),
                      if (cloudSync.lastSyncAt != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16),
                          child: Text(
                            '마지막 동기화: '
                            '${cloudSync.lastSyncAt!.year}-'
                            '${cloudSync.lastSyncAt!.month.toString().padLeft(2, '0')}-'
                            '${cloudSync.lastSyncAt!.day.toString().padLeft(2, '0')} '
                            '${cloudSync.lastSyncAt!.hour.toString().padLeft(2, '0')}:'
                            '${cloudSync.lastSyncAt!.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      if (cloudSync.error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: Text(
                            '오류: ${cloudSync.error}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.red),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: cloudSync.isSyncing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.cloud_upload_outlined),
                                label: const Text('업로드'),
                                onPressed: cloudSync.isSyncing
                                    ? null
                                    : () => _cloudUpload(context),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: cloudSync.isSyncing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(
                                        Icons.cloud_download_outlined),
                                label: const Text('다운로드'),
                                onPressed: cloudSync.isSyncing
                                    ? null
                                    : () => _cloudDownload(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
            loading: () => const ListTile(
              leading: CircularProgressIndicator(strokeWidth: 2),
              title: Text('로그인 확인 중...'),
            ),
            error: (_, __) => const ListTile(
              leading: Icon(Icons.cloud_off),
              title: Text('클라우드 동기화 사용 불가'),
              subtitle: Text('Firebase 설정이 필요합니다'),
            ),
          ),

          const Divider(),

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

          Column(
            key: widget.backupSectionKey,
            mainAxisSize: MainAxisSize.min,
            children: [
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
            ],
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

          _SectionHeader('자산 추이'),
          Consumer(builder: (context, ref, _) {
            final period = ref.watch(mddPeriodProvider);
            return ListTile(
              title: const Text('MDD 계산 기간'),
              subtitle: Text('${period.label} 구간에서 최대 낙폭을 계산합니다'),
              trailing: Text(
                period.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              onTap: () => _pickMddPeriod(context, ref, period),
            );
          }),

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

          const Divider(),

          _SectionHeader('도움말'),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('사용법 안내 다시 보기'),
            subtitle: const Text('앱 사용법을 처음부터 안내해 드려요'),
            onTap: () async {
              await resetTutorial();
              if (widget.onShowTutorial != null) {
                widget.onShowTutorial!();
              }
            },
          ),
        ],
      ),
    );
  }
}

/// 로그인 직후 동기화. 한쪽이 비어 있으면 자동으로 처리하고,
/// 양쪽 다 데이터가 있으면 어느 쪽을 쓸지 물어본다.
///
/// 예전에는 여기서 무조건 클라우드를 내려받아 기기 데이터를 덮어썼다.
Future<void> _syncAfterLogin(BuildContext context, WidgetRef ref) async {
  final notifier = ref.read(cloudSyncProvider.notifier);
  final cmp = await notifier.compare();
  if (cmp == null || !context.mounted) return;

  // 클라우드가 비었으면 올리고, 기기가 비었으면 내려받는다.
  if (cmp.cloudEmpty) {
    await notifier.upload();
    return;
  }
  if (cmp.localEmpty) {
    await notifier.restoreFrom(cmp.cloudBackup!);
    return;
  }

  final useCloud = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('어느 데이터를 사용할까요?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이 기기와 클라우드 양쪽에 데이터가 있습니다. '
            '선택하지 않은 쪽은 덮어써집니다.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          _SyncOptionCard(
            title: '이 기기',
            detail: cmp.localSummary,
            when: null,
          ),
          const SizedBox(height: 8),
          _SyncOptionCard(
            title: '클라우드',
            detail: cmp.cloudSummary,
            when: cmp.cloudUpdatedAt,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('나중에'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('기기 것으로 덮어쓰기'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('클라우드 것 쓰기'),
        ),
      ],
    ),
  );

  if (useCloud == null) return; // 나중에 — 아무것도 바꾸지 않는다
  if (useCloud) {
    await notifier.restoreFrom(cmp.cloudBackup!);
  } else {
    await notifier.upload();
  }
}

class _SyncOptionCard extends StatelessWidget {
  final String title;
  final String detail;
  final DateTime? when;

  const _SyncOptionCard({
    required this.title,
    required this.detail,
    this.when,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              if (when != null) ...[
                const Spacer(),
                Text(
                  '${when!.year}.${when!.month.toString().padLeft(2, '0')}.'
                  '${when!.day.toString().padLeft(2, '0')} 저장',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(detail, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

/// MDD 계산 기간 선택 팝업. 전체 자산 카드의 MDD 표시에만 영향을 준다.
Future<void> _pickMddPeriod(
  BuildContext context,
  WidgetRef ref,
  MddPeriod current,
) async {
  final picked = await showDialog<MddPeriod>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('MDD 계산 기간'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(
            '적립·인출은 계산에서 제외하고, 선택한 기간 안에서 고점 대비 '
            '최대 낙폭을 구합니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        for (final p in MddPeriod.values)
          ListTile(
            title: Text(p.label),
            leading: Icon(
              p == current
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: p == current
                  ? Theme.of(ctx).colorScheme.primary
                  : Colors.grey,
            ),
            onTap: () => Navigator.pop(ctx, p),
          ),
      ],
    ),
  );
  if (picked != null) {
    await ref.read(mddPeriodProvider.notifier).set(picked);
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
