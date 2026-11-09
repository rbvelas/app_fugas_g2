import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/cambio_estado_evento.dart';
import '../providers/telemetria_provider.dart';
import '../widgets/demo_banner.dart';

/// Pantalla de Consulta de la sesión activa:
/// - Historial en memoria de cambios de estado (máximo 200 entradas).
/// - Contador de mensajes inválidos descartados por seguridad.
/// - Último mensaje JSON recibido en bruto.
/// - Botón para limpiar historial.
/// - Nota sobre almacenamiento volátil y consulta MySQL [POR COMPLETAR].
class ConsultaScreen extends StatelessWidget {
  const ConsultaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TelemetriaProvider>();
    final historial = provider.historialCambiosEstado;
    final ultimoBruto = provider.ultimoMensajeBruto;
    final descartados = provider.mensajesDescartados;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Consulta y Diagnóstico',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            Text(
              'Historial volátil y auditoría de mensajes',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          if (historial.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48), // Requisito botones ≥ 48 dp
                  foregroundColor: const Color(0xFFD32F2F),
                ),
                icon: const Icon(Icons.delete_sweep_rounded),
                label: const Text('Limpiar'),
                onPressed: () {
                  _mostrarDialogoLimpiar(context, provider);
                },
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (provider.modoDemoActivo) const DemoBanner(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Tarjeta de mensajes descartados por validación de seguridad
                  _buildTarjetaDescartados(theme, descartados),

                  const SizedBox(height: 16),

                  // 2. Tarjeta con el último mensaje recibido en bruto
                  _buildUltimoMensajeBrutoCard(context, theme, ultimoBruto),

                  const SizedBox(height: 20),

                  // 3. Historial de cambios de estado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CAMBIOS DE ESTADO (${historial.length}/200)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (historial.isNotEmpty)
                        Text(
                          'Más recientes primero',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (historial.isEmpty)
                    _buildHistorialVacio(theme)
                  else
                    _buildListaHistorial(historial),

                  const SizedBox(height: 24),

                  // 4. Aclaración obligatoria sobre memoria volátil y MySQL [POR COMPLETAR]
                  _buildAclaracionMemoriaYMysql(theme),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaDescartados(ThemeData theme, int descartados) {
    final tieneDescartes = descartados > 0;
    final colorBorde = tieneDescartes ? const Color(0xFFE65100) : const Color(0xFF2E7D32);
    final colorFondo = tieneDescartes ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9);
    final colorTexto = tieneDescartes ? const Color(0xFFBF360C) : const Color(0xFF1B5E20);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorBorde.withOpacity(0.5), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorBorde.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              tieneDescartes ? Icons.security_update_warning_rounded : Icons.verified_user_rounded,
              color: colorBorde,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VALIDACIÓN DE SEGURIDAD Y TIPOS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Color(0xFF616161),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Mensajes descartados: $descartados',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: colorTexto,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Filtra caudales negativos, variaciones fuera de ±100 %, estados ajenos o RSSI fuera de [-120, 0].',
                  style: TextStyle(
                    fontSize: 11,
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

  Widget _buildUltimoMensajeBrutoCard(
    BuildContext context,
    ThemeData theme,
    String? ultimoBruto,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF212121),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.terminal_rounded, size: 18, color: Color(0xFF64B5F6)),
                  SizedBox(width: 8),
                  Text(
                    'ÚLTIMO MENSAJE EN BRUTO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Color(0xFFB0BEC5),
                    ),
                  ),
                ],
              ),
              if (ultimoBruto != null)
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.white70),
                  tooltip: 'Copiar payload',
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: ultimoBruto));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Payload copiado al portapapeles'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              ultimoBruto ?? 'sin datos (ningún mensaje recibido aún)',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: ultimoBruto != null ? const Color(0xFF81C784) : const Color(0xFF757575),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorialVacio(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 40,
            color: theme.colorScheme.outline.withOpacity(0.6),
          ),
          const SizedBox(height: 10),
          Text(
            'Sin cambios de estado registrados',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Solo se añaden entradas cuando el firmware transiciona entre estados '
            '(NORMAL, DESVIACION, FUGA, SIN_FLUJO).',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaHistorial(List<CambioEstadoEvento> historial) {
    final itemsInversos = historial.reversed.toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemsInversos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final evento = itemsInversos[index];
        return _buildEventoCard(context, evento);
      },
    );
  }

  Widget _buildEventoCard(BuildContext context, CambioEstadoEvento evento) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: evento.estadoNuevo.color.withOpacity(0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                evento.horaLimaFormateada,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF616161),
                ),
              ),
              Text(
                'Δ ${evento.diferenciaPorcentaje.toStringAsFixed(1)} %',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: evento.estadoNuevo.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildBadgeEstado(evento.estadoAnterior),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF757575)),
              ),
              _buildBadgeEstado(evento.estadoNuevo),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Qe: ${evento.caudalEntrada.toStringAsFixed(2)} L/min  •  '
            'Qs: ${evento.caudalSalida.toStringAsFixed(2)} L/min',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF424242),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeEstado(dynamic estado) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: estado.colorFondo,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: estado.colorBorde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(estado.icono, size: 13, color: estado.color),
          const SizedBox(width: 4),
          Text(
            estado.etiqueta,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: estado.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAclaracionMemoriaYMysql(ThemeData theme) {
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
              Icon(Icons.info_outline_rounded, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'ALCANCE Y PERSISTENCIA DE DATOS',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '• Este historial se almacena exclusivamente en la memoria RAM de la sesión activa y se pierde por completo al cerrar la aplicación.\n'
            '• No consulta la base de datos MySQL histórica [POR COMPLETAR], dado que dicha funcionalidad requiere una API REST backend que actualmente no existe en la infraestructura del proyecto.',
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

  void _mostrarDialogoLimpiar(BuildContext context, TelemetriaProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpiar historial'),
        content: const Text(
          '¿Desea vaciar el historial de cambios de estado registrado durante esta sesión?',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              provider.limpiarHistorialCambios();
              Navigator.pop(ctx);
            },
            child: const Text('Vaciar historial'),
          ),
        ],
      ),
    );
  }
}
