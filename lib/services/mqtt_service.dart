import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/conexion_estado.dart';
import '../models/lectura.dart';

/// Servicio responsable exclusivamente de la comunicación MQTT con el broker EMQX.
/// No contiene ningún código de interfaz gráfica (UI).
class MqttService {
  static const String topicoPorDefecto = 'unt/iot/g2/riego/telemetria';
  static const int puertoPorDefecto = 1883;

  MqttServerClient? _client;
  ConexionEstado _estado = ConexionEstado.desconectado;
  String? _ultimoError;
  String _topicoActual = topicoPorDefecto;

  final StreamController<Lectura> _lecturasController =
      StreamController<Lectura>.broadcast();
  final StreamController<ConexionEstado> _estadoController =
      StreamController<ConexionEstado>.broadcast();

  Stream<Lectura> get lecturasStream => _lecturasController.stream;
  Stream<ConexionEstado> get estadoStream => _estadoController.stream;
  ConexionEstado get estado => _estado;
  String? get ultimoError => _ultimoError;

  void _actualizarEstado(ConexionEstado nuevoEstado, [String? mensajeError]) {
    _estado = nuevoEstado;
    _ultimoError = mensajeError;
    if (!_estadoController.isClosed) {
      _estadoController.add(nuevoEstado);
    }
  }

  /// Conecta al broker MQTT según los parámetros especificados.
  /// La contraseña solo se utiliza en memoria para la autenticación y nunca
  /// se almacena en disco ni se imprime en consola.
  Future<bool> conectar({
    required String host,
    int puerto = puertoPorDefecto,
    String? usuario,
    String? password,
    String topico = topicoPorDefecto,
  }) async {
    if (_client != null) {
      await desconectar();
    }

    _topicoActual = topico;
    _actualizarEstado(ConexionEstado.conectando);

    // ClientId único: prefijo 'g2-app-' seguido de un número aleatorio
    final randomId = Random().nextInt(900000) + 100000;
    final clientId = 'g2-app-$randomId';

    final client = MqttServerClient.withPort(host.trim(), clientId, puerto);
    _client = client;

    // Configuración estricta según requerimientos del proyecto
    client.keepAlivePeriod = 20; // Keep-alive de 20 segundos
    client.autoReconnect = true; // Reconexión automática
    client.resubscribeOnAutoReconnect = true; // Re-suscripción tras reconectar
    client.logging(on: false); // Seguridad: sin volcado de credenciales en logs

    client.onConnected = () {
      _actualizarEstado(ConexionEstado.conectado);
      // Suscripción al tópico de telemetría con QoS 0
      client.subscribe(_topicoActual, MqttQos.atMostOnce);
    };

    client.onDisconnected = () {
      if (_estado != ConexionEstado.desconectado) {
        _actualizarEstado(ConexionEstado.desconectado);
      }
    };

    client.onAutoReconnected = () {
      _actualizarEstado(ConexionEstado.conectado);
    };

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean();

    if (usuario != null && usuario.trim().isNotEmpty) {
      connMessage.authenticateAs(usuario.trim(), password ?? '');
    }

    client.connectionMessage = connMessage;

    try {
      final status = await client.connect();
      if (status?.state == MqttConnectionState.connected) {
        _escucharMensajes(client);
        return true;
      } else {
        _actualizarEstado(
          ConexionEstado.error,
          'No se pudo conectar al broker (Estado: ${status?.state}). Verifique host y puerto.',
        );
        client.disconnect();
        return false;
      }
    } catch (e) {
      _actualizarEstado(
        ConexionEstado.error,
        'Error al conectar al broker EMQX: $e',
      );
      client.disconnect();
      return false;
    }
  }

  void _escucharMensajes(MqttServerClient client) {
    client.updates?.listen((List<MqttReceivedMessage<MqttMessage>>? messages) {
      if (messages == null || messages.isEmpty) return;
      for (final msg in messages) {
        final recMess = msg.payload as MqttPublishMessage;
        try {
          final payloadStr = utf8.decode(recMess.payload.message);
          // Parseo seguro: descarta JSON inválidos y mensajes como {"mensaje":"ESP32 conectado"}
          final lectura = Lectura.fromRawJson(payloadStr);
          if (lectura != null && !_lecturasController.isClosed) {
            _lecturasController.add(lectura);
          }
        } catch (_) {
          // Ignorar cualquier fallo de decodificación
        }
      }
    });
  }

  /// Desconecta el cliente MQTT de forma ordenada.
  Future<void> desconectar() async {
    try {
      _client?.disconnect();
    } catch (_) {}
    _client = null;
    _actualizarEstado(ConexionEstado.desconectado);
  }

  void dispose() {
    desconectar();
    _lecturasController.close();
    _estadoController.close();
  }
}

