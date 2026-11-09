import 'package:flutter/material.dart';
import 'conexion_screen.dart';
import 'monitoreo_screen.dart';

/// Pantalla principal que alberga la barra de navegación inferior.
/// En este Paso 1 cuenta con las secciones: Monitoreo y Conexión.
/// Los Pasos 2 y 3 ampliarán las pestañas disponibles (historial, configuración de umbrales, etc.).
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
            onIrAConexion: () => _navegarAIndice(1),
          ),
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
            tooltip: 'Pantalla de monitoreo en tiempo real',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_input_antenna_outlined),
            selectedIcon: Icon(Icons.settings_input_antenna_rounded),
            label: 'Conexión',
            tooltip: 'Configuración del broker MQTT',
          ),
        ],
      ),
    );
  }
}

