# Aqualerta — Detección temprana de fugas de agua con IoT

Aplicación móvil en Flutter para supervisar y controlar un tramo de tubería con un nodo **ESP32** y dos sensores de caudal. Aqualerta avisa cuando la diferencia entre el agua que entra y la que sale indica una posible fuga, y permite pausar o reanudar la medición del equipo.

El diseño está pensado para estudiantes y personal no técnico: el estado se entiende de un vistazo y siempre combina **color + icono + texto**.

---

## 1. Qué muestra la app

| Estado | Significado para el usuario | Color e icono |
| :--- | :--- | :--- |
| **Normal** | El agua circula como se espera. | Verde + check |
| **Desviación** | Hay una diferencia moderada; conviene revisar la tubería. | Ámbar + triángulo de advertencia |
| **Fuga** | La diferencia es grande; hay que revisar el tramo cuanto antes. | Rojo + señal de error |
| **Sin flujo** | No está pasando agua por el tramo. | Azul + gota |
| **En pausa** | El equipo no mide ni publica datos; el agua sigue fluyendo. | Gris + pausa |
| **Sin datos** | Todavía no hay lecturas o la conexión está caída. | Gris + sensor apagado |

La app **no recalcula** el estado: representa el que calcula el firmware del ESP32.

---

## 2. Cambios de interfaz: Antes → Después

| Pantalla | Antes | Después |
| :--- | :--- | :--- |
| Control | El botón se bloqueaba 2 s por un temporizador, sin mirar el estado real. | Los botones se habilitan según el estado confirmado del equipo. |
| Control | «Pausar circuito» y «Reanudar circuito» con tamaños y énfasis distintos. | «Pausar» y «Reanudar», misma fila, misma altura (≥ 52 dp), uno habilitado a la vez. |
| Control | Confirmación para pausar y reanudar. | Confirmación solo para pausar; reanudar va directo. |
| Control | Al enviar una orden no se veía progreso. | «Esperando confirmación del equipo…» con indicador de progreso y botones deshabilitados. |
| Control | Tras 5 s sin respuesta, la pantalla quedaba bloqueada. | Mensaje claro y botón «Reintentar»; no se deja al usuario sin salida. |
| Control | Recuadro «Propuesta de arquitectura IoT» con jerga. | Nota breve: el equipo confirma cada orden y se puede reintentar. |
| Monitoreo | Con el equipo pausado decía «sin datos» o «SIN FLUJO». | «Circuito en pausa» con icono y botón «Reanudar». |
| Monitoreo | Semáforo, hora técnica, seis tarjetas y gráfico compitiendo. | Estado grande → caudal de entrada, salida y diferencia → gráfico → «Detalles» plegable. |
| Monitoreo | Jerga: «(FIRMWARE)», «Sensor entrada YF-S201», tópicos MQTT. | Lenguaje simple: «Caudal de entrada», «Señal WiFi», «Dispositivo». |
| Monitoreo | Cuatro puntitos de colores sin explicación. | Se eliminaron; el estado usa color + icono + texto. |
| Monitoreo | Gráfico con eje Y irregular y líneas que se tapaban. | Eje Y con marcas 0, 1, 2, 3…, entrada continua, salida discontinua, leyenda con valores y aviso «Sin flujo». |
| Monitoreo | Fecha y hora completas de Lima en el cuerpo. | «Última lectura hace 2 s»; la hora de Lima queda en «Detalles». |
| Monitoreo | WiFi solo en dBm. | «Buena / Regular / Débil» + dBm (umbrales en la sección 4). |
| Consulta | Primero el diagnóstico, el mensaje en bruto y los descartados. | Primero el historial de cambios de estado. |
| Consulta | «(Lima, UTC-5)» repetido en cada fila. | Una sola vez en el encabezado; cada fila con hora corta, transición, duración y valores. |
| Consulta | Sin filtros. | Filtros «Todos / Fugas / Desviaciones». |
| Consulta | Texto de alcance técnico (RAM, MySQL) en el cuerpo. | «Este historial se guarda mientras la app está abierta». Lo técnico va en «Acerca de». |
| Conexión | Modo DEMO y TLS primero; el estado y los datos después. | Estado → datos → Conectar/Desconectar → «Opciones avanzadas» plegable. |
| Conexión | Campos deshabilitados con bajo contraste al conectar. | Campos bloqueados, legibles, con candado y aviso «Desconecta para cambiar estos datos». |
| Conexión | La contraseña podía quedar visible. | Oculta por defecto; se vuelve a ocultar al conectar, al cambiar de pestaña y al pasar a segundo plano. |
| Conexión | Título «Conexión al Broker MQTT». | Título «Conexión» y ayudas simples: «Dirección del servidor», ejemplo `192.168.0.20`. |
| Global | Cada pantalla tenía una barra distinta; solo Monitoreo mostraba la conexión. | Barra común con nombre + chip Conectado / Sin conexión / Demo + ayuda. |
| Global | «Fuga crítica», «SIN FLUJO», «DESVIACION». | «Fuga», «Sin flujo», «Desviación», «Normal», «En pausa». |
| Global | El color podía ser el único indicador. | Siempre color + icono + texto; DEMO usa violeta. |
| Global | Sin etiquetas para lectores de pantalla. | `Semantics` en estado, cifras, botones, gráfico, historial y alertas. |
| Global | Rejillas fijas que podían desbordar con texto grande. | `Wrap`, `Flexible`, `Expanded`, `IntrinsicHeight` y scroll; probado para crecer con el texto. |

