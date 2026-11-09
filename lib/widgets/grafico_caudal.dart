import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/lectura.dart';
import '../theme/paleta_estados.dart';
import '../utils/formato_numeros.dart';

/// Gráfico de los últimos 120 segundos.
///
/// - Eje Y con marcas "agradables" (0, 1, 2, 3…).
/// - Entrada en línea continua y salida en línea discontinua.
/// - Leyenda con los valores actuales.
/// - Aviso "Sin flujo" superpuesto cuando ambos caudales son 0.
class GraficoCaudal extends StatelessWidget {
  final List<Lectura> lecturas;

  const GraficoCaudal({
    super.key,
    required this.lecturas,
  });

  static const Color _colorEntrada = Color(0xFF0D47A1);
  static const Color _colorSalida = Color(0xFFC2410C);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actual = lecturas.isEmpty ? null : lecturas.last;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Caudal de los últimos 2 minutos',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'L/min',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: PaletaEstados.textoSecundario,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _LeyendaLinea(
                color: _colorEntrada,
                discontinua: false,
                texto: actual == null
                    ? 'Entrada'
                    : 'Entrada ${numeroConComa(actual.caudalEntrada)} L/min',
              ),
              _LeyendaLinea(
                color: _colorSalida,
                discontinua: true,
                texto: actual == null
                    ? 'Salida'
                    : 'Salida ${numeroConComa(actual.caudalSalida)} L/min',
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 210,
            child: lecturas.isEmpty
                ? _buildEstadoVacio(theme)
                : _buildGrafico(context, actual),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoVacio(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.show_chart_rounded,
            size: 36,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 8),
          Text(
            'Aún no hay datos para el gráfico',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: PaletaEstados.textoSecundario,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Los puntos aparecerán cuando llegue la primera lectura.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: PaletaEstados.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrafico(BuildContext context, Lectura? actual) {
    final theme = Theme.of(context);
    final ahora = DateTime.now();
    final spotsEntrada = <FlSpot>[];
    final spotsSalida = <FlSpot>[];
    double maxValor = 0;

    for (final lectura in lecturas) {
      final segundos = ahora.difference(lectura.timestamp).inMilliseconds / 1000.0;
      if (segundos > 120.0) continue;
      final x = (120.0 - segundos).clamp(0.0, 120.0).toDouble();
      spotsEntrada.add(FlSpot(x, lectura.caudalEntrada));
      spotsSalida.add(FlSpot(x, lectura.caudalSalida));
      maxValor = max(maxValor, max(lectura.caudalEntrada, lectura.caudalSalida));
    }

    spotsEntrada.sort((a, b) => a.x.compareTo(b.x));
    spotsSalida.sort((a, b) => a.x.compareTo(b.x));

    if (spotsEntrada.isEmpty) {
      return _buildEstadoVacio(theme);
    }

    final paso = _pasoAgradable(maxValor);
    final maxY = max(paso, (maxValor * 1.1 / paso).ceilToDouble() * paso);
    final decimalesEje = paso < 1 ? 1 : 0;
    final sinFlujo = actual != null &&
        actual.caudalEntrada == 0 &&
        actual.caudalSalida == 0;

    final descripcion = actual == null
        ? 'Gráfico de caudal sin datos.'
        : 'Gráfico de caudal de los últimos 120 segundos. '
            'Entrada ${numeroConComa(actual.caudalEntrada)} litros por minuto '
            'en línea continua; salida ${numeroConComa(actual.caudalSalida)} '
            'litros por minuto en línea discontinua.';

    return Semantics(
      label: descripcion,
      child: Stack(
        children: [
          Positioned.fill(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 120,
                minY: 0,
                maxY: maxY,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: paso,
                  verticalInterval: 30,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: theme.colorScheme.outlineVariant.withAlpha(140),
                    strokeWidth: 1,
                    dashArray: const [4, 4],
                  ),
                  getDrawingVerticalLine: (value) => FlLine(
                    color: theme.colorScheme.outlineVariant.withAlpha(89),
                    strokeWidth: 1,
                    dashArray: const [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 30,
                      getTitlesWidget: (value, meta) {
                        final texto = switch (value.toInt()) {
                          0 => '-120 s',
                          30 => '-90 s',
                          60 => '-60 s',
                          90 => '-30 s',
                          120 => 'Ahora',
                          _ => '',
                        };
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            texto,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: PaletaEstados.textoSecundario,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: paso,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          numeroConComa(value, decimales: decimalesEje),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: PaletaEstados.textoSecundario,
                          ),
                          textAlign: TextAlign.right,
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spotsEntrada,
                    isCurved: false,
                    color: _colorEntrada,
                    barWidth: 2.6,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: spotsSalida,
                    isCurved: false,
                    color: _colorSalida,
                    barWidth: 2.6,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    dashArray: const [7, 4],
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final esEntrada = spot.barIndex == 0;
                        return LineTooltipItem(
                          '${esEntrada ? "Entrada" : "Salida"}: '
                          '${numeroConComa(spot.y)} L/min',
                          TextStyle(
                            color: esEntrada ? _colorEntrada : _colorSalida,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          if (sinFlujo)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(230),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: PaletaEstados.sinFlujoBorde,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.water_drop_outlined,
                            size: 18, color: PaletaEstados.sinFlujo),
                        SizedBox(width: 6),
                        Text(
                          'Sin flujo',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: PaletaEstados.sinFlujo,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Elige un intervalo de eje "redondo": 0,5, 1, 2, 5, 10, 20, 50…
  double _pasoAgradable(double maxValor) {
    if (maxValor <= 0) return 1;
    final objetivo = maxValor / 4;
    const pasos = [0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0];
    for (final paso in pasos) {
      if (paso >= objetivo) return paso;
    }
    return (objetivo / 100).ceilToDouble() * 100;
  }
}

class _LeyendaLinea extends StatelessWidget {
  final Color color;
  final bool discontinua;
  final String texto;

  const _LeyendaLinea({
    required this.color,
    required this.discontinua,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MuestraLinea(color: color, discontinua: discontinua),
        const SizedBox(width: 6),
        Text(
          texto,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: PaletaEstados.textoSecundario,
          ),
        ),
      ],
    );
  }
}

class _MuestraLinea extends StatelessWidget {
  final Color color;
  final bool discontinua;

  const _MuestraLinea({required this.color, required this.discontinua});

  @override
  Widget build(BuildContext context) {
    if (!discontinua) {
      return Container(
        width: 18,
        height: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _segmento(color),
        const SizedBox(width: 3),
        _segmento(color),
        const SizedBox(width: 3),
        _segmento(color),
      ],
    );
  }

  Widget _segmento(Color color) {
    return Container(
      width: 4,
      height: 3,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
