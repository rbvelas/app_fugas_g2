import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conexion_estado.dart';
import '../models/lectura.dart';
import '../providers/telemetria_provider.dart';
import '../widgets/alerta_fuga_banner.dart';
import '../widgets/demo_banner.dart';
import '../widgets/grafico_caudal.dart';
import '../widgets/metrica_card.dart';
import '../widgets/semaforo_widget.dart';

/// Pantalla principal de monitoreo en tiempo real.
/// Muestra semáforo de estado, banner de alerta, métricas de caudales,
/// volúmenes, RSSI, hora en Lima (UTC-5) y gráfico de 120 segundos.
class MonitoreoScreen extends StatelessWidget {
  final VoidCallback onIrAConexion;

  const MonitoreoScreen({
    super.key,
    required this.onIrAConexion,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TelemetriaProvider>();
    final hayDatos = provider.hayDatosRecientes && provider.ultimaLectura != null;
    final l = provider.ultimaLectura;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aqualerta',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            Text(
              'UNT - Internet de las Cosas',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          // Chip de estado de conexión al broker
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ActionChip(
              avatar: Icon(
                provider.modoDemoActivo
                    ? Icons.science_rounded
                    : provider.estadoConexion.icono,
                size: 16,
                color: provider.modoDemoActivo
                    ? const Color(0xFFE65100)
                    : provider.estadoConexion.color,
              ),
              label: Text(
                provider.modoDemoActivo ? 'DEMO' : provider.estadoConexion.etiqueta,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: provider.modoDemoActivo
                      ? const Color(0xFFE65100)
                      : provider.estadoConexion.color,
                ),
              ),
              onPressed: onIrAConexion,
              tooltip: 'Configuración de conexión MQTT',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Letrero permanente de Modo DEMO si está activo
          if (provider.modoDemoActivo) const DemoBanner(),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                if (provider.estadoConexion == ConexionEstado.desconectado &&
                    provider.host.isNotEmpty &&
                    !provider.modoDemoActivo) {
                  await provider.conectar(
                    host: provider.host,
                    puerto: provider.puerto,
                    usuario: provider.usuario,
                  );
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner rojo crítico al pasar a FUGA
                    if (provider.alertaFugaActiva)
                      AlertaFugaBanner(
                        onCerrar: provider.cerrarBannerFuga,
                      ),

                    // Semáforo principal del estado del firmware
                    SemaforoWidget(
                      estado: hayDatos ? l?.estado : null,
                      hayDatosRecientes: hayDatos,
                    ),

                    const SizedBox(height: 16),

                    // Tarjeta de marca temporal en hora de Lima (UTC-5)
                    _buildHoraLimaCard(context, hayDatos, l),

                    const SizedBox(height: 16),

                    // Grilla de métricas instantáneas del payload real
                    Text(
                      'MÉTRICAS DE CAUDAL Y VOLUMEN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 500;
                        final crossAxisCount = isWide ? 3 : 2;

                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: isWide ? 1.5 : 1.35,
                          children: [
                            MetricaCard(
                              titulo: 'Caudal Entrada (Qe)',
                              valor: hayDatos ? l!.caudalEntrada.toStringAsFixed(2) : 'sin datos',
                              unidad: 'L/min',
                              subtitulo: 'Sensor entrada YF-S201',
                              icono: Icons.login_rounded,
                              colorIcono: const Color(0xFF0288D1),
                            ),
                            MetricaCard(
                              titulo: 'Caudal Salida (Qs)',
                              valor: hayDatos ? l!.caudalSalida.toStringAsFixed(2) : 'sin datos',
                              unidad: 'L/min',
                              subtitulo: 'Sensor salida YF-S201',
                              icono: Icons.logout_rounded,
                              colorIcono: const Color(0xFFE65100),
                            ),
                            MetricaCard(
                              titulo: 'Diferencia (ΔQ)',
                              valor: hayDatos ? l!.diferenciaLMin.toStringAsFixed(2) : 'sin datos',
                              unidad: 'L/min',
                              subtitulo: hayDatos
                                  ? '${l!.diferenciaPorcentaje.toStringAsFixed(1)} % variación'
                                  : 'sin datos',
                              icono: Icons.compare_arrows_rounded,
                              colorIcono: const Color(0xFFD32F2F),
                              esDestacado: hayDatos && l!.diferenciaPorcentaje >= 15.0,
                            ),
                            MetricaCard(
                              titulo: 'Volumen Acumulado',
                              valor: hayDatos
                                  ? '${l!.volumenEntrada.toStringAsFixed(1)} / ${l!.volumenSalida.toStringAsFixed(1)}'
                                  : 'sin datos',
                              unidad: 'L',
                              subtitulo: 'Entrada (Ve) / Salida (Vs)',
                              icono: Icons.water_rounded,
                              colorIcono: const Color(0xFF1976D2),
                            ),
                            MetricaCard(
                              titulo: 'Señal RSSI',
                              valor: hayDatos && l!.rssi != null ? '${l!.rssi}' : 'sin datos',
                              unidad: 'dBm',
                              subtitulo: 'Conectividad WiFi ESP32',
                              icono: Icons.wifi_rounded,
                              colorIcono: const Color(0xFF388E3C),
                            ),
                            MetricaCard(
                              titulo: 'Dispositivo IoT',
                              valor: hayDatos ? l!.dispositivo : 'sin datos',
                              subtitulo: 'Tópico: riego/telemetria',
                              icono: Icons.developer_board_rounded,
                              colorIcono: const Color(0xFF5E35B1),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Gráfico continuo con fl_chart de los últimos 120 segundos
                    GraficoCaudal(
                      lecturas: provider.historialLecturas,
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoraLimaCard(BuildContext context, bool hayDatos, Lectura? l) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time_rounded,
            size: 20,
            color: hayDatos ? const Color(0xFF1976D2) : Colors.grey,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ÚLTIMA LECTURA (HORA DE LIMA, UTC-5)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Color(0xFF616161),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hayDatos && l != null
                      ? l.fechaHoraLimaFormateada
                      : 'sin datos (> 4 s sin mensajes recibidos)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: hayDatos ? const Color(0xFF212121) : const Color(0xFF9E9E9E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
