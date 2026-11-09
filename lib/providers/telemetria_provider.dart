import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/cambio_estado_evento.dart';
import '../models/conexion_estado.dart';
import '../models/estado_lectura.dart';
import '../models/lectura.dart';
import '../services/mqtt_service.dart';

/// Provider principal de la aplicación.
/// Administra el estado de conexión MQTT, recepción de telemetría,
/// ventana de 120 s para gráficos, historial de cambios de estado (máx 200),
/// estado del equipo y lógica de confirmación (5 s), y Modo DEMO desde CSV.
class TelemetriaProvider with ChangeNotifier {
  final MqttService _mqttService;

  // Parámetros de conexión (sin valores por defecto en host/usuario/password)
  String _host = '';
  int _puerto = 1883;
  String _usuario = '';
  String _password = ''; // Reside estrictamente en memoria RAM

  ConexionEstado _estadoConexion = ConexionEstado.desconectado;
  String? _mensajeError;

  Lectura? _ultimaLectura;
  String? _ultimoMensajeBruto;
  final List<Lectura> _historialLecturas = [];
  final List<CambioEstadoEvento> _historialCambiosEstado = [];

  bool _hayDatosRecientes = false;
  bool _alertaFugaActiva = false;
  EstadoLectura? _estadoAnterior;

  // Estado del equipo y control
  bool? _equipoActivo; // null = sin datos, true = activo, false = pausado
  bool _esperandoConfirmacion = false;
  bool _confirmacionExpirada = false;
  String? _ordenPendiente;
  Timer? _temporizadorConfirmacion;

  // Modo DEMO
  bool _modoDemoActivo = false;
  Timer? _demoTimer;
  int _demoIndex = 0;
  List<String> _demoLineasCsv = [];

  StreamSubscription<Lectura>? _lecturasSub;
  StreamSubscription<ConexionEstado>? _estadoSub;
  StreamSubscription<bool>? _equipoSub;
  StreamSubscription<String>? _brutosSub;
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
  String? get ultimoMensajeBruto => _ultimoMensajeBruto;
  List<Lectura> get historialLecturas => List.unmodifiable(_historialLecturas);
  List<CambioEstadoEvento> get historialCambiosEstado =>
      List.unmodifiable(_historialCambiosEstado);
  bool get hayDatosRecientes => _hayDatosRecientes;
  bool get alertaFugaActiva => _alertaFugaActiva;
  String get host => _host;
  int get puerto => _puerto;
  String get usuario => _usuario;

  bool? get equipoActivo => _equipoActivo;
  bool get esperandoConfirmacion => _esperandoConfirmacion;
  bool get confirmacionExpirada => _confirmacionExpirada;
  String? get ordenPendiente => _ordenPendiente;

  bool get modoDemoActivo => _modoDemoActivo;

  void _inicializarSubscripciones() {
    _estadoSub = _mqttService.estadoStream.listen((nuevoEstado) {
      _estadoConexion = nuevoEstado;
      _mensajeError = _mqttService.ultimoError;
      if (nuevoEstado != ConexionEstado.conectado && !_modoDemoActivo) {
        _hayDatosRecientes = false;
      }
      notifyListeners();
    });

    _lecturasSub = _mqttService.lecturasStream.listen((lectura) {
      _procesarNuevaLectura(lectura);
    });

    _equipoSub = _mqttService.equipoActivoStream.listen((activo) {
      _procesarEstadoEquipo(activo);
    });

    _brutosSub = _mqttService.mensajesBrutosStream.listen((bruto) {
      _ultimoMensajeBruto = bruto;
      notifyListeners();
    });
  }

