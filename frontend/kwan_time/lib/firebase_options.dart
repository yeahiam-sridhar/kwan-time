import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not configured.');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Platform not configured.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCwhG6Z-NxM65nYrd97V4JQMUete8lPLSU',
    appId: '1:888050513735:android:d327e3e84046e7d4b83e62',
    messagingSenderId: '888050513735',
    projectId: 'kwan-time',
    storageBucket: 'kwan-time.firebasestorage.app',
  );
}
