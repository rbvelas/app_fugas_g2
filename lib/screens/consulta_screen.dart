import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/cambio_estado_evento.dart';
import '../models/conexion_estado.dart';
import '../models/estado_lectura.dart';
import '../providers/telemetria_provider.dart';
import '../theme/paleta_estados.dart';
import '../utils/formato_numeros.dart';
import '../utils/formato_tiempo.dart';
import '../widgets/barra_superior_aqualerta.dart';
import '../widgets/demo_banner.dart';

enum _FiltroHistorial { todos, fugas, desviaciones }

/// Pantalla de Consulta.
///
/// Prioriza el historial de cambios de estado. El diagnóstico (mensajes
/// descartados y mensaje recibido) queda en una sección secundaria plegable.
class ConsultaScreen extends StatefulWidget {
  final VoidCallback onIrAConexion;

  const ConsultaScreen({super.key, required this.onIrAConexion});

  @override
  State<ConsultaScreen> createState() => _ConsultaScreenState();
}

class _ConsultaScreenState extends State<ConsultaScreen> {
  _FiltroHistorial _filtro = _FiltroHistorial.todos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TelemetriaProvider>();
    final historial = provider.historialCambiosEstado;
    final conectado = provider.estadoConexion == ConexionEstado.conectado;
    final filtrado = _aplicarFiltro(historial);

