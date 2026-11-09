import 'package:flutter/material.dart';

/// Tarjeta para visualización de métricas individuales o compuestas.
/// Si no hay datos, muestra claramente "sin datos".
class MetricaCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final String? unidad;
  final String? subtitulo;
  final IconData icono;
  final Color? colorIcono;
  final bool porCompletar;
  final bool esDestacado;

  const MetricaCard({
    super.key,
    required this.titulo,
    required this.valor,
    required this.icono,
    this.unidad,
    this.subtitulo,
    this.colorIcono,
    this.porCompletar = false,
    this.esDestacado = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool sinDatos = valor.trim().toLowerCase() == 'sin datos';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: esDestacado
            ? theme.colorScheme.primaryContainer.withOpacity(0.3)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: esDestacado
              ? theme.colorScheme.primary.withOpacity(0.3)
              : theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                icono,
                size: 20,
                color: colorIcono ?? theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (porCompletar)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.shade700, width: 0.8),
                  ),
                  child: Text(
                    '[POR COMPLETAR]',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  valor,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: sinDatos ? 18 : 22,
                    color: sinDatos
                        ? theme.colorScheme.outline
                        : (esDestacado
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unidad != null && !sinDatos) ...[
                const SizedBox(width: 4),
                Text(
                  unidad!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitulo!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

