import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:typed_data/typed_data.dart' as typed;
import '../constants/mqtt_topicos.dart';
import '../models/conexion_estado.dart';
import '../models/lectura.dart';

/// Abstracción del cliente MQTT para permitir inyección de dependencias
/// y pruebas unitarias aisladas sin necesidad de un broker real.
abstract class IMqttClientWrapper {
  Stream<List<MqttReceivedMessage<MqttMessage>>>? get updates;
  bool get estaConectado;

  Future<bool> conectar({
    required String host,
    required int puerto,
    required String clientId,
    String? usuario,
    String? password,
    bool usarTls,
    void Function()? onConnected,
    void Function()? onDisconnected,
    void Function()? onAutoReconnected,
  });

  void desconectar();
  void suscribir(String topico, MqttQos qos);
  int? publicarMensaje(String topico, MqttQos qos, typed.Uint8Buffer data, {bool retain = false});
}

/// Implementación real basada en MqttServerClient sobre TCP (con o sin TLS).
class RealMqttClientWrapper implements IMqttClientWrapper {
  MqttServerClient? _client;

  @override
  Stream<List<MqttReceivedMessage<MqttMessage>>>? get updates => _client?.updates;

  @override
  bool get estaConectado =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

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
    final client = MqttServerClient.withPort(host.trim(), clientId, puerto);
    _client = client;

    client.keepAlivePeriod = 20;
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;
    client.logging(on: false);

    // Conexión segura TLS sin bypass de certificados
    client.secure = usarTls;
    if (usarTls) {
      client.securityContext = SecurityContext.defaultContext;
    }

    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
    client.onAutoReconnected = onAutoReconnected;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean();

    if (usuario != null && usuario.trim().isNotEmpty) {
      connMessage.authenticateAs(usuario.trim(), password ?? '');
    }

    client.connectionMessage = connMessage;

    try {
      final status = await client.connect();
      return status?.state == MqttConnectionState.connected;
    } catch (_) {
      client.disconnect();
      rethrow;
    }
  }

  @override
  void desconectar() {
    try {
      _client?.disconnect();
    } catch (_) {}
    _client = null;
  }

  @override
  void suscribir(String topico, MqttQos qos) {
    _client?.subscribe(topico, qos);
  }

  @override
  int? publicarMensaje(String topico, MqttQos qos, typed.Uint8Buffer data, {bool retain = false}) {
    return _client?.publishMessage(topico, qos, data, retain: retain);
  }
}

/// Servicio responsable exclusivamente de la comunicación MQTT con el broker EMQX.
/// Gestiona telemetría (QoS 0), confirmación de estado del equipo (retained)
/// y publicación de órdenes de control (QoS 1).
class MqttService {
  final IMqttClientWrapper _clientWrapper;

  ConexionEstado _estado = ConexionEstado.desconectado;
  String? _ultimoError;
  bool? _ultimoEstadoEquipo;
  String? _ultimoMensajeBruto;
  int _mensajesDescartados = 0;

  final StreamController<Lectura> _lecturasController =
      StreamController<Lectura>.broadcast();
  final StreamController<ConexionEstado> _estadoController =
      StreamController<ConexionEstado>.broadcast();
  final StreamController<bool> _equipoActivoController =
      StreamController<bool>.broadcast();
  final StreamController<String> _mensajesBrutosController =
      StreamController<String>.broadcast();
  final StreamController<int> _mensajesDescartadosController =
      StreamController<int>.broadcast();

  Stream<Lectura> get lecturasStream => _lecturasController.stream;
  Stream<ConexionEstado> get estadoStream => _estadoController.stream;
  Stream<bool> get equipoActivoStream => _equipoActivoController.stream;
  Stream<String> get mensajesBrutosStream => _mensajesBrutosController.stream;
  Stream<int> get mensajesDescartadosStream => _mensajesDescartadosController.stream;

  ConexionEstado get estado => _estado;
  String? get ultimoError => _ultimoError;
  bool? get ultimoEstadoEquipo => _ultimoEstadoEquipo;
  String? get ultimoMensajeBruto => _ultimoMensajeBruto;
  int get mensajesDescartados => _mensajesDescartados;

  MqttService({IMqttClientWrapper? clientWrapper})
      : _clientWrapper = clientWrapper ?? RealMqttClientWrapper();

  void _actualizarEstado(ConexionEstado nuevoEstado, [String? mensajeError]) {
    _estado = nuevoEstado;
    _ultimoError = mensajeError;
    if (!_estadoController.isClosed) {
      _estadoController.add(nuevoEstado);
    }
  }