---

## 3. Control: máquina de estados de los botones

La lógica vive en `lib/models/estado_control.dart` y se prueba sin broker en `test/maquina_estados_control_test.dart`.

| Estado real | «Pausar» | «Reanudar» | Mensaje / acción |
| :--- | :---: | :---: | :--- |
| Activo | Habilitado | Deshabilitado | «Puedes pausar la medición». |
| En pausa | Deshabilitado | Habilitado y principal | «Puedes reanudar la medición». |
| Orden enviada | Deshabilitado | Deshabilitado | «Esperando confirmación del equipo…» + progreso. |
| Sin confirmación (5 s) | Deshabilitado | Deshabilitado | «No se recibió confirmación…» + «Reintentar». |
| Sin conexión | Deshabilitado | Deshabilitado | «Conéctate al servidor para controlar el equipo» + «Ir a Conexión». |
| Modo DEMO | Deshabilitado | Deshabilitado | «Modo DEMO: los controles no envían órdenes reales». |
| Estado desconocido | Deshabilitado | Deshabilitado | «Todavía no conocemos el estado del equipo». |

> **Seguridad hidráulica:** pausar detiene la medición y la publicación de datos del ESP32; **no cierra electroválvulas ni detiene el flujo de agua**.

---

## 4. Señal WiFi: umbrales orientativos

Se muestran en «Detalles» de Monitoreo, junto al valor en dBm.

| Calidad | RSSI | Lectura para el usuario |
| :--- | :--- | :--- |
| **Buena** | ≥ −60 dBm | La señal del equipo es estable. |
| **Regular** | −61 a −75 dBm | La señal puede perder mensajes de vez en cuando. |
| **Débil** | < −75 dBm | Acerca el equipo al router o revisa su antena. |

Son umbrales orientativos de laboratorio, no una garantía de cobertura.

---

## 5. Arquitectura de comunicación y tópicos MQTT

La app se comunica con un broker **EMQX**. Los tópicos y formatos no cambiaron:

| Tópico | Dirección | QoS | Estado | Formato / descripción |
| :--- | :--- | :---: | :---: | :--- |
| `unt/iot/g2/riego/telemetria` | ESP32 → App | 0 | Implementado | JSON con caudales, volúmenes, estado y RSSI. El mensaje de arranque `{"mensaje":"ESP32 conectado"}` se ignora de forma segura. |
| `unt/iot/g2/riego/comando` | App → ESP32 | 1 | Implementado | `{"orden":"PAUSAR"}` o `{"orden":"REANUDAR"}`. |
| `unt/iot/g2/riego/equipo` | ESP32 → App | 1 | Implementado | `{"activo":true}` o `{"activo":false}` (retained). Es la fuente del estado real de los botones. |

La app no publica telemetría ni modifica los payloads; solo consume lecturas, muestra el estado y envía órdenes.

---

## 6. Seguridad y validación

| Mecanismo | Estado | Detalle |
| :--- | :---: | :--- |
| Contraseña solo en memoria | Implementado | No se guarda en disco, preferencias, SQLite ni logs. Se borra al desconectar. |
| Contraseña oculta | Implementado | Oculta por defecto; se vuelve a ocultar al conectar, al salir de la pestaña y al pasar la app a segundo plano. |
| Validación de dirección y puerto | Implementado | Sin espacios ni esquemas en la dirección; puerto entre 1 y 65535. |
| Validación de rangos | Implementado | Se descartan caudales negativos, diferencias fuera de ±100 %, estados desconocidos y RSSI fuera de [−120, 0] dBm. |
| Protección contra doble envío | Implementado | El botón queda deshabilitado mientras se espera la confirmación; ya no se usa un bloqueo fijo de 2 s. |
| Confirmación de órdenes | Implementado | El estado real se lee del mensaje retenido del equipo; si no llega en 5 s se ofrece «Reintentar». |
| TLS opcional | Implementado | Disponible en «Opciones avanzadas» (puerto 8883), sin bypass de certificados. |
| ACL en EMQX | Propuesto | Esquema por usuario y tópico documentado para configurar en el panel. |
| mTLS con certificados de cliente | Propuesto | Pendiente de despliegue de certificados X.509 por dispositivo. |
| Persistencia histórica MySQL | Pendiente | Requiere una API REST intermedia. `[POR COMPLETAR]` |

---

## 7. Accesibilidad

