import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'features/auth/login.dart';
import 'features/home/home.dart';
import 'features/admin/admin_home.dart';
import 'providers/current_user_provider.dart';
import 'services/auth_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AuthService _authService = AuthService();
  StreamSubscription<User?>? _authSub;
  int _navToken = 0;

  @override
  void initState() {
    super.initState();
    _authSub = _authService.authStateChanges().listen(
          _handleAuthStateChange,
        );
  }

  Future<void> _handleAuthStateChange(User? user) async {
    final int token = ++_navToken;

    if (user == null) {
      _replaceRouteStack((_) => const LoginPage(), token);
      return;
    }

    try {
      final role = await _authService.getUserRole(user.uid);
      if (!mounted || token != _navToken) return;

      _replaceRouteStack(
        (_) => role == 'admin' ? const AdminHomePage() : const HomePage(),
        token,
      );
    } catch (e, s) {
      debugPrint('Auth route resolution failed: $e');
      debugPrintStack(stackTrace: s);
      if (!mounted || token != _navToken) return;

      _replaceRouteStack((_) => const HomePage(), token);
    }
  }

  void _replaceRouteStack(WidgetBuilder builder, int token) {
    if (!mounted || token != _navToken) return;

    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: builder),
        (route) => false,
      );
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || token != _navToken) return;
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: builder),
        (route) => false,
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CurrentUserProvider()..start(),
      child: MaterialApp(
        title: 'E-ATTEND',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFD95A)),
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFFD95A),
      body: Center(
        child: CircularProgressIndicator(color: Colors.black),
      ),
    );
  }
}
