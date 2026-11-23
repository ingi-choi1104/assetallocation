import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/firebase_service.dart';
import 'database_providers.dart';

export '../../services/firebase_service.dart' show User, CloudSyncResult;

// ── Auth state ────────────────────────────────────────────────────────────────

final authStateProvider = StreamProvider<User?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  User? previous;
  var seenSignedIn = false;

  return FirebaseService.instance.authStateChanges.map((user) {
    // 로그인 상태였다가 풀린 순간을 기록해 둔다. 앱은 스스로 로그아웃시키지
    // 않으므로, 여기 기록이 남으면 토큰이 서버에서 무효화된 것이다.
    if (seenSignedIn && previous != null && user == null) {
      if (_deliberateSignOut) {
        _deliberateSignOut = false; // 사용자가 직접 누른 로그아웃 — 기록 안 함
      } else {
        prefs.setString(
          kLastUnexpectedSignOutKey,
          DateTime.now().toIso8601String(),
        );
      }
    }
    if (user != null) seenSignedIn = true;
    previous = user;
    return user;
  });
});

/// 의도치 않게 로그아웃된 마지막 시각 (설정 화면에 표시).
const kLastUnexpectedSignOutKey = 'last_unexpected_signout_at';

/// 설정의 로그아웃 버튼을 누른 경우를 표시해, 자동 로그아웃 기록과 구분한다.
bool _deliberateSignOut = false;

/// 로그아웃 버튼을 누르기 직전에 호출한다.
void markDeliberateSignOut() => _deliberateSignOut = true;

final lastUnexpectedSignOutProvider = Provider<DateTime?>((ref) {
  // 인증 상태가 바뀔 때마다 다시 읽는다.
  ref.watch(authStateProvider);
  final raw = ref
      .watch(sharedPreferencesProvider)
      .getString(kLastUnexpectedSignOutKey);
  return raw == null ? null : DateTime.tryParse(raw);
});

// ── 로그인 직후 로컬/클라우드 비교 ─────────────────────────────────────────────

/// 어느 쪽 데이터를 쓸지 사용자가 고를 수 있도록 양쪽 상태를 담아 둔다.
class SyncComparison {
  /// 클라우드에 저장된 백업. 없으면 null.
  final Map<String, dynamic>? cloudBackup;

  /// 이 기기의 현재 데이터.
  final Map<String, dynamic> localBackup;

  final DateTime? cloudUpdatedAt;

  const SyncComparison({
    required this.cloudBackup,
    required this.localBackup,
    this.cloudUpdatedAt,
  });

  static int _records(Map<String, dynamic>? b) {
    if (b == null) return 0;
    int len(String key) => (b[key] as List?)?.length ?? 0;
    return len('portfolios') + len('transactions') + len('investments');
  }

  bool get cloudEmpty => _records(cloudBackup) == 0;
  bool get localEmpty => _records(localBackup) == 0;

  /// 양쪽 다 내용이 있어 사용자가 골라야 하는 상황.
  bool get needsChoice => !cloudEmpty && !localEmpty;

  String get cloudSummary =>
      cloudBackup == null ? '데이터 없음' : _summary(cloudBackup!);
  String get localSummary => _summary(localBackup);

  static String _summary(Map<String, dynamic> b) {
    int len(String key) => (b[key] as List?)?.length ?? 0;
    return '포트폴리오 ${len('portfolios')}개 · '
        '거래 ${len('transactions')}건 · '
        '투자금 ${len('investments')}건';
  }
}

// ── Cloud sync notifier ───────────────────────────────────────────────────────

class CloudSyncState {
  final bool isSyncing;
  final String? message;
  final DateTime? lastSyncAt;
  final String? error;

  const CloudSyncState({
    this.isSyncing = false,
    this.message,
    this.lastSyncAt,
    this.error,
  });

  CloudSyncState copyWith({
    bool? isSyncing,
    String? message,
    DateTime? lastSyncAt,
    String? error,
    bool clearError = false,
  }) =>
      CloudSyncState(
        isSyncing: isSyncing ?? this.isSyncing,
        message: message ?? this.message,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        error: clearError ? null : (error ?? this.error),
      );
}

class CloudSyncNotifier extends StateNotifier<CloudSyncState> {
  final Ref _ref;
  static const _lastSyncKey = 'cloud_last_sync_at';
  static const _lastUploadKey = 'cloud_last_upload_at';

  CloudSyncNotifier(this._ref) : super(const CloudSyncState()) {
    _loadLastSync();
  }

