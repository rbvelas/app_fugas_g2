import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conexion_estado.dart';
import '../models/estado_control.dart';
import '../providers/telemetria_provider.dart';
import '../theme/paleta_estados.dart';
import '../widgets/barra_superior_aqualerta.dart';
import '../widgets/demo_banner.dart';

/// Pantalla de Control de la medición.
///
/// La habilitación de los botones depende del estado REAL del equipo
/// (mensaje retenido de estado), no de un temporizador de doble toque:
/// - Activo: "Pausar" habilitado.
/// - En pausa: "Reanudar" habilitado y principal.
/// - Orden enviada: ambos deshabilitados con progreso.
/// - Sin confirmación: "Reintentar", sin dejar la pantalla bloqueada.
class ControlScreen extends StatefulWidget {
  final VoidCallback onIrAConexion;

  const ControlScreen({super.key, required this.onIrAConexion});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  bool _estabaEsperando = false;
  String? _ultimaOrdenEnviada;

  Future<void> _solicitarPausar(TelemetriaProvider provider) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pausar la medición'),
        content: const Text(
          'Se dejarán de medir y publicar datos hasta que reanudes. '
          'El agua seguirá fluyendo.',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: PaletaEstados.desviacion,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pausar'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      await _enviarOrden(provider, 'PAUSAR');
    }
  }

  Future<void> _reanudar(TelemetriaProvider provider) async {
    await _enviarOrden(provider, 'REANUDAR');
  }

  Future<void> _reintentar(TelemetriaProvider provider) async {
    final orden = provider.ordenPendiente;
    if (orden == null) return;
    await _enviarOrden(provider, orden);
  }

  Future<void> _enviarOrden(TelemetriaProvider provider, String orden) async {
    _ultimaOrdenEnviada = orden;
    await provider.enviarOrden(orden);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TelemetriaProvider>();
    final machine = MaquinaEstadosControl.evaluar(
      conectado: provider.estadoConexion == ConexionEstado.conectado,
      modoDemo: provider.modoDemoActivo,
      equipoActivo: provider.equipoActivo,
      esperandoConfirmacion: provider.esperandoConfirmacion,
      confirmacionExpirada: provider.confirmacionExpirada,
    );

    _avisarConfirmacion(provider);

    return Scaffold(
      appBar: BarraSuperiorAqualerta(
        titulo: 'Control',
        onIrAConexion: widget.onIrAConexion,
      ),
      body: Column(
        children: [
          if (provider.modoDemoActivo) const DemoBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TarjetaEstadoEquipo(maquina: machine),
                  const SizedBox(height: 16),
                  const _AvisoSeguridadHidraulica(),
                  const SizedBox(height: 24),
                  Text(
                    'Órdenes de medición',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _BotonControl(
                            etiqueta: 'Pausar',
                            icono: Icons.pause_rounded,
                            habilitado: machine.pausarHabilitado,
                            color: PaletaEstados.desviacion,
                            semantica:
                                'Pausar la medición. Se dejarán de medir y publicar datos hasta que reanudes.',
                            onPressed: () => _solicitarPausar(provider),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BotonControl(
                            etiqueta: 'Reanudar',
                            icono: Icons.play_arrow_rounded,
                            habilitado: machine.reanudarHabilitado,
                            color: PaletaEstados.normal,
                            esPrincipal: machine.reanudarEsPrincipal,
                            semantica: 'Reanudar la medición del equipo.',
                            onPressed: () => _reanudar(provider),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _EstadoBotones(
                    maquina: machine,
                    proveedor: provider,
                    onReintentar: () => _reintentar(provider),
                    onIrAConexion: widget.onIrAConexion,
                  ),
                  const SizedBox(height: 24),
                  const _NotaConfirmacion(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _avisarConfirmacion(TelemetriaProvider provider) {
    final esperandoAhora = provider.esperandoConfirmacion;
    if (_estabaEsperando == esperandoAhora) return;
    final acababaDeEsperar = _estabaEsperando;
    _estabaEsperando = esperandoAhora;

    if (!acababaDeEsperar ||
        esperandoAhora ||
        provider.confirmacionExpirada ||
        _ultimaOrdenEnviada == null) {
      return;
    }

    final confirmado = _ultimaOrdenEnviada == 'PAUSAR'
        ? provider.equipoActivo == false
        : provider.equipoActivo == true;
    if (!confirmado) return;

    final mensaje = _ultimaOrdenEnviada == 'PAUSAR'
        ? 'El equipo confirmó la pausa.'
        : 'El equipo confirmó la reanudación.';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }
}

class _TarjetaEstadoEquipo extends StatelessWidget {
  final MaquinaEstadosControl maquina;

  const _TarjetaEstadoEquipo({required this.maquina});

  @override
  Widget build(BuildContext context) {
    final estilo = _estiloEstado(maquina.estado);
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Estado del equipo: ${maquina.etiquetaEstado}. ${maquina.detalleEstado}',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: estilo.fondo,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: estilo.color.withAlpha(115), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: estilo.color.withAlpha(38),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(estilo.icono, color: estilo.color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estado del equipo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: PaletaEstados.textoSecundario,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        maquina.etiquetaEstado,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: estilo.color,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              maquina.detalleEstado,
              style: const TextStyle(
                color: PaletaEstados.textoSecundario,
                height: 1.35,
              ),
            ),
            if (maquina.mostrarProgreso) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const LinearProgressIndicator(minHeight: 6),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _EstiloEstado _estiloEstado(EstadoControl estado) {
    switch (estado) {
      case EstadoControl.activo:
        return const _EstiloEstado(
          PaletaEstados.normal,
          PaletaEstados.normalFondo,
          Icons.play_circle_filled_rounded,
        );
      case EstadoControl.pausado:
        return const _EstiloEstado(
          PaletaEstados.pausa,
          PaletaEstados.pausaFondo,
          Icons.pause_circle_filled_rounded,
        );
      case EstadoControl.enviando:
      case EstadoControl.sinConfirmar:
        return const _EstiloEstado(
          PaletaEstados.desviacion,
          PaletaEstados.desviacionFondo,
          Icons.sync_rounded,
        );
      case EstadoControl.sinConexion:
        return const _EstiloEstado(
          PaletaEstados.pausa,
          PaletaEstados.pausaFondo,
          Icons.cloud_off_rounded,
        );
      case EstadoControl.demo:
        return const _EstiloEstado(
          PaletaEstados.demo,
          PaletaEstados.demoFondo,
          Icons.science_rounded,
        );
      case EstadoControl.desconocido:
        return const _EstiloEstado(
          PaletaEstados.pausa,
          PaletaEstados.pausaFondo,
          Icons.help_outline_rounded,
        );
    }
  }
}

class _EstiloEstado {
  final Color color;
  final Color fondo;
  final IconData icono;

  const _EstiloEstado(this.color, this.fondo, this.icono);
}

class _BotonControl extends StatelessWidget {
  final String etiqueta;
  final IconData icono;
  final bool habilitado;
  final bool esPrincipal;
  final Color color;
  final String semantica;
  final VoidCallback onPressed;

  const _BotonControl({
    required this.etiqueta,
    required this.icono,
    required this.habilitado,
    required this.color,
    required this.semantica,
    required this.onPressed,
    this.esPrincipal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: habilitado,
      label: semantica,
      onTap: habilitado ? onPressed : null,
      excludeSemantics: true,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: PaletaEstados.pausaFondo,
          disabledForegroundColor: PaletaEstados.textoSecundario.withAlpha(191),
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: esPrincipal ? 2 : 0,
        ),
        onPressed: habilitado ? onPressed : null,
        icon: Icon(icono, size: 22),
        label: Text(
          etiqueta,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _EstadoBotones extends StatelessWidget {
  final MaquinaEstadosControl maquina;
  final TelemetriaProvider proveedor;
  final VoidCallback onReintentar;
  final VoidCallback onIrAConexion;

  const _EstadoBotones({
    required this.maquina,
    required this.proveedor,
    required this.onReintentar,
    required this.onIrAConexion,
  });

  @override
  Widget build(BuildContext context) {
    if (maquina.mostrarProgreso) {
      return Semantics(
        liveRegion: true,
        label: 'Esperando confirmación del equipo',
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Esperando confirmación del equipo…',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (maquina.mostrarReintentar) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            maquina.explicacionBotones,
            style: const TextStyle(
              color: PaletaEstados.desviacion,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: PaletaEstados.desviacion,
                side: const BorderSide(color: PaletaEstados.desviacion),
              ),
              onPressed: proveedor.ordenPendiente == null ? null : onReintentar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ),
        ],
      );
    }

    if (maquina.ambosDeshabilitados) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            maquina.explicacionBotones,
            style: const TextStyle(
              color: PaletaEstados.textoSecundario,
              height: 1.3,
            ),
          ),
          if (maquina.ofrecerIrAConexion) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onIrAConexion,
              icon: const Icon(Icons.settings_input_antenna_rounded),
              label: const Text('Ir a Conexión'),
            ),
          ],
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

class _AvisoSeguridadHidraulica extends StatelessWidget {
  const _AvisoSeguridadHidraulica();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PaletaEstados.desviacionFondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaletaEstados.desviacionBorde, width: 1.5),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              color: PaletaEstados.desviacion, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pausar detiene la medición y la publicación de datos. '
              'El agua seguirá fluyendo.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: PaletaEstados.desviacion,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotaConfirmacion extends StatelessWidget {
  const _NotaConfirmacion();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined,
              size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'El equipo confirma cada orden. Si no responde en 5 segundos, '
              'aparecerá la opción Reintentar.',
              style: TextStyle(
                color: PaletaEstados.textoSecundario,
                height: 1.35,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
