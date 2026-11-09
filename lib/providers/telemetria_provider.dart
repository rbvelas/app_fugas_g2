import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/conexion_estado.dart';
import '../models/estado_lectura.dart';
import '../models/lectura.dart';
import '../services/mqtt_service.dart';

/// Provider principal de la aplicación.
/// Administra el estado de la conexión MQTT, la recepción de telemetría,
/// la ventana temporal de los últimos 120 s para el gráfico, la detección de
/// "sin datos" tras 4 s de inactividad y la alerta háptica/visual al pasar a FUGA.
class TelemetriaProvider with ChangeNotifier {
  final MqttService _mqttService;

  // Credenciales y parámetros de conexión (en memoria exclusivamente)
  String _host = '';
  int _puerto = 1883;
  String _usuario = '';
  String _password = ''; // Nunca se almacena en disco ni se registra

  ConexionEstado _estadoConexion = ConexionEstado.desconectado;
  String? _mensajeError;

  Lectura? _ultimaLectura;
  final List<Lectura> _historialLecturas = [];
  bool _hayDatosRecientes = false;
  bool _alertaFugaActiva = false;
  EstadoLectura? _estadoAnterior;

  StreamSubscription<Lectura>? _lecturasSub;
  StreamSubscription<ConexionEstado>? _estadoSub;
  Timer? _temporizadorVigilancia;

  TelemetriaProvider({MqttService? mqttService})
      : _mqttService = mqttService ?? MqttService() {
    _inicializarSubscripciones();
    _iniciarTemporizadorVigilancia();
  }

  // Getters para la interfaz de usuario
  ConexionEstado get estadoConexion => _estadoConexion;
  String? get mensajeError => _mensajeError;
  Lectura? get ultimaLectura => _ultimaLectura;
  List<Lectura> get historialLecturas => List.unmodifiable(_historialLecturas);
  bool get hayDatosRecientes => _hayDatosRecientes;
  bool get alertaFugaActiva => _alertaFugaActiva;
  String get host => _host;
  int get puerto => _puerto;
  String get usuario => _usuario;

  void _inicializarSubscripciones() {
    _estadoSub = _mqttService.estadoStream.listen((nuevoEstado) {
      _estadoConexion = nuevoEstado;
      _mensajeError = _mqttService.ultimoError;
      if (nuevoEstado != ConexionEstado.conectado) {
        _hayDatosRecientes = false;
      }
      notifyListeners();
    });

    _lecturasSub = _mqttService.lecturasStream.listen(_procesarNuevaLectura);
  }

  void _procesarNuevaLectura(Lectura lectura) {
    _ultimaLectura = lectura;
    _hayDatosRecientes = true;

    // Agregar al historial y descartar lecturas que superen la ventana de 120 segundos
    final ahora = DateTime.now();
    _historialLecturas.add(lectura);
    _historialLecturas.removeWhere((item) =>
        ahora.difference(item.timestamp).inSeconds > 120);

    // Detección de transición al estado FUGA:
    // "Al pasar a FUGA: HapticFeedback y banner rojo."
    if (lectura.estado == EstadoLectura.fuga) {
      _alertaFugaActiva = true;
      if (_estadoAnterior != EstadoLectura.fuga) {
        HapticFeedback.heavyImpact();
      }
    } else {
      _alertaFugaActiva = false;
    }

    _estadoAnterior = lectura.estado;
    notifyListeners();
  }

  /// Temporizador de 1 segundo para verificar la regla:
  /// "sin datos si pasan más de 4 s sin mensajes."
  void _iniciarTemporizadorVigilancia() {
    _temporizadorVigilancia?.cancel();
    _temporizadorVigilancia = Timer.periodic(const Duration(seconds: 1), (_) {
      final ahora = DateTime.now();

      // Limpiar datos antiguos del gráfico continuamente
      if (_historialLecturas.isNotEmpty) {
        final antes = _historialLecturas.length;
        _historialLecturas.removeWhere((item) =>
            ahora.difference(item.timestamp).inSeconds > 120);
        if (_historialLecturas.length != antes) {
          notifyListeners();
        }
      }

      // Verificar frescura de la última lectura (umbral de 4 segundos)
      if (_ultimaLectura == null) {
        if (_hayDatosRecientes) {
          _hayDatosRecientes = false;
          notifyListeners();
        }
        return;
      }

      final segundosSinLectura = ahora.difference(_ultimaLectura!.timestamp).inSeconds;
      final vigente = segundosSinLectura <= 4;

      if (_hayDatosRecientes != vigente) {
        _hayDatosRecientes = vigente;
        notifyListeners();
      }
    });
  }

  /// Inicia la conexión con los parámetros dados.
  /// La contraseña reside únicamente en la memoria de la sesión.
  Future<bool> conectar({
    required String host,
    int puerto = 1883,
    String? usuario,
    String? password,
  }) async {
    _host = host;
    _puerto = puerto;
    _usuario = usuario ?? '';
    _password = password ?? '';

    final exito = await _mqttService.conectar(
      host: _host,
      puerto: _puerto,
      usuario: _usuario.isNotEmpty ? _usuario : null,
      password: _password.isNotEmpty ? _password : null,
    );

    return exito;
  }

  /// Desconecta la sesión MQTT y reinicia estados volátiles.
  Future<void> desconectar() async {
    await _mqttService.desconectar();
    _hayDatosRecientes = false;
    _alertaFugaActiva = false;
    _estadoAnterior = null;
    notifyListeners();
  }

  /// Permite cerrar el banner de alerta de fuga manualmente si el usuario lo descarta.
  void cerrarBannerFuga() {
    _alertaFugaActiva = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _temporizadorVigilancia?.cancel();
    _lecturasSub?.cancel();
    _estadoSub?.cancel();
    _mqttService.dispose();
    super.dispose();
  }
}

