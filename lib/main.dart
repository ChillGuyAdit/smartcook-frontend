import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:smartcook/auth/signIn.dart';
import 'package:smartcook/service/api_service.dart';
import 'package:smartcook/view/splashscreen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  ApiService.onUnauthorized = () {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/signin',
      (route) => false,
    );
  };

  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const splashscreen(),
        '/signin': (context) => const signin(),
      },
    );
  }
}