- Áreas táctiles de 48 dp o más en botones, chips, iconos y filas plegables.
- Texto con contraste orientativo ≥ 4,5:1 sobre sus fondos (ver `docs/auditoria_ux.md`).
- La interfaz usa scroll, `Wrap`, `Flexible` y `Expanded` para crecer con el texto del sistema hasta 200 %.
- El color nunca es el único indicador: cada estado incluye icono y palabra.
- Etiquetas `Semantics` en estado, cifras, botones, gráfico, historial y alertas.
- Ayuda breve desde el icono «?» de la barra superior, con los cuatro estados y la pausa.

---

## 8. Guía rápida

### Modo DEMO (sin broker)
1. Abre **Conexión**.
2. Despliega **Opciones avanzadas**.
3. Activa **Modo DEMO**. Se reproducen datos de ejemplo desde `assets/demo_telemetria.csv`.
4. Aparece el letrero violeta «Demo · datos de ejemplo».
5. Los controles de pausa/reanudar quedan deshabilitados porque no hay un equipo real.

### Conexión real
1. Abre **Conexión**.
2. Revisa el estado de la conexión y completa la **Dirección del servidor** y el **Puerto** (`1883`, o `8883` con TLS).
3. Ingresa usuario y contraseña si el servidor los pide.
4. Presiona **Conectar**.
5. En **Monitoreo** verás el estado y los caudales; en **Control** podrás pausar o reanudar.

### Lectura del historial
- **Consulta** muestra primero los cambios más recientes.
- La hora de Lima (UTC-5) aparece una vez en el encabezado.
- Cada fila indica hora corta, estado anterior → nuevo, duración del estado anterior y valores clave.
- Usa «Todos / Fugas / Desviaciones» para filtrar.
- «Diagnóstico» y «Ver último mensaje» quedan al final para revisar mensajes descartados o el JSON recibido.

---

## 9. Compilación y pruebas

```bash
flutter pub get
flutter test
flutter build apk --release
```

El flujo de GitHub Actions compila el APK y ejecuta `flutter test`. No se modificó `.github/workflows/apk.yml`.

Verificado con Flutter 3.47.9 / Dart 3.13.7: `flutter analyze` terminó **sin incidencias**, `flutter test` pasó **43/43** y `flutter build bundle` compiló toda la app. El APK no se compiló en este entorno porque no hay Android SDK; de eso se encarga GitHub Actions.

Pruebas añadidas:
- `test/maquina_estados_control_test.dart`: activo, pausado, enviando, sin confirmar, sin conexión, DEMO, desconocido y prioridades.
- `test/presentacion_test.dart`: antigüedad relativa, duraciones, hora de Lima, umbrales WiFi, nombres de estados y formato numérico.

Ninguna prueba usa clases internas de `mqtt_client` ni necesita un broker real.

---

## 10. Puntos a revisar a mano en el celular

- [ ] Instalar el APK y comprobar que la barra superior no desborda con **texto al 200 %** en una pantalla pequeña.
- [ ] Activar TalkBack y recorrer Monitoreo, Control y Conexión: estado, cifras y botones deben leerse una sola vez y con sentido.
- [ ] Probar la pausa y la reanudación con el equipo real: confirmar que el estado de los botones cambia solo cuando llega el mensaje retenido.
- [ ] Cortar la red justo después de enviar una orden y comprobar el mensaje «No se recibió confirmación» y «Reintentar».
- [ ] Verificar que la contraseña se oculta al cambiar de pestaña y al mandar la app a segundo plano.
- [ ] Revisar el gráfico con caudales reales: marcas del eje Y, línea continua/discontinua y aviso «Sin flujo».
- [ ] Medir el contraste con una herramienta y ajustar si el centro educativo lo exige.
- [ ] Confirmar que el firmware publica el estado retenido en `unt/iot/g2/riego/equipo` al arrancar y tras cada orden.

---

## 11. Limitaciones conocidas

1. **Persistencia histórica**: el historial vive en memoria y se pierde al cerrar la app. La consulta a MySQL sigue `[POR COMPLETAR]` y requiere un backend.
2. **Ayuda de primer uso automática**: se ofrece desde «?»; mostrarla una sola vez requeriría persistencia local y no se añadió una dependencia para eso. `[POR COMPLETAR]` si se desea.
3. **Capturas de pantalla**: no se implementó `FLAG_SECURE` de Android. La contraseña se oculta al pasar a segundo plano, pero conviene revisarlo en el dispositivo.
4. **Validación de campo**: la app fue evaluada en laboratorio; la validación hidráulica con flujo real en el campus está `[POR COMPLETAR]`.
5. **TLS en el laboratorio**: el broker del laboratorio puede operar sin TLS; la app incluye el soporte para cuando se configuren certificados válidos.

---

## 12. Documentación de diseño

- `docs/auditoria_ux.md`: tabla completa de problemas, principios violados y soluciones, más las decisiones y lo que no se pudo verificar.
- `README.md`: este documento, con la tabla «Antes → Después», umbrales WiFi y la máquina de estados.

## 13. Capturas de pantalla

*Capturas de la app en ejecución: `[POR COMPLETAR]`.*
