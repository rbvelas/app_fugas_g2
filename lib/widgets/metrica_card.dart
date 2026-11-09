import 'package:flutter/material.dart';
import '../theme/paleta_estados.dart';

/// Cifra clave de Monitoreo.
///
/// No recorta textos con "…": permite varias líneas y crece con el tamaño de
/// letra del sistema (hasta 200 %). El color nunca es el único indicador: cada
/// insignia incluye icono y texto.
class MetricaCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final String? unidad;
  final String? subtitulo;
  final IconData icono;
  final Color? colorIcono;
  final Color? colorValor;
  final Widget? insignia;
  final String? semantica;

  const MetricaCard({
    super.key,
    required this.titulo,
    required this.valor,
    required this.icono,
    this.unidad,
    this.subtitulo,
    this.colorIcono,
    this.colorValor,
    this.insignia,
    this.semantica,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = colorValor ?? theme.colorScheme.onSurface;

    return Semantics(
      container: true,
      label: semantica ??
          '$titulo: $valor ${unidad ?? ''}. ${subtitulo ?? ''}'.trim(),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: PaletaEstados.textoSecundario,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 4,
              runSpacing: 2,
              children: [
                Text(
                  valor,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1.1,
                  ),
                ),
                if (unidad != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      unidad!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: PaletaEstados.textoSecundario,
                      ),
                    ),
                  ),
              ],
            ),
            if (insignia != null) ...[
              const SizedBox(height: 8),
              insignia!,
            ],
            if (subtitulo != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitulo!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: PaletaEstados.textoSecundario,
                  height: 1.25,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
