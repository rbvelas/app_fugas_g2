import 'estado_lectura.dart';

/// Representa un evento de cambio de estado detectado en la telemetría del ESP32.
/// Se almacena en la memoria de la sesión activa (máximo 200 registros).
class CambioEstadoEvento {
  final DateTime timestamp;
  final EstadoLectura estadoAnterior;
  final EstadoLectura estadoNuevo;
  final double caudalEntrada; // L/min
  final double caudalSalida; // L/min
  final double diferenciaPorcentaje; // %

  const CambioEstadoEvento({
    required this.timestamp,
    required this.estadoAnterior,
    required this.estadoNuevo,
    required this.caudalEntrada,
    required this.caudalSalida,
    required this.diferenciaPorcentaje,
  });

  /// Hora en formato Lima (UTC-5): dd/MM/yyyy HH:mm:ss (Lima, UTC-5)
  String get horaLimaFormateada {
    final lima = timestamp.toUtc().subtract(const Duration(hours: 5));
    final d = lima.day.toString().padLeft(2, '0');
    final mo = lima.month.toString().padLeft(2, '0');
    final y = lima.year.toString();
    final h = lima.hour.toString().padLeft(2, '0');
    final mi = lima.minute.toString().padLeft(2, '0');
    final s = lima.second.toString().padLeft(2, '0');
    return '$d/$mo/$y $h:$mi:$s (Lima, UTC-5)';
  }
}

