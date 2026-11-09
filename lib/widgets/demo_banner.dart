import 'package:flutter/material.dart';

/// Letrero permanente displayed when Modo DEMO is active.
/// Indica claramente que los datos son de ejemplo y no mediciones reales.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFE65100), // Naranja intenso de advertencia/simulación
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.science_rounded,
            color: Colors.white,
            size: 18,
          ),
          SizedBox(width: 8),
          Text(
            'DEMO · datos de ejemplo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

