import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/auth/auth_wrapper.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");
    print('✅ Archivo .env cargado correctamente');
  } catch (e) {
    print('⚠️ Warning: No se pudo cargar el archivo .env: $e');
    print('Usando API key por defecto');
  }
  
  // Inicializar Supabase
  try {
    await SupabaseService.initialize();
  } catch (e) {
    print('❌ Error inicializando Supabase: $e');
    // Continuar sin Supabase si hay error
  }
  
  runApp(const RiverApp());
}

class RiverApp extends StatelessWidget {
  const RiverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'River - Notion-like Editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Poppins',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
          displayMedium: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
          displaySmall: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
          headlineLarge: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
          headlineMedium: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
          headlineSmall: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
          titleLarge: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
          titleMedium: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
          titleSmall: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400),
          bodySmall: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400),
          labelLarge: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
          labelMedium: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
          labelSmall: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}