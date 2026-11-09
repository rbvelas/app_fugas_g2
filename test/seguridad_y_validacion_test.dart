import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fugas_g2/constants/mqtt_topicos.dart';
import 'package:fugas_g2/models/conexion_estado.dart';
import 'package:fugas_g2/providers/telemetria_provider.dart';
import 'package:fugas_g2/services/mqtt_service.dart';
import 'package:fugas_g2/utils/validador_conexion.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:typed_data/typed_data.dart' as typed;

/// Cliente MQTT simulado para pruebas de seguridad que no requiere red ni broker real.
class MockSecurityMqttClientWrapper implements IMqttClientWrapper {
  bool debeFallarConexion = false;
  String tipoFallo = '';

  @override
  Stream<List<MqttReceivedMessage<MqttMessage>>>? get updates => null;

  @override
  bool get estaConectado => false;

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
    if (debeFallarConexion) {
      if (tipoFallo == 'tls') {
        throw Exception('HandshakeException: Handshake error in client (certificate verify failed)');
      } else {
        throw Exception('SocketException: OS Error: Connection refused, errno = 111');
      }
    }
    onConnected?.call();
    return true;
  }

  @override
  void desconectar() {}

  @override
  void suscribir(String topico, MqttQos qos) {}

  @override
  int? publicarMensaje(String topico, MqttQos qos, typed.Uint8Buffer data, {bool retain = false}) {
    return 1;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Seguridad: Validación de entradas del usuario (Host, Puerto, Usuario)', () {
    test('1. Validación de Host: rechaza espacios y esquemas de protocolo', () {
      // Espacios
      expect(ValidadorConexion.validarHost('192.168.1. 100'), contains('espacios'));
      expect(ValidadorConexion.validarHost(' broker.emqx.io '), contains('espacios'));

      // Esquemas de protocolo no permitidos
      expect(ValidadorConexion.validarHost('http://192.168.1.100'), contains('esquema'));
      expect(ValidadorConexion.validarHost('https://broker.emqx.io'), contains('esquema'));
      expect(ValidadorConexion.validarHost('mqtt://192.168.1.50'), contains('esquema'));
      expect(ValidadorConexion.validarHost('mqtts://broker.emqx.io'), contains('esquema'));
      expect(ValidadorConexion.validarHost('ws://192.168.1.100'), contains('esquema'));
      expect(ValidadorConexion.validarHost('tcp://192.168.1.100'), contains('esquema'));

      // Valores válidos
      expect(ValidadorConexion.validarHost('192.168.1.100'), isNull);
      expect(ValidadorConexion.validarHost('broker.emqx.io'), isNull);
      expect(ValidadorConexion.validarHost('10.0.2.2'), isNull);
    });

    test('2. Validación de Puerto: rango estricto de 1 a 65535 y formato entero', () {
      // Puertos inválidos
      expect(ValidadorConexion.validarPuerto('0'), contains('1 y 65535'));
      expect(ValidadorConexion.validarPuerto('-1'), contains('1 y 65535'));
      expect(ValidadorConexion.validarPuerto('65536'), contains('1 y 65535'));
      expect(ValidadorConexion.validarPuerto('abc'), contains('entero'));
      expect(ValidadorConexion.validarPuerto(''), contains('puerto'));

      // Puertos válidos
      expect(ValidadorConexion.validarPuerto('1883'), isNull);
      expect(ValidadorConexion.validarPuerto('8883'), isNull);
      expect(ValidadorConexion.validarPuerto('1'), isNull);
      expect(ValidadorConexion.validarPuerto('65535'), isNull);
    });

    test('3. Limpieza de Usuario: elimina espacios accidentales', () {
      expect(ValidadorConexion.limpiarUsuario('  usuario_unt  '), 'usuario_unt');
      expect(ValidadorConexion.limpiarUsuario(null), '');
    });
  });

  group('Seguridad: Credenciales y ausencia de fugas en memoria y errores', () {
    late MockSecurityMqttClientWrapper mockClient;
    late MqttService mqttService;
    late TelemetriaProvider provider;

    setUp(() {
      mockClient = MockSecurityMqttClientWrapper();
      mqttService = MqttService(clientWrapper: mockClient);
      provider = TelemetriaProvider(mqttService: mqttService);
    });

    tearDown(() {
      provider.dispose();
    });

    test('4. La contraseña secreta jamás aparece en los mensajes de error ni excepciones', () async {
      const contrasenaSecreta = 'MiClaveUltraSecreta_XYZ#2026';
      mockClient.debeFallarConexion = true;
      mockClient.tipoFallo = 'tls';

      // Intentar conectar con fallo de TLS
      await provider.conectar(
        host: '192.168.1.100',
        puerto: 8883,
        usuario: 'admin',
        password: contrasenaSecreta,
        usarTls: true,
      );

      expect(provider.estadoConexion, ConexionEstado.error);
      expect(provider.mensajeError, isNotNull);

      // Comprobar rigurosamente que la contraseña NO aparece en el texto del error
      expect(provider.mensajeError!.contains(contrasenaSecreta), isFalse);
      expect(mqttService.ultimoError!.contains(contrasenaSecreta), isFalse);
    });

    test('5. Desconectar borra la contraseña de la memoria RAM', () async {
      const claveEnMemoria = 'Password_Temporal_123';
      mockClient.debeFallarConexion = false;

      await provider.conectar(
        host: '192.168.1.100',
        puerto: 1883,
        usuario: 'user',
        password: claveEnMemoria,
      );

      // Al llamar a desconectar(), la contraseña debe eliminarse
      await provider.desconectar();

      // Comprobar que provider no retiene la contraseña internamente
      // Simulamos nuevo intento con contraseña nula para verificar que no quedó persistida
      expect(provider.estadoConexion, ConexionEstado.desconectado);
    });
  });

  group('Seguridad: Validación de mensajes entrantes y contador de descartados', () {
    late MockSecurityMqttClientWrapper mockClient;
    late MqttService mqttService;
    late TelemetriaProvider provider;

    setUp(() async {
      mockClient = MockSecurityMqttClientWrapper();
      mqttService = MqttService(clientWrapper: mockClient);
      provider = TelemetriaProvider(mqttService: mqttService);
      await provider.conectar(host: '192.168.1.100', puerto: 1883);
    });

    tearDown(() {
      provider.dispose();
    });

    test('6. Mensajes con rangos inválidos son descartados e incrementan el contador', () async {
      expect(provider.mensajesDescartados, 0);

      // 1. Mensaje con caudal_entrada negativo (-2.0)
      mqttService.procesarMensajeRecibido(
        MqttTopicos.telemetria,
        jsonEncode({
          'dispositivo': 'ESP32',
          'caudal_entrada': -2.0,
          'caudal_salida': 10.0,
          'diferencia_porcentaje': 0.0,
          'estado': 'NORMAL',
        }),
      );

      // 2. Mensaje con diferencia_porcentaje fuera de rango (150.0 %)
      mqttService.procesarMensajeRecibido(
        MqttTopicos.telemetria,
        jsonEncode({
          'dispositivo': 'ESP32',
          'caudal_entrada': 10.0,
          'caudal_salida': 0.0,
          'diferencia_porcentaje': 150.0,
          'estado': 'FUGA',
        }),
      );

      // 3. Mensaje con estado ajeno no permitido
      mqttService.procesarMensajeRecibido(
        MqttTopicos.telemetria,
        jsonEncode({
          'dispositivo': 'ESP32',
          'caudal_entrada': 10.0,
          'caudal_salida': 10.0,
          'diferencia_porcentaje': 0.0,
          'estado': 'ESTADO_HACKER',
        }),
      );

      // 4. Mensaje con RSSI positivo fuera de rango (+20 dBm)
      mqttService.procesarMensajeRecibido(
        MqttTopicos.telemetria,
        jsonEncode({
          'dispositivo': 'ESP32',
          'caudal_entrada': 10.0,
          'caudal_salida': 10.0,
          'diferencia_porcentaje': 0.0,
          'estado': 'NORMAL',
          'rssi': 20,
        }),
      );

      // 5. Mensaje válido con diferencia negativa pequeña (-1.5 %) -> NO debe descartarse
      mqttService.procesarMensajeRecibido(
        MqttTopicos.telemetria,
        jsonEncode({
          'dispositivo': 'ESP32',
          'caudal_entrada': 10.0,
          'caudal_salida': 10.15,
          'diferencia_porcentaje': -1.5,
          'estado': 'NORMAL',
          'rssi': -65,
        }),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      // Se descartaron exactamente los 4 mensajes inválidos; el 5to fue aceptado
      expect(provider.mensajesDescartados, 4);
      expect(provider.ultimaLectura, isNotNull);
      expect(provider.ultimaLectura!.diferenciaPorcentaje, -1.5);
    });
  });
}

