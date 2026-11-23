import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'share_code.dart';

export 'package:firebase_auth/firebase_auth.dart' show User;

enum CloudSyncResult { notLoggedIn, uploaded, downloaded, noData, error }

class FirebaseService {
  static final instance = FirebaseService._();
  FirebaseService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    final googleUser = await GoogleSignIn(
      serverClientId: '1037924995770-0ievgibacsvgcvb1lu3oejghhoba5f6e.apps.googleusercontent.com',
    ).signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    return result.user;
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _dataCol(String uid) =>
      _userDoc(uid).collection('sync_data');

  /// Stores the backup map in Firestore under users/{uid}/sync_data/*.
  Future<void> uploadBackup(Map<String, dynamic> backup) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다');
    final now = Timestamp.now();

    await _userDoc(uid).set({
      'updatedAt': now,
      'email': currentUser?.email ?? '',
      'portfolioCount': (backup['portfolios'] as List?)?.length ?? 0,
    }, SetOptions(merge: true));

    final col = _dataCol(uid);
    await Future.wait([
      col.doc('portfolios').set(
          {'json': jsonEncode(backup['portfolios'] ?? [])}),
      col.doc('assets').set(
          {'json': jsonEncode(backup['assets'] ?? [])}),
      col.doc('portfolio_assets').set(
          {'json': jsonEncode(backup['portfolioAssets'] ?? [])}),
      col.doc('transactions').set(
          {'json': jsonEncode(backup['transactions'] ?? [])}),
      col.doc('investments').set(
          {'json': jsonEncode(backup['investments'] ?? [])}),
      col.doc('prefs').set(
          {'json': jsonEncode(backup['prefs'] ?? {})}),
    ]);
  }

  /// Downloads the backup map from Firestore. Returns null if no data exists.
  Future<Map<String, dynamic>?> downloadBackup() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;

    final meta = await _userDoc(uid).get();
    if (!meta.exists) return null;
    final updatedAt = (meta.data()?['updatedAt'] as Timestamp?)?.toDate();

    final col = _dataCol(uid);
    final docs = await Future.wait([
      col.doc('portfolios').get(),
      col.doc('assets').get(),
      col.doc('portfolio_assets').get(),
      col.doc('transactions').get(),
      col.doc('investments').get(),
      col.doc('prefs').get(),
    ]);

    if (docs.any((d) => !d.exists)) return null;

    String getField(DocumentSnapshot<Map<String, dynamic>> d) =>
        d.data()?['json'] as String? ?? '[]';

    return {
      'version': 1,
      'exportedAt':
          updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'portfolios': jsonDecode(getField(docs[0])),
      'assets': jsonDecode(getField(docs[1])),
      'portfolioAssets': jsonDecode(getField(docs[2])),
      'transactions': jsonDecode(getField(docs[3])),
      'investments': jsonDecode(getField(docs[4])),
      'prefs': (() {
        final raw = docs[5].data()?['json'] as String? ?? '{}';
        final decoded = jsonDecode(raw);
        return decoded is Map ? decoded : {};
      })(),
    };
  }

  Future<DateTime?> getCloudUpdatedAt() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    try {
      final doc = await _userDoc(uid).get();
      final ts = doc.data()?['updatedAt'] as Timestamp?;
      return ts?.toDate();
    } catch (_) {
      return null;
    }
  }

  // ── Portfolio sharing ────────────────────────────────────────────────────────

  /// 공유 문서를 만들고 코드를 돌려준다. **로그인이 필요하다.**
  ///
  /// 코드가 이미 있으면 Firestore 규칙(`allow update: if false`)이
  /// permission-denied로 막는다 — 조용한 덮어쓰기 대신 재시도한다.
  /// 32^6 ≈ 10억이고 암호학적 난수를 쓰므로 실제로 걸릴 일은 거의 없다.
  Future<String> sharePortfolio(Map<String, dynamic> data) async {
    final user = currentUser;
    if (user == null) throw ShareAuthRequiredException();

    const maxAttempts = 5;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final code = ShareCode.generate();
      try {
        await _db.collection('portfolio_shares').doc(code).set({
          ...data,
          'sharedAt': Timestamp.now(),
          'sharedBy': user.email ?? user.uid,
        });
        return code;
      } on FirebaseException catch (e) {
        // 로그인은 위에서 확인했으므로 코드 충돌로 본다. 마지막 시도까지
        // 막히면 그대로 올려 사용자에게 알린다.
        if (e.code == 'permission-denied' && attempt < maxAttempts) continue;
        rethrow;
      }
    }
    throw Exception('공유 코드를 만들지 못했습니다. 다시 시도해주세요.');
  }

  /// 코드로 공유 포트폴리오를 가져온다. **로그인이 필요하다.**
  ///
  /// 코드가 없으면 null. 권한이 없으면 [ShareAuthRequiredException],
  /// 그 외 오류는 그대로 올린다 — 전에는 모든 오류를 null로 삼켜
  /// 네트워크 장애가 '코드 없음'으로 보였다.
  Future<Map<String, dynamic>?> getSharedPortfolio(String code) async {
    if (currentUser == null) throw ShareAuthRequiredException();
    try {
      final doc = await _db
          .collection('portfolio_shares')
          .doc(ShareCode.normalize(code))
          .get();
      return doc.exists ? doc.data() : null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw ShareAuthRequiredException();
      rethrow;
    }
  }
}

/// 공유를 만들거나 보려면 로그인이 필요하다는 뜻.
///
/// '코드 없음'과 구분해야 화면에서 로그인 안내를 띄울 수 있다.
class ShareAuthRequiredException implements Exception {
  final String message;
  ShareAuthRequiredException([this.message = '로그인이 필요합니다']);

  @override
  String toString() => message;
}
