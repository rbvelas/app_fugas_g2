import 'package:flutter/material.dart';

/// Paleta semántica única de Aqualerta.
///
/// Convención (nunca se usa el color como único indicador):
/// - Verde: normal / correcto.
/// - Ámbar: desviación o advertencia.
/// - Rojo: fuga o peligro.
/// - Azul: sin flujo o información.
/// - Gris: pausa o sin datos.
/// - Violeta: modo DEMO (nunca se reutiliza para alertas).
///
/// Los tonos de texto se eligieron para superar 4,5:1 sobre sus fondos claros.
class PaletaEstados {
  PaletaEstados._();

  static const Color normal = Color(0xFF1B5E20);
  static const Color normalFondo = Color(0xFFE8F5E9);
  static const Color normalBorde = Color(0xFFA5D6A7);

  static const Color desviacion = Color(0xFF8A5300);
  static const Color desviacionFondo = Color(0xFFFFF8E1);
  static const Color desviacionBorde = Color(0xFFFFCC80);

  static const Color fuga = Color(0xFFB3261E);
  static const Color fugaFondo = Color(0xFFFFEBEE);
  static const Color fugaBorde = Color(0xFFEF9A9A);

  static const Color sinFlujo = Color(0xFF0D47A1);
  static const Color sinFlujoFondo = Color(0xFFE3F2FD);
  static const Color sinFlujoBorde = Color(0xFF90CAF9);

  static const Color pausa = Color(0xFF37474F);
  static const Color pausaFondo = Color(0xFFECEFF1);
  static const Color pausaBorde = Color(0xFFB0BEC5);

  static const Color demo = Color(0xFF4527A0);
  static const Color demoFondo = Color(0xFFEDE7F6);
  static const Color demoBorde = Color(0xFFB39DDB);

  static const Color textoPrincipal = Color(0xFF1C1B1F);
  static const Color textoSecundario = Color(0xFF49454F);
  static const Color infoFondo = Color(0xFFE8F1F8);
}
