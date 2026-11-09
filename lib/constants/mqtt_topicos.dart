/// Tópicos MQTT y avisos de arquitectura de Aqualerta.
/// Tópicos definidos para el proyecto de Internet de las Cosas de la UNT.
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

  /// Aviso oficial respecto a la propuesta de los tópicos de control.
  static const String avisoPropuestaControl =
      'Nota: Los tópicos de comando ("unt/iot/g2/riego/comando") y equipo '
      '("unt/iot/g2/riego/equipo") son una propuesta técnica; '
      'el firmware del ESP32 aún debe implementarlos.';
}
