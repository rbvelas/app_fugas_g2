/// Calidad cualitativa de la señal WiFi del equipo.
///
/// Umbrales orientativos (documentados también en el README):
/// - Buena: RSSI mayor o igual a -60 dBm.
/// - Regular: RSSI entre -75 y -61 dBm.
/// - Débil: RSSI menor que -75 dBm.
enum CalidadSenal { buena, regular, debil, desconocida }

class SenalWifi {
  SenalWifi._();

  static CalidadSenal clasificar(int? rssi) {
    if (rssi == null) return CalidadSenal.desconocida;
    if (rssi >= -60) return CalidadSenal.buena;
    if (rssi >= -75) return CalidadSenal.regular;
    return CalidadSenal.debil;
  }

  static String etiqueta(CalidadSenal calidad) {
    switch (calidad) {
      case CalidadSenal.buena:
        return 'Buena';
      case CalidadSenal.regular:
        return 'Regular';
      case CalidadSenal.debil:
        return 'Débil';
      case CalidadSenal.desconocida:
        return 'Sin datos';
    }
  }

  static String descripcion(CalidadSenal calidad) {
    switch (calidad) {
      case CalidadSenal.buena:
        return 'La señal del equipo es estable.';
      case CalidadSenal.regular:
        return 'La señal puede perder mensajes de vez en cuando.';
      case CalidadSenal.debil:
        return 'Acerca el equipo al router o revisa su antena.';
      case CalidadSenal.desconocida:
        return 'El equipo todavía no informa su señal.';
    }
  }
}