    return Scaffold(
      appBar: BarraSuperiorAqualerta(
        titulo: 'Consulta',
        onIrAConexion: widget.onIrAConexion,
        acciones: [
          if (historial.isNotEmpty)
            IconButton(
              tooltip: 'Limpiar historial',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _confirmarLimpiar(provider),
            ),
        ],
      ),
      body: Column(
        children: [
          if (provider.modoDemoActivo) const DemoBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'Historial de cambios',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Hora de Lima (UTC-5)',
                          style: TextStyle(
                            fontSize: 11,
                            color: PaletaEstados.textoSecundario,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Primero aparece lo más reciente.',
                    style: TextStyle(
                      color: PaletaEstados.textoSecundario,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _chipFiltro(
                        'Todos',
                        _FiltroHistorial.todos,
                        theme,
                      ),
                      _chipFiltro(
                        'Fugas',
                        _FiltroHistorial.fugas,
                        theme,
                      ),
                      _chipFiltro(
                        'Desviaciones',
                        _FiltroHistorial.desviaciones,
                        theme,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (historial.isEmpty)
                    _EstadoVacioHistorial(
                      titulo: 'Aún no hay cambios de estado',
                      detalle: conectado
                          ? 'Cuando el equipo cambie de estado, lo verás aquí.'
                          : 'Conéctate al servidor para empezar a recibir datos.',
                      icono: Icons.history_toggle_off_rounded,
                      accion: conectado
                          ? null
                          : _BotonIrAConexion(
                              onIrAConexion: widget.onIrAConexion,
                            ),
                    )
                  else if (filtrado.isEmpty)
                    _EstadoVacioHistorial(
                      titulo: 'No hay cambios de este tipo',
                      detalle: 'Prueba con otro filtro para ver todo el historial.',
                      icono: Icons.filter_alt_off_rounded,
                      accion: TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: () {
                          setState(() {
                            _filtro = _FiltroHistorial.todos;
                          });
                        },
                        child: const Text('Ver todos'),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtrado.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final evento = filtrado[index];
                        final indice = historial.indexOf(evento);
                        final duracion = indice > 0
                            ? evento.timestamp
                                .difference(historial[indice - 1].timestamp)
                            : null;
                        return _EventoCard(
                          evento: evento,
                          duracionEstadoAnterior: duracion,
                        );
                      },
                    ),
                  const SizedBox(height: 20),
                  _SeccionDiagnostico(
                    descartados: provider.mensajesDescartados,
                    ultimoMensaje: provider.ultimoMensajeBruto,
                  ),
                  const SizedBox(height: 12),
                  const _SeccionAcercaDe(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipFiltro(
    String etiqueta,
    _FiltroHistorial valor,
    ThemeData theme,
  ) {
    return ChoiceChip(
      label: Text(etiqueta),
      selected: _filtro == valor,
      showCheckmark: true,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      selectedColor: theme.colorScheme.secondaryContainer,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: _filtro == valor
            ? theme.colorScheme.onSecondaryContainer
            : PaletaEstados.textoSecundario,
      ),
      onSelected: (_) {
        setState(() {
          _filtro = valor;
        });
      },
    );
  }

  List<CambioEstadoEvento> _aplicarFiltro(List<CambioEstadoEvento> historial) {
    final inverso = historial.reversed.toList();
    switch (_filtro) {
      case _FiltroHistorial.todos:
        return inverso;
      case _FiltroHistorial.fugas:
        return inverso
            .where((e) => e.estadoNuevo == EstadoLectura.fuga)
            .toList();
      case _FiltroHistorial.desviaciones:
        return inverso
            .where((e) => e.estadoNuevo == EstadoLectura.desviacion)
            .toList();
    }
  }

  void _confirmarLimpiar(TelemetriaProvider provider) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpiar historial'),
        content: const Text(
          '¿Vaciar el historial de cambios de esta sesión?',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () {
              provider.limpiarHistorialCambios();
              Navigator.pop(ctx);
            },
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
  }
}

class _EventoCard extends StatelessWidget {
  final CambioEstadoEvento evento;
  final Duration? duracionEstadoAnterior;

  const _EventoCard({
    required this.evento,
    required this.duracionEstadoAnterior,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duracion = duracionEstadoAnterior == null
        ? '—'
        : formatearDuracion(duracionEstadoAnterior!);
    final valores =
        'Entrada ${numeroConComa(evento.caudalEntrada)} L/min · '
        'Salida ${numeroConComa(evento.caudalSalida)} L/min · '
        'Diferencia ${porcentajeConComa(evento.diferenciaPorcentaje)}';

    return Semantics(
      container: true,
      label: 'A las ${evento.horaCortaLima}, cambió de '
          '${evento.estadoAnterior.etiqueta} a ${evento.estadoNuevo.etiqueta}. '
          'El estado anterior duró $duracion. $valores.',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: evento.estadoNuevo.color.withAlpha(89),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  evento.horaCortaLima,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: PaletaEstados.textoSecundario,
                  ),
                ),
                _ChipDuracion(texto: 'Duró $duracion'),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _BadgeEstado(estado: evento.estadoAnterior),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: PaletaEstados.textoSecundario,
                ),
                _BadgeEstado(estado: evento.estadoNuevo),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              valores,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: PaletaEstados.textoSecundario,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipDuracion extends StatelessWidget {
  final String texto;

  const _ChipDuracion({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: PaletaEstados.pausaFondo,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.timer_outlined,
            size: 13,
            color: PaletaEstados.textoSecundario,
          ),
          const SizedBox(width: 4),
          Text(
            texto,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: PaletaEstados.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeEstado extends StatelessWidget {
  final EstadoLectura estado;

  const _BadgeEstado({required this.estado});

  @override
  Widget build(BuildContext context) {
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
          Icon(estado.icono, size: 14, color: estado.color),
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
}

class _EstadoVacioHistorial extends StatelessWidget {
  final String titulo;
  final String detalle;
  final IconData icono;
  final Widget? accion;

  const _EstadoVacioHistorial({
    required this.titulo,
    required this.detalle,
    required this.icono,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icono, size: 40, color: theme.colorScheme.outline),
          const SizedBox(height: 10),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detalle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: PaletaEstados.textoSecundario,
              height: 1.35,
            ),
          ),
          if (accion != null) ...[
            const SizedBox(height: 12),
            accion!,
          ],
        ],
      ),
    );
  }
}

class _BotonIrAConexion extends StatelessWidget {
  final VoidCallback onIrAConexion;

  const _BotonIrAConexion({required this.onIrAConexion});

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      onPressed: onIrAConexion,
      icon: const Icon(Icons.settings_input_antenna_rounded),
      label: const Text('Ir a Conexión'),
    );
  }
}

class _SeccionDiagnostico extends StatelessWidget {
  final int descartados;
  final String? ultimoMensaje;

  const _SeccionDiagnostico({
    required this.descartados,
    required this.ultimoMensaje,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.monitor_heart_outlined,
                  size: 20,
                  color: PaletaEstados.textoSecundario,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Diagnóstico',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    descartados == 0
                        ? 'Ningún mensaje descartado'
                        : '$descartados descartados',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      color: PaletaEstados.textoSecundario,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            leading: const Icon(
              Icons.code_rounded,
              color: PaletaEstados.textoSecundario,
            ),
            title: const Text(
              'Ver último mensaje',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            children: [
              if (ultimoMensaje == null)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Aún no se recibió ningún mensaje.',
                      style: TextStyle(color: PaletaEstados.textoSecundario),
                    ),
                  ),
                )
              else
                _PanelMensajeBruto(mensaje: ultimoMensaje!),
            ],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Los mensajes con valores fuera de rango se descartan automáticamente.',
                style: TextStyle(
                  fontSize: 12,
                  color: PaletaEstados.textoSecundario,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelMensajeBruto extends StatelessWidget {
  final String mensaje;

  const _PanelMensajeBruto({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Último mensaje recibido',
                  style: TextStyle(
                    color: Color(0xFFB0BEC5),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copiar mensaje',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(
                  Icons.copy_rounded,
                  size: 18,
                  color: Colors.white70,
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: mensaje));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mensaje copiado'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
          SelectableText(
            mensaje,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Color(0xFFB9F6CA),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeccionAcercaDe extends StatelessWidget {
  const _SeccionAcercaDe();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: const ExpansionTile(
        shape: Border(),
        collapsedShape: Border(),
        leading: Icon(
          Icons.info_outline_rounded,
          color: PaletaEstados.textoSecundario,
        ),
        title: Text(
          'Acerca de',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Este historial se guarda mientras la app está abierta. '
              'Si la cierras, se borra.',
              style: TextStyle(
                color: PaletaEstados.textoSecundario,
                height: 1.4,
              ),
            ),
          ),
          SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Se guardan como máximo 200 cambios. La hora se muestra en '
              'zona de Lima (UTC-5).',
              style: TextStyle(
                color: PaletaEstados.textoSecundario,
                height: 1.4,
              ),
            ),
          ),
          SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'No se consulta una base de datos histórica externa. '
              '[POR COMPLETAR]',
              style: TextStyle(
                color: PaletaEstados.textoSecundario,
                height: 1.4,
              ),
            ),
          ),
          SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Por seguridad se descartan los mensajes con caudales negativos, '
              'diferencias fuera de ±100 %, estados desconocidos o señal WiFi '
              'fuera del rango válido.',
              style: TextStyle(
                color: PaletaEstados.textoSecundario,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
