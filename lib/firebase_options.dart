import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
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
    apiKey: 'AIzaSyDWS9722OGGyNTtDVaL4LJSQsuvAXKxBPI',
    appId: '1:528608210144:android:f4b811935189d7be893485',
    messagingSenderId: '528608210144',
    projectId: 'fixradar-77067',
    storageBucket: 'fixradar-77067.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAYQHHsRTQrUK9frThn4xoiPcsuR80Uqck',
    appId: '1:528608210144:ios:31341746a6ddddda893485',
    messagingSenderId: '528608210144',
    projectId: 'fixradar-77067',
    storageBucket: 'fixradar-77067.firebasestorage.app',
    iosClientId: '528608210144-4nnmq9kqont8b0bjs2s2v6r9fnhu54vp.apps.googleusercontent.com',
    iosBundleId: 'com.venturesflstudio.fixRadar',
  );
}
