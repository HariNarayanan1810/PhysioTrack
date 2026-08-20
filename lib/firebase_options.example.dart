import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Firebase options are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'your_web_api_key',
    appId: 'your_web_app_id',
    messagingSenderId: 'your_sender_id',
    projectId: 'your_firebase_project_id',
    authDomain: 'your_firebase_project_id.firebaseapp.com',
    storageBucket: 'your_firebase_project_id.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'your_android_api_key',
    appId: 'your_android_app_id',
    messagingSenderId: 'your_sender_id',
    projectId: 'your_firebase_project_id',
    storageBucket: 'your_firebase_project_id.appspot.com',
  );
}
