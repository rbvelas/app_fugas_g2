import 'package:flutter_test/flutter_test.dart';
import 'package:fugas_g2/models/estado_lectura.dart';
import 'package:fugas_g2/utils/formato_numeros.dart';
import 'package:fugas_g2/utils/formato_tiempo.dart';
import 'package:fugas_g2/utils/senal_wifi.dart';

void main() {
  group('Textos de tiempo en lenguaje natural', () {
    final ahora = DateTime.utc(2026, 11, 9, 18, 0, 0);

    test('Antigüedad en segundos, minutos, horas y días', () {
      expect(
        antiguedadRelativa(
          ahora.subtract(const Duration(seconds: 2)),
          ahora: ahora,
        ),
        'hace 2 s',
      );
      expect(
        antiguedadRelativa(
          ahora.subtract(const Duration(seconds: 65)),
          ahora: ahora,
        ),
        'hace 1 min',
      );
      expect(
        antiguedadRelativa(
          ahora.subtract(const Duration(hours: 3)),
          ahora: ahora,
        ),
        'hace 3 h',
      );
      expect(
        antiguedadRelativa(
          ahora.subtract(const Duration(days: 2)),
          ahora: ahora,
        ),
        'hace 2 d',
      );
    });

    test('Duraciones breves para el historial', () {
      expect(formatearDuracion(const Duration(seconds: 45)), '45 s');
      expect(formatearDuracion(const Duration(minutes: 3)), '3 min');
      expect(
        formatearDuracion(const Duration(hours: 1, minutes: 20)),
        '1 h 20 min',
      );
    });

    test('Hora corta de Lima (UTC-5)', () {
      expect(horaCortaLima(DateTime.utc(2026, 11, 9, 17, 30, 45)), '12:30:45');
    });
  });

  group('Señal WiFi cualitativa', () {
    test('Umbrales orientativos: Buena, Regular y Débil', () {
      expect(SenalWifi.clasificar(-55), CalidadSenal.buena);
      expect(SenalWifi.clasificar(-60), CalidadSenal.buena);
      expect(SenalWifi.clasificar(-61), CalidadSenal.regular);
      expect(SenalWifi.clasificar(-75), CalidadSenal.regular);
      expect(SenalWifi.clasificar(-76), CalidadSenal.debil);
      expect(SenalWifi.clasificar(null), CalidadSenal.desconocida);
    });

    test('Etiquetas visibles', () {
      expect(SenalWifi.etiqueta(CalidadSenal.buena), 'Buena');
      expect(SenalWifi.etiqueta(CalidadSenal.regular), 'Regular');
      expect(SenalWifi.etiqueta(CalidadSenal.debil), 'Débil');
      expect(SenalWifi.etiqueta(CalidadSenal.desconocida), 'Sin datos');
    });
  });

  group('Nombres consistentes de estados', () {
    test('Se usa "Fuga" y no "Fuga crítica"', () {
      expect(EstadoLectura.fuga.etiqueta, 'Fuga');
      expect(EstadoLectura.desviacion.etiqueta, 'Desviación');
      expect(EstadoLectura.sinFlujo.etiqueta, 'Sin flujo');
      expect(EstadoLectura.normal.etiqueta, 'Normal');
      expect(EstadoLectura.fuga.etiqueta.contains('crítica'), isFalse);
    });

    test('Etiquetas de la diferencia: normal, revisar y fuga', () {
      expect(EstadoLectura.normal.etiquetaDiferencia, 'Normal');
      expect(EstadoLectura.desviacion.etiquetaDiferencia, 'Revisar');
      expect(EstadoLectura.fuga.etiquetaDiferencia, 'Fuga');
    });
  });

  group('Formato numérico en español', () {
    test('Coma decimal y porcentaje', () {
      expect(numeroConComa(12.5), '12,50');
      expect(numeroConComa(12.5, decimales: 1), '12,5');
      expect(porcentajeConComa(18.3), '18,3 %');
    });
  });
}
