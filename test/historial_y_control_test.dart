import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fugas_g2/constants/mqtt_topicos.dart';
import 'package:fugas_g2/models/estado_lectura.dart';
import 'package:fugas_g2/providers/telemetria_provider.dart';
import 'package:fugas_g2/services/mqtt_service.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:typed_data/typed_data.dart' as typed;

/// Registro de publicaciones capturadas en el cliente simulado.
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
/// No utiliza clases internas complejas de la librería mqtt_client.
class MockMqttClientWrapper implements IMqttClientWrapper {
  final List<PublicacionRegistro> publicaciones = [];
  bool _conectado = false;

  @override
  Stream<List<MqttReceivedMessage<MqttMessage>>>? get updates => null;

  @override
  bool get estaConectado => _conectado;

  @override
  Future<bool> conectar({
    required String host,
    required int puerto,
    required String clientId,
    String? usuario,
    String? password,
    bool usarTls = false,
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

      final decoded = jsonDecode(pub.payloadStr);
      expect(decoded, {'orden': 'PAUSAR'});
    });

    test('Publicar orden REANUDAR genera el JSON y el tópico correctos con QoS 1', () async {
      final exito = await mqttService.publicarComando('REANUDAR');

      expect(exito, isTrue);
      expect(mockClient.publicaciones.length, 1);

      final pub = mockClient.publicaciones.first;
      expect(pub.topico, MqttTopicos.comando);
      expect(pub.qos, MqttQos.atLeastOnce); // QoS 1
      expect(pub.retain, isFalse);

      final decoded = jsonDecode(pub.payloadStr);
      expect(decoded, {'orden': 'REANUDAR'});
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
      provider = TelemetriaProvider(mqttService: mqttService);
      await provider.conectar(host: '127.0.0.1', puerto: 1883);
    });

    tearDown(() {
      provider.dispose();
    });

    test('1. Historial de cambios: solo se registra cuando el estado cambia', () async {
      expect(provider.historialCambiosEstado, isEmpty);

      // Usamos el método público del servicio sin clases internas de mqtt_client
      mqttService.procesarMensajeRecibido(
        MqttTopicos.telemetria,
        jsonEncode({
          'dispositivo': 'ESP32',
          'caudal_entrada': 10.0,
          'caudal_salida': 9.8,
          'diferencia_porcentaje': 2.0,
          'estado': 'NORMAL',
        }),
      );

      // Mismo estado NORMAL -> no debe agregar historial
      mqttService.procesarMensajeRecibido(
        MqttTopicos.telemetria,
        jsonEncode({
          'dispositivo': 'ESP32',
          'caudal_entrada': 10.2,
          'caudal_salida': 9.9,
          'diferencia_porcentaje': 2.1,
          'estado': 'NORMAL',
        }),
      );

      // Cambio a DESVIACION -> agrega 1er evento
      mqttService.procesarMensajeRecibido(
        MqttTopicos.telemetria,
        jsonEncode({
          'dispositivo': 'ESP32',
          'caudal_entrada': 12.0,
          'caudal_salida': 9.8,
          'diferencia_porcentaje': 18.3,
          'estado': 'DESVIACION',
        }),
      );

      // Mismo estado DESVIACION -> no debe agregar historial
      mqttService.procesarMensajeRecibido(
        MqttTopicos.telemetria,
        jsonEncode({
          'dispositivo': 'ESP32',
          'caudal_entrada': 12.1,
          'caudal_salida': 9.9,
          'diferencia_porcentaje': 18.1,
          'estado': 'DESVIACION',
        }),
      );

      // Cambio a FUGA -> agrega 2do evento
      mqttService.procesarMensajeRecibido(
        MqttTopicos.telemetria,
        jsonEncode({
          'dispositivo': 'ESP32',
          'caudal_entrada': 14.0,
          'caudal_salida': 7.0,
          'diferencia_porcentaje': 50.0,
          'estado': 'FUGA',
        }),
      );

      await Future.delayed(const Duration(milliseconds: 50));

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
      for (int i = 0; i < 250; i++) {
        final estado = i % 2 == 0 ? 'NORMAL' : 'DESVIACION';
        mqttService.procesarMensajeRecibido(
          MqttTopicos.telemetria,
          jsonEncode({
            'dispositivo': 'ESP32',
            'caudal_entrada': 10.0 + (i % 5),
            'caudal_salida': 9.0,
            'diferencia_porcentaje': i % 2 == 0 ? 5.0 : 20.0,
            'estado': estado,
          }),
        );
      }

      await Future.delayed(const Duration(milliseconds: 100));

      expect(provider.historialCambiosEstado.length, 200);

      provider.limpiarHistorialCambios();
      expect(provider.historialCambiosEstado, isEmpty);
    });

    test('3. Lógica de "sin confirmar" tras timeout inyectado sin fakeAsync', () async {
      // Inyección de timeout de 50 ms para pruebas rápidas y deterministas
      final providerConTimeoutCorto = TelemetriaProvider(
        mqttService: mqttService,
        timeoutConfirmacion: const Duration(milliseconds: 50),
      );

      expect(providerConTimeoutCorto.esperandoConfirmacion, isFalse);
      expect(providerConTimeoutCorto.confirmacionExpirada, isFalse);

      await providerConTimeoutCorto.enviarOrden('PAUSAR');

      expect(providerConTimeoutCorto.esperandoConfirmacion, isTrue);
      expect(providerConTimeoutCorto.confirmacionExpirada, isFalse);
      expect(providerConTimeoutCorto.ordenPendiente, 'PAUSAR');

      // Esperar 120 ms (supera el umbral inyectado de 50 ms)
      await Future.delayed(const Duration(milliseconds: 120));

      expect(providerConTimeoutCorto.esperandoConfirmacion, isFalse);
      expect(providerConTimeoutCorto.confirmacionExpirada, isTrue);

      providerConTimeoutCorto.dispose();
    });

    test('4. Confirmación exitosa en tópico equipo dentro del tiempo cancela timeout', () async {
      final providerConTimeoutCorto = TelemetriaProvider(
        mqttService: mqttService,
        timeoutConfirmacion: const Duration(milliseconds: 50),
      );

      await providerConTimeoutCorto.enviarOrden('PAUSAR');
      expect(providerConTimeoutCorto.esperandoConfirmacion, isTrue);

      // Recepción pública directa sin clases internas de mqtt_client
      mqttService.procesarMensajeRecibido(
        MqttTopicos.equipo,
        jsonEncode({'activo': false}),
      );

      await Future.delayed(const Duration(milliseconds: 10));

      expect(providerConTimeoutCorto.esperandoConfirmacion, isFalse);
      expect(providerConTimeoutCorto.confirmacionExpirada, isFalse);
      expect(providerConTimeoutCorto.equipoActivo, isFalse);

      // Esperar que transcurran 120 ms adicionales para comprobar que el timeout fue cancelado
      await Future.delayed(const Duration(milliseconds: 120));
      expect(providerConTimeoutCorto.confirmacionExpirada, isFalse);

      providerConTimeoutCorto.dispose();
    });
  });
}
