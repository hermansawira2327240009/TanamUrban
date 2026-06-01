import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode {
    return _isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> loadTheme() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = userDoc.data();

    _isDarkMode = data?['isDarkMode'] ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme(bool value) async {
    final User? user = FirebaseAuth.instance.currentUser;

    _isDarkMode = value;
    notifyListeners();

    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'isDarkMode': value,
      });
    }
  }
}