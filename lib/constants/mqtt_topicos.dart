/// Tópicos MQTT y avisos de arquitectura para el proyecto Aqualerta.
class MqttTopicos {
  MqttTopicos._();

  /// Tópico de publicación de telemetría por parte del ESP32 (QoS 0).
  /// Payload: JSON con caudal_entrada, caudal_salida, volumen, estado, etc.
  static const String telemetria = 'unt/iot/g2/riego/telemetria';

  /// Tópico para publicar órdenes de control al ESP32 (QoS 1).
  /// Payload: {"orden": "PAUSAR"} o {"orden": "REANUDAR"}
  static const String comando = 'unt/iot/g2/riego/comando';

  /// Tópico al que se suscribe la app para conocer el estado del ESP32 (retained).
  /// Payload: {"activo": true} o {"activo": false}
  static const String equipo = 'unt/iot/g2/riego/equipo';

  /// Nota interna: el firmware ya implementa las órdenes de control.
  /// La app se limita a mostrar el estado confirmado del equipo.
  static const String avisoPropuestaControl =
      'El equipo confirma el resultado de cada orden. '
      'La app muestra ese estado real y permite reintentar si no hay respuesta.';
}
