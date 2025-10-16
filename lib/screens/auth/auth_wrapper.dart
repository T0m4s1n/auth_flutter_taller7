import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';
import '../notion_home.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
    _listenToAuthChanges();
  }

  void _checkAuthState() {
    final user = AuthService.currentUser;
    print('🔍 Initial auth check - User: ${user?.email}');
    setState(() {
      _currentUser = user;
      _isLoading = false;
    });
  }

  void _listenToAuthChanges() {
    AuthService.authStateChanges.listen((AuthState authState) {
      print('🔍 Auth state changed - Event: ${authState.event}');
      print('🔍 Auth state changed - Session: ${authState.session != null}');
      print('🔍 Auth state changed - User: ${authState.session?.user.email}');
      
      setState(() {
        _currentUser = authState.session?.user;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
              SizedBox(height: 16),
              Text(
                'Cargando...',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    print('🔍 AuthWrapper - Current user: ${_currentUser?.email}');
    print('🔍 AuthWrapper - Is authenticated: ${_currentUser != null}');

    if (_currentUser != null) {
      print('✅ AuthWrapper - Navigating to main app');
      return const NotionHomeScreen();
    } else {
      print('❌ AuthWrapper - Showing login screen');
      return const LoginScreen();
    }
  }
}
