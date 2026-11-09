import 'package:flutter_test/flutter_test.dart';
import 'package:fugas_g2/models/estado_lectura.dart';
import 'package:fugas_g2/models/lectura.dart';

void main() {
  group('Pruebas unitarias de parseo de Lectura', () {
    test('1. Mensaje válido completo con todos los campos de telemetría', () {
      const jsonStr = '''
      {
        "dispositivo": "ESP32_G2_RIEDO",
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
      expect(lectura!.dispositivo, 'ESP32_G2_RIEDO');
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

      expect(lectura, isNull, reason: 'El mensaje de inicio del ESP32 no es telemetría y debe ignorarse');
      expect(Lectura.tryFromJson(const {'mensaje': 'ESP32 conectado'}), isNull);
    });

    test('4. Mensaje sin caudal_entrada es ignorado (retorna null o FormatException en fromJson)', () {
      const payloadSinCaudalEntrada = '''
      {
        "dispositivo": "ESP32_G2",
        "caudal_salida": 5.0,
        "estado": "NORMAL",
        "rssi": -70
      }
      ''';

      expect(Lectura.fromRawJson(payloadSinCaudalEntrada), isNull);
      expect(
        () => Lectura.fromJson(const {
          'dispositivo': 'ESP32_G2',
          'caudal_salida': 5.0,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('5. Tolerancia a campos opcionales ausentes con valores por defecto seguros', () {
      const jsonMinimo = '{"caudal_entrada": 8.4}';

      final lectura = Lectura.fromRawJson(jsonMinimo);

      expect(lectura, isNotNull);
      expect(lectura!.caudalEntrada, 8.4);
      expect(lectura.caudalSalida, 0.0);
      expect(lectura.diferenciaLMin, 8.4);
      expect(lectura.volumenEntrada, 0.0);
      expect(lectura.volumenSalida, 0.0);
      expect(lectura.estado, EstadoLectura.desconocido);
      expect(lectura.rssi, isNull);
      expect(lectura.dispositivo, 'ESP32_G2');
    });

    test('6. Mapeo exhaustivo de estados provenientes del firmware', () {
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

    test('7. Tolerancia a valores numéricos enviados como String', () {
      const jsonConStrings = '''
      {
        "caudal_entrada": "15.75",
        "caudal_salida": "12.25",
        "diferencia_l_min": "3.50",
        "diferencia_porcentaje": "22.2",
        "volumen_entrada": "50.0",
        "volumen_salida": "45.0",
        "estado": "DESVIACION",
        "rssi": "-75"
      }
      ''';

      final lectura = Lectura.fromRawJson(jsonConStrings);

      expect(lectura, isNotNull);
      expect(lectura!.caudalEntrada, 15.75);
      expect(lectura.caudalSalida, 12.25);
      expect(lectura.diferenciaLMin, 3.5);
      expect(lectura.rssi, -75);
    });

    test('8. Formateo de fecha y hora en zona horaria de Lima (UTC-5)', () {
      // 17:30:45 UTC corresponde a 12:30:45 en Lima (UTC-5)
      final tiempoUtc = DateTime.utc(2026, 11, 8, 17, 30, 45);

      final lectura = Lectura(
        dispositivo: 'ESP32_G2',
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
      expect(lectura.fechaHoraLimaFormateada, contains('08/11/2026 12:30:45 (UTC-5)'));
    });
  });
}

