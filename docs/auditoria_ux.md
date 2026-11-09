# Auditoría UX/UI de Aqualerta

Fecha: 9 de noviembre de 2026
Alcance: las cuatro pantallas de la app Flutter `fugas_g2` (Monitoreo, Consulta, Control y Conexión), barra superior, ayuda y estados vacíos.

## Criterios usados

- Heurísticas de Nielsen: visibilidad del estado, correspondencia con el mundo real, prevención de errores, reconocimiento antes que recuerdo, diseño minimalista y mensajes de error útiles.
- Buenas prácticas para apps IoT (NN/g): confirmar cada orden, estado visible de un vistazo, combinar color + icono + texto, progreso en acciones con retardo y explicar los fallos.
- Material Design 3 y accesibilidad: áreas táctiles de 48 dp o más, contraste de texto de 4,5:1 o más, uso con texto al 200 %, estados deshabilitados distinguibles y etiquetas `Semantics`.

## Tabla de problemas y soluciones

| Prioridad | Pantalla | Problema detectado | Principio violado | Solución implementada |
| :--- | :--- | :--- | :--- | :--- |
| P0 | Control | Los botones se habilitaban con un temporizador fijo de 2 s, no con el estado real del equipo. | Visibilidad del estado; prevención de errores. | Se eliminó el bloqueo de 2 s. La habilitación se deriva de `MaquinaEstadosControl`, construida con `equipoActivo`, `esperandoConfirmacion`, `confirmacionExpirada`, conexión y Modo DEMO. |
| P0 | Control | Activo y pausado no tenían reglas distintas: ambos botones podían estar habilitados a la vez. | Correspondencia con el mundo real; prevención de errores. | Activo: solo «Pausar». Pausado: solo «Reanudar», como acción principal. Enviando: ambos deshabilitados. |
| P0 | Control | Al enviar una orden no había progreso ni espera visible. | Visibilidad del estado del sistema. | Ambos botones se deshabilitan y aparece «Esperando confirmación del equipo…» con indicador de progreso y `liveRegion`. |
| P0 | Control | Tras 5 s sin confirmación la pantalla quedaba bloqueada. | Mensajes de error útiles; prevención de errores. | Se muestra «No se recibió confirmación. Revisa que el equipo esté encendido y conectado» y un botón «Reintentar» que reenvía la última orden. |
| P0 | Control | Sin conexión, Modo DEMO o estado desconocido no explicaban por qué los botones estaban deshabilitados. | Visibilidad del estado; mensajes útiles. | Cada caso tiene una línea explicativa. Sin conexión y DEMO ofrecen «Ir a Conexión». Estado desconocido explica que falta la confirmación del equipo. |
| P0 | Control | El diálogo de confirmación se usaba para pausar y reanudar. | Prevención de errores sin fricción innecesaria. | Se mantiene solo para «Pausar», con el texto solicitado. «Reanudar» va directo. |
| P0 | Control | Recuadro «Propuesta de arquitectura IoT» con jerga y una promesa de firmware que ya está implementada. | Correspondencia con el mundo real; diseño minimalista. | Se reemplazó por una nota breve: el equipo confirma cada orden y se puede reintentar a los 5 s. |
| P0 | Control | Botones de distinto texto, tamaño y alineación («Pausar circuito», «Reanudar circuito»). | Consistencia; accesibilidad táctil. | Botones «Pausar» y «Reanudar», misma fila, misma altura mínima de 52 dp, alineados y con crecimiento vertical si el texto se amplía. |
| P0 | Monitoreo | Con el equipo pausado se mostraba «sin datos» o «SIN FLUJO». | Correspondencia con el mundo real; visibilidad del estado. | Estado propio «Circuito en pausa», en gris, con icono de pausa y botón «Reanudar» en la misma tarjeta. |
| P1 | Monitoreo | La jerarquía no priorizaba el estado: métricas y volúmenes competían con el semáforo. | Diseño minimalista; jerarquía visual. | Orden: estado principal grande → tres cifras clave (entrada, salida, diferencia) → gráfico → «Detalles» plegable. |
| P1 | Monitoreo | Jerga visible: «(FIRMWARE)», «Sensor entrada YF-S201», tópicos MQTT y etiquetas cortadas con «…». | Correspondencia con el mundo real; reconocimiento. | Se eliminó la jerga. Las tarjetas usan etiquetas cortas, permiten varias líneas y no recortan con puntos suspensivos. |
| P1 | Monitoreo | Cuatro puntitos de colores sin explicación, dependientes solo del color. | Accesibilidad; reconocimiento. | Se eliminaron. El estado se comunica con color + icono + texto. |
| P1 | Monitoreo | Gráfico con eje Y irregular, líneas que se tapaban y sin aviso de flujo cero. | Visibilidad del estado; accesibilidad visual. | Eje Y con pasos «agradables» (0, 1, 2, 3…), entrada continua, salida discontinua, leyenda con valor actual, escala automática y aviso superpuesto «Sin flujo». Se movió arriba, antes de «Detalles». |
| P1 | Monitoreo | La marca de tiempo mostraba una fecha técnica y no la antigüedad. | Correspondencia con el mundo real. | «Última lectura hace 2 s», actualizada cada segundo. La hora de Lima queda en «Detalles». |
| P1 | Monitoreo | La señal WiFi solo mostraba dBm. | Reconocimiento antes que recuerdo. | Se añadió etiqueta cualitativa Buena / Regular / Débil, con umbrales documentados en el README, además del valor en dBm. |
| P1 | Consulta | Lo primero era el diagnóstico técnico y el mensaje en bruto. | Jerarquía; diseño minimalista. | Primero el historial de cambios. El contador de descartados pasa a una fila discreta de «Diagnóstico» y el mensaje en bruto a «Ver último mensaje». |
| P1 | Consulta | Cada fila repetía «(Lima, UTC-5)». | Diseño minimalista. | La zona horaria aparece una sola vez en el encabezado. Cada fila muestra hora corta, estado anterior → nuevo, duración del estado anterior y valores clave. |
| P1 | Consulta | No se podía filtrar el historial. | Reconocimiento; control del usuario. | Filtros «Todos / Fugas / Desviaciones» con estado vacío y acción «Ver todos». |
| P1 | Consulta | El texto de alcance era técnico y hablaba de RAM/MySQL en el cuerpo principal. | Correspondencia con el mundo real. | «Este historial se guarda mientras la app está abierta. Si la cierras, se borra». Lo técnico y `[POR COMPLETAR]` se movieron a «Acerca de». |
| P1 | Conexión | Modo DEMO y TLS aparecían antes que el estado y los datos de conexión. | Jerarquía; correspondencia con el mundo real. | Orden: estado → datos → Conectar/Desconectar → «Opciones avanzadas» plegable (TLS y DEMO). |
| P1 | Conexión | Al conectar, los campos se veían con bajo contraste o quedaban editables. | Accesibilidad; prevención de errores. | Campos bloqueados, legibles, con fondo y candado, aviso «Desconecta para cambiar estos datos» y mensaje al tocarlos. |
| P1 | Conexión | La contraseña podía quedar visible después de conectar o al cambiar de pestaña. | Privacidad; prevención de errores. | Se oculta por defecto, se vuelve a ocultar al conectar, al salir de la pestaña y al pasar la app a segundo plano. Al conectar se limpia el campo; solo queda en memoria. |
| P1 | Conexión | Título «Conexión al Broker MQTT» y ayudas técnicas («Host», «TCP», «RAM»). | Correspondencia con el mundo real. | Título «Conexión» y ayudas simples: «Dirección del servidor», ejemplo `192.168.1.50`, «Puerto», «Se borra al desconectar». |
| P2 | Global | Solo Monitoreo tenía chip de conexión; las demás pantallas no. | Consistencia; visibilidad del estado. | `BarraSuperiorAqualerta` unifica las cuatro pantallas: nombre + chip Conectado / Sin conexión / Demo + ayuda. |
| P2 | Global | Semántica de color ambigua: ámbar y rojo se mezclaban con la conexión y DEMO. | Consistencia; accesibilidad. | Paleta única: verde normal, ámbar desviación, rojo fuga, azul sin flujo, gris pausa/sin datos y violeta DEMO. Siempre con icono y texto. |
| P2 | Global | Nombres inconsistentes: «Fuga crítica», «SIN FLUJO», «DESVIACION», «sin datos». | Consistencia; correspondencia con el mundo real. | «Normal», «Desviación», «Fuga», «Sin flujo», «En pausa» y «Sin datos» en toda la app. |
| P2 | Global | Estados vacíos sin acción. | Mensajes útiles; prevención de errores. | «Aún no hay datos. Conéctate al servidor» con botón «Ir a Conexión»; los filtros vacíos ofrecen «Ver todos». |
| P2 | Global | Sin etiquetas `Semantics` en estado, cifras, botones y filas. | Accesibilidad. | Se añadieron etiquetas en estado, cifras, botones, gráfico, filas del historial y alertas; el estado, el progreso y las alertas usan `liveRegion`. |
| P2 | Global | La interfaz podía desbordarse con texto al 200 %. | Accesibilidad. | Se reemplazaron rejillas de altura fija por `Wrap`, `Flexible`, `Expanded`, `IntrinsicHeight` y scroll. Se quitaron `maxLines: 1` de las cifras. |
| P2 | Global | No había ayuda para interpretar los estados. | Reconocimiento antes que recuerdo. | Icono «?» en la barra superior con una hoja breve que explica los cuatro estados y la pausa. |
| Extra | Monitoreo | El gesto de recargar intentaba reconectar sin la contraseña guardada. | Prevención de errores. | Se quitó la reconexión implícita por gesto. La acción explícita está en Conexión y en los estados vacíos. |
| Extra | Monitoreo | El banner de fuga se podía cerrar mientras la fuga seguía activa. | Visibilidad del estado; prevención de errores. | El banner permanece visible mientras el estado sea Fuga. |
| Extra | Consulta | El botón «Limpiar» usaba rojo, color reservado a fuga/peligro. | Consistencia de color. | Se cambió por un icono neutro con confirmación. |
| Extra | Global | «Fuga» se anunciaba como «crítica» y el nivel de alerta no coincidía con el firmware. | Correspondencia con el mundo real. | Se unificó a «Fuga». |

