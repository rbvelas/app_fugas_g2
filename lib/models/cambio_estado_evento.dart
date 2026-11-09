import '../utils/formato_tiempo.dart' as tiempo;
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

  /// Hora corta de Lima (UTC-5) para la fila del historial: HH:mm:ss.
  String get horaCortaLima => tiempo.horaCortaLima(timestamp);

  /// Hora completa de Lima (UTC-5) para el detalle.
  String get fechaHoraLimaFormateada => tiempo.fechaHoraLima(timestamp);
}
