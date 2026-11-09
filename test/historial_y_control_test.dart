import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fugas_g2/constants/mqtt_topicos.dart';
import 'package:fugas_g2/models/conexion_estado.dart';
import 'package:fugas_g2/models/estado_lectura.dart';
import 'package:fugas_g2/models/lectura.dart';
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
  final StreamController<List<MqttReceivedMessage<MqttMessage>>> _updatesController =
      StreamController<List<MqttReceivedMessage<MqttMessage>>>.broadcast();

  bool _conectado = false;

  @override
  Stream<List<MqttReceivedMessage<MqttMessage>>> get updates => _updatesController.stream;

  @override
  bool get estaConectado => _conectado;

  @override
  Future<bool> conectar({
    required String host,
    required int puerto,
    required String clientId,
    String? usuario,
    String? password,
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

  void dispose() {
    _updatesController.close();
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
      mockClient.dispose();
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
      mockClient.dispose();
    });

    Lectura crearLectura(EstadoLectura estado, {double qe = 10.0, double qs = 9.8, double difPorc = 2.0}) {
      return Lectura(
        dispositivo: 'ESP32_TEST',
        caudalEntrada: qe,
        caudalSalida: qs,
        diferenciaLMin: (qe - qs).abs(),
        diferenciaPorcentaje: difPorc,
        volumenEntrada: 100.0,
        volumenSalida: 98.0,
        estado: estado,
        timestamp: DateTime.now(),
      );
    }

    test('1. Historial de cambios: solo se registra cuando el estado cambia', () {
      expect(provider.historialCambiosEstado, isEmpty);

      // Primera lectura: inicializa estado anterior, no hay transición previa
      // Se alimenta simulando evento en el servicio
      mqttService.lecturasStream; // activa listen
      
      // Simulamos llegadas secuenciales mediante método directo a través de lecturasStream
      // Primera lectura NORMAL
      final l1 = crearLectura(EstadoLectura.normal);
      // Segunda lectura NORMAL (mismo estado)
      final l2 = crearLectura(EstadoLectura.normal);
      // Tercera lectura DESVIACION (cambio de estado)
      final l3 = crearLectura(EstadoLectura.desviacion, qe: 12.0, qs: 9.8, difPorc: 18.3);
      // Cuarta lectura DESVIACION (mismo estado)
      final l4 = crearLectura(EstadoLectura.desviacion, qe: 12.1, qs: 9.9, difPorc: 18.1);
      // Quinta lectura FUGA (cambio de estado)
      final l5 = crearLectura(EstadoLectura.fuga, qe: 14.0, qs: 7.0, difPorc: 50.0);

      // Enviamos a través de provider emulando stream
      // Usamos el cliente mock para inyectar si fuera necesario, o invocando la lógica
      // Para probar la lógica de provider de forma exacta:
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

      // Alimentar via process
      // Simulamos mensaje MQTT entrante en tópico telemetria
      // Creamos mensajes MqttPublishMessage simulados:
      void emitirMensajeTelemetria(String jsonStr) {
        final bytes = utf8.encode(jsonStr);
        final header = MqttHeader()..type = MqttMessageType.publish;
        final variableHeader = MqttPublishVariableHeader()..topicName = MqttTopicos.telemetria;
        final payload = MqttPublishPayload()..message = (typed.Uint8Buffer()..addAll(bytes));
        final pubMsg = MqttPublishMessage(header, variableHeader, payload);
        mockClient._updatesController.add([
          MqttReceivedMessage<MqttMessage>(MqttTopicos.telemetria, pubMsg),
        ]);
      }

      emitirMensajeTelemetria(rawL1);
      emitirMensajeTelemetria(rawL2);
      emitirMensajeTelemetria(rawL3);
      emitirMensajeTelemetria(rawL4);
      emitirMensajeTelemetria(rawL5);

      // Esperar breve tick de microtask para que los streams procesen
      return Future.delayed(const Duration(milliseconds: 50), () {
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
    });

    test('2. Historial de cambios respeta el tope máximo de 200 entradas', () async {
      void emitirMensajeTelemetria(String estado, int indice) {
        final jsonStr = jsonEncode({
          'dispositivo': 'ESP32_TEST',
          'caudal_entrada': 10.0 + indice,
          'caudal_salida': 9.0,
          'estado': estado,
        });
        final bytes = utf8.encode(jsonStr);
        final header = MqttHeader()..type = MqttMessageType.publish;
        final variableHeader = MqttPublishVariableHeader()..topicName = MqttTopicos.telemetria;
        final payload = MqttPublishPayload()..message = (typed.Uint8Buffer()..addAll(bytes));
        final pubMsg = MqttPublishMessage(header, variableHeader, payload);
        mockClient._updatesController.add([
          MqttReceivedMessage<MqttMessage>(MqttTopicos.telemetria, pubMsg),
        ]);
      }

      // Generar 250 alternancias de estado (NORMAL <-> DESVIACION)
      for (int i = 0; i < 250; i++) {
        final estado = i % 2 == 0 ? 'NORMAL' : 'DESVIACION';
        emitirMensajeTelemetria(estado, i);
      }

      await Future.delayed(const Duration(milliseconds: 100));

      // El total de cambios no debe exceder 200
      expect(provider.historialCambiosEstado.length, 200);

      // El botón de limpiar vacía el historial
      provider.limpiarHistorialCambios();
      expect(provider.historialCambiosEstado, isEmpty);
    });

    test('3. Lógica de "sin confirmar" tras enviar orden si pasan 5 segundos sin confirmación', () {
      fakeAsync((async) {
        expect(provider.esperandoConfirmacion, isFalse);
        expect(provider.confirmacionExpirada, isFalse);

        // Enviar orden PAUSAR
        provider.enviarOrden('PAUSAR');

        expect(provider.esperandoConfirmacion, isTrue);
        expect(provider.confirmacionExpirada, isFalse);
        expect(provider.ordenPendiente, 'PAUSAR');

        // Avanzar el tiempo 4 segundos (aún esperando)
        async.elapse(const Duration(seconds: 4));
        expect(provider.esperandoConfirmacion, isTrue);
        expect(provider.confirmacionExpirada, isFalse);

        // Avanzar 1.1 segundos más (supera los 5 segundos de umbral)
        async.elapse(const Duration(milliseconds: 1100));

        // Debe expirar y marcar "sin confirmar"
        expect(provider.esperandoConfirmacion, isFalse);
        expect(provider.confirmacionExpirada, isTrue);
      });
    });

    test('4. Confirmación exitosa en tópico equipo dentro de los 5 segundos cancela timeout', () {
      fakeAsync((async) {
        provider.enviarOrden('PAUSAR');
        expect(provider.esperandoConfirmacion, isTrue);

        // Simulamos respuesta retained en unt/iot/g2/riego/equipo: {"activo": false}
        final jsonEquipo = jsonEncode({'activo': false});
        final bytes = utf8.encode(jsonEquipo);
        final header = MqttHeader()..type = MqttMessageType.publish;
        final variableHeader = MqttPublishVariableHeader()..topicName = MqttTopicos.equipo;
        final payload = MqttPublishPayload()..message = (typed.Uint8Buffer()..addAll(bytes));
        final pubMsg = MqttPublishMessage(header, variableHeader, payload);
        mockClient._updatesController.add([
          MqttReceivedMessage<MqttMessage>(MqttTopicos.equipo, pubMsg),
        ]);

        async.elapse(const Duration(milliseconds: 100));

        // Confirmado exitosamente
        expect(provider.esperandoConfirmacion, isFalse);
        expect(provider.confirmacionExpirada, isFalse);
        expect(provider.equipoActivo, isFalse);

        // Si avanza 10 segundos más, no debe marcar sin confirmar
        async.elapse(const Duration(seconds: 10));
        expect(provider.confirmacionExpirada, isFalse);
      });
    });
  });
}

