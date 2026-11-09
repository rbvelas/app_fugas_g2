/// Estados posibles de la pantalla de Control.
///
/// La habilitación de los botones se deriva del estado REAL del equipo
/// (mensaje retenido `unt/iot/g2/riego/equipo`) y del estado de la orden,
/// nunca de un temporizador de doble toque.
enum EstadoControl {
  /// El equipo mide y publica datos.
  activo,

  /// El equipo está detenido por una orden de pausa.
  pausado,

  /// Se envió una orden y se espera la confirmación del equipo.
  enviando,

  /// Pasó el tiempo de espera sin confirmación del equipo.
  sinConfirmar,

  /// No hay conexión con el servidor.
  sinConexion,

  /// Los datos provienen de la simulación local.
  demo,

  /// Todavía no se conoce el estado real del equipo.
  desconocido,
}

/// Máquina de estados pura (sin Flutter, sin red) que decide qué botón se
/// habilita y qué mensaje se muestra en Control y en Monitoreo.
///
/// Reglas:
/// - activo: "Pausar" habilitado; "Reanudar" deshabilitado.
/// - pausado: "Reanudar" habilitado y principal; "Pausar" deshabilitado.
/// - enviando: ambos deshabilitados, con progreso y espera visible.
/// - sinConfirmar: ambos deshabilitados, pero se ofrece "Reintentar".
/// - sinConexion / demo / desconocido: ambos deshabilitados con explicación.
class MaquinaEstadosControl {
  final EstadoControl estado;

  const MaquinaEstadosControl(this.estado);

  factory MaquinaEstadosControl.evaluar({
    required bool conectado,
    required bool modoDemo,
    required bool? equipoActivo,
    required bool esperandoConfirmacion,
    required bool confirmacionExpirada,
  }) {
    if (modoDemo) {
      return const MaquinaEstadosControl(EstadoControl.demo);
    }
    if (!conectado) {
      return const MaquinaEstadosControl(EstadoControl.sinConexion);
    }
    if (esperandoConfirmacion) {
      return const MaquinaEstadosControl(EstadoControl.enviando);
    }
    if (confirmacionExpirada) {
      return const MaquinaEstadosControl(EstadoControl.sinConfirmar);
    }
    if (equipoActivo == true) {
      return const MaquinaEstadosControl(EstadoControl.activo);
    }
    if (equipoActivo == false) {
      return const MaquinaEstadosControl(EstadoControl.pausado);
    }
    return const MaquinaEstadosControl(EstadoControl.desconocido);
  }

  bool get pausarHabilitado => estado == EstadoControl.activo;

  bool get reanudarHabilitado => estado == EstadoControl.pausado;

  /// En pausa, "Reanudar" es la acción principal de la pantalla.
  bool get reanudarEsPrincipal => estado == EstadoControl.pausado;

  bool get mostrarProgreso => estado == EstadoControl.enviando;

  bool get mostrarReintentar => estado == EstadoControl.sinConfirmar;

  bool get ambosDeshabilitados => !pausarHabilitado && !reanudarHabilitado;

  bool get ofrecerIrAConexion =>
      estado == EstadoControl.sinConexion || estado == EstadoControl.demo;

  /// Etiqueta breve del estado real del equipo.
  String get etiquetaEstado {
    switch (estado) {
      case EstadoControl.activo:
        return 'Activo';
      case EstadoControl.pausado:
        return 'En pausa';
      case EstadoControl.enviando:
        return 'Enviando orden…';
      case EstadoControl.sinConfirmar:
        return 'Sin confirmar';
      case EstadoControl.sinConexion:
        return 'Sin conexión';
      case EstadoControl.demo:
        return 'Modo DEMO';
      case EstadoControl.desconocido:
        return 'Estado desconocido';
    }
  }

  /// Explicación del estado, en lenguaje del usuario (sin tópicos MQTT).
  String get detalleEstado {
    switch (estado) {
      case EstadoControl.activo:
        return 'El equipo está midiendo y publicando datos.';
      case EstadoControl.pausado:
        return 'El equipo no mide ni publica datos. El agua sigue fluyendo.';
      case EstadoControl.enviando:
        return 'Esperando confirmación del equipo…';
      case EstadoControl.sinConfirmar:
        return 'No se recibió confirmación. Revisa que el equipo esté encendido y conectado.';
      case EstadoControl.sinConexion:
        return 'Conéctate al servidor para ver y controlar el equipo.';
      case EstadoControl.demo:
        return 'Datos de ejemplo. No hay un equipo real conectado.';
      case EstadoControl.desconocido:
        return 'Aún no llega el estado del equipo. Espera a que envíe su confirmación.';
    }
  }

  /// Línea breve que explica por qué los botones están deshabilitados.
  String get explicacionBotones {
    switch (estado) {
      case EstadoControl.activo:
        return 'Puedes pausar la medición.';
      case EstadoControl.pausado:
        return 'Puedes reanudar la medición.';
      case EstadoControl.enviando:
        return 'Esperando confirmación del equipo…';
      case EstadoControl.sinConfirmar:
        return 'No se recibió confirmación. Revisa que el equipo esté encendido y conectado.';
      case EstadoControl.sinConexion:
        return 'Conéctate al servidor para controlar el equipo.';
      case EstadoControl.demo:
        return 'Modo DEMO: los controles no envían órdenes reales.';
      case EstadoControl.desconocido:
        return 'Todavía no conocemos el estado del equipo. Espera su confirmación.';
    }
  }
}
