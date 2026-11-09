import 'dart:async';
import 'dart:convert';
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
    void Function()? onConnected,
    void Function()? onDisconnected,
    void Function()? onAutoReconnected,
  });

  void desconectar();
  void suscribir(String topico, MqttQos qos);
  int? publicarMensaje(String topico, MqttQos qos, typed.Uint8Buffer data, {bool retain = false});
}

/// Implementación real basada en MqttServerClient sobre TCP.
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
      return false;
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

  final StreamController<Lectura> _lecturasController =
      StreamController<Lectura>.broadcast();
  final StreamController<ConexionEstado> _estadoController =
      StreamController<ConexionEstado>.broadcast();
  final StreamController<bool> _equipoActivoController =
      StreamController<bool>.broadcast();
  final StreamController<String> _mensajesBrutosController =
      StreamController<String>.broadcast();

  Stream<Lectura> get lecturasStream => _lecturasController.stream;
  Stream<ConexionEstado> get estadoStream => _estadoController.stream;
  Stream<bool> get equipoActivoStream => _equipoActivoController.stream;
  Stream<String> get mensajesBrutosStream => _mensajesBrutosController.stream;

  ConexionEstado get estado => _estado;
  String? get ultimoError => _ultimoError;
  bool? get ultimoEstadoEquipo => _ultimoEstadoEquipo;
  String? get ultimoMensajeBruto => _ultimoMensajeBruto;

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
  /// Se suscribe al tópico de telemetría (QoS 0) y al tópico de estado del equipo (QoS 1).
  Future<bool> conectar({
    required String host,
    int puerto = 1883,
    String? usuario,
    String? password,
  }) async {
    if (_clientWrapper.estaConectado) {
      await desconectar();
    }

    _actualizarEstado(ConexionEstado.conectando);

    final randomId = Random().nextInt(900000) + 100000;
    final clientId = 'g2-app-$randomId';

    try {
      final conectado = await _clientWrapper.conectar(
        host: host,
        puerto: puerto,
        clientId: clientId,
        usuario: usuario,
        password: password,
        onConnected: () {
          _actualizarEstado(ConexionEstado.conectado);
          // Suscripción al tópico de telemetría con QoS 0
          _clientWrapper.suscribir(MqttTopicos.telemetria, MqttQos.atMostOnce);
          // Suscripción al tópico de estado del equipo con QoS 1
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
          'No se pudo conectar al broker. Verifique la IP del equipo donde corre EMQX y el puerto.',
        );
        return false;
      }
    } catch (e) {
      _actualizarEstado(
        ConexionEstado.error,
        'Error al conectar al broker EMQX: $e',
      );
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
          _procesarMensajeRecibido(msg.topic, payloadStr);
        } catch (_) {
          // Ignorar cualquier fallo de decodificación
        }
      }
    });
  }

  /// Procesa los mensajes recibidos por tópico y alimenta los streams respectivos.
  void _procesarMensajeRecibido(String topico, String payloadStr) {
    _ultimoMensajeBruto = payloadStr;
    if (!_mensajesBrutosController.isClosed) {
      _mensajesBrutosController.add(payloadStr);
    }

    if (topico == MqttTopicos.telemetria) {
      final lectura = Lectura.fromRawJson(payloadStr);
      if (lectura != null && !_lecturasController.isClosed) {
        _lecturasController.add(lectura);
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
  }
}
