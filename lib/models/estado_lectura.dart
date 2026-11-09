import 'package:flutter/material.dart';
import '../theme/paleta_estados.dart';

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
  /// Se usa "Fuga" (igual que el firmware), nunca "Fuga crítica".
  String get etiqueta {
    switch (this) {
      case EstadoLectura.normal:
        return 'Normal';
      case EstadoLectura.desviacion:
        return 'Desviación';
      case EstadoLectura.fuga:
        return 'Fuga';
      case EstadoLectura.sinFlujo:
        return 'Sin flujo';
      case EstadoLectura.desconocido:
        return 'Desconocido';
    }
  }

  /// Etiqueta breve de la diferencia de caudal para las cifras clave.
  /// "normal / revisar / fuga" según el estado calculado por el equipo.
  String get etiquetaDiferencia {
    switch (this) {
      case EstadoLectura.normal:
        return 'Normal';
      case EstadoLectura.desviacion:
        return 'Revisar';
      case EstadoLectura.fuga:
        return 'Fuga';
      case EstadoLectura.sinFlujo:
        return 'Sin flujo';
      case EstadoLectura.desconocido:
        return 'Sin datos';
    }
  }

  /// Color semafórico principal según los requisitos:
  /// - Verde: NORMAL
  /// - Ámbar: DESVIACION
  /// - Rojo: FUGA
  /// - Azul: SIN_FLUJO
  Color get color {
    switch (this) {
      case EstadoLectura.normal:
        return PaletaEstados.normal;
      case EstadoLectura.desviacion:
        return PaletaEstados.desviacion;
      case EstadoLectura.fuga:
        return PaletaEstados.fuga;
      case EstadoLectura.sinFlujo:
        return PaletaEstados.sinFlujo;
      case EstadoLectura.desconocido:
        return PaletaEstados.pausa;
    }
  }

  /// Color de fondo suave para tarjetas o insignias.
  Color get colorFondo {
    switch (this) {
      case EstadoLectura.normal:
        return PaletaEstados.normalFondo;
      case EstadoLectura.desviacion:
        return PaletaEstados.desviacionFondo;
      case EstadoLectura.fuga:
        return PaletaEstados.fugaFondo;
      case EstadoLectura.sinFlujo:
        return PaletaEstados.sinFlujoFondo;
      case EstadoLectura.desconocido:
        return PaletaEstados.pausaFondo;
    }
  }

  /// Color de borde para destacar la tarjeta de estado.
  Color get colorBorde {
    switch (this) {
      case EstadoLectura.normal:
        return PaletaEstados.normalBorde;
      case EstadoLectura.desviacion:
        return PaletaEstados.desviacionBorde;
      case EstadoLectura.fuga:
        return PaletaEstados.fugaBorde;
      case EstadoLectura.sinFlujo:
        return PaletaEstados.sinFlujoBorde;
      case EstadoLectura.desconocido:
        return PaletaEstados.pausaBorde;
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
        return Icons.error_rounded;
      case EstadoLectura.sinFlujo:
        return Icons.water_drop_outlined;
      case EstadoLectura.desconocido:
        return Icons.help_outline_rounded;
    }
  }

  /// Descripción breve, en lenguaje del usuario (sin jerga del protocolo).
  String get descripcion {
    switch (this) {
      case EstadoLectura.normal:
        return 'El agua circula como se espera.';
      case EstadoLectura.desviacion:
        return 'Hay una diferencia moderada entre el agua que entra y la que sale.';
      case EstadoLectura.fuga:
        return 'La diferencia es grande: revisa el tramo de tubería cuanto antes.';
      case EstadoLectura.sinFlujo:
        return 'No está pasando agua por el tramo.';
      case EstadoLectura.desconocido:
        return 'No hay datos suficientes para determinar el estado.';
    }
  }
}
