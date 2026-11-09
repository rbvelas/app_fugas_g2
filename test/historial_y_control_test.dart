import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fugas_g2/constants/mqtt_topicos.dart';
import 'package:fugas_g2/models/conexion_estado.dart';
import 'package:fugas_g2/models/estado_lectura.dart';
import 'package:fugas_g2/providers/telemetria_provider.dart';
import 'package:fugas_g2/services/mqtt_service.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:typed_data/typed_data.dart' as typed;

/// Registro de publicaciones para pruebas con cliente MQTT simulado.
class PublicacionRegistro {
  final String topico;
  final MqttQos qos;
  final String payloadStr;
  final bool retain;

  PublicacionRegistro({
    required this.topico,
    required this.qos,
    required this.payloadStr,
    required this.retain,
  });
}

/// Cliente MQTT simulado que no requiere conexión de red ni broker EMQX real.
class MockMqttClientWrapper implements IMqttClientWrapper {
  final List<PublicacionRegistro> publicaciones = [];

  bool _conectado = false;

  @override
  bool get estaConectado => _conectado;

  @override
  Future<bool> conectar({
    required String host,
    required int puerto,
    required String clientId,
    String? usuario,
    String? password,
    void Function(String topico, String payload)? onMessage,
    void Function()? onConnected,
    void Function()? onDisconnected,
    void Function()? onAutoReconnected,
  }) async {
    _conectado = true;
    onConnected?.call();
    return true;
  }

  @override
  void desconectar() {
    _conectado = false;
  }

  @override
  void suscribir(String topico, MqttQos qos) {}

