import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAjpt1cgzVZDfWC6BN5st7fHyUfLV1JtEE',
    appId: '1:434472415626:android:adf0d13d157c3c1ecbd873',
    messagingSenderId: '434472415626',
    projectId: 'smartapp-b109a',
    storageBucket: 'smartapp-b109a.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD7-zs7W8Y1NkaqsN-KxQziJpG_rYDDuJU',
    appId: '1:434472415626:ios:8980709c07ebc9a1cbd873',
    messagingSenderId: '434472415626',
    projectId: 'smartapp-b109a',
    storageBucket: 'smartapp-b109a.firebasestorage.app',
    iosBundleId: 'com.talkingcards.app',
  );
}
