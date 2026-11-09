import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/telemetria_provider.dart';
import 'screens/main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FugasApp());
}

/// Aplicación móvil de detección temprana de fugas de agua con IoT.
/// Universidad Nacional de Trujillo - Ingeniería de Sistemas - Grupo G2.
class FugasApp extends StatelessWidget {
  const FugasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TelemetriaProvider(),
      child: MaterialApp(
        title: 'Detección de Fugas G2',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0288D1), // Azul agua IoT
            brightness: Brightness.light,
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
          ),
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'PE'),
          Locale('es', ''),
        ],
        home: const MainScreen(),
      ),
    );
  }
}