## Decisiones de diseño justificadas

1. **Estado real, no temporizador.** Un temporizador de 2 s solo evita el doble toque, pero no informa si el equipo obedeció. La máquina de estados usa el mensaje retenido del equipo porque es la única fuente que confirma la orden (visibilidad del estado y prevención de errores).
2. **«Reintentar» en vez de dejar todo bloqueado.** Un fallo de red no debe convertir la pantalla en un callejón sin salida. El mensaje explica la causa y la acción permite recuperarse (mensajes de error útiles).
3. **Pausa en gris, no en ámbar ni rojo.** La pausa no es una alerta: es un estado operativo. El gris evita falsas alarmas y deja el ámbar y el rojo para desviación y fuga.
4. **Diferencia con porcentaje y palabra.** El número solo no dice si es normal; se añade «Normal / Revisar / Fuga» con icono. Así el color no es el único indicador.
5. **Cifras en dos columnas y diferencia a ancho completo.** Con texto al 200 %, tres columnas en un teléfono obligan a recortar o a reducir la letra. Dos columnas mantienen la lectura y la diferencia conserva protagonismo.
6. **Línea continua y discontinua.** La forma de la línea permite distinguir entrada y salida sin depender del color (accesibilidad visual).
7. **Diagnóstico plegado.** Los mensajes descartados y el JSON son útiles para depurar, pero no para el usuario no técnico. Se mantienen accesibles sin competir con el historial.
8. **DEMO en violeta.** El naranja se confundía con advertencias. El violeta identifica la simulación y no se reutiliza en estados de alerta.
9. **Contraseña oculta al salir de la pestaña.** `IndexedStack` mantiene la pantalla viva; por eso se pasa `visible` desde `MainScreen` y se oculta al cambiar de pestaña, además de al conectar y al pasar a segundo plano.

