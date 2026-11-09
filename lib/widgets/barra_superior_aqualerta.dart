import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/telemetria_provider.dart';
import '../theme/paleta_estados.dart';
import 'ayuda_estados.dart';

/// Barra superior común a las cuatro pantallas:
/// nombre de la pantalla + chip de conexión siempre visible + ayuda.
class BarraSuperiorAqualerta extends StatelessWidget
    implements PreferredSizeWidget {
  final String titulo;
  final VoidCallback onIrAConexion;
  final List<Widget> acciones;

  const BarraSuperiorAqualerta({
    super.key,
    required this.titulo,
    required this.onIrAConexion,
    this.acciones = const [],
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TelemetriaProvider>();
    final esDemo = provider.modoDemoActivo;
    final estado = provider.estadoConexion;

    final String textoChip;
    final Color colorChip;
    final Color fondoChip;
    final IconData iconoChip;

    if (esDemo) {
      textoChip = 'Demo';
      colorChip = PaletaEstados.demo;
      fondoChip = PaletaEstados.demoFondo;
      iconoChip = Icons.science_rounded;
    } else {
      textoChip = estado.etiqueta;
      colorChip = estado.color;
      fondoChip = estado.colorFondo;
      iconoChip = estado.icono;
    }

    return AppBar(
      titleSpacing: 16,
      title: Row(
        children: [
          Expanded(
            child: Text(
              titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Conexión: $textoChip. Abrir la pantalla de conexión',
            onTap: onIrAConexion,
            excludeSemantics: true,
            child: ActionChip(
              materialTapTargetSize: MaterialTapTargetSize.padded,
              avatar: Icon(iconoChip, size: 16, color: colorChip),
              label: Text(
                textoChip,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colorChip,
                ),
              ),
              backgroundColor: fondoChip,
              side: BorderSide(color: colorChip.withAlpha(115)),
              tooltip: 'Ver conexión',
              onPressed: onIrAConexion,
            ),
          ),
        ],
      ),
      actions: [
        ...acciones,
        IconButton(
          tooltip: 'Ayuda: qué significa cada estado',
          icon: const Icon(Icons.help_outline_rounded),
          onPressed: () => mostrarAyudaEstados(context),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
