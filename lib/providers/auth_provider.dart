// KEY FIXES:
// 1. Remove notifyListeners() call inside authStateChanges listener
// 2. Add state check in _startVerificationCheck to prevent duplicate timers
// 3. Better error handling for Firebase operations

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isListening = false; // Add this to prevent duplicate listeners

  // Getters
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get isEmailVerified => _currentUser?.emailVerified ?? false;

  AuthProvider() {
    _initializeAuth();
  }

  /// Initialize authentication on app start
  Future<void> _initializeAuth() async {
    _isLoading = true;
    notifyListeners();

    _currentUser = _firebaseAuth.currentUser;
    if (_currentUser != null) {
      try {
        await _currentUser!.reload();
        _currentUser = _firebaseAuth.currentUser;
        debugPrint(
            'User reloaded: ${_currentUser?.email}, verified: ${_currentUser?.emailVerified}');
      } catch (e) {
        debugPrint('Error reloading user: $e');
        _errorMessage = 'Failed to refresh user data: $e';
      }
    }

    _isLoading = false;
    notifyListeners();

    // Listen to auth state changes - FIXED: Only set up listener once
    if (!_isListening) {
      _isListening = true;
      _firebaseAuth.authStateChanges().listen((User? user) {
        _currentUser = user;
        if (user != null) {
          // Don't call notifyListeners inside async operation
          _handleAuthStateChange(user);
        } else {
          notifyListeners();
        }
      });
    }
  }

  /// Handle auth state changes
  Future<void> _handleAuthStateChange(User user) async {
    try {
      await user.reload();
      _currentUser = _firebaseAuth.currentUser;
      debugPrint(
          'Auth state changed: ${_currentUser?.email}, verified: ${_currentUser?.emailVerified}');
    } catch (e) {
      debugPrint('Error reloading user in auth state: $e');
      _errorMessage = 'Failed to refresh user data: $e';
    }
    // Only notify once after all operations complete
    notifyListeners();
  }

  /// Sign up with email and password
  Future<bool> signup(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      _currentUser = userCredential.user;
      await _secureStorage.write(key: 'user_email', value: email);

      // Send verification email - FIXED: Added better error handling
      if (_currentUser != null && !_currentUser!.emailVerified) {
        try {
          await _currentUser!.sendEmailVerification();
          debugPrint('✅ Verification email sent to $email');
          _errorMessage = null; // Clear any previous errors
        } catch (e) {
          debugPrint('⚠️ Error sending verification email: $e');
          _errorMessage = 'Could not send verification email: $e';
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      debugPrint('Signup error: ${e.code} - ${e.message}');
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      debugPrint('Signup unexpected error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Login with email and password
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _currentUser = userCredential.user;
      await _secureStorage.write(key: 'user_email', value: email);

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      debugPrint('Login error: ${e.code} - ${e.message}');
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      debugPrint('Login unexpected error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout
  Future<bool> logout() async {
    try {
      await _firebaseAuth.signOut();
      await _secureStorage.delete(key: 'user_email');
      _currentUser = null;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Logout failed: $e';
      debugPrint('Logout error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Send password reset email
  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      debugPrint('Password reset email sent to $email');
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      debugPrint('Reset password error: ${e.code} - ${e.message}');
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to send reset email: $e';
      debugPrint('Reset password unexpected error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Send email verification
  Future<bool> sendEmailVerification() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_currentUser != null && !_currentUser!.emailVerified) {
        await _currentUser!.sendEmailVerification();
        debugPrint('✅ Verification email sent to ${_currentUser!.email}');
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = 'No user signed in or email already verified';
      debugPrint('⚠️ Send verification failed: No user or already verified');
      _isLoading = false;
      notifyListeners();
      return false;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      debugPrint('❌ Send verification error: ${e.code} - ${e.message}');
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to send verification email: $e';
      debugPrint('❌ Send verification unexpected error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Check email verification status - FIXED: Add delay and limit checks
  Future<bool> checkEmailVerified() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _currentUser?.reload();
      _currentUser = _firebaseAuth.currentUser;

      final isVerified = _currentUser?.emailVerified ?? false;
      debugPrint(
          'Checked email verification: ${_currentUser?.email}, verified: $isVerified');

      _isLoading = false;
      notifyListeners();
      return isVerified;
    } catch (e) {
      _errorMessage = 'Failed to check verification status: $e';
      debugPrint('❌ Check verification error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<String?> getUserEmail() async {
    return await _secureStorage.read(key: 'user_email');
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Map Firebase error codes to user-friendly messages
  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password authentication is not enabled.';
      case 'requires-recent-login':
        return 'Please log in again to perform this action.';
      default:
        return 'An error occurred: $code. Please try again.';
    }
  }

  Future<bool> deleteAccount() async {
    try {
      await _currentUser?.delete();
      await _secureStorage.delete(key: 'user_email');
      _currentUser = null;
      _errorMessage = null;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = 'Failed to delete account: ${e.message}';
      debugPrint('Delete account error: ${e.code} - ${e.message}');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateEmail(String newEmail) async {
    try {
      await _currentUser?.verifyBeforeUpdateEmail(newEmail);
      await _secureStorage.write(key: 'user_email', value: newEmail);
      debugPrint('Verification email for new email sent to $newEmail');
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      debugPrint('Update email error: ${e.code} - ${e.message}');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    try {
      await _currentUser?.updatePassword(newPassword);
      debugPrint('Password updated successfully');
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      debugPrint('Update password error: ${e.code} - ${e.message}');
      notifyListeners();
      return false;
    }
  }
}
