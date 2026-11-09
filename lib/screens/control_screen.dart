import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/mqtt_topicos.dart';
import '../models/conexion_estado.dart';
import '../providers/telemetria_provider.dart';
import '../widgets/demo_banner.dart';

/// Pantalla de Control de comandos hacia el ESP32:
/// - Botones "Pausar circuito" y "Reanudar circuito" (≥ 48 dp).
/// - Publica en unt/iot/g2/riego/comando (QoS 1).
/// - Monitorea confirmación en unt/iot/g2/riego/equipo con timeout de 5 s ("sin confirmar").
/// - Bloqueo de doble toque durante 2 s y confirmación con diálogo antes de pausar.
/// - Textos fijos obligatorios y aviso de propuesta de firmware.
class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  bool _bloqueoDobleToque = false;
  Timer? _temporizadorBloqueo;

  @override
  void dispose() {
    _temporizadorBloqueo?.cancel();
    super.dispose();
  }

  void _activarBloqueoDobleToque() {
    setState(() {
      _bloqueoDobleToque = true;
    });
    _temporizadorBloqueo?.cancel();
    _temporizadorBloqueo = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _bloqueoDobleToque = false;
        });
      }
    });
  }

  Future<void> _solicitarPausar(BuildContext context, TelemetriaProvider provider) async {
    if (_bloqueoDobleToque || provider.modoDemoActivo) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar pausa del circuito'),
        content: const Text(
          'Pausar detiene la medición y la publicación del ESP32; no detiene el flujo de agua.\n\n¿Desea enviar la orden de PAUSAR?',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: const Color(0xFFF57F17),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pausar circuito'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      _activarBloqueoDobleToque();
      await provider.enviarOrden('PAUSAR');
    }
  }

  Future<void> _solicitarReanudar(TelemetriaProvider provider) async {
    if (_bloqueoDobleToque || provider.modoDemoActivo) return;
    _activarBloqueoDobleToque();
    await provider.enviarOrden('REANUDAR');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TelemetriaProvider>();
    final estaConectado = provider.estadoConexion == ConexionEstado.conectado;
    final esDemo = provider.modoDemoActivo;
    final botonesHabilitados = estaConectado && !esDemo && !_bloqueoDobleToque && !provider.esperandoConfirmacion;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Control de Circuito',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            Text(
              'Envío de órdenes al ESP32',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (esDemo) const DemoBanner(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Tarjeta de Estado Real del Equipo (unt/iot/g2/riego/equipo)
                  _buildTarjetaEstadoEquipo(theme, provider),

                  const SizedBox(height: 16),

                  // 2. Texto fijo obligatorio de seguridad hidráulica
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFB74D), width: 1.5),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Pausar detiene la medición y la publicación del ESP32; no detiene el flujo de agua.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFBF360C),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Botones de Control (Pausar y Reanudar, ≥ 48 dp)
                  Text(
                    'ÓRDENES DISPONIBLES (QoS 1)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      // Botón Pausar Circuito
                      Expanded(
                        child: SizedBox(
                          height: 54, // Cumple ≥ 48 dp
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF57F17),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              disabledForegroundColor: Colors.grey.shade600,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.pause_circle_outline_rounded),
                            label: const Text(
                              'Pausar circuito',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            onPressed: botonesHabilitados
                                ? () => _solicitarPausar(context, provider)
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Botón Reanudar Circuito
                      Expanded(
                        child: SizedBox(
                          height: 54, // Cumple ≥ 48 dp
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              disabledForegroundColor: Colors.grey.shade600,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.play_circle_outline_rounded),
                            label: const Text(
                              'Reanudar circuito',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            onPressed: botonesHabilitados
                                ? () => _solicitarReanudar(provider)
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  if (esDemo)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        'Los botones de control están deshabilitados en Modo DEMO.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE65100),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else if (!estaConectado)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        'Conéctese al broker para habilitar el envío de comandos.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF757575),
                        ),
                      ),
                    )
                  else if (_bloqueoDobleToque)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        'Protección activa contra doble toque (esperando 2 s)...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1976D2),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // 4. Aviso obligatorio sobre propuesta de firmware
                  _buildAvisoPropuestaFirmware(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaEstadoEquipo(ThemeData theme, TelemetriaProvider provider) {
    Color colorEstado;
    IconData iconoEstado;
    String textoEstado;
    String detalleEstado;

    if (provider.confirmacionExpirada) {
      colorEstado = const Color(0xFFD32F2F);
      iconoEstado = Icons.warning_rounded;
      textoEstado = 'sin confirmar';
      detalleEstado = 'El ESP32 no confirmó la orden en 5 segundos.';
    } else if (provider.esperandoConfirmacion) {
      colorEstado = const Color(0xFFF57F17);
      iconoEstado = Icons.sync_rounded;
      textoEstado = 'Confirmando (${provider.ordenPendiente})...';
      detalleEstado = 'Orden enviada; esperando respuesta en ${MqttTopicos.equipo} (máx 5 s).';
    } else if (provider.equipoActivo == true) {
      colorEstado = const Color(0xFF2E7D32);
      iconoEstado = Icons.check_circle_rounded;
      textoEstado = 'Activo (Midiendo)';
      detalleEstado = 'El equipo está midiendo caudal y publicando telemetría.';
    } else if (provider.equipoActivo == false) {
      colorEstado = const Color(0xFFF57F17);
      iconoEstado = Icons.pause_circle_filled_rounded;
      textoEstado = 'Pausado';
      detalleEstado = 'Medición y publicación en reposo.';
    } else {
      colorEstado = const Color(0xFF757575);
      iconoEstado = Icons.help_outline_rounded;
      textoEstado = 'sin datos';
      detalleEstado = 'Sin mensaje retenido en ${MqttTopicos.equipo}.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorEstado.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorEstado.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorEstado.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(iconoEstado, color: colorEstado, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ESTADO REAL DEL EQUIPO (RETAINED)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Color(0xFF616161),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  textoEstado,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: colorEstado,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detalleEstado,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF424242),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvisoPropuestaFirmware(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.developer_mode_rounded, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'PROPUESTA DE ARQUITECTURA IOT',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            MqttTopicos.avisoPropuestaControl,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF424242),
            ),
          ),
        ],
      ),
    );
  }
}
