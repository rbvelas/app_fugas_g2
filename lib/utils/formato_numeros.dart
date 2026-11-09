/// Formato numérico con coma decimal, habitual en español.
String numeroConComa(num valor, {int decimales = 2}) {
  return valor.toStringAsFixed(decimales).replaceAll('.', ',');
}

/// Porcentaje con coma decimal y símbolo, por ejemplo "18,3 %".
String porcentajeConComa(num valor, {int decimales = 1}) {
  return '${numeroConComa(valor, decimales: decimales)} %';
}
