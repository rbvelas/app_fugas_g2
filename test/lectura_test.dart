import 'package:flutter_test/flutter_test.dart';
import 'package:fugas_g2/models/estado_lectura.dart';
import 'package:fugas_g2/models/lectura.dart';

void main() {
  group('Pruebas unitarias de parseo y validación de rangos de Lectura', () {
    test('1. Mensaje válido completo con todos los campos de telemetría', () {
      const jsonStr = '''
      {
        "dispositivo": "ESP32_RIEGO",
        "caudal_entrada": 12.5,
        "caudal_salida": 10.0,
        "diferencia_l_min": 2.5,
        "diferencia_porcentaje": 20.0,
        "volumen_entrada": 150.2,
        "volumen_salida": 140.0,
        "estado": "DESVIACION",
        "rssi": -68
      }
      ''';

      final lectura = Lectura.fromRawJson(jsonStr);

      expect(lectura, isNotNull);
      expect(lectura!.dispositivo, 'ESP32_RIEGO');
      expect(lectura.caudalEntrada, 12.5);
      expect(lectura.caudalSalida, 10.0);
      expect(lectura.diferenciaLMin, 2.5);
      expect(lectura.diferenciaPorcentaje, 20.0);
      expect(lectura.volumenEntrada, 150.2);
      expect(lectura.volumenSalida, 140.0);
      expect(lectura.estado, EstadoLectura.desviacion);
      expect(lectura.rssi, -68);
    });

    test('2. JSON sintácticamente inválido retorna null sin excepción no controlada', () {
      const jsonInvalido1 = '{caudal_entrada: 12.5, estado: "NORMAL"';
      const jsonInvalido2 = 'texto plano no json';
      const jsonInvalido3 = '';

      expect(Lectura.fromRawJson(jsonInvalido1), isNull);
      expect(Lectura.fromRawJson(jsonInvalido2), isNull);
      expect(Lectura.fromRawJson(jsonInvalido3), isNull);
    });

    test('3. Mensaje de arranque "ESP32 conectado" es ignorado (retorna null)', () {
      const mensajeInicio = '{"mensaje":"ESP32 conectado"}';

      final lectura = Lectura.fromRawJson(mensajeInicio);

      expect(lectura, isNull);
      expect(Lectura.tryFromJson(const {'mensaje': 'ESP32 conectado'}), isNull);
    });

    test('4. Mensaje sin caudal_entrada es ignorado (retorna null o FormatException en fromJson)', () {
      const payloadSinCaudalEntrada = '''
      {
        "dispositivo": "ESP32",
        "caudal_salida": 5.0,
        "estado": "NORMAL",
        "rssi": -70
      }
      ''';

      expect(Lectura.fromRawJson(payloadSinCaudalEntrada), isNull);
      expect(
        () => Lectura.fromJson(const {
          'dispositivo': 'ESP32',
          'caudal_salida': 5.0,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('5. Validación de rangos: diferencia porcentual negativa pequeña es válida', () {
      // Un sensor de salida a veces cuenta 1 pulso más: diferencia negativa pequeña válida
      const jsonDifNegativa = '''
      {
        "caudal_entrada": 10.0,
        "caudal_salida": 10.25,
        "diferencia_l_min": -0.25,
        "diferencia_porcentaje": -2.5,
        "estado": "NORMAL",
        "rssi": -65
      }
      ''';

      final lectura = Lectura.fromRawJson(jsonDifNegativa);
      expect(lectura, isNotNull);
      expect(lectura!.diferenciaPorcentaje, -2.5);
      expect(
        Lectura.validarRangos(
          caudalEntrada: 10.0,
          caudalSalida: 10.25,
          diferenciaPorcentaje: -2.5,
          estado: EstadoLectura.normal,
          rssi: -65,
        ),
        isTrue,
      );
    });

    test('6. Validación de rangos: diferencia porcentual 150 % es inválida', () {
      const jsonDifExcesiva = '''
      {
        "caudal_entrada": 10.0,
        "caudal_salida": 0.0,
        "diferencia_l_min": 10.0,
        "diferencia_porcentaje": 150.0,
        "estado": "FUGA",
        "rssi": -65
      }
      ''';

      final lectura = Lectura.fromRawJson(jsonDifExcesiva);
      expect(lectura, isNull, reason: '150% supera el rango válido de ±100%');
      expect(
        Lectura.validarRangos(
          caudalEntrada: 10.0,
          caudalSalida: 0.0,
          diferenciaPorcentaje: 150.0,
          estado: EstadoLectura.fuga,
        ),
        isFalse,
      );
    });

    test('7. Validación de rangos: caudales negativos son inválidos', () {
      const jsonCaudalNegativo = '''
      {
        "caudal_entrada": -1.5,
        "caudal_salida": 10.0,
        "diferencia_porcentaje": 10.0,
        "estado": "NORMAL"
      }
      ''';

      expect(Lectura.fromRawJson(jsonCaudalNegativo), isNull);
      expect(
        Lectura.validarRangos(
          caudalEntrada: -1.5,
          caudalSalida: 10.0,
          diferenciaPorcentaje: 10.0,
          estado: EstadoLectura.normal,
        ),
        isFalse,
      );
    });

    test('8. Validación de rangos: estado desconocido es inválido', () {
      const jsonEstadoInvalido = '''
      {
        "caudal_entrada": 10.0,
        "caudal_salida": 10.0,
        "diferencia_porcentaje": 0.0,
        "estado": "ESTADO_INEXISTENTE"
      }
      ''';

      expect(Lectura.fromRawJson(jsonEstadoInvalido), isNull);
      expect(
        Lectura.validarRangos(
          caudalEntrada: 10.0,
          caudalSalida: 10.0,
          diferenciaPorcentaje: 0.0,
          estado: EstadoLectura.desconocido,
        ),
        isFalse,
      );
    });

    test('9. Validación de rangos: RSSI fuera de [-120, 0] es inválido', () {
      expect(
        Lectura.validarRangos(
          caudalEntrada: 10.0,
          caudalSalida: 10.0,
          diferenciaPorcentaje: 0.0,
          estado: EstadoLectura.normal,
          rssi: 10, // Inválido (> 0)
        ),
        isFalse,
      );

      expect(
        Lectura.validarRangos(
          caudalEntrada: 10.0,
          caudalSalida: 10.0,
          diferenciaPorcentaje: 0.0,
          estado: EstadoLectura.normal,
          rssi: -130, // Inválido (< -120)
        ),
        isFalse,
      );

      expect(
        Lectura.validarRangos(
          caudalEntrada: 10.0,
          caudalSalida: 10.0,
          diferenciaPorcentaje: 0.0,
          estado: EstadoLectura.normal,
          rssi: -65, // Válido
        ),
        isTrue,
      );
    });

    test('10. Mapeo exhaustivo de estados provenientes del firmware', () {
      expect(EstadoLectura.fromString('NORMAL'), EstadoLectura.normal);
      expect(EstadoLectura.fromString('normal'), EstadoLectura.normal);
      expect(EstadoLectura.fromString('DESVIACION'), EstadoLectura.desviacion);
      expect(EstadoLectura.fromString('DESVIACIÓN'), EstadoLectura.desviacion);
      expect(EstadoLectura.fromString('FUGA'), EstadoLectura.fuga);
      expect(EstadoLectura.fromString('fuga'), EstadoLectura.fuga);
      expect(EstadoLectura.fromString('SIN_FLUJO'), EstadoLectura.sinFlujo);
      expect(EstadoLectura.fromString('SIN FLUJO'), EstadoLectura.sinFlujo);
      expect(EstadoLectura.fromString('VALOR_DESCONOCIDO'), EstadoLectura.desconocido);
      expect(EstadoLectura.fromString(null), EstadoLectura.desconocido);
    });

    test('11. Formateo de fecha y hora única en zona horaria de Lima (UTC-5)', () {
      final tiempoUtc = DateTime.utc(2026, 11, 8, 17, 30, 45);

      final lectura = Lectura(
        dispositivo: 'ESP32',
        caudalEntrada: 10.0,
        caudalSalida: 9.8,
        diferenciaLMin: 0.2,
        diferenciaPorcentaje: 2.0,
        volumenEntrada: 100.0,
        volumenSalida: 98.0,
        estado: EstadoLectura.normal,
        timestamp: tiempoUtc,
      );

      expect(lectura.horaLimaFormateada, '12:30:45');
      expect(lectura.fechaHoraLimaFormateada, '08/11/2026 12:30:45 (Lima, UTC-5)');
    });
  });
}
