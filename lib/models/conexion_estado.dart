import 'package:flutter/material.dart';
import '../theme/paleta_estados.dart';

/// Estado de la conexión al servidor de mensajes (broker MQTT).
///
/// El tono rojo se reserva para fugas/peligro; los fallos de conexión se
/// muestran en gris con icono de advertencia para no confundir semánticas.
enum ConexionEstado {
  desconectado,
  conectando,
  conectado,
  error;

  /// Texto visible al usuario: "Conectado" o "Sin conexión".
  String get etiqueta {
    switch (this) {
      case ConexionEstado.desconectado:
        return 'Sin conexión';
      case ConexionEstado.conectando:
        return 'Conectando…';
      case ConexionEstado.conectado:
        return 'Conectado';
      case ConexionEstado.error:
        return 'Sin conexión';
    }
  }

  /// Texto del estado en la pantalla de Conexión (algo más explícito).
  String get etiquetaDetallada {
    switch (this) {
      case ConexionEstado.desconectado:
        return 'Sin conexión';
      case ConexionEstado.conectando:
        return 'Conectando…';
      case ConexionEstado.conectado:
        return 'Conectado';
      case ConexionEstado.error:
        return 'No se pudo conectar';
    }
  }

  Color get color {
    switch (this) {
      case ConexionEstado.desconectado:
        return PaletaEstados.pausa;
      case ConexionEstado.conectando:
        return PaletaEstados.desviacion;
      case ConexionEstado.conectado:
        return PaletaEstados.normal;
      case ConexionEstado.error:
        return PaletaEstados.pausa;
    }
  }

  Color get colorFondo {
    switch (this) {
      case ConexionEstado.desconectado:
        return PaletaEstados.pausaFondo;
      case ConexionEstado.conectando:
        return PaletaEstados.desviacionFondo;
      case ConexionEstado.conectado:
        return PaletaEstados.normalFondo;
      case ConexionEstado.error:
        return PaletaEstados.pausaFondo;
    }
  }

  IconData get icono {
    switch (this) {
      case ConexionEstado.desconectado:
        return Icons.cloud_off_rounded;
      case ConexionEstado.conectando:
        return Icons.sync_rounded;
      case ConexionEstado.conectado:
        return Icons.cloud_done_rounded;
      case ConexionEstado.error:
        return Icons.cloud_off_rounded;
    }
  }
}
