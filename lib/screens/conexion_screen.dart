import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conexion_estado.dart';
import '../providers/telemetria_provider.dart';
import '../utils/validador_conexion.dart';
import '../widgets/demo_banner.dart';

/// Pantalla de configuración y gestión de la conexión MQTT con el broker EMQX.
/// Soporta interruptor TLS seguro y modo DEMO local.
/// La contraseña ingresada reside exclusivamente en la memoria RAM y se borra
/// automáticamente al desconectar.
class ConexionScreen extends StatefulWidget {
  const ConexionScreen({super.key});

  @override
  State<ConexionScreen> createState() => _ConexionScreenState();
}

class _ConexionScreenState extends State<ConexionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _hostController;
  late final TextEditingController _puertoController;
  late final TextEditingController _usuarioController;
  late final TextEditingController _passwordController;

  bool _ocultarPassword = true;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TelemetriaProvider>();
    _hostController = TextEditingController(text: provider.host);
    _puertoController = TextEditingController(text: provider.puerto.toString());
    _usuarioController = TextEditingController(text: provider.usuario);
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _puertoController.dispose();
    _usuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _ejecutarAccionConexion(TelemetriaProvider provider) async {
    if (provider.estadoConexion == ConexionEstado.conectado) {
      // Borrado explícito de contraseña en RAM y desconexión
      _passwordController.clear();
      await provider.desconectar();
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final host = _hostController.text.trim();
    final puerto = int.tryParse(_puertoController.text.trim()) ?? (provider.usarTls ? 8883 : 1883);
    final usuario = _usuarioController.text.trim();
    final password = _passwordController.text;

    await provider.conectar(
      host: host,
      puerto: puerto,
      usuario: usuario.isNotEmpty ? usuario : null,
      password: password.isNotEmpty ? password : null,
      usarTls: provider.usarTls,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Conexión al Broker MQTT',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          if (esDemo) const DemoBanner(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Interruptores: Modo DEMO y TLS Seguro
                    _buildSwitchModoDemo(theme, provider),
                    const SizedBox(height: 10),
                    _buildSwitchTls(theme, provider, estaConectado || estaConectando),

                    const SizedBox(height: 16),

                    // 2. Tarjeta visual del estado de la conexión
                    _buildTarjetaEstado(theme, estado, provider.mensajeError, esDemo, provider.usarTls),

                    const SizedBox(height: 20),

                    // 3. Campo Host / IP (con validación de espacios y esquemas)
                    TextFormField(
                      controller: _hostController,
                      enabled: !estaConectando && !estaConectado && !esDemo,
                      decoration: const InputDecoration(
                        labelText: 'Host o Dirección IP del Broker',
                        hintText: 'IP del equipo donde corre EMQX',
                        helperText: 'Sin espacios ni esquema (no use http:// ni mqtt://)',
                        prefixIcon: Icon(Icons.dns_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (esDemo) return null;
                        return ValidadorConexion.validarHost(value);
                      },
                    ),

                    const SizedBox(height: 16),

                    // 4. Campo Puerto (1883 o 8883 editable, rango 1-65535)
                    TextFormField(
                      controller: _puertoController,
                      enabled: !estaConectando && !estaConectado && !esDemo,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Puerto TCP',
                        hintText: provider.usarTls ? '8883' : '1883',
                        helperText: provider.usarTls
                            ? 'Puerto estándar TLS seguro (8883)'
                            : 'Puerto TCP estándar sin cifrar (1883)',
                        prefixIcon: const Icon(Icons.numbers_rounded),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (esDemo) return null;
                        return ValidadorConexion.validarPuerto(value);
                      },
                    ),

                    const SizedBox(height: 16),

                    // 5. Campo Usuario (opcional)
                    TextFormField(
                      controller: _usuarioController,
                      enabled: !estaConectando && !estaConectado && !esDemo,
                      decoration: const InputDecoration(
                        labelText: 'Usuario MQTT (Opcional)',
                        hintText: 'Dejar vacío si el broker no requiere autenticación',
                        prefixIcon: Icon(Icons.person_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 6. Campo Contraseña (oculto por defecto, solo en memoria)
                    TextFormField(
                      controller: _passwordController,
                      enabled: !estaConectando && !estaConectado && !esDemo,
                      obscureText: _ocultarPassword,
                      decoration: InputDecoration(
                        labelText: 'Contraseña (Opcional)',
                        hintText: 'Reside únicamente en memoria RAM',
                        helperText: 'Se borra de memoria automáticamente al desconectar',
                        prefixIcon: const Icon(Icons.lock_rounded),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
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
                          tooltip: _ocultarPassword
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 7. Botón principal Conectar / Desconectar (Altura ≥ 48 dp)
                    SizedBox(
                      height: 52, // Cumple requisito botones ≥ 48 dp
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: estaConectado
                              ? const Color(0xFFD32F2F)
                              : (estaConectando ? Colors.amber.shade800 : null),
                          foregroundColor: estaConectado || estaConectando
                              ? Colors.white
                              : null,
                          elevation: 2,
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
                            : Icon(estaConectado
                                ? Icons.power_settings_new_rounded
                                : Icons.link_rounded),
                        label: Text(
                          estaConectando
                              ? 'Conectando...'
                              : (estaConectado
                                  ? 'Desconectar del Broker'
                                  : 'Conectar al Broker'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 8. Tarjeta informativa de privacidad y seguridad
                    _buildTarjetaInformacion(theme),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchModoDemo(ThemeData theme, TelemetriaProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: provider.modoDemoActivo
            ? const Color(0xFFFFF3E0)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: provider.modoDemoActivo
              ? const Color(0xFFFF9800)
              : theme.colorScheme.outlineVariant.withOpacity(0.5),
          width: provider.modoDemoActivo ? 1.5 : 1.0,
        ),
      ),
      child: SwitchListTile(
        title: const Row(
          children: [
            Icon(Icons.science_rounded, size: 20, color: Color(0xFFE65100)),
            SizedBox(width: 8),
            Text(
              'Modo DEMO',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ],
        ),
        subtitle: const Text(
          'Reproduce datos ficticios en bucle (60 filas, 1 lect/s) sin broker MQTT.',
          style: TextStyle(fontSize: 12),
        ),
        value: provider.modoDemoActivo,
        activeColor: const Color(0xFFE65100),
        onChanged: (valor) {
          provider.setModoDemo(valor);
        },
      ),
    );
  }

  Widget _buildSwitchTls(ThemeData theme, TelemetriaProvider provider, bool bloqueado) {
    return Container(
      decoration: BoxDecoration(
        color: provider.usarTls ? const Color(0xFFE8F5E9) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: provider.usarTls ? const Color(0xFF2E7D32) : theme.colorScheme.outlineVariant.withOpacity(0.5),
          width: provider.usarTls ? 1.5 : 1.0,
        ),
      ),
      child: SwitchListTile(
        title: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: 20, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text(
              'Conexión segura (TLS)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ],
        ),
        subtitle: Text(
          provider.usarTls
              ? 'TLS activo: usa cifrado estricto y puerto 8883 (editable).'
              : 'TLS desactivado: puerto 1883 sin cifrar (predeterminado del laboratorio).',
          style: const TextStyle(fontSize: 12),
        ),
        value: provider.usarTls,
        activeColor: const Color(0xFF2E7D32),
        onChanged: bloqueado
            ? null
            : (valor) {
                provider.setUsarTls(valor);
                setState(() {
                  _puertoController.text = provider.puerto.toString();
                });
              },
      ),
    );
  }

  Widget _buildTarjetaEstado(
    ThemeData theme,
    ConexionEstado estado,
    String? error,
    bool esDemo,
    bool usarTls,
  ) {
    if (esDemo) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFF9800), width: 1.5),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.science_rounded, color: Color(0xFFE65100), size: 28),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ESTADO DEL SISTEMA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: Color(0xFFE65100),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Modo DEMO activo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE65100),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Simulando telemetría desde assets/demo_telemetria.csv.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF424242)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: estado.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: estado.color.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: estado.color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              estado.icono,
              color: estado.color,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ESTADO DE LA CONEXIÓN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Color(0xFF616161),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  estado.etiqueta,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: estado.color,
                  ),
                ),
                if (estado == ConexionEstado.error && error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    error,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade900,
                    ),
                  ),
                ] else if (estado == ConexionEstado.conectado) ...[
                  const SizedBox(height: 4),
                  Text(
                    usarTls
                        ? 'Conexión segura TLS activa. Suscrito a telemetria y equipo.'
                        : 'Conexión TCP activa (sin TLS). Suscrito a telemetria y equipo.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaInformacion(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'POLÍTICA DE PRIVACIDAD Y SEGURIDAD',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '• La contraseña vive estrictamente en la memoria RAM y se borra al desconectar.\n'
            '• No se almacena en disco, SQLite, SharedPreferences ni se expone en logs ni errores.\n'
            '• Admite TLS sobre TCP (puerto 8883) con validación estricta de certificados CA.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF424242),
            ),
          ),
        ],
      ),
    );
  }
}
