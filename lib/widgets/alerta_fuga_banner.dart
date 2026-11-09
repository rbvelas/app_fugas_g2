import 'package:flutter/material.dart';
import '../theme/paleta_estados.dart';

/// Aviso rojo persistente mientras el estado del equipo sea FUGA.
/// No se puede cerrar: la alerta debe seguir visible hasta que el estado cambie.
class AlertaFugaBanner extends StatelessWidget {
  const AlertaFugaBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Alerta de fuga. La diferencia entre entrada y salida es grande. '
          'Revisa el tramo de tubería.',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PaletaEstados.fuga,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.warning_rounded, color: Colors.white, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Alerta de fuga',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'La diferencia entre el agua que entra y la que sale es grande. '
                    'Revisa el tramo de tubería.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