## Contraste comprobado (orientativo)

| Uso | Texto | Fondo | Contraste aproximado |
| :--- | :--- | :--- | :--- |
| Normal | `#1B5E20` | `#E8F5E9` | 7,5:1 |
| Desviación | `#8A5300` | `#FFF8E1` | 6,0:1 |
| Fuga | `#B3261E` | `#FFEBEE` | 5,9:1 |
| Sin flujo | `#0D47A1` | `#E3F2FD` | 7,4:1 |
| Pausa / sin datos | `#37474F` | `#ECEFF1` | 7,0:1 |
| DEMO | `#4527A0` | `#EDE7F6` | 8,0:1 |

Los valores son estimaciones de diseño; conviene revalidarlos con un medidor de contraste antes de publicar.

## Lo que no se pudo implementar o verificar

- **Verificación automática**: se ejecutaron `flutter analyze` (sin incidencias), `flutter test` (43 pruebas, todas correctas) y `flutter build bundle` (compilación completa del código Dart) con Flutter 3.47.9 / Dart 3.13.7. Las pruebas no usan broker ni clases internas de `mqtt_client`.
- **Compilación del APK**: no se ejecutó `flutter build apk` porque el entorno de trabajo no tiene Android SDK; el flujo de GitHub Actions (`subosito/flutter-action`) se encarga de compilarlo.
- **Ayuda automática de primer uso**: se ofrece desde el icono «?» de la barra superior. No se muestra automáticamente porque requeriría persistencia local (por ejemplo `shared_preferences`), una dependencia que no se añadió. Queda como `[POR COMPLETAR]` si se desea mostrar una sola vez.
- **Bloqueo de capturas de pantalla a nivel de Android (`FLAG_SECURE`)**: no se añadió código de plataforma. La contraseña se oculta al pasar la app a segundo plano, pero la captura del sistema podría tomarla en el instante previo. Conviene revisarlo en el dispositivo.
- **Validación visual con lector de pantalla real (TalkBack) y con texto al 200 %**: se implementaron `Semantics`, `Wrap` y scroll, pero no se pudo ejecutar en un dispositivo.
- **Contraste medido con herramienta**: los valores de la tabla son estimaciones a partir de los códigos hexadecimales.
- **Base de datos histórica MySQL**: sigue como `[POR COMPLETAR]` y se documenta en «Acerca de».
