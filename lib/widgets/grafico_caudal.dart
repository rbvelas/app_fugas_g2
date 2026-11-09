import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/lectura.dart';

/// Gráfico temporal continuo de los últimos 120 segundos utilizando fl_chart.
/// Muestra simultáneamente el caudal de entrada (Qe) y el de salida (Qs) con leyenda.
class GraficoCaudal extends StatelessWidget {
  final List<Lectura> lecturas;

  const GraficoCaudal({
    super.key,
    required this.lecturas,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const colorEntrada = Color(0xFF0288D1); // Azul cian para Entrada
    const colorSalida = Color(0xFFE65100); // Naranja oscuro para Salida

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
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
              Text(
                'HISTORIAL EN TIEMPO REAL (120 s)',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Icon(Icons.show_chart_rounded, size: 20, color: Color(0xFF757575)),
            ],
          ),
          const SizedBox(height: 12),
          // Leyenda interactiva
          Row(
            children: [
              _buildLeyendaItem('Qe Entrada (L/min)', colorEntrada),
              const SizedBox(width: 16),
              _buildLeyendaItem('Qs Salida (L/min)', colorSalida),
            ],
          ),
          const SizedBox(height: 16),
          // Área del gráfico
          SizedBox(
            height: 200,
            child: lecturas.isEmpty
                ? _buildEstadoVacio(theme)
                : _buildLineChart(theme, colorEntrada, colorSalida),
          ),
        ],
      ),
    );
  }

  Widget _buildLeyendaItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF424242),
          ),
        ),
      ],
    );
  }

  Widget _buildEstadoVacio(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.query_builder_rounded,
            size: 36,
            color: theme.colorScheme.outline.withOpacity(0.6),
          ),
          const SizedBox(height: 8),
          Text(
            'Esperando telemetría del ESP32...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Los puntos aparecerán automáticamente cada 1 s.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(ThemeData theme, Color colorEntrada, Color colorSalida) {
    final ahora = DateTime.now();
    final spotsEntrada = <FlSpot>[];
    final spotsSalida = <FlSpot>[];

    double maxVal = 5.0;

    for (final l in lecturas) {
      final diffSegundos = ahora.difference(l.timestamp).inMilliseconds / 1000.0;
      if (diffSegundos > 120.0) continue;

      // El eje X va de 0 a 120 s (donde 120 es el momento actual)
      final x = (120.0 - diffSegundos).clamp(0.0, 120.0);
      spotsEntrada.add(FlSpot(x, l.caudalEntrada));
      spotsSalida.add(FlSpot(x, l.caudalSalida));

      maxVal = max(maxVal, max(l.caudalEntrada, l.caudalSalida));
    }

    // Ordenar spots por coordenada X ascendente (requisito de fl_chart)
    spotsEntrada.sort((a, b) => a.x.compareTo(b.x));
    spotsSalida.sort((a, b) => a.x.compareTo(b.x));

    final maxY = (maxVal * 1.25).ceilToDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 120,
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: max(1.0, (maxY / 4).roundToDouble()),
          verticalInterval: 30,
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.colorScheme.outlineVariant.withOpacity(0.4),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
          getDrawingVerticalLine: (value) => FlLine(
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 30,
              getTitlesWidget: (value, meta) {
                String texto;
                switch (value.toInt()) {
                  case 0:
                    texto = '-120s';
                    break;
                  case 30:
                    texto = '-90s';
                    break;
                  case 60:
                    texto = '-60s';
                    break;
                  case 90:
                    texto = '-30s';
                    break;
                  case 120:
                    texto = 'Ahora';
                    break;
                  default:
                    texto = '';
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    texto,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF757575),
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: max(1.0, (maxY / 4).roundToDouble()),
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF757575),
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
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spotsEntrada,
            isCurved: false,
            color: colorEntrada,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: spotsSalida,
            isCurved: false,
            color: colorSalida,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final esEntrada = spot.barIndex == 0;
                return LineTooltipItem(
                  '${esEntrada ? "Qe" : "Qs"}: ${spot.y.toStringAsFixed(2)} L/min',
                  TextStyle(
                    color: esEntrada ? colorEntrada : colorSalida,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