  Future<void> _loadLastSync() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final stored = prefs.getString(_lastSyncKey);
    if (stored != null) {
      final dt = DateTime.tryParse(stored);
      if (dt != null) {
        state = state.copyWith(lastSyncAt: dt);
      }
    }
  }

  Future<void> _saveLastSync(DateTime dt) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setString(_lastSyncKey, dt.toIso8601String());
    state = state.copyWith(lastSyncAt: dt);
  }

  /// 로컬과 클라우드가 마지막으로 같아진 시각을 기록한다.
  /// 업로드·복원 양쪽 모두에서 남겨야 한다.
  Future<void> _saveLastUpload(DateTime dt) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setString(_lastUploadKey, dt.toIso8601String());
  }

  /// Uploads local data to Firestore.
  Future<CloudSyncResult> upload() async {
    if (FirebaseService.instance.currentUser == null) {
      return CloudSyncResult.notLoggedIn;
    }
    state = state.copyWith(isSyncing: true, clearError: true);
    try {
      final backup = await _buildBackup();
      await FirebaseService.instance.uploadBackup(backup);
      final now = DateTime.now();
      await _saveLastSync(now);
      await _saveLastUpload(now);
      state = state.copyWith(isSyncing: false, message: '업로드 완료');
      return CloudSyncResult.uploaded;
    } catch (e) {
      state = state.copyWith(isSyncing: false, error: e.toString());
      return CloudSyncResult.error;
    }
  }

  /// Downloads cloud data and restores local DB.
  Future<CloudSyncResult> download() async {
    if (FirebaseService.instance.currentUser == null) {
      return CloudSyncResult.notLoggedIn;
    }
    state = state.copyWith(isSyncing: true, clearError: true);
    try {
      final backup = await FirebaseService.instance.downloadBackup();
      if (backup == null) {
        state = state.copyWith(isSyncing: false, message: '클라우드에 데이터가 없습니다');
        return CloudSyncResult.noData;
      }
      final backupSvc = _ref.read(backupServiceProvider);
      await backupSvc.restore(backup);
      final now = DateTime.now();
      await _saveLastSync(now);
      // 복원 후에는 로컬과 클라우드가 같다. 이걸 기록해 두지 않으면
      // 다음 로그인 때 또 덮어쓸 후보가 된다.
      await _saveLastUpload(now);
      state = state.copyWith(isSyncing: false, message: '다운로드 완료. 앱을 재시작해 주세요.');
      return CloudSyncResult.downloaded;
    } catch (e) {
      state = state.copyWith(isSyncing: false, error: e.toString());
      return CloudSyncResult.error;
    }
  }

  /// 로그인 직후 로컬과 클라우드를 비교만 한다. **아무것도 덮어쓰지 않는다.**
  ///
  /// 예전에는 여기서 자동으로 download()를 불렀는데, download()가 마지막
  /// 업로드 시각을 기록하지 않아 `lastUpload`가 계속 null로 남았다. 그 결과
  /// 로그인할 때마다 로컬이 클라우드로 덮어써져 기기에서 새로 입력한 내용이
  /// 사라질 수 있었다. 이제는 어느 쪽을 쓸지 사용자가 고르게 한다.
  Future<SyncComparison?> compare() async {
    if (FirebaseService.instance.currentUser == null) return null;

    state = state.copyWith(isSyncing: true, clearError: true);
    try {
      final cloud = await FirebaseService.instance.downloadBackup();
      final cloudUpdatedAt =
          await FirebaseService.instance.getCloudUpdatedAt();
      final local = await _buildBackup();
      state = state.copyWith(isSyncing: false);
      return SyncComparison(
        cloudBackup: cloud,
        localBackup: local,
        cloudUpdatedAt: cloudUpdatedAt,
      );
    } catch (e) {
      state = state.copyWith(isSyncing: false, error: e.toString());
      return null;
    }
  }

  /// 이미 받아 둔 백업으로 로컬을 교체한다 (다시 내려받지 않는다).
  Future<CloudSyncResult> restoreFrom(Map<String, dynamic> backup) async {
    state = state.copyWith(isSyncing: true, clearError: true);
    try {
      await _ref.read(backupServiceProvider).restore(backup);
      final now = DateTime.now();
      await _saveLastSync(now);
      // 이 시점부터 로컬과 클라우드가 같다.
      await _saveLastUpload(now);
      state = state.copyWith(
          isSyncing: false, message: '복원 완료. 앱을 재시작해 주세요.');
      return CloudSyncResult.downloaded;
    } catch (e) {
      state = state.copyWith(isSyncing: false, error: e.toString());
      return CloudSyncResult.error;
    }
  }

  Future<Map<String, dynamic>> _buildBackup() =>
      _ref.read(backupServiceProvider).buildBackup();
}

final cloudSyncProvider =
    StateNotifierProvider<CloudSyncNotifier, CloudSyncState>((ref) {
  return CloudSyncNotifier(ref);
});
