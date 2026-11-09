import 'package:flutter/material.dart';
import 'conexion_screen.dart';
import 'consulta_screen.dart';
import 'control_screen.dart';
import 'monitoreo_screen.dart';

/// Pantalla principal con la barra de navegación inferior de 4 secciones:
/// Monitoreo, Consulta, Control y Conexión.
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
    void irAConexion() => _navegarAIndice(3);

    return Scaffold(
      body: IndexedStack(
        index: _indiceSeleccionado,
        children: [
          MonitoreoScreen(onIrAConexion: irAConexion),
          ConsultaScreen(onIrAConexion: irAConexion),
          ControlScreen(onIrAConexion: irAConexion),
          ConexionScreen(
            onIrAConexion: irAConexion,
            visible: _indiceSeleccionado == 3,
          ),
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
            tooltip: 'Estado y caudales en tiempo real',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_search_outlined),
            selectedIcon: Icon(Icons.manage_search_rounded),
            label: 'Consulta',
            tooltip: 'Historial de cambios de estado',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune_rounded),
            label: 'Control',
            tooltip: 'Pausar o reanudar la medición',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_input_antenna_outlined),
            selectedIcon: Icon(Icons.settings_input_antenna_rounded),
            label: 'Conexión',
            tooltip: 'Configurar la conexión',
          ),
        ],
      ),
    );
  }
}
