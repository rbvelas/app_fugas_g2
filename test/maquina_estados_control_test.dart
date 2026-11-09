import 'package:flutter_test/flutter_test.dart';
import 'package:fugas_g2/models/estado_control.dart';

void main() {
  group('Máquina de estados de los botones de Control', () {
    MaquinaEstadosControl evaluar({
      bool conectado = true,
      bool modoDemo = false,
      bool? equipoActivo,
      bool esperando = false,
      bool expirada = false,
    }) {
      return MaquinaEstadosControl.evaluar(
        conectado: conectado,
        modoDemo: modoDemo,
        equipoActivo: equipoActivo,
        esperandoConfirmacion: esperando,
        confirmacionExpirada: expirada,
      );
    }

    test('Activo: Pausar habilitado y Reanudar deshabilitado', () {
      final machine = evaluar(equipoActivo: true);

      expect(machine.estado, EstadoControl.activo);
      expect(machine.pausarHabilitado, isTrue);
      expect(machine.reanudarHabilitado, isFalse);
      expect(machine.reanudarEsPrincipal, isFalse);
      expect(machine.mostrarProgreso, isFalse);
      expect(machine.mostrarReintentar, isFalse);
      expect(machine.explicacionBotones, contains('pausar'));
    });

    test('Pausado: Pausar deshabilitado, Reanudar habilitado y principal', () {
      final machine = evaluar(equipoActivo: false);

      expect(machine.estado, EstadoControl.pausado);
      expect(machine.pausarHabilitado, isFalse);
      expect(machine.reanudarHabilitado, isTrue);
      expect(machine.reanudarEsPrincipal, isTrue);
      expect(machine.mostrarProgreso, isFalse);
      expect(machine.mostrarReintentar, isFalse);
    });

    test('Enviando: ambos deshabilitados con progreso y espera visible', () {
      final machine = evaluar(equipoActivo: true, esperando: true);

      expect(machine.estado, EstadoControl.enviando);
      expect(machine.pausarHabilitado, isFalse);
      expect(machine.reanudarHabilitado, isFalse);
      expect(machine.ambosDeshabilitados, isTrue);
      expect(machine.mostrarProgreso, isTrue);
      expect(machine.mostrarReintentar, isFalse);
      expect(machine.explicacionBotones, contains('Esperando confirmación'));
    });

    test('Sin confirmar: ambos deshabilitados, pero se ofrece Reintentar', () {
      final machine = evaluar(equipoActivo: true, expirada: true);

      expect(machine.estado, EstadoControl.sinConfirmar);
      expect(machine.pausarHabilitado, isFalse);
      expect(machine.reanudarHabilitado, isFalse);
      expect(machine.ambosDeshabilitados, isTrue);
      expect(machine.mostrarReintentar, isTrue);
      expect(machine.mostrarProgreso, isFalse);
      expect(machine.explicacionBotones, contains('No se recibió confirmación'));
    });

    test('Sin conexión: ambos deshabilitados y explicación de conexión', () {
      final machine = evaluar(
        conectado: false,
        equipoActivo: true,
        esperando: true,
      );

      expect(machine.estado, EstadoControl.sinConexion);
      expect(machine.pausarHabilitado, isFalse);
      expect(machine.reanudarHabilitado, isFalse);
      expect(machine.mostrarProgreso, isFalse);
      expect(machine.ofrecerIrAConexion, isTrue);
      expect(machine.explicacionBotones, contains('Conéctate al servidor'));
    });

    test('Modo DEMO: ambos deshabilitados y explicación de simulación', () {
      final machine = evaluar(modoDemo: true, equipoActivo: null);

      expect(machine.estado, EstadoControl.demo);
      expect(machine.pausarHabilitado, isFalse);
      expect(machine.reanudarHabilitado, isFalse);
      expect(machine.ofrecerIrAConexion, isTrue);
      expect(machine.explicacionBotones, contains('Modo DEMO'));
    });

    test('Estado desconocido: ambos deshabilitados con explicación', () {
      final machine = evaluar(equipoActivo: null);

      expect(machine.estado, EstadoControl.desconocido);
      expect(machine.pausarHabilitado, isFalse);
      expect(machine.reanudarHabilitado, isFalse);
      expect(machine.explicacionBotones, contains('Todavía no conocemos'));
    });

    test('Prioridad: DEMO gana sobre conexión y orden pendiente', () {
      final machine = evaluar(
        modoDemo: true,
        conectado: true,
        esperando: true,
        equipoActivo: true,
      );
      expect(machine.estado, EstadoControl.demo);
    });

    test('Prioridad: sin conexión gana sobre una orden pendiente', () {
      final machine = evaluar(
        conectado: false,
        esperando: true,
        equipoActivo: false,
      );
      expect(machine.estado, EstadoControl.sinConexion);
    });

    test('Prioridad: enviando gana sobre el estado anterior del equipo', () {
      final machine = evaluar(
        equipoActivo: false,
        esperando: true,
        expirada: false,
      );
      expect(machine.estado, EstadoControl.enviando);
    });

    test('Prioridad: sin confirmar gana sobre el estado anterior del equipo', () {
      final machine = evaluar(
        equipoActivo: true,
        expirada: true,
      );
      expect(machine.estado, EstadoControl.sinConfirmar);
    });
  });
}