  void _procesarNuevaLectura(Lectura lectura, [String? mensajeBruto]) {
    _ultimaLectura = lectura;
    _hayDatosRecientes = true;
    if (mensajeBruto != null) {
      _ultimoMensajeBruto = mensajeBruto;
    }

    // Ventana continua de 120 segundos para el gráfico
    final ahora = DateTime.now();
    _historialLecturas.add(lectura);
    _historialLecturas.removeWhere(
      (item) => ahora.difference(item.timestamp).inSeconds > 120,
    );

    // Registro del cambio de estado (máximo 200 entradas en memoria, solo si cambia el estado)
    if (_estadoAnterior != null && lectura.estado != _estadoAnterior) {
      final evento = CambioEstadoEvento(
        timestamp: lectura.timestamp,
        estadoAnterior: _estadoAnterior!,
        estadoNuevo: lectura.estado,
        caudalEntrada: lectura.caudalEntrada,
        caudalSalida: lectura.caudalSalida,
        diferenciaPorcentaje: lectura.diferenciaPorcentaje,
      );

      if (_historialCambiosEstado.length >= 200) {
        _historialCambiosEstado.removeAt(0);
      }
      _historialCambiosEstado.add(evento);
    }

    // Detección de transición al estado FUGA: HapticFeedback y banner rojo
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

  void _procesarEstadoEquipo(bool activo) {
    _equipoActivo = activo;

    // Si estábamos esperando confirmación de una orden previa
    if (_esperandoConfirmacion && _ordenPendiente != null) {
      final orden = _ordenPendiente!;
      if ((orden == 'PAUSAR' && !activo) || (orden == 'REANUDAR' && activo)) {
        _temporizadorConfirmacion?.cancel();
        _esperandoConfirmacion = false;
        _confirmacionExpirada = false;
        _ordenPendiente = null;
      }
    }

    notifyListeners();
  }

  /// Limpia el historial en memoria de cambios de estado.
  void limpiarHistorialCambios() {
    _historialCambiosEstado.clear();
    notifyListeners();
  }

  /// Publica una orden ("PAUSAR" o "REANUDAR") en unt/iot/g2/riego/comando (QoS 1).
  /// Inicia un temporizador de 5 segundos: si no llega confirmación de
  /// unt/iot/g2/riego/equipo en 5 s, muestra "sin confirmar".
  Future<bool> enviarOrden(String orden) async {
    if (_modoDemoActivo) {
      return false; // En modo demo los controles están deshabilitados
    }

    final ordenNormalizada = orden.trim().toUpperCase();
    _ordenPendiente = ordenNormalizada;
    _esperandoConfirmacion = true;
    _confirmacionExpirada = false;
    notifyListeners();

    // Cancelar temporizador previo si existiera
    _temporizadorConfirmacion?.cancel();
    _temporizadorConfirmacion = Timer(const Duration(seconds: 5), () {
      if (_esperandoConfirmacion) {
        _esperandoConfirmacion = false;
        _confirmacionExpirada = true; // "sin confirmar"
        notifyListeners();
      }
    });

    try {
      final exito = await _mqttService.publicarComando(ordenNormalizada);
      if (!exito) {
        _esperandoConfirmacion = false;
        _confirmacionExpirada = true;
        _temporizadorConfirmacion?.cancel();
        notifyListeners();
      }
      return exito;
    } catch (_) {
      _esperandoConfirmacion = false;
      _confirmacionExpirada = true;
      _temporizadorConfirmacion?.cancel();
      notifyListeners();
      return false;
    }
  }

  /// Activa o desactiva el Modo DEMO (reproducción local desde CSV sin broker).
  Future<void> setModoDemo(bool activo) async {
    if (_modoDemoActivo == activo) return;

    if (activo) {
      if (_estadoConexion == ConexionEstado.conectado ||
          _estadoConexion == ConexionEstado.conectando) {
        await desconectar();
      }
      _modoDemoActivo = true;
      _demoIndex = 0;
      await _iniciarReproduccionDemo();
    } else {
      _demoTimer?.cancel();
      _modoDemoActivo = false;
      _hayDatosRecientes = false;
      _alertaFugaActiva = false;
      _estadoAnterior = null;
    }

    notifyListeners();
  }

  Future<void> _iniciarReproduccionDemo() async {
    try {
      final csvString = await rootBundle.loadString('assets/demo_telemetria.csv');
      final lineas = csvString
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      // Descartar encabezado
      if (lineas.isNotEmpty && lineas.first.startsWith('dispositivo')) {
        lineas.removeAt(0);
      }

      _demoLineasCsv = lineas;
      _demoTimer?.cancel();

      if (_demoLineasCsv.isEmpty) return;

      // Emitir 1 lectura por segundo en bucle
      _demoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_modoDemoActivo || _demoLineasCsv.isEmpty) return;

        final linea = _demoLineasCsv[_demoIndex];
        _demoIndex = (_demoIndex + 1) % _demoLineasCsv.length;

        final partes = linea.split(',');
        if (partes.length >= 8) {
          final payloadSimulado = {
            'dispositivo': partes[0],
            'caudal_entrada': double.tryParse(partes[1]) ?? 0.0,
            'caudal_salida': double.tryParse(partes[2]) ?? 0.0,
            'diferencia_l_min': double.tryParse(partes[3]) ?? 0.0,
            'diferencia_porcentaje': double.tryParse(partes[4]) ?? 0.0,
            'volumen_entrada': double.tryParse(partes[5]) ?? 0.0,
            'volumen_salida': double.tryParse(partes[6]) ?? 0.0,
            'estado': partes[7],
            'rssi': partes.length > 8 ? int.tryParse(partes[8]) : null,
          };

          final lectura = Lectura.fromJson(payloadSimulado);
          _procesarNuevaLectura(lectura, jsonEncode(payloadSimulado));
        }
      });
    } catch (_) {
      // Si falla carga de assets demo
    }
  }

  /// Temporizador de vigilancia de 4 segundos ("sin datos").
  void _iniciarTemporizadorVigilancia() {
    _temporizadorVigilancia?.cancel();
    _temporizadorVigilancia = Timer.periodic(const Duration(seconds: 1), (_) {
      final ahora = DateTime.now();

      // Limpieza continua de datos del gráfico
      if (_historialLecturas.isNotEmpty) {
        final antes = _historialLecturas.length;
        _historialLecturas.removeWhere(
          (item) => ahora.difference(item.timestamp).inSeconds > 120,
        );
        if (_historialLecturas.length != antes) {
          notifyListeners();
        }
      }

      if (_modoDemoActivo) return; // En modo demo el timer de demo mantiene la frescura

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

  /// Conecta al broker MQTT EMQX.
  Future<bool> conectar({
    required String host,
    int puerto = 1883,
    String? usuario,
    String? password,
  }) async {
    if (_modoDemoActivo) {
      await setModoDemo(false);
    }

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

  /// Desconecta la sesión MQTT y restablece banderas temporales.
  Future<void> desconectar() async {
    await _mqttService.desconectar();
    _hayDatosRecientes = false;
    _alertaFugaActiva = false;
    _estadoAnterior = null;
    _equipoActivo = null;
    _esperandoConfirmacion = false;
    _confirmacionExpirada = false;
    _temporizadorConfirmacion?.cancel();
    notifyListeners();
  }

  void cerrarBannerFuga() {
    _alertaFugaActiva = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _demoTimer?.cancel();
    _temporizadorConfirmacion?.cancel();
    _temporizadorVigilancia?.cancel();
    _lecturasSub?.cancel();
    _estadoSub?.cancel();
    _equipoSub?.cancel();
    _brutosSub?.cancel();
    _mqttService.dispose();
    super.dispose();
  }
}
