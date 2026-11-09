# Aqualerta - Detección Temprana de Fugas de Agua con IoT

Aplicación móvil desarrollada en Flutter para la supervisión y control del sistema de detección temprana de fugas de agua en tramos de tubería y riego, como parte del curso de Internet de las Cosas de la Escuela Profesional de Ingeniería de Sistemas (Universidad Nacional de Trujillo).

---

## 1. Descripción del Sistema

Aqualerta permite supervisar en tiempo real la telemetría enviada por un nodo sensor **ESP32** equipado con dos sensores de caudal por pulsos **YF-S201** instalados a la entrada ($Q_e$) y salida ($Q_s$) de un tramo hidráulico.

El firmware del microcontrolador calcula localmente el estado operativo:
- **NORMAL**: Flujo de agua dentro de los parámetros regulares.
- **DESVIACION**: Diferencia de caudal $\ge 15\text{ \%}$ sostenida durante 3 lecturas continuas.
- **FUGA**: Diferencia de caudal $\ge 30\text{ \%}$ sostenida durante 3 lecturas continuas (fuga crítica).
- **SIN_FLUJO**: Ambos sensores registran caudales menores a $0{,}5\text{ L/min}$.

La aplicación **no recalcula el estado**; lo representa visualmente mediante un semáforo de alta visibilidad, alerta háptica y notificaciones críticas.

---

## 2. Arquitectura de Comunicación y Tópicos MQTT

La aplicación se comunica con un broker **EMQX 5.8.6**. Los tópicos y formatos de mensaje se distribuyen de la siguiente manera:

| Tópico | Dirección | QoS | Estado en el Sistema | Formato de Payload / Descripción |
| :--- | :--- | :---: | :---: | :--- |
| `unt/iot/g2/riego/telemetria` | ESP32 $\rightarrow$ App | 0 | **Real (Existente)** | JSON con telemetría: `{"dispositivo":"ESP32","caudal_entrada":12.5,"caudal_salida":10.0,"diferencia_l_min":2.5,"diferencia_porcentaje":20.0,"volumen_entrada":150.2,"volumen_salida":140.0,"estado":"DESVIACION","rssi":-68}`. El mensaje de inicio `{"mensaje":"ESP32 conectado"}` es descartado de forma segura. |
| `unt/iot/g2/riego/comando` | App $\rightarrow$ ESP32 | 1 | **Propuesta técnica** | `{"orden":"PAUSAR"}` o `{"orden":"REANUDAR"}`. Permite suspender o reanudar la medición del ESP32. |
| `unt/iot/g2/riego/equipo` | ESP32 $\rightarrow$ App | 1 | **Propuesta técnica** | `{"activo":true}` o `{"activo":false}` (Retained). Informa el estado real del nodo emisor con confirmación. |

> [!WARNING]
> **Aviso de seguridad hidráulica**:
> La orden **Pausar** detiene exclusivamente el conteo y la publicación de telemetría del ESP32; **no cierra físicamente electroválvulas ni detiene el flujo de agua en la tubería**.

---

## 3. Matriz de Control de Acceso (ACL) y Mínimo Privilegio

Para garantizar el principio de mínimo privilegio en el broker EMQX, se establece la separación estricta de credenciales y permisos entre la aplicación móvil y el firmware:

| Usuario | Acción Permitida | Tópicos Autorizados | Justificación de Seguridad |
| :--- | :--- | :--- | :--- |
| **`app_movil_user`** (Aplicación) | `SUBSCRIBE` (Lectura)<br>`PUBLISH` (Escritura) | `unt/iot/g2/riego/telemetria`<br>`unt/iot/g2/riego/equipo`<br>`unt/iot/g2/riego/comando` | La aplicación móvil solo necesita consumir lecturas y telemetría, y emitir órdenes de control. **No debe publicar lecturas falsas de caudal**. |
| **`esp32_sensor_user`** (Firmware) | `PUBLISH` (Escritura)<br>`SUBSCRIBE` (Lectura) | `unt/iot/g2/riego/telemetria`<br>`unt/iot/g2/riego/equipo`<br>`unt/iot/g2/riego/comando` | El nodo físico solo debe publicar mediciones y su estado retenido, escuchando órdenes en el canal de comando. |

> [!IMPORTANT]
> **Recomendación de credenciales**:
> La app **no debe compartir ni reutilizar las credenciales del ESP32**. En entornos de producción y entrega de laboratorio, cada cliente móvil debe autenticarse con su propio usuario y contraseña restringido por ACL.

---

## 4. Estado de los Mecanismos de Seguridad

