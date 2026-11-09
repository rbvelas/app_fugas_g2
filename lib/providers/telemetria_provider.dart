import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/cambio_estado_evento.dart';
import '../models/conexion_estado.dart';
import '../models/estado_lectura.dart';
import '../models/lectura.dart';
import '../services/mqtt_service.dart';
import '../utils/validador_conexion.dart';

/// Provider principal de la aplicación Aqualerta.
/// Administra el estado de conexión MQTT (con soporte TLS opcional),
/// recepción de telemetría con validación de rangos, historial de cambios de estado,
/// estado del equipo y lógica de confirmación, conteo de mensajes descartados y Modo DEMO.
class TelemetriaProvider with ChangeNotifier {
  final MqttService _mqttService;
  final Duration timeoutConfirmacion;

  // Parámetros de conexión (sin credenciales por defecto)
  String _host = '';
  int _puerto = 1883;
  String _usuario = '';
  String _password = ''; // Reside estrictamente en memoria RAM volátil
  bool _usarTls = false;

  ConexionEstado _estadoConexion = ConexionEstado.desconectado;
  String? _mensajeError;

  Lectura? _ultimaLectura;
  String? _ultimoMensajeBruto;
  int _mensajesDescartados = 0;

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
  StreamSubscription<int>? _descartadosSub;
  Timer? _temporizadorVigilancia;

  TelemetriaProvider({
    MqttService? mqttService,
    this.timeoutConfirmacion = const Duration(seconds: 5),
  }) : _mqttService = mqttService ?? MqttService() {
    _inicializarSubscripciones();
    _iniciarTemporizadorVigilancia();
  }

  // Getters para la interfaz de usuario
  ConexionEstado get estadoConexion => _estadoConexion;
  String? get mensajeError => _mensajeError;
  Lectura? get ultimaLectura => _ultimaLectura;
  String? get ultimoMensajeBruto => _ultimoMensajeBruto;
  int get mensajesDescartados => _mensajesDescartados;
  List<Lectura> get historialLecturas => List.unmodifiable(_historialLecturas);
  List<CambioEstadoEvento> get historialCambiosEstado =>
      List.unmodifiable(_historialCambiosEstado);
  bool get hayDatosRecientes => _hayDatosRecientes;
  bool get alertaFugaActiva => _alertaFugaActiva;
  String get host => _host;
  int get puerto => _puerto;
  String get usuario => _usuario;
  bool get usarTls => _usarTls;

  /// Getter de solo lectura que indica si hay una contraseña cargada en la memoria volátil.
  /// No expone el valor de la contraseña en texto plano.
  bool get tieneContrasena => _password.isNotEmpty;

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

    _descartadosSub = _mqttService.mensajesDescartadosStream.listen((total) {
      _mensajesDescartados = total;
      notifyListeners();
    });
  }

  /// Configura el uso de conexión cifrada TLS y adapta el puerto sugerido.
  void setUsarTls(bool activo) {
    if (_usarTls == activo) return;
    _usarTls = activo;
    if (activo && _puerto == 1883) {
      _puerto = 8883;
    } else if (!activo && _puerto == 8883) {
      _puerto = 1883;
    }
    notifyListeners();
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
  /// Inicia el temporizador de confirmación configurable: si no llega confirmación, muestra "sin confirmar".
  Future<bool> enviarOrden(String orden) async {
    if (_modoDemoActivo) {
      return false; // En modo demo los controles están deshabilitados
    }

    final ordenNormalizada = orden.trim().toUpperCase();
    _ordenPendiente = ordenNormalizada;
    _esperandoConfirmacion = true;
    _confirmacionExpirada = false;
    notifyListeners();

    _temporizadorConfirmacion?.cancel();
    _temporizadorConfirmacion = Timer(timeoutConfirmacion, () {
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

      if (lineas.isNotEmpty && lineas.first.startsWith('dispositivo')) {
        lineas.removeAt(0);
      }

      _demoLineasCsv = lineas;
      _demoTimer?.cancel();

      if (_demoLineasCsv.isEmpty) return;

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

          final lectura = Lectura.tryFromJson(payloadSimulado);
          if (lectura != null) {
            _procesarNuevaLectura(lectura, jsonEncode(payloadSimulado));
          } else {
            _mensajesDescartados++;
            notifyListeners();
          }
        }
      });
    } catch (_) {}
  }

  /// Temporizador de vigilancia de 4 segundos ("sin datos").
  void _iniciarTemporizadorVigilancia() {
    _temporizadorVigilancia?.cancel();
    _temporizadorVigilancia = Timer.periodic(const Duration(seconds: 1), (_) {
      final ahora = DateTime.now();

      if (_historialLecturas.isNotEmpty) {
        final antes = _historialLecturas.length;
        _historialLecturas.removeWhere(
          (item) => ahora.difference(item.timestamp).inSeconds > 120,
        );
        if (_historialLecturas.length != antes) {
          notifyListeners();
        }
      }

      if (_modoDemoActivo) return;

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

  /// Conecta al broker MQTT validando previamente las entradas del usuario.
  Future<bool> conectar({
    required String host,
    int puerto = 1883,
    String? usuario,
    String? password,
    bool? usarTls,
  }) async {
    if (_modoDemoActivo) {
      await setModoDemo(false);
    }

    // Validación rigurosa de entradas
    final errorHost = ValidadorConexion.validarHost(host);
    if (errorHost != null) {
      _estadoConexion = ConexionEstado.error;
      _mensajeError = errorHost;
      notifyListeners();
      return false;
    }

    final errorPuerto = ValidadorConexion.validarPuerto(puerto.toString());
    if (errorPuerto != null) {
      _estadoConexion = ConexionEstado.error;
      _mensajeError = errorPuerto;
      notifyListeners();
      return false;
    }

    _host = host.trim();
    _puerto = puerto;
    _usuario = ValidadorConexion.limpiarUsuario(usuario);
    _password = password ?? '';
    if (usarTls != null) {
      _usarTls = usarTls;
    }

    final exito = await _mqttService.conectar(
      host: _host,
      puerto: _puerto,
      usuario: _usuario.isNotEmpty ? _usuario : null,
      password: _password.isNotEmpty ? _password : null,
      usarTls: _usarTls,
    );

    // Sincronizar de inmediato el estado del provider con el servicio MQTT
    _estadoConexion = _mqttService.estado;
    _mensajeError = _mqttService.ultimoError;
    notifyListeners();

    return exito;
  }

  /// Desconecta la sesión MQTT y borra la contraseña de la memoria RAM.
  Future<void> desconectar() async {
    await _mqttService.desconectar();
    _password = ''; // Borrado riguroso de la contraseña en RAM al desconectar
    _estadoConexion = ConexionEstado.desconectado;
    _mensajeError = null;
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
    _password = '';
    _demoTimer?.cancel();
    _temporizadorConfirmacion?.cancel();
    _temporizadorVigilancia?.cancel();
    _lecturasSub?.cancel();
    _estadoSub?.cancel();
    _equipoSub?.cancel();
    _brutosSub?.cancel();
    _descartadosSub?.cancel();
    _mqttService.dispose();
    super.dispose();
  }
}
