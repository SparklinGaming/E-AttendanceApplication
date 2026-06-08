import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign In
  Future<User?> signIn(String email, String password) async {
    UserCredential result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return result.user;
  }

  // Create Employee Account (Admin only)
  // This uses a secondary Firebase App instance so the Admin doesn't get logged out
  Future<String?> createEmployeeAccount(
    String email,
    String password,
    String name,
  ) async {
    FirebaseApp? tempApp;
    try {
      tempApp = await Firebase.initializeApp(
        name: 'tempApp_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );

      UserCredential result = await FirebaseAuth.instanceFor(
        app: tempApp,
      ).createUserWithEmailAndPassword(email: email, password: password);

      if (result.user != null) {
        await _firestore.collection('users').doc(result.user!.uid).set({
          'uid': result.user!.uid,
          'email': email,
          'name': name,
          'role': 'employee',
          'createdAt': FieldValue.serverTimestamp(),
          'photoUrl': null,
        });
        return null; // null = success
      }
      return 'Failed to create user';
    } catch (e) {
      return e.toString();
    } finally {
      await tempApp?.delete(); // ✅ Always cleanup even on error
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      debugPrint('🔒 AuthService: signing out');
      await _auth.signOut();
      debugPrint('🔓 AuthService: signOut completed');
    } catch (e, s) {
      debugPrint('❌ AuthService.signOut error: $e');
      debugPrintStack(stackTrace: s);
      rethrow;
    }
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  // Get user role
  Future<String> getUserRole(String uid) async {
    debugPrint('🔍 getUserRole for uid: $uid');
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) {
        debugPrint('⚠️ User document does not exist. Defaulting to employee.');
        return 'employee';
      }
      final data = doc.data();
      final role = data?['role'];
      debugPrint('✅ Role from Firestore: $role');
      return role == 'admin' ? 'admin' : 'employee';
    } catch (e, s) {
      debugPrint('❌ getUserRole error: $e');
      debugPrintStack(stackTrace: s);
      return 'employee';
    }
  }

  //Get User Data
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Creating a user document if it doesn't exist
  Future<void> createUserDoc(
    String uid,
    String email,
    String name,
    String role,
  ) async {
    await _firestore.collection('users').doc(uid).set({
      'email': email,
      'name': name,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  //Update user profile
  Future<void> updateUserProfile(
    String uid, {
    String? name,
    String? photoUrl,
  }) async {
    Map<String, dynamic> updateData = {};
    if (name != null) updateData['name'] = name;
    if (photoUrl != null) updateData['photoUrl'] = photoUrl;
    if (updateData.isNotEmpty) {
      await _firestore.collection('users').doc(uid).update(updateData);
    }
  }

  // Seed Test Users (Dev Helper)
  Future<String> seedTestUsers() async {
    try {
      // Create Admin
      try {
        UserCredential adminCred = await _auth.createUserWithEmailAndPassword(
          email: 'admin@test.com',
          password: 'Password123',
        );
        await createUserDoc(
          adminCred.user!.uid,
          'admin@test.com',
          'Admin User',
          'admin',
        );
      } catch (e) {
        // Ignore if already exists, but try to update doc
        // Note: Can't easily get UID if auth fails, but for dev seed we assume fresh or ignoring.
        debugPrint('Admin creation skipped (likely exists): $e');
      }

      // Create Employee
      try {
        UserCredential empCred = await _auth.createUserWithEmailAndPassword(
          email: 'employee@test.com',
          password: 'Password123',
        );
        await createUserDoc(
          empCred.user!.uid,
          'employee@test.com',
          'John Employee',
          'employee',
        );
      } catch (e) {
        debugPrint('Employee creation skipped (likely exists): $e');
      }
      return 'Seeding attempt complete. Login with:\nadmin@test.com / Password123\nemployee@test.com / Password123';
    } catch (e) {
      return 'Seeding failed: $e';
    }
  }
}
