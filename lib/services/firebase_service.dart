import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  /// Saves portfolio data to public Firestore and returns a 6-char share code.
  Future<String> sharePortfolio(Map<String, dynamic> data) async {
    final code = _generateCode();
    await _db.collection('portfolio_shares').doc(code).set({
      ...data,
      'sharedAt': Timestamp.now(),
      'sharedBy': currentUser?.email ?? 'anonymous',
    });
    return code;
  }

  /// Fetches shared portfolio data by code. Returns null if not found.
  Future<Map<String, dynamic>?> getSharedPortfolio(String code) async {
    try {
      final doc = await _db
          .collection('portfolio_shares')
          .doc(code.toUpperCase())
          .get();
      return doc.exists ? doc.data() : null;
    } catch (_) {
      return null;
    }
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = DateTime.now().millisecondsSinceEpoch;
    var seed = rand;
    final buf = StringBuffer();
    for (int i = 0; i < 6; i++) {
      seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF;
      buf.write(chars[seed % chars.length]);
    }
    return buf.toString();
  }
}
