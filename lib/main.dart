import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/telemetria_provider.dart';
import 'screens/main_screen.dart';
import 'theme/paleta_estados.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AqualertaApp());
}

/// Aplicación móvil de detección temprana de fugas de agua con IoT.
class AqualertaApp extends StatelessWidget {
  const AqualertaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final esquema = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0E7FB8), // Azul agua institucional #0E7FB8
      brightness: Brightness.light,
    );

    return ChangeNotifierProvider(
      create: (_) => TelemetriaProvider(),
      child: MaterialApp(
        title: 'Aqualerta',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: esquema,
          scaffoldBackgroundColor: const Color(0xFFF7F9FA),
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
            backgroundColor: Color(0xFFFFFFFF),
            foregroundColor: PaletaEstados.textoPrincipal,
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
