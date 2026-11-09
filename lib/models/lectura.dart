import 'dart:convert';
import 'estado_lectura.dart';

/// Modelo inmutable de una lectura de telemetría proveniente del ESP32.
/// Tópico: unt/iot/g2/riego/telemetria
class Lectura {
  final String dispositivo;
  final double caudalEntrada; // L/min (Obligatorio en telemetría válida)
  final double caudalSalida; // L/min
  final double diferenciaLMin; // L/min
  final double diferenciaPorcentaje; // %
  final double volumenEntrada; // L
  final double volumenSalida; // L
  final EstadoLectura estado; // Calculado por firmware
  final int? rssi; // dBm (puede ser null)
  final DateTime timestamp; // Instante de recepción

  const Lectura({
    required this.dispositivo,
    required this.caudalEntrada,
    required this.caudalSalida,
    required this.diferenciaLMin,
    required this.diferenciaPorcentaje,
    required this.volumenEntrada,
    required this.volumenSalida,
    required this.estado,
    required this.timestamp,
    this.rssi,
  });

  /// Validador estricto de rangos físicos y de ingeniería:
  /// - Caudales ≥ 0
  /// - Diferencia porcentual entre -100.0 % y 100.0 % (valores negativos leves son normales)
  /// - Estado debe ser NORMAL, DESVIACION, FUGA o SIN_FLUJO (no desconocido)
  /// - RSSI entre -120 y 0 dBm (si está presente)
  /// - Volúmenes ≥ 0
  static bool validarRangos({
    required double caudalEntrada,
    required double caudalSalida,
    required double diferenciaPorcentaje,
    required EstadoLectura estado,
    int? rssi,
    double volumenEntrada = 0.0,
    double volumenSalida = 0.0,
  }) {
    if (caudalEntrada < 0 || caudalSalida < 0) return false;
    if (diferenciaPorcentaje < -100.0 || diferenciaPorcentaje > 100.0) return false;
    if (volumenEntrada < 0 || volumenSalida < 0) return false;
    if (estado == EstadoLectura.desconocido) return false;
    if (rssi != null && (rssi < -120 || rssi > 0)) return false;
    return true;
  }

  /// Constructor tolerante a campos ausentes o tipos variados.
  /// Si falta el campo esencial de telemetría `caudal_entrada`, lanza FormatException.
  factory Lectura.fromJson(Map<String, dynamic> json, {DateTime? timestamp}) {
    if (!json.containsKey('caudal_entrada') || json['caudal_entrada'] == null) {
      throw const FormatException('Payload sin campo requerido: caudal_entrada');
    }

    final qEntrada = _parseNum(json['caudal_entrada'])?.toDouble();
    if (qEntrada == null) {
      throw const FormatException('caudal_entrada no contiene un número válido');
    }

    final qSalida = _parseNum(json['caudal_salida'])?.toDouble() ?? 0.0;
    final difLMin = _parseNum(json['diferencia_l_min'])?.toDouble() ?? (qEntrada - qSalida);
    final difPorc = _parseNum(json['diferencia_porcentaje'])?.toDouble() ??
        (qEntrada > 0 ? ((qEntrada - qSalida).abs() / qEntrada * 100) : 0.0);
    final volEntrada = _parseNum(json['volumen_entrada'])?.toDouble() ?? 0.0;
    final volSalida = _parseNum(json['volumen_salida'])?.toDouble() ?? 0.0;
    final estado = EstadoLectura.fromString(json['estado']?.toString());
    final rssi = _parseNum(json['rssi'])?.toInt();
    final dispositivo = json['dispositivo']?.toString() ?? 'ESP32';

    return Lectura(
      dispositivo: dispositivo,
      caudalEntrada: qEntrada,
      caudalSalida: qSalida,
      diferenciaLMin: difLMin,
      diferenciaPorcentaje: difPorc,
      volumenEntrada: volEntrada,
      volumenSalida: volSalida,
      estado: estado,
      rssi: rssi,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  /// Parsea un Map y valida estrictamente tipos y rangos.
  /// Retorna null si faltan campos indispensables o si algún valor está fuera de rango.
  static Lectura? tryFromJson(Map<String, dynamic>? json, {DateTime? timestamp}) {
    if (json == null) return null;

    // Mensaje de arranque del ESP32 no es telemetría
    if (!json.containsKey('caudal_entrada') || json['caudal_entrada'] == null) {
      return null;
    }

    try {
      final lectura = Lectura.fromJson(json, timestamp: timestamp);

      // Verificación estricta de rangos requerida por el Laboratorio 11
      final esValido = validarRangos(
        caudalEntrada: lectura.caudalEntrada,
        caudalSalida: lectura.caudalSalida,
        diferenciaPorcentaje: lectura.diferenciaPorcentaje,
        estado: lectura.estado,
        rssi: lectura.rssi,
        volumenEntrada: lectura.volumenEntrada,
        volumenSalida: lectura.volumenSalida,
      );

      return esValido ? lectura : null;
    } catch (_) {
      return null;
    }
  }

  /// Parsea de forma segura una cadena JSON cruda validando tipo y rango.
  /// Retorna null si la cadena está corrupta, no es JSON, o está fuera de rango.
  static Lectura? fromRawJson(String rawJson, {DateTime? timestamp}) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        return tryFromJson(decoded, timestamp: timestamp);
      } else if (decoded is Map) {
        return tryFromJson(
          decoded.map((k, v) => MapEntry(k.toString(), v)),
          timestamp: timestamp,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Convierte la marca de tiempo a la zona horaria de Lima (UTC-5).
  DateTime get horaLima => timestamp.toUtc().subtract(const Duration(hours: 5));

  /// Formatea la hora en Lima en formato HH:mm:ss.
  String get horaLimaFormateada {
    final lima = horaLima;
    final h = lima.hour.toString().padLeft(2, '0');
    final m = lima.minute.toString().padLeft(2, '0');
    final s = lima.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// Formatea la fecha y hora completa en Lima: dd/MM/yyyy HH:mm:ss (Lima, UTC-5).
  String get fechaHoraLimaFormateada {
    final lima = horaLima;
    final d = lima.day.toString().padLeft(2, '0');
    final mo = lima.month.toString().padLeft(2, '0');
    final y = lima.year.toString();
    return '$d/$mo/$y $horaLimaFormateada (Lima, UTC-5)';
  }

  static num? _parseNum(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor;
    if (valor is String) return num.tryParse(valor.trim());
    return null;
  }
}
