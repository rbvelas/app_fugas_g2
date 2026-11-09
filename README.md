# Aqualerta - Detección Temprana de Fugas de Agua con IoT

Aplicación móvil desarrollada en Flutter para el proyecto de Internet de las Cosas de la Universidad Nacional de Trujillo (UNT).

## Arquitectura y Tópicos MQTT

La aplicación se comunica a través del broker **EMQX 5.8.6 (TCP 1883)** utilizando los siguientes tópicos:

| Tópico | Dirección | QoS | Payload / Descripción |
| :--- | :--- | :---: | :--- |
| `unt/iot/g2/riego/telemetria` | ESP32 $\rightarrow$ App | 0 | `{"dispositivo":"...","caudal_entrada":12.5,"caudal_salida":10.0,"diferencia_l_min":2.5,"diferencia_porcentaje":20.0,"volumen_entrada":150.2,"volumen_salida":140.0,"estado":"...","rssi":-68}` |
| `unt/iot/g2/riego/comando` | App $\rightarrow$ ESP32 | 1 | `{"orden":"PAUSAR"}` o `{"orden":"REANUDAR"}` |
| `unt/iot/g2/riego/equipo` | ESP32 $\rightarrow$ App | 1 | `{"activo":true}` o `{"activo":false}` (Retained) |

> [!IMPORTANT]
> **Aviso sobre tópicos de control**:
> Los tópicos de comando (`unt/iot/g2/riego/comando`) y equipo (`unt/iot/g2/riego/equipo`) son una propuesta técnica; el firmware del ESP32 aún debe implementarlos.
>
> **Aviso de seguridad hidráulica**:
> Pausar el circuito detiene la medición y la publicación del ESP32; **no detiene el flujo de agua físico**.

## Secciones de la Aplicación

1. **Monitoreo**:
   - Semáforo del estado del firmware (`NORMAL`, `DESVIACION`, `FUGA`, `SIN_FLUJO`, `SIN DATOS`).
   - Métricas en tiempo real ($Q_e$, $Q_s$, diferencia de caudal en $\text{L/min}$ y $\%$, volúmenes acumulados, RSSI).
   - Hora de última lectura en hora de Lima (`UTC-5`) formateada como `dd/MM/yyyy HH:mm:ss (Lima, UTC-5)`.
   - Gráfico temporal continuo de los últimos 120 segundos con `fl_chart`.
   - Alerta háptica y banner rojo ante estado de `FUGA`.

2. **Consulta**:
   - Historial en memoria de cambios de estado durante la sesión (máximo 200 entradas).
   - Botón para limpiar el historial.
   - Visualización del último mensaje JSON recibido en bruto.
   - Aclaración: la persistencia es volátil y no consulta la base de datos MySQL (`[POR COMPLETAR]`, pendiente de API backend).

3. **Control**:
   - Botones "Pausar circuito" y "Reanudar circuito" (botones $\ge 48\text{ dp}$).
   - Diálogo de confirmación antes de pausar.
   - Bloqueo contra doble toque durante 2 segundos.
   - Estado real del equipo (`unt/iot/g2/riego/equipo`) con timeout de 5 s ("sin confirmar").
   - Deshabilitado en Modo DEMO.

4. **Conexión**:
   - Configuración de IP/host del broker EMQX, puerto TCP (1883), usuario y contraseña en memoria RAM.
   - Interruptor de **Modo DEMO** para reproducir telemetría local desde `assets/demo_telemetria.csv` (60 registros ficticios en bucle, 1 por segundo).

## Ejecución de Pruebas Unitarias

```bash
flutter pub get
flutter test
```
Las pruebas unitarias validan:
- Parseo tolerante de telemetría, JSON inválido y descarte del mensaje de arranque `"ESP32 conectado"`.
- Registro de cambios de estado (solo cuando el estado varía).
- Tope máximo de 200 entradas en memoria.
- Lógica de timeout ("sin confirmar") a los 5 segundos.
- Generación exacta de tópicos y payloads JSON con cliente MQTT simulado sin broker real.
