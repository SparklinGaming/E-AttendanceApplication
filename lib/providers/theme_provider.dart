import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'current_user_provider.dart';

/// Manages the app's theme mode (light / dark) and persists the preference
/// to the user's Firestore document so the choice survives logouts.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLoaded => _loaded;

  /// Call after the CurrentUserProvider has finished loading the user profile.
  Future<void> load({required CurrentUserProvider userProvider}) async {
    final uid = userProvider.uid;
    final profile = userProvider.profile;

    if (profile != null && profile['theme_mode'] is String) {
      _themeMode = profile['theme_mode'] == 'dark'
          ? ThemeMode.dark
          : ThemeMode.light;
    } else if (uid != null) {
      // Fallback: read from Firestore directly
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      if (data != null && data['theme_mode'] is String) {
        _themeMode =
            data['theme_mode'] == 'dark' ? ThemeMode.dark : ThemeMode.light;
      }
    }

    _loaded = true;
    notifyListeners();
  }

  /// Toggle between light and dark mode and persist to Firestore.
  Future<void> toggle({required String uid}) async {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();

    // Persist to Firestore (fire-and-forget)
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'theme_mode': _themeMode == ThemeMode.dark ? 'dark' : 'light',
    });
  }

  /// Set a specific theme mode and persist.
  Future<void> setThemeMode({
    required ThemeMode mode,
    required String uid,
  }) async {
    _themeMode = mode;
    notifyListeners();

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'theme_mode': mode == ThemeMode.dark ? 'dark' : 'light',
    });
  }
}
