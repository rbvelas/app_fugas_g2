import 'package:flutter/material.dart';
import '../models/estado_lectura.dart';

/// Semáforo visual del estado de fuga según el cálculo del firmware:
/// - NORMAL: Verde (check)
/// - DESVIACIÓN: Amarillo (advertencia)
/// - FUGA: Rojo (error crítico)
/// - SIN FLUJO: Azul (gota/ondas)
/// - SIN DATOS: Gris (sin telemetría reciente > 4 s)
class SemaforoWidget extends StatelessWidget {
  final EstadoLectura? estado;
  final bool hayDatosRecientes;

  const SemaforoWidget({
    super.key,
    required this.estado,
    required this.hayDatosRecientes,
  });

  @override
  Widget build(BuildContext context) {
    final bool activo = hayDatosRecientes && estado != null;
    final Color colorPrincipal = activo ? estado!.color : const Color(0xFF616161);
    final Color colorFondo = activo ? estado!.colorFondo : const Color(0xFFF5F5F5);
    final Color colorBorde = activo ? estado!.colorBorde : const Color(0xFFE0E0E0);
    final IconData icono = activo ? estado!.icono : Icons.sensors_off_rounded;
    final String titulo = activo ? estado!.etiqueta : 'SIN DATOS';
    final String descripcion = activo
        ? estado!.descripcion
        : 'Sin recepción de telemetría activa (> 4 s sin mensajes).';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorBorde, width: 2),
        boxShadow: [
          BoxShadow(
            color: colorPrincipal.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Indicador luminoso circular con icono
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorPrincipal,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorPrincipal.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  icono,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ESTADO DEL SISTEMA (FIRMWARE)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Color(0xFF757575),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: colorPrincipal,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Mini indicadores de estados posibles (estilo semáforo industrial)
              _buildMiniSemaforo(estado, activo),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            descripcion,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF424242),
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSemaforo(EstadoLectura? estadoActual, bool activo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _miniDot(
            const Color(0xFF2E7D32),
            activo && estadoActual == EstadoLectura.normal,
            'NORMAL',
          ),
          const SizedBox(width: 6),
          _miniDot(
            const Color(0xFFF57F17),
            activo && estadoActual == EstadoLectura.desviacion,
            'DESV',
          ),
          const SizedBox(width: 6),
          _miniDot(
            const Color(0xFFD32F2F),
            activo && estadoActual == EstadoLectura.fuga,
            'FUGA',
          ),
          const SizedBox(width: 6),
          _miniDot(
            const Color(0xFF1976D2),
            activo && estadoActual == EstadoLectura.sinFlujo,
            'S/FLUJO',
          ),
        ],
      ),
    );
  }

  Widget _miniDot(Color color, bool estaEncendido, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: estaEncendido ? color : color.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(
            color: estaEncendido ? Colors.white : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: estaEncendido
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.6),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

