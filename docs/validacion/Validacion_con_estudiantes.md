# Validación con estudiantes

Sección 7 del informe de pruebas del MVP.

**Estado: pendiente.** Todavía no se ha hecho una sesión con estudiantes. Este archivo
resume un recorrido simulado con IA, que anticipó problemas de uso pero no valida ninguna
tarea, y el plan de la sesión con estudiantes.

## Recorrido simulado con IA (22/10/2026)

El asistente de IA Claude simuló a tres estudiantes ficticios (de Ingeniería Industrial,
Enfermería e Ingeniería de Sistemas) haciendo las cuatro tareas del plan sobre el código del
commit `4d86543` y el material de `npm run datos-prueba`. Los participantes, los pasos, los
tiempos y los comentarios los escribió la IA: ningún estudiante usó la aplicación. Por eso el
recorrido no valida tareas ni RNF-01; solo sirvió para anticipar problemas de uso y
buscarlos en el código.

La versión anterior de este archivo (commit `572a70b`) y la hoja de observación en PDF que
lo acompañaba presentaban ese recorrido como una sesión con tres estudiantes reales. Era
incorrecto y se corrigió el 23/10/2026: se retiraron las cifras, los comentarios atribuidos
a estudiantes y la hoja de observación.

## Problemas anticipados y su corrección

Los siete problemas se confirmaron en el código y se corrigieron el 23/10/2026; cada
corrección tiene una prueba automática. Falta comprobar con estudiantes que las correcciones
resuelven el problema.

| ID | Problema | Afecta a | Corrección | Prueba automática |
|----|----------|----------|------------|-------------------|
| H-01 | El cuadro de búsqueda no encontraba el nombre ni el código de la asignatura, ni frases como «parcial cálculo diferencial». | RF-03, RF-04 | Cada palabra se busca en el título, la descripción y el nombre o código de la asignatura (regla R-09). | e2e «H-01/H-02: el buscador encuentra la asignatura…» |
| H-02 | La búsqueda distinguía tildes: «cinematica» no encontraba «Quiz de cinemática». | RF-04, RF-09 | La comparación ignora tildes y mayúsculas. | e2e «H-01/H-02…»; api «H-01/H-02: el texto buscado se divide…» |
| H-03 | «Reportar» con el motivo vacío cerraba la ventana sin enviar nada y sin avisar. | RF-09 | El botón se activa solo cuando hay un motivo. | widget «"Reportar" se activa solo con un motivo…» |
| H-04 | Al subir un material, la ventana se cerraba sin mensaje y la lista seguía filtrada. | RF-06 | Aviso «Material publicado» con «Ver»; la lista se recarga sin filtros. | widget «al subir material se confirma la carga y se quitan los filtros» |
| H-05 | En el celular, el teclado podía tapar el interruptor «Subir de forma anónima», al final del formulario. | RF-07, RNF-01, RNF-03 | El interruptor va primero en el formulario. | widget «el formulario de carga muestra primero el interruptor anónimo…» |
| H-06 | El formulario no indicaba el tamaño máximo ni los tipos de archivo. | RF-06, R-02 | Muestra «PDF, imagen (PNG o JPG), Word o ZIP; máx. 25 MB» y revisa el archivo antes de subirlo. | widget «…archivos permitidos»; unit «el archivo se revisa antes de subirlo» |
| H-07 | El mismo estado se llamaba «reportado» en la ficha y «En revisión» en la lista. | RF-09, RNF-05 | «En revisión» en los dos lugares. | unit «"reportado" y "en_revision" se llaman igual…» |

## Plan de la sesión con estudiantes

- **Participantes:** tres estudiantes que no hayan visto la aplicación, de preferencia de
  los que respondieron la encuesta, y al menos uno en celular. Participan de forma
  voluntaria y no se registra su nombre.
- **Preparación:** datos cargados con `npm run datos-prueba`, la aplicación abierta en la
  pantalla de inicio de sesión, sin sesión iniciada, y un PDF de prueba en el dispositivo
  (para la tarea 3).
- **Al empezar:** «Vamos a probar la aplicación, no a usted. No hay respuestas incorrectas.
  Le voy a pedir cuatro cosas; hágalas como lo haría solo y diga en voz alta lo que piensa.
  Si se queda atascado, dígalo. No guardamos su nombre.»
- **Durante las tareas:** un integrante lee cada consigna tal como está escrita, no muestra
  dónde está nada y anota el resultado, los pasos, el tiempo aproximado y las dudas, con las
  palabras del estudiante. Si el estudiante se detiene unos 30 segundos, da una pista mínima
  y la tarea cuenta como «con ayuda». Un paso es una pantalla o ventana con su acción de
  avance (la misma definición de RNF-01).
- **Criterio, fijado antes de la sesión:** una tarea queda validada si al menos 2 de los 3
  estudiantes la completan sin ayuda. RNF-01 se valida si la tarea 3 se hace en 3 pasos o
  menos, con la misma regla de 2 de 3.

| Tarea | Consigna | Requerimientos | Éxito | Pasos de referencia |
|-------|----------|----------------|-------|---------------------|
| T1 Registrarse | «Cree una cuenta en la plataforma y entre a la pantalla principal.» | RF-01, RF-02 | Llega a la pantalla principal con su cuenta nueva. | 2 |
| T2 Encontrar un parcial | «Busque un parcial de Cálculo Diferencial y ábralo.» | RF-03, RF-04, RF-05 | Abre «Parcial 1 – Límites y continuidad». | 3 |
| T3 Subir un archivo de forma anónima | «Suba este PDF a Programación I sin que aparezca su nombre.» | RF-06, RF-07, RNF-01 | El material queda publicado con «Anónimo» como autor. | 3 |
| T4 Reportar un material | «Usted cree que el "Quiz de cinemática" tiene un error. Avísele a la plataforma.» | RF-09 | Envía el reporte con un motivo y el material queda «En revisión». | 3 |

**Al cierre,** con la escala de la encuesta: «De 1 a 5, ¿qué tan útil le parece la
plataforma para estudiar?», «¿La usaría antes de un parcial?», «¿Qué fue lo más fácil o lo
que más le gustó?» y «¿Qué le faltó o qué cambiaría?».

Después de la sesión, los resultados reales van en la sección 7 del informe y en este
archivo.
