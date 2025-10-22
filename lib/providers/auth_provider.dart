// lib/providers/auth_provider.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  User? _currentUser;
  bool _isLoading =
      false; // Represents LOGIN/SIGNUP/PASSWORD_RESET process primarily
  String? _errorMessage;
  bool _isListening = false; // Prevents duplicate listeners

  // Getters
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get isEmailVerified => _currentUser?.emailVerified ?? false;

  AuthProvider() {
    _initializeAuth();
  }

  /// Initialize authentication on app start and set up listener
  Future<void> _initializeAuth() async {
    // Check initial state without blocking with loading=true yet
    _currentUser = _firebaseAuth.currentUser;
    bool needsInitialNotify = false; // Flag to notify once at the end

    if (_currentUser != null) {
      debugPrint(
          '[AuthProvider._initializeAuth] Found initial user: ${_currentUser?.email}. Will reload.');
      // Set loading briefly ONLY if reloading an existing user initially
      _isLoading = true;
      // Don't notify yet, wait until after listener setup or reload attempt
      try {
        await _currentUser!.reload();
        _currentUser = _firebaseAuth.currentUser; // Refresh
        debugPrint(
            '[AuthProvider._initializeAuth] Initial user reloaded: ${_currentUser?.email}, verified: ${_currentUser?.emailVerified}');
      } catch (e) {
        debugPrint(
            '[AuthProvider._initializeAuth] Error reloading initial user: $e');
        _errorMessage = 'Failed to refresh initial user data: $e';
        // Consider signing out if reload fails critically
        // await _firebaseAuth.signOut();
        // _currentUser = null;
      }
      _isLoading = false; // Done with initial reload attempt
      needsInitialNotify = true; // Need to notify about the initial user state
    } else {
      debugPrint('[AuthProvider._initializeAuth] No initial user found.');
      _isLoading = false; // Ensure loading is false
      // Listener will fire with null, triggering notification if needed
    }

    // Set up the listener ONCE
    if (!_isListening) {
      _isListening = true;
      _firebaseAuth.authStateChanges().listen((User? user) {
        debugPrint(
            '[AuthProvider] authStateChanges listener fired. New user: ${user?.email}, Previous user: ${_currentUser?.email}');

        bool userActuallyChanged = _currentUser?.uid != user?.uid;
        String? previousUserEmail = _currentUser?.email; // Store before update

        // --- Core Logic Change ---
        _currentUser = user; // Update the user state *immediately*

        if (user != null) {
          // User is logged IN
          if (userActuallyChanged) {
            debugPrint(
                '[AuthProvider] User logged IN (${user.email}). Notifying for navigation.');
            // Ensure loading from login/signup process is OFF before notifying
            if (_isLoading) _isLoading = false;
            notifyListeners(); // <<== IMMEDIATE NOTIFICATION FOR NAVIGATION/UI UPDATE

            // Now, attempt reload in background - DO NOT await here
            _handleBackgroundReload(user);
          } else {
            // Listener fired, but user is the same (e.g., token refresh)
            debugPrint(
                '[AuthProvider] Listener fired, user unchanged: ${user.email}. Triggering background reload.');
            // Trigger background reload to potentially catch verification changes
            _handleBackgroundReload(user);
          }
        } else {
          // User is logged OUT
          if (userActuallyChanged) {
            debugPrint(
                '[AuthProvider] User logged OUT (previously $previousUserEmail). Notifying.');
            if (_isLoading) _isLoading = false; // Ensure loading is off
            _errorMessage = null; // Clear errors on logout
            notifyListeners(); // Notify UI about logout
          } else {
            // Listener fired with null, but user was already null. No notification needed.
            debugPrint('[AuthProvider] Listener fired, user still null.');
          }
        }
        // --- End Core Logic Change ---
      });
      debugPrint(
          '[AuthProvider._initializeAuth] Auth state listener attached.');
    }

    // Notify listeners with the initial state after setup or if initial user was reloaded
    if (needsInitialNotify) {
      notifyListeners();
    }
  }

  /// Handle background user data refresh (e.g., verification status)
  Future<void> _handleBackgroundReload(User user) async {
    debugPrint(
        '[AuthProvider._handleBackgroundReload] Started for ${user.email}');
    try {
      await user.reload();
      // Check if the user context is still valid (user hasn't logged out during reload)
      if (_currentUser?.uid == user.uid) {
        User? reloadedUser =
            _firebaseAuth.currentUser; // Get the refreshed user
        bool verificationStatusChanged =
            _currentUser?.emailVerified != reloadedUser?.emailVerified;
        _currentUser = reloadedUser; // Update the provider's user instance
        debugPrint(
            '[AuthProvider._handleBackgroundReload] User reloaded: ${_currentUser?.email}, verified: ${_currentUser?.emailVerified}');
        // Only notify if the verification status actually changed
        if (verificationStatusChanged) {
          debugPrint(
              '[AuthProvider._handleBackgroundReload] Verification status changed. Notifying.');
          notifyListeners();
        } else {
          debugPrint(
              '[AuthProvider._handleBackgroundReload] Verification status unchanged. No notification needed from reload.');
        }
      } else {
        debugPrint(
            '[AuthProvider._handleBackgroundReload] User changed during reload. Ignoring result.');
      }
    } catch (e) {
      debugPrint(
          '[AuthProvider._handleBackgroundReload] Error reloading user: $e');
      // Only set error message if the user context is still valid
      if (_currentUser?.uid == user.uid) {
        _errorMessage = 'Failed to refresh user data: $e';
        // Consider if notifying about a background error is desired
        // notifyListeners();
      }
    }
  }

  /// Sign up with email and password
  Future<bool> signup(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // Show loading indicator
    debugPrint('[AuthProvider.signup] Attempting signup for $email');

    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _secureStorage.write(key: 'user_email', value: email);

      // Send verification email
      if (userCredential.user != null && !userCredential.user!.emailVerified) {
        try {
          await userCredential.user!.sendEmailVerification();
          debugPrint(
              '[AuthProvider.signup] ✓ Verification email sent to $email');
          _errorMessage = null;
        } catch (e) {
          debugPrint(
              '[AuthProvider.signup] ⚠️ Error sending verification email: $e');
          _errorMessage = 'Could not send verification email: $e';
        }
      }

      debugPrint(
          '[AuthProvider.signup] Signup successful for $email. Waiting for listener...');
      // Let the authStateChanges listener handle loading=false and notification.
      // _isLoading = false; // Handled by listener
      return true; // Indicate signup call succeeded
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      debugPrint('[AuthProvider.signup] Error: ${e.code} - $_errorMessage');
      _isLoading = false;
      notifyListeners(); // Notify UI about the error and loading state change
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred during signup: $e';
      debugPrint('[AuthProvider.signup] Unexpected error: $e');
      _isLoading = false;
      notifyListeners(); // Notify UI about the error and loading state change
      return false;
    }
  }

  /// Login with email and password
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // Show loading indicator on button
    debugPrint('[AuthProvider.login] Attempting login for $email');

    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint(
          '[AuthProvider.login] signInWithEmailAndPassword successful for $email. Waiting for listener to handle user state...');
      await _secureStorage.write(key: 'user_email', value: email);

      // Set loading false HERE and notify to stop button loading
      // The listener will handle the actual user state update and navigation trigger
      _isLoading = false;
      notifyListeners(); // <<< This stops the button loading

      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      debugPrint('[AuthProvider.login] Error: ${e.code} - $_errorMessage');
      _isLoading = false; // Ensure loading is false on error
      notifyListeners(); // Notify UI about the error and loading state change
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred during login: $e';
      debugPrint('[AuthProvider.login] Unexpected error: $e');
      _isLoading = false; // Ensure loading is false on error
      notifyListeners(); // Notify UI about the error and loading state change
      return false;
    }
  }

  /// Logout
  Future<bool> logout() async {
    debugPrint('[AuthProvider.logout] Attempting logout...');
    try {
      await _firebaseAuth.signOut();
      await _secureStorage.delete(key: 'user_email');
      _errorMessage = null;
      // _isLoading = false; // Listener will set this when user becomes null
      debugPrint(
          '[AuthProvider.logout] Sign out successful. Waiting for listener...');
      // Let the authStateChanges listener handle _currentUser = null and notifyListeners().
      return true;
    } catch (e) {
      _errorMessage = 'Logout failed: $e';
      debugPrint('[AuthProvider.logout] Error: $e');
      _isLoading = false; // Ensure loading is false on error
      notifyListeners(); // Notify UI about the error
      return false;
    }
  }

  /// Send password reset email
  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    debugPrint('[AuthProvider.resetPassword] Sending reset email to $email');

    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      debugPrint('[AuthProvider.resetPassword] Password reset email sent.');
      _isLoading = false;
      notifyListeners(); // Notify completion
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      debugPrint(
          '[AuthProvider.resetPassword] Error: ${e.code} - $_errorMessage');
      _isLoading = false;
      notifyListeners(); // Notify error
      return false;
    } catch (e) {
      _errorMessage = 'Failed to send reset email: $e';
      debugPrint('[AuthProvider.resetPassword] Unexpected error: $e');
      _isLoading = false;
      notifyListeners(); // Notify error
      return false;
    }
  }

  /// Send email verification link to the current user
  Future<bool> sendEmailVerification() async {
    if (_currentUser == null || _currentUser!.emailVerified) {
      _errorMessage = 'No user signed in or email already verified';
      debugPrint(
          '[AuthProvider.sendEmailVerification] Failed: No user or already verified.');
      // Only notify if error message actually changed
      if (_errorMessage != 'No user signed in or email already verified') {
        notifyListeners();
      }
      return false;
    }

    // Use a local flag or specific UI state instead of global _isLoading
    // for actions that don't block login/logout flow.
    // For simplicity here, we still use _isLoading, but consider refining.
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    debugPrint(
        '[AuthProvider.sendEmailVerification] Sending verification to ${_currentUser!.email}');

    try {
      await _currentUser!.sendEmailVerification();
      debugPrint(
          '[AuthProvider.sendEmailVerification] ✓ Verification email sent.');
      _errorMessage = null; // Clear potential error
      _isLoading = false;
      notifyListeners(); // Notify completion/state change
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      debugPrint(
          '[AuthProvider.sendEmailVerification] ❌ Send verification error: ${e.code} - $_errorMessage');
      _isLoading = false;
      notifyListeners(); // Notify error
      return false;
    } catch (e) {
      _errorMessage = 'Failed to send verification email: $e';
      debugPrint(
          '[AuthProvider.sendEmailVerification] ❌ Send verification unexpected error: $e');
      _isLoading = false;
      notifyListeners(); // Notify error
      return false;
    }
  }

  /// Manually check if the current user's email is verified
  Future<bool> checkEmailVerified() async {
    if (_currentUser == null) {
      debugPrint('[AuthProvider.checkEmailVerified] No user to check.');
      return false;
    }

    // Use local flag or specific UI state if needed, not global _isLoading
    // _isLoading = true;
    // notifyListeners();
    debugPrint(
        '[AuthProvider.checkEmailVerified] Checking verification for ${_currentUser!.email}');

    bool verifiedStatusBeforeReload = _currentUser?.emailVerified ?? false;

    try {
      await _currentUser!.reload();
      // Important: Refresh the instance from FirebaseAuth after reload
      _currentUser = _firebaseAuth.currentUser;
      final isVerified = _currentUser?.emailVerified ?? false;
      debugPrint(
          '[AuthProvider.checkEmailVerified] Status after reload: $isVerified');

      // _isLoading = false; // Match removal above if done
      if (isVerified != verifiedStatusBeforeReload) {
        debugPrint(
            '[AuthProvider.checkEmailVerified] Status changed. Notifying.');
        _errorMessage = null; // Clear potential previous error
        notifyListeners(); // Notify state change ONLY if status changed
      } else {
        debugPrint('[AuthProvider.checkEmailVerified] Status unchanged.');
      }
      return isVerified;
    } catch (e) {
      _errorMessage = 'Failed to check verification status: $e';
      debugPrint(
          '[AuthProvider.checkEmailVerified] ❌ Check verification error: $e');
      // _isLoading = false; // Match removal above if done
      notifyListeners(); // Notify about the error
      return false;
    }
  }

  /// Get stored user email (might not match auth state during email change)
  Future<String?> getUserEmail() async {
    return await _secureStorage.read(key: 'user_email');
  }

  /// Clear any existing error message
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Map Firebase error codes to user-friendly messages
  String _getErrorMessage(String code) {
    // Keep your existing _getErrorMessage logic
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
        // This is important for delete/update operations
        return 'This action requires you to have logged in recently. Please log out and log back in.';
      default:
        return 'An error occurred ($code). Please try again.';
    }
  }

  /// Delete the current user's account
  Future<bool> deleteAccount() async {
    debugPrint('[AuthProvider.deleteAccount] Attempting account deletion...');
    if (_currentUser == null) {
      _errorMessage = 'No user is currently signed in.';
      debugPrint('[AuthProvider.deleteAccount] Failed: No user signed in.');
      notifyListeners();
      return false;
    }
    // Consider setting a specific loading state for deletion if needed
    // _isLoading = true; notifyListeners();
    try {
      await _currentUser!.delete();
      await _secureStorage.delete(key: 'user_email');
      _errorMessage = null;
      // _isLoading = false; // Match above if set
      debugPrint(
          '[AuthProvider.deleteAccount] Account deleted. Waiting for listener...');
      // Let authStateChanges listener handle UI update (user becomes null)
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = 'Failed to delete account: ${_getErrorMessage(e.code)}';
      debugPrint(
          '[AuthProvider.deleteAccount] Error: ${e.code} - ${e.message}');
      // _isLoading = false; // Match above if set
      notifyListeners(); // Notify UI about the error
      return false;
    } catch (e) {
      _errorMessage =
          'An unexpected error occurred during account deletion: $e';
      debugPrint('[AuthProvider.deleteAccount] Unexpected error: $e');
      // _isLoading = false; // Match above if set
      notifyListeners(); // Notify error
      return false;
    }
  }

  /// Initiate email update process
  Future<bool> updateEmail(String newEmail) async {
    debugPrint(
        '[AuthProvider.updateEmail] Attempting to initiate email update...');
    if (_currentUser == null) {
      _errorMessage = 'No user is currently signed in.';
      debugPrint('[AuthProvider.updateEmail] Failed: No user signed in.');
      notifyListeners();
      return false;
    }
    // Consider specific loading state
    // _isLoading = true; notifyListeners();
    try {
      await _currentUser!.verifyBeforeUpdateEmail(newEmail);
      // Store the *intended* new email locally. Actual update requires verification + re-auth.
      await _secureStorage.write(key: 'user_email', value: newEmail);
      debugPrint(
          '[AuthProvider.updateEmail] Verification email for new email sent to $newEmail');
      _errorMessage =
          'Verification email sent to $newEmail. Please verify and potentially re-login to complete the change.';
      // _isLoading = false; // Match above if set
      notifyListeners(); // Notify about the message/instruction
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      debugPrint('[AuthProvider.updateEmail] Error: ${e.code} - ${e.message}');
      // _isLoading = false; // Match above if set
      notifyListeners(); // Notify error
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred during email update: $e';
      debugPrint('[AuthProvider.updateEmail] Unexpected error: $e');
      // _isLoading = false; // Match above if set
      notifyListeners(); // Notify error
      return false;
    }
  }

  /// Update the current user's password
  Future<bool> updatePassword(String newPassword) async {
    debugPrint('[AuthProvider.updatePassword] Attempting password update...');
    if (_currentUser == null) {
      _errorMessage = 'No user is currently signed in.';
      debugPrint('[AuthProvider.updatePassword] Failed: No user signed in.');
      notifyListeners();
      return false;
    }
    // Consider specific loading state
    // _isLoading = true; notifyListeners();
    try {
      await _currentUser!.updatePassword(newPassword);
      debugPrint(
          '[AuthProvider.updatePassword] Password updated successfully.');
      _errorMessage = null; // Clear previous errors
      // _isLoading = false; // Match above if set
      notifyListeners(); // Notify for potential UI feedback (e.g., success message)
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      debugPrint(
          '[AuthProvider.updatePassword] Error: ${e.code} - ${e.message}');
      // _isLoading = false; // Match above if set
      notifyListeners(); // Notify error
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred during password update: $e';
      debugPrint('[AuthProvider.updatePassword] Unexpected error: $e');
      // _isLoading = false; // Match above if set
      notifyListeners(); // Notify error
      return false;
    }
  }
}
