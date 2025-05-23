import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Automatically generated by flutterfire configure
import 'package:sevaexchange/app.dart'; // Your app entry point
import 'package:sevaexchange/flavor_config.dart'; // Flavor management (e.g., dev/prod)

Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with options from firebase_options.dart
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize custom app configurations (e.g., flavors)
  await initApp(Flavor.APP);

  // Run the main application widget
  runApp(
    MainApplication(skipToHomePage: false),
  );
}