  /// Conecta al broker MQTT según los parámetros especificados.
  /// La contraseña reside solo en memoria y no se incluye en logs ni mensajes de error.
  Future<bool> conectar({
    required String host,
    int puerto = 1883,
    String? usuario,
    String? password,
    bool usarTls = false,
  }) async {
    if (_clientWrapper.estaConectado) {
      await desconectar();
    }

    _actualizarEstado(ConexionEstado.conectando);

    final randomId = Random().nextInt(900000) + 100000;
    final clientId = 'aqualerta-app-$randomId';

    try {
      final conectado = await _clientWrapper.conectar(
        host: host,
        puerto: puerto,
        clientId: clientId,
        usuario: usuario,
        password: password,
        usarTls: usarTls,
        onConnected: () {
          _actualizarEstado(ConexionEstado.conectado);
          _clientWrapper.suscribir(MqttTopicos.telemetria, MqttQos.atMostOnce);
          _clientWrapper.suscribir(MqttTopicos.equipo, MqttQos.atLeastOnce);
        },
        onDisconnected: () {
          if (_estado != ConexionEstado.desconectado) {
            _actualizarEstado(ConexionEstado.desconectado);
          }
        },
        onAutoReconnected: () {
          _actualizarEstado(ConexionEstado.conectado);
        },
      );

      if (conectado) {
        _escucharMensajes();
        return true;
      } else {
        _actualizarEstado(
          ConexionEstado.error,
          'No se pudo conectar al broker. Verifique la IP del equipo y el puerto.',
        );
        return false;
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      String mensajeSanitizado;

      if (usarTls && (errorStr.contains('handshake') || errorStr.contains('certificate') || errorStr.contains('tls'))) {
        mensajeSanitizado = 'Fallo de negociación TLS o certificado no válido del broker.';
      } else if (usarTls && errorStr.contains('connection refused')) {
        mensajeSanitizado = 'Conexión rechazada en puerto TLS ($puerto). Verifique la configuración del broker.';
      } else if (errorStr.contains('socketexception')) {
        mensajeSanitizado = 'No se pudo alcanzar el host. Verifique que la IP y el puerto sean correctos.';
      } else {
        mensajeSanitizado = 'Error de conexión al broker EMQX.';
      }

      _actualizarEstado(ConexionEstado.error, mensajeSanitizado);
      return false;
    }
  }

  void _escucharMensajes() {
    _clientWrapper.updates?.listen((List<MqttReceivedMessage<MqttMessage>>? messages) {
      if (messages == null || messages.isEmpty) return;
      for (final msg in messages) {
        final recMess = msg.payload as MqttPublishMessage;
        try {
          final payloadStr = utf8.decode(recMess.payload.message);
          procesarMensajeRecibido(msg.topic, payloadStr);
        } catch (_) {
          // Ignorar payloads binarios no decodificables
        }
      }
    });
  }

  /// Método público para procesar mensajes entrantes.
  /// Usado tanto por la conexión en vivo como por las pruebas unitarias sin clases internas de mqtt_client.
  void procesarMensajeRecibido(String topico, String payloadStr) {
    _ultimoMensajeBruto = payloadStr;
    if (!_mensajesBrutosController.isClosed) {
      _mensajesBrutosController.add(payloadStr);
    }

    if (topico == MqttTopicos.telemetria) {
      // Ignorar aviso de arranque del ESP32 sin considerarlo error de telemetría
      if (payloadStr.contains('"mensaje":"ESP32 conectado"') ||
          payloadStr.contains('"mensaje": "ESP32 conectado"')) {
        return;
      }

      final lectura = Lectura.fromRawJson(payloadStr);
      if (lectura != null) {
        if (!_lecturasController.isClosed) {
          _lecturasController.add(lectura);
        }
      } else {
        // Mensaje corrupto o con rangos inválidos: descartar e incrementar contador
        _mensajesDescartados++;
        if (!_mensajesDescartadosController.isClosed) {
          _mensajesDescartadosController.add(_mensajesDescartados);
        }
      }
    } else if (topico == MqttTopicos.equipo) {
      try {
        final decoded = jsonDecode(payloadStr);
        if (decoded is Map<String, dynamic> && decoded.containsKey('activo')) {
          final activo = decoded['activo'];
          if (activo is bool) {
            _ultimoEstadoEquipo = activo;
            if (!_equipoActivoController.isClosed) {
              _equipoActivoController.add(activo);
            }
          }
        }
      } catch (_) {
        // Ignorar payload no JSON en tópico de equipo
      }
    }
  }

  /// Publica una orden de control ("PAUSAR" o "REANUDAR") en el tópico de comando con QoS 1.
  /// Formato JSON: {"orden":"PAUSAR"} o {"orden":"REANUDAR"}
  Future<bool> publicarComando(String orden) async {
    final ordenNormalizada = orden.trim().toUpperCase();
    if (ordenNormalizada != 'PAUSAR' && ordenNormalizada != 'REANUDAR') {
      throw ArgumentError('Orden de comando no permitida: "$orden". Use PAUSAR o REANUDAR.');
    }

    final jsonPayload = jsonEncode({'orden': ordenNormalizada});
    final bytes = utf8.encode(jsonPayload);
    final buffer = typed.Uint8Buffer()..addAll(bytes);

    final resultado = _clientWrapper.publicarMensaje(
      MqttTopicos.comando,
      MqttQos.atLeastOnce, // QoS 1 exigido
      buffer,
      retain: false,
    );

    return resultado != null;
  }

  /// Desconecta el cliente MQTT de forma ordenada.
  Future<void> desconectar() async {
    _clientWrapper.desconectar();
    _actualizarEstado(ConexionEstado.desconectado);
  }

  void dispose() {
    desconectar();
    _lecturasController.close();
    _estadoController.close();
    _equipoActivoController.close();
    _mensajesBrutosController.close();
    _mensajesDescartadosController.close();
  }
}
