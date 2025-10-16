import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  
  // Get current user
  static User? get currentUser => _supabase.auth.currentUser;
  
  // Get current session
  static Session? get currentSession => _supabase.auth.currentSession;
  
  // Check if user is logged in
  static bool get isLoggedIn => currentUser != null;
  
  // Stream of auth state changes
  static Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
  
  // =====================================================
  // SIGN UP METHODS
  // =====================================================
  
  /// Sign up with email and password
  static Future<AuthResponse?> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
        },
      );
      
      if (response.user != null) {
        print('✅ Usuario registrado exitosamente: ${response.user!.email}');
        print('🔍 Session after signup: ${response.session != null ? "Valid" : "Invalid"}');
        
        // If user is automatically logged in after signup
        if (response.session != null) {
          print('✅ Usuario automáticamente logueado después del registro');
          await Future.delayed(const Duration(milliseconds: 100));
          print('🔍 Current user after signup: ${_supabase.auth.currentUser?.email}');
        }
      }
      
      return response;
    } catch (e) {
      print('❌ Error en registro: $e');
      rethrow;
    }
  }
  
  /// Sign up with Google (requires additional setup)
  static Future<bool> signUpWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutterquickstart://login-callback/',
      );
      
      return true;
    } catch (e) {
      print('❌ Error en registro con Google: $e');
      return false;
    }
  }
  
  // =====================================================
  // SIGN IN METHODS
  // =====================================================
  
  /// Sign in with email and password
  static Future<AuthResponse?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        print('✅ Usuario autenticado: ${response.user!.email}');
        print('🔍 Session token: ${response.session?.accessToken != null ? "Valid" : "Invalid"}');
        print('🔍 Current user after login: ${_supabase.auth.currentUser?.email}');
        
        // Force a small delay to ensure session is properly set
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Verify session is still valid
        final currentUser = _supabase.auth.currentUser;
        if (currentUser != null) {
          print('✅ Session confirmed: User ${currentUser.email} is logged in');
        } else {
          print('❌ Session lost after login');
        }
      }
      
      return response;
    } catch (e) {
      print('❌ Error en login: $e');
      rethrow;
    }
  }
  
  /// Sign in with Google
  static Future<bool> signInWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutterquickstart://login-callback/',
      );
      
      return true;
    } catch (e) {
      print('❌ Error en login con Google: $e');
      return false;
    }
  }
  
  // =====================================================
  // PASSWORD RESET
  // =====================================================
  
  /// Send password reset email (also confirms unconfirmed users)
  static Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.flutterquickstart://reset-password/',
      );
      print('✅ Email de recuperación enviado a: $email');
    } catch (e) {
      print('❌ Error enviando email de recuperación: $e');
      rethrow;
    }
  }
  
  /// Alternative method to confirm user account via password reset
  static Future<void> confirmUserViaPasswordReset(String email) async {
    try {
      // This method will send a confirmation email that also acts as password reset
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.flutterquickstart://reset-password/',
      );
      print('✅ Email de confirmación enviado a: $email');
    } catch (e) {
      print('❌ Error enviando email de confirmación: $e');
      rethrow;
    }
  }
  
  // =====================================================
  // USER MANAGEMENT
  // =====================================================
  
  /// Update user profile
  static Future<UserResponse?> updateProfile({
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      
      final response = await _supabase.auth.updateUser(
        UserAttributes(data: updates),
      );
      
      if (response.user != null) {
        print('✅ Perfil actualizado');
      }
      
      return response;
    } catch (e) {
      print('❌ Error actualizando perfil: $e');
      rethrow;
    }
  }
  
  /// Update user password
  static Future<UserResponse?> updatePassword(String newPassword) async {
    try {
      final response = await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      
      print('✅ Contraseña actualizada');
      return response;
    } catch (e) {
      print('❌ Error actualizando contraseña: $e');
      rethrow;
    }
  }
  
  /// Get user profile from database
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      if (currentUser == null) return null;
      
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', currentUser!.id)
          .single();
      
      return response;
    } catch (e) {
      print('❌ Error obteniendo perfil: $e');
      return null;
    }
  }
  
  /// Update user profile in database
  static Future<bool> updateUserProfile({
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      if (currentUser == null) return false;
      
      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      
      await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', currentUser!.id);
      
      print('✅ Perfil actualizado en base de datos');
      return true;
    } catch (e) {
      print('❌ Error actualizando perfil en BD: $e');
      return false;
    }
  }
  
  // =====================================================
  // SIGN OUT
  // =====================================================
  
  /// Sign out current user
  static Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      print('✅ Usuario deslogueado');
    } catch (e) {
      print('❌ Error en logout: $e');
      rethrow;
    }
  }
  
  // =====================================================
  // UTILITY METHODS
  // =====================================================
  
  /// Get error message from AuthException
  static String getErrorMessage(AuthException e) {
    switch (e.message) {
      case 'Invalid login credentials':
        return 'Credenciales inválidas. Verifica tu email y contraseña.';
      case 'Email not confirmed':
        return 'Tu cuenta necesita ser activada. Por favor contacta al administrador o usa la opción de recuperación de contraseña.';
      case 'User already registered':
        return 'Este email ya está registrado. Intenta iniciar sesión.';
      case 'Password should be at least 6 characters':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'Unable to validate email address: invalid format':
        return 'Formato de email inválido.';
      default:
        return e.message;
    }
  }
  
  /// Validate email format
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
  
  /// Validate password strength
  static bool isValidPassword(String password) {
    return password.length >= 6;
  }
  
  /// Show error snackbar
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
  
  /// Show success snackbar
  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  /// Show loading dialog
  static void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
  
  /// Hide loading dialog
  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }
}
