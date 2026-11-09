import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conexion_estado.dart';
import '../providers/telemetria_provider.dart';
import '../theme/paleta_estados.dart';
import '../utils/validador_conexion.dart';
import '../widgets/barra_superior_aqualerta.dart';
import '../widgets/demo_banner.dart';

/// Pantalla de Conexión.
///
/// Orden: estado → datos de conexión → botón Conectar/Desconectar →
/// Opciones avanzadas (TLS y Modo DEMO).
/// La contraseña está oculta por defecto y se vuelve a ocultar al conectar,
/// al cambiar de pestaña y al pasar la app a segundo plano.
class ConexionScreen extends StatefulWidget {
  final VoidCallback onIrAConexion;
  final bool visible;

  const ConexionScreen({
    super.key,
    required this.onIrAConexion,
    this.visible = true,
  });

  @override
  State<ConexionScreen> createState() => _ConexionScreenState();
}

class _ConexionScreenState extends State<ConexionScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _hostController;
  late final TextEditingController _puertoController;
  late final TextEditingController _usuarioController;
  late final TextEditingController _passwordController;

  bool _ocultarPassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final provider = context.read<TelemetriaProvider>();
    _hostController = TextEditingController(text: provider.host);
    _puertoController =
        TextEditingController(text: provider.puerto.toString());
    _usuarioController = TextEditingController(text: provider.usuario);
    _passwordController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant ConexionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.visible && oldWidget.visible) {
      _ocultarContrasenaAhora();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _ocultarContrasenaAhora();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hostController.dispose();
    _puertoController.dispose();
    _usuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _ocultarContrasenaAhora() {
    if (!mounted || _ocultarPassword) return;
    setState(() {
      _ocultarPassword = true;
    });
  }

  Future<void> _ejecutarAccionConexion(TelemetriaProvider provider) async {
    if (provider.estadoConexion == ConexionEstado.conectado) {
      _passwordController.clear();
      _ocultarContrasenaAhora();
      await provider.desconectar();
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final host = _hostController.text.trim();
    final puerto = int.tryParse(_puertoController.text.trim()) ??
        (provider.usarTls ? 8883 : 1883);
    final usuario = _usuarioController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _ocultarPassword = true;
    });

    final exito = await provider.conectar(
      host: host,
      puerto: puerto,
      usuario: usuario.isNotEmpty ? usuario : null,
      password: password.isNotEmpty ? password : null,
      usarTls: provider.usarTls,
    );

    if (!mounted) return;
    if (exito) {
      _passwordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conexión establecida'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo conectar. Revisa los datos.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _avisarBloqueo(String motivo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(motivo),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TelemetriaProvider>();
    final estado = provider.estadoConexion;
    final estaConectado = estado == ConexionEstado.conectado;
    final estaConectando = estado == ConexionEstado.conectando;
    final esDemo = provider.modoDemoActivo;
    final bloqueado = estaConectado || estaConectando || esDemo;

    final motivoBloqueo = esDemo
        ? 'Desactiva el Modo DEMO para configurar la conexión.'
        : estaConectado
            ? 'Desconecta para cambiar estos datos.'
            : estaConectando
                ? 'Espera a que termine la conexión.'
                : null;

    return Scaffold(
      appBar: BarraSuperiorAqualerta(
        titulo: 'Conexión',
        onIrAConexion: widget.onIrAConexion,
      ),
      body: Column(
        children: [
          if (esDemo) const DemoBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TarjetaEstadoConexion(
                      estado: estado,
                      esDemo: esDemo,
                      usarTls: provider.usarTls,
                      mensajeError: provider.mensajeError,
                      estaConectando: estaConectando,
                      onReintentar: () =>
                          _ejecutarAccionConexion(provider),
                    ),
                    const SizedBox(height: 16),
                    if (motivoBloqueo != null) ...[
                      _AvisoBloqueo(motivo: motivoBloqueo),
                      const SizedBox(height: 12),
                    ],
                    _campoTexto(
                      controller: _hostController,
                      etiqueta: 'Dirección del servidor',
                      pista: 'Ejemplo: 192.168.0.20',
                      ayuda: 'IP o nombre del equipo donde corre el servidor.',
                      icono: Icons.dns_rounded,
                      bloqueado: bloqueado,
                      motivoBloqueo: motivoBloqueo,
                      validador: (value) =>
                          esDemo ? null : ValidadorConexion.validarHost(value),
                    ),
                    const SizedBox(height: 14),
                    _campoTexto(
                      controller: _puertoController,
                      etiqueta: 'Puerto',
                      pista: provider.usarTls ? '8883' : '1883',
                      ayuda: provider.usarTls
                          ? 'Puerto habitual con conexión segura (8883).'
                          : 'Puerto habitual sin cifrado (1883).',
                      icono: Icons.numbers_rounded,
                      bloqueado: bloqueado,
                      motivoBloqueo: motivoBloqueo,
                      teclado: TextInputType.number,
                      validador: (value) =>
                          esDemo ? null : ValidadorConexion.validarPuerto(value),
                    ),
                    const SizedBox(height: 14),
                    _campoTexto(
                      controller: _usuarioController,
                      etiqueta: 'Usuario (opcional)',
                      pista: 'Déjalo vacío si no se pide',
                      ayuda: 'Nombre de usuario del servidor, si lo tiene.',
                      icono: Icons.person_rounded,
                      bloqueado: bloqueado,
                      motivoBloqueo: motivoBloqueo,
                    ),
                    const SizedBox(height: 14),
                    _campoContrasena(provider, bloqueado, motivoBloqueo),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: estaConectado
                            ? PaletaEstados.pausa
                            : theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(48, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: estaConectando || esDemo
                          ? null
                          : () => _ejecutarAccionConexion(provider),
                      icon: estaConectando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              estaConectado
                                  ? Icons.power_settings_new_rounded
                                  : Icons.link_rounded,
                            ),
                      label: Text(
                        estaConectando
                            ? 'Conectando…'
                            : (estaConectado ? 'Desconectar' : 'Conectar'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _OpcionesAvanzadas(
                      provider: provider,
                      estado: estado,
                      esDemo: esDemo,
                      alCambiarTls: () {
                        setState(() {
                          _puertoController.text =
                              provider.puerto.toString();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'La contraseña no se guarda en el teléfono: '
                      'solo vive en memoria mientras dura la conexión.',
                      style: TextStyle(
                        fontSize: 12,
                        color: PaletaEstados.textoSecundario,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoTexto({
    required TextEditingController controller,
    required String etiqueta,
    required String pista,
    required String ayuda,
    required IconData icono,
    required bool bloqueado,
    required String? motivoBloqueo,
    TextInputType? teclado,
    String? Function(String?)? validador,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      readOnly: bloqueado,
      showCursor: !bloqueado,
      enableInteractiveSelection: !bloqueado,
      keyboardType: teclado,
      autocorrect: false,
      enableSuggestions: false,
      onTap: bloqueado && motivoBloqueo != null
          ? () => _avisarBloqueo(motivoBloqueo)
          : null,
      style: TextStyle(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: etiqueta,
        hintText: pista,
        helperText: bloqueado ? null : ayuda,
        prefixIcon: Icon(icono),
        suffixIcon: bloqueado
            ? const Icon(Icons.lock_outline_rounded, size: 18)
            : null,
        filled: bloqueado,
        fillColor:
            bloqueado ? PaletaEstados.pausaFondo : null,
        border: const OutlineInputBorder(),
      ),
      validator: validador,
    );
  }

  Widget _campoContrasena(
    TelemetriaProvider provider,
    bool bloqueado,
    String? motivoBloqueo,
  ) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: _passwordController,
      readOnly: bloqueado,
      showCursor: !bloqueado,
      enableInteractiveSelection: !bloqueado,
      obscureText: _ocultarPassword,
      autocorrect: false,
      enableSuggestions: false,
      onTap: bloqueado && motivoBloqueo != null
          ? () => _avisarBloqueo(motivoBloqueo)
          : null,
      style: TextStyle(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: 'Contraseña (opcional)',
        hintText: bloqueado && provider.tieneContrasena
            ? 'Guardada en memoria'
            : 'Solo se guarda en memoria',
        helperText: bloqueado ? null : 'Se borra al desconectar.',
        prefixIcon: const Icon(Icons.lock_rounded),
        suffixIcon: bloqueado
            ? const Icon(Icons.lock_outline_rounded, size: 18)
            : IconButton(
                constraints:
                    const BoxConstraints(minWidth: 48, minHeight: 48),
                tooltip: _ocultarPassword
                    ? 'Mostrar contraseña'
                    : 'Ocultar contraseña',
                icon: Icon(
                  _ocultarPassword
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
                onPressed: () {
                  setState(() {
                    _ocultarPassword = !_ocultarPassword;
                  });
                },
              ),
        filled: bloqueado,
        fillColor:
            bloqueado ? PaletaEstados.pausaFondo : null,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _AvisoBloqueo extends StatelessWidget {
  final String motivo;

  const _AvisoBloqueo({required this.motivo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PaletaEstados.infoFondo,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded,
              size: 18, color: PaletaEstados.sinFlujo),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              motivo,
              style: const TextStyle(
                color: PaletaEstados.textoSecundario,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaEstadoConexion extends StatelessWidget {
  final ConexionEstado estado;
  final bool esDemo;
  final bool usarTls;
  final String? mensajeError;
  final bool estaConectando;
  final VoidCallback onReintentar;

  const _TarjetaEstadoConexion({
    required this.estado,
    required this.esDemo,
    required this.usarTls,
    required this.mensajeError,
    required this.estaConectando,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final Color fondo;
    final IconData icono;
    final String titulo;
    final String detalle;

    if (esDemo) {
      color = PaletaEstados.demo;
      fondo = PaletaEstados.demoFondo;
      icono = Icons.science_rounded;
      titulo = 'Modo DEMO activo';
      detalle = 'Se muestran datos de ejemplo. No hay un equipo real conectado.';
    } else {
      color = estado.color;
      fondo = estado.colorFondo;
      icono = estado.icono;
      titulo = estado.etiquetaDetallada;
      if (estado == ConexionEstado.conectado) {
        detalle = usarTls
            ? 'Conexión segura activa. Recibiendo datos del servidor.'
            : 'Recibiendo datos del servidor.';
      } else if (estado == ConexionEstado.conectando) {
        detalle = 'Esperando respuesta del servidor…';
      } else if (estado == ConexionEstado.error) {
        detalle = mensajeError ??
            'Revisa la dirección y el puerto, y vuelve a intentar.';
      } else {
        detalle = 'Ingresa los datos y presiona Conectar.';
      }
    }

    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Estado de la conexión: $titulo. $detalle',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(102), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withAlpha(41),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icono, color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: color,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detalle,
                        style: const TextStyle(
                          color: PaletaEstados.textoSecundario,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (estaConectando) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const LinearProgressIndicator(minHeight: 6),
              ),
            ],
            if (!esDemo &&
                estado == ConexionEstado.error &&
                !estaConectando) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                onPressed: onReintentar,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OpcionesAvanzadas extends StatelessWidget {
  final TelemetriaProvider provider;
  final ConexionEstado estado;
  final bool esDemo;
  final VoidCallback alCambiarTls;

  const _OpcionesAvanzadas({
    required this.provider,
    required this.estado,
    required this.esDemo,
    required this.alCambiarTls,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final puedeCambiar = estado == ConexionEstado.desconectado ||
        estado == ConexionEstado.error;
    final bloqueadoTls = !puedeCambiar || esDemo;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(
          Icons.settings_outlined,
          color: PaletaEstados.textoSecundario,
        ),
        title: const Text(
          'Opciones avanzadas',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text(
          'Conexión segura y modo de prueba',
          style: TextStyle(
            color: PaletaEstados.textoSecundario,
            fontSize: 12,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        children: [
          SwitchListTile(
            value: provider.usarTls,
            onChanged: bloqueadoTls
                ? null
                : (valor) {
                    provider.setUsarTls(valor);
                    alCambiarTls();
                  },
            title: const Text(
              'Conexión segura (TLS)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              provider.usarTls
                  ? 'Protege la conexión con cifrado. Puerto 8883.'
                  : 'Sin cifrado. Puerto 1883.',
              style: const TextStyle(
                color: PaletaEstados.textoSecundario,
                fontSize: 12,
              ),
            ),
            secondary: const Icon(
              Icons.lock_outline_rounded,
              color: PaletaEstados.normal,
            ),
          ),
          SwitchListTile(
            value: provider.modoDemoActivo,
            onChanged: estado == ConexionEstado.conectando
                ? null
                : (valor) {
                    provider.setModoDemo(valor);
                  },
            title: const Text(
              'Modo DEMO',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Muestra datos de ejemplo sin conectar un equipo.',
              style: TextStyle(
                color: PaletaEstados.textoSecundario,
                fontSize: 12,
              ),
            ),
            secondary: const Icon(
              Icons.science_outlined,
              color: PaletaEstados.demo,
            ),
          ),
          if (!puedeCambiar)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Desconecta para cambiar la conexión segura.',
                  style: TextStyle(
                    color: PaletaEstados.textoSecundario,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
