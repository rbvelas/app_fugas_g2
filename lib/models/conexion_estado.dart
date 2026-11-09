import 'package:flutter/material.dart';

/// Estado de la conexión al broker MQTT (EMQX 5.8.6).
enum ConexionEstado {
  desconectado,
  conectando,
  conectado,
  error;

  String get etiqueta {
    switch (this) {
      case ConexionEstado.desconectado:
        return 'Desconectado';
      case ConexionEstado.conectando:
        return 'Conectando...';
      case ConexionEstado.conectado:
        return 'Conectado';
      case ConexionEstado.error:
        return 'Error de conexión';
    }
  }

  Color get color {
    switch (this) {
      case ConexionEstado.desconectado:
        return const Color(0xFF757575);
      case ConexionEstado.conectando:
        return const Color(0xFFF57F17);
      case ConexionEstado.conectado:
        return const Color(0xFF2E7D32);
      case ConexionEstado.error:
        return const Color(0xFFD32F2F);
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
        return Icons.error_outline_rounded;
    }
  }
}

