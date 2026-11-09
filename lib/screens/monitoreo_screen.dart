import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conexion_estado.dart';
import '../models/estado_lectura.dart';
import '../models/lectura.dart';
import '../providers/telemetria_provider.dart';
import '../theme/paleta_estados.dart';
import '../utils/formato_numeros.dart';
import '../utils/formato_tiempo.dart';
import '../utils/senal_wifi.dart';
import '../widgets/alerta_fuga_banner.dart';
import '../widgets/barra_superior_aqualerta.dart';
import '../widgets/demo_banner.dart';
import '../widgets/grafico_caudal.dart';
import '../widgets/metrica_card.dart';
import '../widgets/semaforo_widget.dart';

/// Pantalla de Monitoreo.
///
/// Jerarquía: estado principal → tres cifras clave → gráfico → detalles.
/// Cuando el equipo está en pausa se muestra "Circuito en pausa" y no
/// "sin datos" ni "sin flujo".
class MonitoreoScreen extends StatefulWidget {
  final VoidCallback onIrAConexion;

  const MonitoreoScreen({
    super.key,
    required this.onIrAConexion,
  });

  @override
  State<MonitoreoScreen> createState() => _MonitoreoScreenState();
}

class _MonitoreoScreenState extends State<MonitoreoScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Refresca "hace 2 s" aunque no lleguen lecturas nuevas.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TelemetriaProvider>();
    final conectado = provider.estadoConexion == ConexionEstado.conectado;
    final enPausa = provider.equipoActivo == false;
    final hayDatos = provider.hayDatosRecientes && provider.ultimaLectura != null;
    final lectura = provider.ultimaLectura;
    final mostrarValores = enPausa ? lectura != null : hayDatos;

    return Scaffold(
      appBar: BarraSuperiorAqualerta(
        titulo: 'Monitoreo',
        onIrAConexion: widget.onIrAConexion,
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
                  if (provider.alertaFugaActiva && !enPausa)
                    const AlertaFugaBanner(),
                  SemaforoWidget(
                    estado: lectura?.estado,
                    hayDatosRecientes: hayDatos,
                    enPausa: enPausa,
                    esperandoConfirmacion: provider.esperandoConfirmacion,
                    confirmacionExpirada: provider.confirmacionExpirada,
                    conectado: conectado,
                    esDemo: provider.modoDemoActivo,
                    ultimaLecturaTimestamp: lectura?.timestamp,
                    onReanudar: () => provider.enviarOrden('REANUDAR'),
                    onIrAConexion: widget.onIrAConexion,
                  ),
                  const SizedBox(height: 10),
                  _LineaAntiguedad(
                    enPausa: enPausa,
                    lectura: lectura,
                    hayDatos: hayDatos,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Caudales ahora',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: MetricaCard(
                            titulo: 'Caudal de entrada',
                            valor: _valor(mostrarValores, lectura?.caudalEntrada),
                            unidad: 'L/min',
                            subtitulo: enPausa
                                ? 'Última medición antes de la pausa'
                                : (hayDatos
                                    ? 'Agua que entra al tramo'
                                    : 'Esperando datos'),
                            icono: Icons.login_rounded,
                            colorIcono: PaletaEstados.sinFlujo,
                            semantica: _semanticaCaudal(
                              'Caudal de entrada',
                              mostrarValores,
                              lectura?.caudalEntrada,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MetricaCard(
                            titulo: 'Caudal de salida',
                            valor: _valor(mostrarValores, lectura?.caudalSalida),
                            unidad: 'L/min',
                            subtitulo: enPausa
                                ? 'Última medición antes de la pausa'
                                : (hayDatos
                                    ? 'Agua que sale del tramo'
                                    : 'Esperando datos'),
                            icono: Icons.logout_rounded,
                            colorIcono: const Color(0xFFC2410C),
                            semantica: _semanticaCaudal(
                              'Caudal de salida',
                              mostrarValores,
                              lectura?.caudalSalida,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _TarjetaDiferencia(
                    enPausa: enPausa,
                    hayDatos: mostrarValores,
                    lectura: lectura,
                  ),
                  const SizedBox(height: 20),
                  GraficoCaudal(lecturas: provider.historialLecturas),
                  const SizedBox(height: 12),
                  _DetallesLectura(
                    lectura: lectura,
                    hayDatos: mostrarValores,
                    enPausa: enPausa,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _valor(bool disponible, double? valor) {
    if (!disponible || valor == null) return '—';
    return numeroConComa(valor);
  }

  String _semanticaCaudal(String titulo, bool disponible, double? valor) {
    if (!disponible || valor == null) {
      return '$titulo: sin lectura disponible.';
    }
    return '$titulo: ${numeroConComa(valor)} litros por minuto.';
  }
}

class _LineaAntiguedad extends StatelessWidget {
  final bool enPausa;
  final Lectura? lectura;
  final bool hayDatos;

  const _LineaAntiguedad({
    required this.enPausa,
    required this.lectura,
    required this.hayDatos,
  });

  @override
  Widget build(BuildContext context) {
    final texto = lectura == null
        ? 'Aún no hay lecturas en esta sesión'
        : 'Última lectura ${antiguedadRelativa(lectura!.timestamp)}';
    final icono = enPausa
        ? Icons.pause_circle_outline_rounded
        : (hayDatos ? Icons.schedule_rounded : Icons.hourglass_empty_rounded);

    return Semantics(
      label: texto,
      child: Row(
        children: [
          Icon(icono, size: 18, color: PaletaEstados.textoSecundario),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                color: PaletaEstados.textoSecundario,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaDiferencia extends StatelessWidget {
  final bool enPausa;
  final bool hayDatos;
  final Lectura? lectura;

  const _TarjetaDiferencia({
    required this.enPausa,
    required this.hayDatos,
    required this.lectura,
  });

  @override
  Widget build(BuildContext context) {
    final EstadoLectura? estado = enPausa
        ? null
        : (hayDatos ? lectura?.estado : null);
    final Color color;
    if (enPausa) {
      color = PaletaEstados.pausa;
    } else if (!hayDatos) {
      color = PaletaEstados.pausa;
    } else {
      color = estado?.color ?? PaletaEstados.pausa;
    }

    return MetricaCard(
      titulo: 'Diferencia entre entrada y salida',
      valor: hayDatos && lectura != null
          ? numeroConComa(lectura!.diferenciaLMin)
          : '—',
      unidad: 'L/min',
      icono: Icons.compare_arrows_rounded,
      colorIcono: color,
      colorValor: color,
      insignia: _InsigniaDiferencia(
        estado: estado,
        enPausa: enPausa,
        hayDatos: hayDatos,
        diferenciaPorcentaje: lectura?.diferenciaPorcentaje,
      ),
      subtitulo: enPausa
          ? 'La medición está detenida'
          : (hayDatos
              ? 'Así se calcula el estado que ves arriba'
              : 'Esperando la primera lectura'),
      semantica: enPausa
          ? 'Diferencia entre entrada y salida: el circuito está en pausa.'
          : (hayDatos && lectura != null
              ? 'Diferencia entre entrada y salida: '
                  '${numeroConComa(lectura!.diferenciaLMin)} litros por minuto, '
                  '${porcentajeConComa(lectura!.diferenciaPorcentaje)}. '
                  '${estado?.etiquetaDiferencia ?? ''}.'
              : 'Diferencia entre entrada y salida: sin lectura disponible.'),
    );
  }
}

class _InsigniaDiferencia extends StatelessWidget {
  final EstadoLectura? estado;
  final bool enPausa;
  final bool hayDatos;
  final double? diferenciaPorcentaje;

  const _InsigniaDiferencia({
    required this.estado,
    required this.enPausa,
    required this.hayDatos,
    required this.diferenciaPorcentaje,
  });

  @override
  Widget build(BuildContext context) {
    final String texto;
    final IconData icono;
    final Color color;
    final Color fondo;

    if (enPausa) {
      texto = 'En pausa';
      icono = Icons.pause_circle_filled_rounded;
      color = PaletaEstados.pausa;
      fondo = PaletaEstados.pausaFondo;
    } else if (!hayDatos || estado == null) {
      texto = 'Sin datos';
      icono = Icons.help_outline_rounded;
      color = PaletaEstados.pausa;
      fondo = PaletaEstados.pausaFondo;
    } else {
      texto = estado!.etiquetaDiferencia;
      icono = estado!.icono;
      color = estado!.color;
      fondo = estado!.colorFondo;
    }

    final porcentaje = diferenciaPorcentaje == null
        ? null
        : porcentajeConComa(diferenciaPorcentaje!);

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withAlpha(115)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 15, color: color),
              const SizedBox(width: 5),
              Text(
                texto,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        if (porcentaje != null)
          Text(
            porcentaje,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
      ],
    );
  }
}

class _DetallesLectura extends StatelessWidget {
  final Lectura? lectura;
  final bool hayDatos;
  final bool enPausa;

  const _DetallesLectura({
    required this.lectura,
    required this.hayDatos,
    required this.enPausa,
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
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.tune_rounded, color: PaletaEstados.textoSecundario),
        title: const Text(
          'Detalles',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text(
          'Volúmenes, señal WiFi y dispositivo',
          style: TextStyle(color: PaletaEstados.textoSecundario),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (!hayDatos || lectura == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Aún no hay detalles disponibles.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: PaletaEstados.textoSecundario,
                  ),
                ),
              ),
            )
          else ...[
            _FilaDetalle(
              etiqueta: 'Volumen de entrada',
              valor: '${numeroConComa(lectura!.volumenEntrada, decimales: 1)} L',
            ),
            _FilaDetalle(
              etiqueta: 'Volumen de salida',
              valor: '${numeroConComa(lectura!.volumenSalida, decimales: 1)} L',
            ),
            _FilaSenalWifi(rssi: lectura!.rssi),
            _FilaDetalle(
              etiqueta: 'Dispositivo',
              valor: lectura!.dispositivo,
            ),
            _FilaDetalle(
              etiqueta: 'Última lectura (hora de Lima)',
              valor: fechaHoraLima(lectura!.timestamp),
            ),
            if (enPausa)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Estos valores son de la última medición antes de la pausa.',
                  style: TextStyle(
                    color: PaletaEstados.textoSecundario,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _FilaDetalle extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _FilaDetalle({required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$etiqueta: $valor',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Text(
                etiqueta,
                style: const TextStyle(
                  color: PaletaEstados.textoSecundario,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: Text(
                valor,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaSenalWifi extends StatelessWidget {
  final int? rssi;

  const _FilaSenalWifi({required this.rssi});

  @override
  Widget build(BuildContext context) {
    final calidad = SenalWifi.clasificar(rssi);
    final color = switch (calidad) {
      CalidadSenal.buena => PaletaEstados.normal,
      CalidadSenal.regular => PaletaEstados.desviacion,
      CalidadSenal.debil => PaletaEstados.desviacion,
      CalidadSenal.desconocida => PaletaEstados.pausa,
    };
    final detalle = rssi == null
        ? SenalWifi.etiqueta(calidad)
        : '${SenalWifi.etiqueta(calidad)} ($rssi dBm)';

    return Semantics(
      label: 'Señal WiFi: $detalle. ${SenalWifi.descripcion(calidad)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  flex: 3,
                  child: Text(
                    'Señal WiFi',
                    style: TextStyle(color: PaletaEstados.textoSecundario),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.wifi_rounded, size: 17, color: color),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          detalle,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (rssi != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  SenalWifi.descripcion(calidad),
                  style: const TextStyle(
                    fontSize: 12,
                    color: PaletaEstados.textoSecundario,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
