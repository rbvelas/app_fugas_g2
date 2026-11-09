import 'package:flutter/material.dart';
import '../models/estado_lectura.dart';
import '../theme/paleta_estados.dart';

/// Ayuda breve, accesible desde el icono "?" de la barra superior.
/// Explica los cuatro estados con color + icono + texto (nunca solo color).
Future<void> mostrarAyudaEstados(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.help_outline_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Qué significa cada estado',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar ayuda',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Aqualerta compara el agua que entra con la que sale del tramo.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: PaletaEstados.textoSecundario,
                ),
              ),
              const SizedBox(height: 16),
              const _FilaAyuda(estado: EstadoLectura.normal),
              const _FilaAyuda(estado: EstadoLectura.desviacion),
              const _FilaAyuda(estado: EstadoLectura.fuga),
              const _FilaAyuda(estado: EstadoLectura.sinFlujo),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.pause_circle_filled_rounded,
                      color: PaletaEstados.pausa, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'En pausa: el equipo no mide ni publica datos. El agua sigue fluyendo.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: PaletaEstados.textoSecundario,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Entendido'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _FilaAyuda extends StatelessWidget {
  final EstadoLectura estado;

  const _FilaAyuda({required this.estado});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: estado.colorFondo,
              shape: BoxShape.circle,
              border: Border.all(color: estado.colorBorde),
            ),
            child: Icon(estado.icono, color: estado.color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  estado.etiqueta,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: estado.color,
                  ),
                ),
                Text(
                  estado.descripcion,
                  style: const TextStyle(
                    color: PaletaEstados.textoSecundario,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
