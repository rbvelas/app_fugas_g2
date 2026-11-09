/// Textos de tiempo en lenguaje natural para la interfaz.
///
/// La hora de Lima (UTC-5) se usa solo en el detalle y en el encabezado del
/// historial; el resto de la app muestra antigüedad relativa.
String antiguedadRelativa(DateTime timestamp, {DateTime? ahora}) {
  final diferencia = (ahora ?? DateTime.now()).difference(timestamp);
  if (diferencia.isNegative || diferencia.inSeconds < 1) {
    return 'ahora mismo';
  }
  if (diferencia.inSeconds < 60) {
    return 'hace ${diferencia.inSeconds} s';
  }
  if (diferencia.inMinutes < 60) {
    return 'hace ${diferencia.inMinutes} min';
  }
  if (diferencia.inHours < 24) {
    return 'hace ${diferencia.inHours} h';
  }
  return 'hace ${diferencia.inDays} d';
}

/// Duración breve, por ejemplo "45 s", "3 min" o "1 h 20 min".
String formatearDuracion(Duration duracion) {
  if (duracion.isNegative) return '—';
  final segundos = duracion.inSeconds;
  if (segundos < 60) return '$segundos s';
  final minutos = duracion.inMinutes;
  if (minutos < 60) return '$minutos min';
  final horas = duracion.inHours;
  final minutosRestantes = minutos % 60;
  if (minutosRestantes == 0) return '$horas h';
  return '$horas h $minutosRestantes min';
}

/// Hora corta de Lima (UTC-5) para filas del historial: HH:mm:ss.
String horaCortaLima(DateTime timestamp) {
  final lima = timestamp.toUtc().subtract(const Duration(hours: 5));
  final h = lima.hour.toString().padLeft(2, '0');
  final m = lima.minute.toString().padLeft(2, '0');
  final s = lima.second.toString().padLeft(2, '0');
  return '$h:$m:$s';
}

/// Fecha y hora completa de Lima (UTC-5) para el detalle.
String fechaHoraLima(DateTime timestamp) {
  final lima = timestamp.toUtc().subtract(const Duration(hours: 5));
  final d = lima.day.toString().padLeft(2, '0');
  final mo = lima.month.toString().padLeft(2, '0');
  final y = lima.year.toString();
  return '$d/$mo/$y ${horaCortaLima(timestamp)} (Lima, UTC-5)';
}
