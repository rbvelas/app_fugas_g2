import 'package:flutter/material.dart';

/// Representa el estado calculado por el firmware del ESP32.
/// La aplicación NO recalcula este estado, solo lo representa visualmente.
enum EstadoLectura {
  normal,
  desviacion,
  fuga,
  sinFlujo,
  desconocido;

  /// Parsea la cadena recibida en el JSON del firmware.
  /// Ejemplos: "NORMAL", "DESVIACION", "FUGA", "SIN_FLUJO".
  static EstadoLectura fromString(String? valor) {
    if (valor == null) return EstadoLectura.desconocido;
    final normalizado = valor.trim().toUpperCase();
    switch (normalizado) {
      case 'NORMAL':
        return EstadoLectura.normal;
      case 'DESVIACION':
      case 'DESVIACIÓN':
        return EstadoLectura.desviacion;
      case 'FUGA':
        return EstadoLectura.fuga;
      case 'SIN_FLUJO':
      case 'SIN FLUJO':
        return EstadoLectura.sinFlujo;
      default:
        return EstadoLectura.desconocido;
    }
  }

  /// Texto legible en español para la interfaz.
  String get etiqueta {
    switch (this) {
      case EstadoLectura.normal:
        return 'NORMAL';
      case EstadoLectura.desviacion:
        return 'DESVIACIÓN';
      case EstadoLectura.fuga:
        return 'FUGA CRÍTICA';
      case EstadoLectura.sinFlujo:
        return 'SIN FLUJO';
      case EstadoLectura.desconocido:
        return 'DESCONOCIDO';
    }
  }

  /// Color semafórico principal según los requisitos:
  /// - Verde: NORMAL
  /// - Amarillo: DESVIACION
  /// - Rojo: FUGA
  /// - Azul: SIN_FLUJO
  Color get color {
    switch (this) {
      case EstadoLectura.normal:
        return const Color(0xFF2E7D32); // Verde 800
      case EstadoLectura.desviacion:
        return const Color(0xFFF57F17); // Ámbar / Amarillo intenso
      case EstadoLectura.fuga:
        return const Color(0xFFD32F2F); // Rojo 700
      case EstadoLectura.sinFlujo:
        return const Color(0xFF1976D2); // Azul 700
      case EstadoLectura.desconocido:
        return const Color(0xFF757575); // Gris 600
    }
  }

  /// Color de fondo suave para tarjetas o insignias.
  Color get colorFondo {
    switch (this) {
      case EstadoLectura.normal:
        return const Color(0xFFE8F5E9);
      case EstadoLectura.desviacion:
        return const Color(0xFFFFFDE7);
      case EstadoLectura.fuga:
        return const Color(0xFFFFEBEE);
      case EstadoLectura.sinFlujo:
        return const Color(0xFFE3F2FD);
      case EstadoLectura.desconocido:
        return const Color(0xFFEEEEEE);
    }
  }

  /// Color de borde para destacar la tarjeta de estado.
  Color get colorBorde {
    switch (this) {
      case EstadoLectura.normal:
        return const Color(0xFFA5D6A7);
      case EstadoLectura.desviacion:
        return const Color(0xFFFFF59D);
      case EstadoLectura.fuga:
        return const Color(0xFFEF9A9A);
      case EstadoLectura.sinFlujo:
        return const Color(0xFF90CAF9);
      case EstadoLectura.desconocido:
        return const Color(0xFFE0E0E0);
    }
  }

  /// Icono representativo además del color (accesibilidad).
  IconData get icono {
    switch (this) {
      case EstadoLectura.normal:
        return Icons.check_circle_rounded;
      case EstadoLectura.desviacion:
        return Icons.warning_amber_rounded;
      case EstadoLectura.fuga:
        return Icons.error_outline_rounded;
      case EstadoLectura.sinFlujo:
        return Icons.water_drop_outlined;
      case EstadoLectura.desconocido:
        return Icons.help_outline_rounded;
    }
  }

  /// Descripción detallada de la regla calculada en el firmware.
  String get descripcion {
    switch (this) {
      case EstadoLectura.normal:
        return 'Flujo de agua dentro de los parámetros esperados.';
      case EstadoLectura.desviacion:
        return 'Diferencia ≥ 15 % durante 3 lecturas continuas.';
      case EstadoLectura.fuga:
        return 'Fuga detectada: Diferencia ≥ 30 % durante 3 lecturas continuas.';
      case EstadoLectura.sinFlujo:
        return 'Ambos sensores registran caudales < 0,5 L/min.';
      case EstadoLectura.desconocido:
        return 'Estado no reconocido o sin telemetría reciente.';
    }
  }
}