  @override
  int? publicarMensaje(String topico, MqttQos qos, typed.Uint8Buffer data, {bool retain = false}) {
    final payloadStr = utf8.decode(data);
    publicaciones.add(PublicacionRegistro(
      topico: topico,
      qos: qos,
      payloadStr: payloadStr,
      retain: retain,
    ));
    return publicaciones.length;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pruebas unitarias de MqttService con cliente simulado (sin broker real)', () {
    late MockMqttClientWrapper mockClient;
    late MqttService mqttService;

    setUp(() async {
      mockClient = MockMqttClientWrapper();
      mqttService = MqttService(clientWrapper: mockClient);
      await mqttService.conectar(host: '127.0.0.1', puerto: 1883);
    });

    tearDown(() {
      mqttService.dispose();
    });

    test('Publicar orden PAUSAR genera el JSON y el tópico correctos con QoS 1', () async {
      final exito = await mqttService.publicarComando('PAUSAR');

      expect(exito, isTrue);
      expect(mockClient.publicaciones.length, 1);

      final pub = mockClient.publicaciones.first;
      expect(pub.topico, MqttTopicos.comando);
      expect(pub.qos, MqttQos.atLeastOnce); // QoS 1
      expect(pub.retain, isFalse);

      expect(pub.payloadStr, '{"orden":"PAUSAR"}');
    });

    test('Publicar orden REANUDAR genera el JSON y el tópico correctos con QoS 1', () async {
      final exito = await mqttService.publicarComando('REANUDAR');

      expect(exito, isTrue);
      expect(mockClient.publicaciones.length, 1);

      final pub = mockClient.publicaciones.first;
      expect(pub.topico, MqttTopicos.comando);
      expect(pub.qos, MqttQos.atLeastOnce); // QoS 1
      expect(pub.retain, isFalse);

      expect(pub.payloadStr, '{"orden":"REANUDAR"}');
    });

    test('Publicar orden no permitida lanza ArgumentError', () async {
      expect(
        () => mqttService.publicarComando('ORDEN_INVALIDA'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Pruebas unitarias de TelemetriaProvider (Historial y Control)', () {
    late MockMqttClientWrapper mockClient;
    late MqttService mqttService;
    late TelemetriaProvider provider;

    setUp(() async {
      mockClient = MockMqttClientWrapper();
      mqttService = MqttService(clientWrapper: mockClient);
      provider = TelemetriaProvider(
        mqttService: mqttService,
        duracionTimeoutConfirmacion: const Duration(milliseconds: 50),
      );
      await provider.conectar(host: '127.0.0.1', puerto: 1883);
    });

    tearDown(() {
      provider.dispose();
    });

    test('1. Historial de cambios: solo se registra cuando el estado cambia', () async {
      expect(provider.historialCambiosEstado, isEmpty);

      final rawL1 = jsonEncode({
        'dispositivo': 'ESP32_TEST',
        'caudal_entrada': 10.0,
        'caudal_salida': 9.8,
        'estado': 'NORMAL',
      });
      final rawL2 = jsonEncode({
        'dispositivo': 'ESP32_TEST',
        'caudal_entrada': 10.2,
        'caudal_salida': 9.9,
        'estado': 'NORMAL',
      });
      final rawL3 = jsonEncode({
        'dispositivo': 'ESP32_TEST',
        'caudal_entrada': 12.0,
        'caudal_salida': 9.8,
        'diferencia_porcentaje': 18.3,
        'estado': 'DESVIACION',
      });
      final rawL4 = jsonEncode({
        'dispositivo': 'ESP32_TEST',
        'caudal_entrada': 12.1,
        'caudal_salida': 9.9,
        'diferencia_porcentaje': 18.1,
        'estado': 'DESVIACION',
      });
      final rawL5 = jsonEncode({
        'dispositivo': 'ESP32_TEST',
        'caudal_entrada': 14.0,
        'caudal_salida': 7.0,
        'diferencia_porcentaje': 50.0,
        'estado': 'FUGA',
      });

      mqttService.procesarMensajeRecibido(MqttTopicos.telemetria, rawL1);
      mqttService.procesarMensajeRecibido(MqttTopicos.telemetria, rawL2);
      mqttService.procesarMensajeRecibido(MqttTopicos.telemetria, rawL3);
      mqttService.procesarMensajeRecibido(MqttTopicos.telemetria, rawL4);
      mqttService.procesarMensajeRecibido(MqttTopicos.telemetria, rawL5);
      await Future<void>.delayed(Duration.zero);

      expect(provider.historialCambiosEstado.length, 2,
          reason: 'Solo deben registrarse 2 eventos: NORMAL->DESVIACION y DESVIACION->FUGA');

      final primerEvento = provider.historialCambiosEstado[0];
      expect(primerEvento.estadoAnterior, EstadoLectura.normal);
      expect(primerEvento.estadoNuevo, EstadoLectura.desviacion);
      expect(primerEvento.diferenciaPorcentaje, 18.3);

      final segundoEvento = provider.historialCambiosEstado[1];
      expect(segundoEvento.estadoAnterior, EstadoLectura.desviacion);
      expect(segundoEvento.estadoNuevo, EstadoLectura.fuga);
      expect(segundoEvento.diferenciaPorcentaje, 50.0);
    });

    test('2. Historial de cambios respeta el tope máximo de 200 entradas', () async {
      void emitirMensajeTelemetria(String estado, int indice) {
        final jsonStr = jsonEncode({
          'dispositivo': 'ESP32_TEST',
          'caudal_entrada': 10.0 + indice,
          'caudal_salida': 9.0,
          'estado': estado,
        });
        mqttService.procesarMensajeRecibido(MqttTopicos.telemetria, jsonStr);
      }

      // Generar 250 alternancias de estado (NORMAL <-> DESVIACION)
      for (int i = 0; i < 250; i++) {
        final estado = i % 2 == 0 ? 'NORMAL' : 'DESVIACION';
        emitirMensajeTelemetria(estado, i);
      }

      await Future<void>.delayed(Duration.zero);

      // El total de cambios no debe exceder 200
      expect(provider.historialCambiosEstado.length, 200);

      // El botón de limpiar vacía el historial
      provider.limpiarHistorialCambios();
      expect(provider.historialCambiosEstado, isEmpty);
    });

    test('3. Lógica de "sin confirmar" después del timeout configurado', () async {
      expect(provider.esperandoConfirmacion, isFalse);
      expect(provider.confirmacionExpirada, isFalse);

      expect(await provider.enviarOrden('PAUSAR'), isTrue);
      expect(provider.esperandoConfirmacion, isTrue);
      expect(provider.confirmacionExpirada, isFalse);
      expect(provider.ordenPendiente, 'PAUSAR');

      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(provider.esperandoConfirmacion, isFalse);
      expect(provider.confirmacionExpirada, isTrue);
    });

    test('4. Confirmación exitosa en tópico equipo cancela timeout', () async {
      expect(await provider.enviarOrden('PAUSAR'), isTrue);
      expect(provider.esperandoConfirmacion, isTrue);

      mqttService.procesarMensajeRecibido(
        MqttTopicos.equipo,
        jsonEncode({'activo': false}),
      );
      await Future<void>.delayed(Duration.zero);

      expect(provider.esperandoConfirmacion, isFalse);
      expect(provider.confirmacionExpirada, isFalse);
      expect(provider.equipoActivo, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(provider.confirmacionExpirada, isFalse);
    });
  });
}
