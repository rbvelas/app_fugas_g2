import 'package:flutter/material.dart';
import 'conexion_screen.dart';
import 'consulta_screen.dart';
import 'control_screen.dart';
import 'monitoreo_screen.dart';

/// Pantalla principal que alberga la barra de navegación inferior con las 4 secciones:
/// 1. Monitoreo: telemetría en tiempo real y gráfico de 120 s.
/// 2. Consulta: historial de cambios de estado y último payload en bruto.
/// 3. Control: envío de comandos PAUSAR / REANUDAR al ESP32.
/// 4. Conexión: configuración de red MQTT EMQX y modo DEMO.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _indiceSeleccionado = 0;

  void _navegarAIndice(int indice) {
    setState(() {
      _indiceSeleccionado = indice;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indiceSeleccionado,
        children: [
          MonitoreoScreen(
            onIrAConexion: () => _navegarAIndice(3), // Navega a la pestaña Conexión
          ),
          const ConsultaScreen(),
          const ControlScreen(),
          const ConexionScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceSeleccionado,
        onDestinationSelected: _navegarAIndice,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.speed_outlined),
            selectedIcon: Icon(Icons.speed_rounded),
            label: 'Monitoreo',
            tooltip: 'Telemetría en tiempo real',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_search_outlined),
            selectedIcon: Icon(Icons.manage_search_rounded),
            label: 'Consulta',
            tooltip: 'Historial de cambios y datos brutos',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune_rounded),
            label: 'Control',
            tooltip: 'Pausa y reanudación del circuito',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_input_antenna_outlined),
            selectedIcon: Icon(Icons.settings_input_antenna_rounded),
            label: 'Conexión',
            tooltip: 'Configuración de broker y demo',
          ),
        ],
      ),
    );
  }
}
