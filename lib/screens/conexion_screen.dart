import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conexion_estado.dart';
import '../providers/telemetria_provider.dart';

/// Pantalla de configuración y gestión de la conexión MQTT con el broker EMQX.
/// La contraseña ingresada reside exclusivamente en la memoria RAM y nunca
/// es persistida en almacenamiento local ni registrada en logs.
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
    // Usar marcador <HOST> o el host configurado previamente
    _hostController = TextEditingController(
      text: provider.host.isNotEmpty ? provider.host : '',
    );
    _puertoController = TextEditingController(
      text: provider.puerto.toString(),
    );
    _usuarioController = TextEditingController(
      text: provider.usuario,
    );
    // La contraseña vive exclusivamente en este controlador en memoria
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
      await provider.desconectar();
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final host = _hostController.text.trim();
    final puerto = int.tryParse(_puertoController.text.trim()) ?? 1883;
    final usuario = _usuarioController.text.trim();
    final password = _passwordController.text;

    await provider.conectar(
      host: host,
      puerto: puerto,
      usuario: usuario.isNotEmpty ? usuario : null,
      password: password.isNotEmpty ? password : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TelemetriaProvider>();
    final estado = provider.estadoConexion;
    final estaConectado = estado == ConexionEstado.conectado;
    final estaConectando = estado == ConexionEstado.conectando;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Conexión al Broker MQTT',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tarjeta visual del estado de la conexión
              _buildTarjetaEstado(theme, estado, provider.mensajeError),

              const SizedBox(height: 20),

              // Campo Host / IP
              TextFormField(
                controller: _hostController,
                enabled: !estaConectando && !estaConectado,
                decoration: const InputDecoration(
                  labelText: 'Host o Dirección IP del Broker',
                  hintText: '<HOST> o 192.168.1.100',
                  helperText: 'Broker EMQX 5.8.6 (marcador <HOST>)',
                  prefixIcon: Icon(Icons.dns_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingrese la dirección del broker MQTT';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Campo Puerto (por defecto 1883)
              TextFormField(
                controller: _puertoController,
                enabled: !estaConectando && !estaConectado,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Puerto TCP',
                  hintText: '1883',
                  helperText: 'Puerto TCP estándar para MQTT sin TLS (1883)',
                  prefixIcon: Icon(Icons.numbers_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingrese el puerto del broker';
                  }
                  final p = int.tryParse(value.trim());
                  if (p == null || p <= 0 || p > 65535) {
                    return 'Puerto inválido (1 - 65535)';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Campo Usuario (opcional)
              TextFormField(
                controller: _usuarioController,
                enabled: !estaConectando && !estaConectado,
                decoration: const InputDecoration(
                  labelText: 'Usuario MQTT (Opcional)',
                  hintText: 'Dejar vacío si no requiere autenticación',
                  prefixIcon: Icon(Icons.person_rounded),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              // Campo Contraseña (campo oculto, memoria volátil)
              TextFormField(
                controller: _passwordController,
                enabled: !estaConectando && !estaConectado,
                obscureText: _ocultarPassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña (Opcional)',
                  hintText: 'Reside únicamente en memoria RAM',
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
                    tooltip: _ocultarPassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Botón principal Conectar / Desconectar (Altura ≥ 48 dp)
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
                  onPressed: estaConectando ? null : () => _ejecutarAccionConexion(provider),
                  icon: estaConectando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Icon(estaConectado ? Icons.power_settings_new_rounded : Icons.link_rounded),
                  label: Text(
                    estaConectando
                        ? 'Conectando...'
                        : (estaConectado ? 'Desconectar del Broker' : 'Conectar al Broker'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Tarjeta informativa de arquitectura y seguridad
              _buildTarjetaInformacion(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTarjetaEstado(ThemeData theme, ConexionEstado estado, String? error) {
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
                      fontWeight: FontWeight.w500,
                      color: Colors.red.shade900,
                    ),
                  ),
                ] else if (estado == ConexionEstado.conectado) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Suscrito a tópico: unt/iot/g2/riego/telemetria (QoS 0)',
                    style: TextStyle(
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
            '• La contraseña vive estrictamente en la memoria volátil de la aplicación.\n'
            '• No se guarda en disco, SharedPreferences ni se imprime en logs de consola.\n'
            '• Conexión directa TCP con keep-alive de 20 s y auto-reconexión configurada.',
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
