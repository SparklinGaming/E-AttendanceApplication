import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../repositories/user_repository.dart';
import '../services/auth_service.dart';

class CurrentUserProvider extends ChangeNotifier {
  CurrentUserProvider({
    AuthService? authService,
    UserRepository? userRepository,
  })  : _authService = authService ?? AuthService(),
        _userRepository = userRepository ?? UserRepository();

  final AuthService _authService;
  final UserRepository _userRepository;

  StreamSubscription<User?>? _authSub;
  User? _user;
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  User? get user => _user;
  String? get uid => _user?.uid;
  Map<String, dynamic>? get profile => _profile;
  bool get isLoading => _isLoading;
  String get displayName => _profile?['name'] ?? 'there';
  String? get photoUrl {
    final value = _profile?['photoUrl'];
    return value is String && value.isNotEmpty ? value : null;
  }

  void start() {
    _authSub ??= _authService.authStateChanges().listen(_setUser);
  }

  Future<void> refreshProfile() async {
    final user = _user;
    if (user == null) return;

    _profile = await _userRepository.getUserData(user.uid);
    notifyListeners();
  }

  Future<void> _setUser(User? user) async {
    _user = user;
    _profile = null;

    if (user != null) {
      try {
        _profile = await _userRepository.getUserData(user.uid);
      } catch (e, s) {
        debugPrint('Failed to fetch user profile: $e');
        debugPrintStack(stackTrace: s);
        // Keep _profile as null — UI handles missing profile gracefully.
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
