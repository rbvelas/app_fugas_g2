import 'package:flutter/material.dart';
import '../theme/paleta_estados.dart';

/// Letrero permanente cuando el Modo DEMO está activo.
/// Usa violeta (no naranja ni rojo) para no confundirse con alertas.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Modo demo activo. Los datos son de ejemplo.',
      child: Container(
        width: double.infinity,
        color: PaletaEstados.demo,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.science_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Demo · datos de ejemplo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
