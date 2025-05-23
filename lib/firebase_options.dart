// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC5p0iPaOTJEtOpfc8bT5zQnxlIrHtVgsU',
    appId: '1:1030900930316:web:870654870f13683c4bdb29',
    messagingSenderId: '1030900930316',
    projectId: 'sevaxproject4sevax',
    authDomain: 'sevaxproject4sevax.firebaseapp.com',
    databaseURL: 'https://sevaxproject4sevax.firebaseio.com',
    storageBucket: 'sevaxproject4sevax.appspot.com',
    measurementId: 'G-P3NV8FZDY6',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC_vek04VOXi_4bgXq9TxKLRI4ZQ_Nj7s0',
    appId: '1:1030900930316:android:7464c40ccff31aa34bdb29',
    messagingSenderId: '1030900930316',
    projectId: 'sevaxproject4sevax',
    databaseURL: 'https://sevaxproject4sevax.firebaseio.com',
    storageBucket: 'sevaxproject4sevax.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAN1i87LDcy81Bh2dFi8eyfrziFHEltxA0',
    appId: '1:1030900930316:ios:48e3764f4656cabe4bdb29',
    messagingSenderId: '1030900930316',
    projectId: 'sevaxproject4sevax',
    databaseURL: 'https://sevaxproject4sevax.firebaseio.com',
    storageBucket: 'sevaxproject4sevax.appspot.com',
    androidClientId: '1030900930316-80jubfdre1241f0agsk38e0rfu16if76.apps.googleusercontent.com',
    iosClientId: '1030900930316-9snjq6ul9adnkjbtagrvriqlnmq144ao.apps.googleusercontent.com',
    iosBundleId: 'com.sevaexchange.app',
  );

}