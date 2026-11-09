import 'package:flutter/material.dart';
import '../models/estado_lectura.dart';
import '../theme/paleta_estados.dart';
import '../utils/formato_tiempo.dart';

/// Tarjeta principal de Monitoreo.
///
/// Prioriza tres situaciones:
/// 1. El equipo está en pausa: "Circuito en pausa" con acción "Reanudar".
/// 2. No hay datos recientes: explicación y acción para ir a Conexión.
/// 3. Hay una lectura: estado grande con color + icono + texto.
class SemaforoWidget extends StatelessWidget {
  final EstadoLectura? estado;
  final bool hayDatosRecientes;
  final bool enPausa;
  final bool esperandoConfirmacion;
  final bool confirmacionExpirada;
  final bool conectado;
  final bool esDemo;
  final DateTime? ultimaLecturaTimestamp;
  final VoidCallback? onReanudar;
  final VoidCallback? onIrAConexion;

  const SemaforoWidget({
    super.key,
    required this.estado,
    required this.hayDatosRecientes,
    required this.enPausa,
    required this.esperandoConfirmacion,
    required this.confirmacionExpirada,
    required this.conectado,
    required this.esDemo,
    this.ultimaLecturaTimestamp,
    this.onReanudar,
    this.onIrAConexion,
  });

  @override
  Widget build(BuildContext context) {
    if (enPausa) {
      return _buildPausa(context);
    }
    final activo = hayDatosRecientes && estado != null;
    if (!activo) {
      return _buildSinDatos(context);
    }
    return _buildEstado(context, estado!);
  }

  Widget _buildEstado(BuildContext context, EstadoLectura valor) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Estado: ${valor.etiqueta}. ${valor.descripcion}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: valor.colorFondo,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: valor.colorBorde, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estado',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: PaletaEstados.textoSecundario,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: valor.color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(valor.icono, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    valor.etiqueta,
                    style: TextStyle(
                      fontSize: 30,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      color: valor.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              valor.descripcion,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                color: PaletaEstados.textoSecundario,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPausa(BuildContext context) {
    final theme = Theme.of(context);
    final esperando = esperandoConfirmacion;
    final expirada = confirmacionExpirada && !esperando;
    final puedeReanudar = conectado && !esperando && onReanudar != null;

    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Circuito en pausa. El equipo no mide ni publica datos. '
          'El agua sigue fluyendo.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: PaletaEstados.pausaFondo,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: PaletaEstados.pausaBorde, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estado',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: PaletaEstados.textoSecundario,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: PaletaEstados.pausa,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pause_circle_filled_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Circuito en pausa',
                    style: TextStyle(
                      fontSize: 26,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      color: PaletaEstados.pausa,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'El equipo no está midiendo ni publicando datos. '
              'El agua sigue fluyendo.',
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: PaletaEstados.textoSecundario,
              ),
            ),
            if (esperando) ...[
              const SizedBox(height: 14),
              Semantics(
                liveRegion: true,
                label: 'Reanudando. Esperando confirmación del equipo.',
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Reanudando… esperando confirmación',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: PaletaEstados.pausa,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (expirada) ...[
              const SizedBox(height: 12),
              Text(
                'No se recibió confirmación. Revisa que el equipo esté encendido y conectado.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: PaletaEstados.desviacion,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: PaletaEstados.pausa,
                  side: const BorderSide(color: PaletaEstados.pausa),
                ),
                onPressed: puedeReanudar ? onReanudar : null,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ] else if (puedeReanudar) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 52),
                  backgroundColor: PaletaEstados.normal,
                  foregroundColor: Colors.white,
                ),
                onPressed: onReanudar,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Reanudar'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSinDatos(BuildContext context) {
    final theme = Theme.of(context);
    final String titulo;
    final String detalle;
    final Widget accion;

    if (esDemo) {
      titulo = 'Cargando datos de ejemplo…';
      detalle = 'La demostración empezará en un momento.';
      accion = const Padding(
        padding: EdgeInsets.only(top: 12),
        child: LinearProgressIndicator(minHeight: 6),
      );
    } else if (!conectado) {
      titulo = 'Sin datos';
      detalle = 'Conéctate al servidor para empezar a recibir lecturas.';
      accion = Padding(
        padding: const EdgeInsets.only(top: 12),
        child: FilledButton.tonalIcon(
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: onIrAConexion,
          icon: const Icon(Icons.settings_input_antenna_rounded),
          label: const Text('Ir a Conexión'),
        ),
      );
    } else {
      titulo = 'Esperando datos…';
      detalle = ultimaLecturaTimestamp == null
          ? 'El equipo aún no ha enviado lecturas. Revisa que esté encendido.'
          : 'La última lectura fue ${antiguedadRelativa(ultimaLecturaTimestamp!)}. '
              'Revisa que el equipo esté encendido y conectado.';
      accion = Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextButton.icon(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: onIrAConexion,
          icon: const Icon(Icons.settings_input_antenna_rounded),
          label: const Text('Ver conexión'),
        ),
      );
    }

    return Semantics(
      container: true,
      liveRegion: true,
      label: '$titulo. $detalle',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: PaletaEstados.pausaFondo,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: PaletaEstados.pausaBorde, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: PaletaEstados.pausa,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    esDemo ? Icons.science_rounded : Icons.sensors_off_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 24,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          color: PaletaEstados.pausa,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        detalle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: PaletaEstados.textoSecundario,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            accion,
          ],
        ),
      ),
    );
  }
}
