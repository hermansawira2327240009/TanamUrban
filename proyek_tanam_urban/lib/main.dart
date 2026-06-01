import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const TanamUrbanApp());
}

class TanamUrbanApp extends StatelessWidget {
  const TanamUrbanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TanamUrban',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
        ),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text(
            'TanamUrban berhasil terhubung ke Firebase',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}