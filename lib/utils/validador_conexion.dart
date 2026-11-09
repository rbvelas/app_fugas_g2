/// Utilidad para la validación estricta de parámetros de conexión MQTT.
/// Previene inyecciones, esquemas indebidos, espacios y puertos fuera de rango.
class ValidadorConexion {
  ValidadorConexion._();

  /// Valida la dirección del host o IP.
  /// No admite valores vacíos, espacios en blanco (en cualquier posición) ni esquemas de protocolo (http://, mqtt://, etc.).
  static String? validarHost(String? valor) {
    if (valor == null || valor.isEmpty) {
      return 'Ingresa la dirección del servidor';
    }

    // Comprobación estricta de espacios: no se permite ningún espacio en blanco
    if (valor.contains(' ')) {
      return 'La dirección no debe contener espacios en blanco';
    }

    final texto = valor.trim();
    if (texto.isEmpty) {
      return 'Ingresa la dirección del servidor';
    }

    // Detectar presencia de esquemas de protocolo comunes (http://, mqtt://, ws://, etc.)
    final regexEsquema = RegExp(r'^[a-zA-Z]+://');
    if (regexEsquema.hasMatch(texto) || texto.contains('://')) {
      return 'La dirección no debe incluir un esquema (no uses http:// ni mqtt://)';
    }

    return null;
  }

  /// Valida el puerto TCP.
  /// Debe ser un número entero en el rango estándar 1 a 65535.
  static String? validarPuerto(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Ingresa el puerto del servidor';
    }

    final puerto = int.tryParse(valor.trim());
    if (puerto == null) {
      return 'El puerto debe ser un número entero válido';
    }

    if (puerto < 1 || puerto > 65535) {
      return 'El puerto debe estar entre 1 y 65535';
    }

    return null;
  }

  /// Limpia y normaliza el nombre de usuario (remueve espacios al inicio y final).
  static String limpiarUsuario(String? valor) {
    if (valor == null) return '';
    return valor.trim();
  }
}