| Mecanismo de Seguridad | Clasificación | Estado de Implementación |
| :--- | :---: | :--- |
| **Aislamiento de credenciales en memoria volátil** | Implementado | La contraseña se mantiene exclusivamente en memoria RAM mientras dura la sesión; se borra automáticamente al desconectar. No se guarda en disco, SharedPreferences, SQLite ni se imprime en logs o errores. |
| **Validación de entradas de conexión** | Implementado | Validación estricta que impide espacios en blanco y esquemas (`http://`, `mqtt://`, etc.) en el host. Puerto validado en el rango 1 a 65535. Usuario normalizado sin espacios. |
| **Validación de tipos y rangos físicos** | Implementado | Filtra caudales $< 0$, variaciones porcentuales fuera de $[-100{,}0\text{ \%}, 100{,}0\text{ \%}]$, estados no reconocidos y RSSI fuera de $[-120, 0]\text{ dBm}$. Los mensajes anómalos se descartan sin romper la app. |
| **Auditoría de mensajes descartados** | Implementado | Conteo en tiempo real de mensajes descartados por violación de rangos o formato, visible en la pantalla de Consulta. |
| **Soporte TLS / MQTTS (TCP seguro)** | Implementado | Conexión cifrada opcional sobre puerto 8883 utilizando el `SecurityContext` del sistema sin bypass de certificados CA no válidos. |
| **Protección contra doble envío** | Implementado | Bloqueo automático de doble toque durante 2 segundos y diálogo de confirmación antes de pausar. |
| **Timeout de confirmación ("sin confirmar")** | Implementado | Si en 5 segundos no arriba la confirmación en `unt/iot/g2/riego/equipo`, el estado pasa a "sin confirmar". |
| **Listas de control de acceso (ACL) en EMQX** | Propuesto | Esquema de reglas de autorización por usuario y tópico documentado para configuración en el panel de EMQX. |
| **Autenticación mTLS (Certificados de cliente)** | Propuesto | Despliegue de certificados X.509 individuales por dispositivo móvil para evitar credenciales estáticas. |
| **Servicio de persistencia histórica MySQL** | Pendiente | Requiere el desarrollo de una API REST de backend que consulte la base de datos relacional del proyecto `[POR COMPLETAR]`. |

---

## 5. Limitaciones Conocidas del Proyecto

1. **Persistencia histórica en MySQL**: La app no consulta directamente la base de datos MySQL debido a que requiere una API de backend intermedia que aún no existe en el proyecto `[POR COMPLETAR]`.
2. **Implementación de órdenes en firmware**: Los comandos de pausa y reanudación dependen de una actualización pendiente en el firmware del ESP32 que procese el tópico `unt/iot/g2/riego/comando`.
3. **Cifrado TLS en el laboratorio**: El broker EMQX actual del laboratorio universitario opera en TCP plano (puerto 1883 sin TLS); la app incluye el soporte TLS para cuando el broker configure certificados válidos.
4. **Pruebas de campo en instalaciones UNT**: La app fue evaluada en laboratorio y mediante simuladores; la validación hidráulica con flujo real en el campus universitario se encuentra `[POR COMPLETAR]`.

---

## 6. Guía de Uso y Modos de Prueba

### A. Modo DEMO (Sin broker MQTT)
Ideal para demostraciones académicas y pruebas de interfaz sin necesidad de conexión física:
1. Diríjase a la sección **Conexión**.
2. Active el interruptor **Modo DEMO**.
3. Se iniciará la reproducción cíclica de 60 registros ficticios desde `assets/demo_telemetria.csv` a razón de 1 lectura por segundo.
4. Aparecerá un letrero permanente: `"DEMO · datos de ejemplo"`.
5. Los botones de control se deshabilitarán automáticamente para prevenir operaciones inválidas.

### B. Modo Conexión al Broker Real
1. Ingrese a la pestaña **Conexión**.
2. Desactive el Modo DEMO si estaba habilitado.
3. Ingrese la IP del equipo donde corre EMQX (ej. `192.168.1.100` o dominio del broker).
4. El puerto predeterminado es `1883` (o `8883` si activa TLS).
5. Ingrese usuario y contraseña si el broker tiene autenticación habilitada.
6. Presione **Conectar al Broker**. El indicador pasará a verde una vez confirmada la suscripción.

---

## 7. Compilación y Ejecución de Pruebas

### Compilación Local
```bash
# 1. Obtener dependencias
flutter pub get

# 2. Ejecutar suite de pruebas unitarias
flutter test

# 3. Compilar APK Release para Android
flutter build apk --release
```

### Compilación en GitHub Actions
El flujo de CI en `.github/workflows/apk.yml` compila el APK automáticamente:
- Genera la plataforma Android con application ID `com.unt.g2.fugas`.
- Inyecta el permiso `android.permission.INTERNET`.
- Ejecuta `flutter pub get` y `flutter test`.
- Compila `flutter build apk --release` y publica el artefacto descargable `app-release.apk`.

---

## 8. Capturas de Pantalla

*Capturas de pantalla de la aplicación en ejecución: [POR COMPLETAR]*
