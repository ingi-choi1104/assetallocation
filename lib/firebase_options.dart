// PLACEHOLDER — 실제 파일은 아래 단계로 생성하세요:
//
// 1. Firebase Console (console.firebase.google.com) 에서 프로젝트 생성
// 2. Android 앱 추가 (패키지명: com.dobby.assetallocation)
// 3. google-services.json 다운로드 → android/app/google-services.json 에 배치
// 4. Authentication → Google 로그인 활성화
// 5. Firestore Database 생성 (프로덕션 모드)
// 6. 아래 명령어 실행:
//    dart pub global activate flutterfire_cli
//    flutterfire configure
//
// flutterfire configure 실행 후 이 파일이 자동으로 교체됩니다.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions: 지원하지 않는 플랫폼입니다.\n'
          'flutterfire configure 를 실행하여 이 파일을 다시 생성하세요.',
        );
    }
  }

  // flutterfire configure 실행 후 실제 값으로 교체됩니다

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAHyI2joePcu-VPTfUikzcnFwaijFzxhzw',
    appId: '1:1037924995770:android:ba9cc7537de9ed31442883',
    messagingSenderId: '1037924995770',
    projectId: 'dobby-assetallocation',
    storageBucket: 'dobby-assetallocation.firebasestorage.app',
  );
}
