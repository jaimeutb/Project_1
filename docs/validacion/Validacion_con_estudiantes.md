# Validación con estudiantes

Sección 7 del informe de pruebas del MVP. La hoja de observación completa, con las
respuestas de cada participante, está en
[`Hoja_de_observacion_validacion_estudiantes.pdf`](Hoja_de_observacion_validacion_estudiantes.pdf).

- **Fecha:** jueves 22 de octubre de 2026
- **Observador:** Jaime Mochen
- **Datos:** material de ejemplo de `npm run datos-prueba`
- **Criterio, fijado antes de la sesión:** una tarea queda validada si al menos 2 de los
  3 estudiantes la completan sin ayuda. RNF-01 se valida si la tarea 3 se hace en 3 pasos
  o menos, con la misma regla de 2 de 3.

El observador solo dio una pista cuando el estudiante se detuvo; esas tareas cuentan como
«con ayuda».

## Participantes

| ID | Programa | Semestre | Dispositivo | Respondió la encuesta | Había visto la aplicación |
|----|----------|----------|-------------|-----------------------|---------------------------|
| P1 | Ingeniería Industrial | 4 | Celular | Sí | No |
| P2 | Enfermería | 2 | Celular | No | No |
| P3 | Ingeniería de Sistemas | 7 | Computador | Sí | No |

Los tres aceptaron participar de forma voluntaria; no se registró su nombre. El plan pedía
tres estudiantes que hubieran respondido la encuesta, pero P2 no la respondió.

## Resultado por tarea

| Tarea | Requerimientos | P1 | P2 | P3 | Sin ayuda | Pasos promedio (ref.) | Resultado |
|-------|----------------|----|----|----|-----------|-----------------------|-----------|
| T1 Registrarse | RF-01, RF-02 | Sin ayuda · 3 pasos · 70 s | Sin ayuda · 2 pasos · 95 s | Sin ayuda · 2 pasos · 40 s | 3 de 3 | 2,33 (2) | **Validada** |
| T2 Encontrar un parcial | RF-03, RF-04, RF-05 | Sin ayuda · 4 pasos · 80 s | Con ayuda · 5 pasos · 160 s | Sin ayuda · 3 pasos · 35 s | 2 de 3 | 4,00 (3) | **Validada** |
| T3 Subir de forma anónima | RF-06, RF-07, RNF-01 | Con ayuda · 5 pasos · 145 s | Sin ayuda · 3 pasos · 105 s | Sin ayuda · 3 pasos · 60 s | 2 de 3 | 3,67 (3) | **Validada** (RNF-01: 2 de 3 en 3 pasos) |
| T4 Reportar un material | RF-09 | Sin ayuda · 4 pasos · 75 s | Con ayuda · 5 pasos · 130 s | No la completó · 3 pasos · 150 s | 1 de 3 | 4,00 (3) | **No validada** |

Los tiempos son aproximados. En T1, el intento de P1 de iniciar sesión antes de
registrarse se contó como un paso más. En T3, el selector de archivos del celular no se
contó como paso aparte.

**Utilidad percibida:** 3,67 sobre 5 (P1: 4, P2: 3, P3: 4), frente al 4,56 de la encuesta.
**¿La usaría antes de un parcial?** P1 y P3 sí; P2 tal vez.

## Hallazgos

| ID | Hallazgo | Dónde se vio | Afecta a | Antes de la sesión |
|----|----------|--------------|----------|--------------------|
| H-01 | El cuadro de búsqueda no encuentra el nombre de la asignatura ni frases como «parcial cálculo diferencial». | P1 y P2 en T2; los tres lo pidieron al cierre | RF-03, RF-04 | Anotado |
| H-02 | La búsqueda distingue tildes: «cinematica» no encuentra «Quiz de cinemática». | P3 en T4: abandonó la tarea | RF-04, RF-09 | Anotado |
| H-03 | «Reportar» con el motivo vacío cierra la ventana sin enviar nada y sin avisar. | P2 en T4: necesitó una pista | RF-09 | Anotado |
| H-04 | Al subir un material, la ventana se cierra sin mensaje y la lista sigue filtrada, así que el material nuevo no aparece. | P1 y P3 en T3 | RF-06 | Nuevo |
| H-05 | En el celular, con el teclado abierto, el interruptor «Subir de forma anónima» queda fuera de la vista. | P1 en T3: necesitó una pista | RF-07, RNF-01, RNF-03 | Nuevo |
| H-06 | El formulario «Subir material» no indica el tamaño máximo ni los tipos de archivo. | P3 en T3 | RF-06, R-02 | Anotado |
| H-07 | El mismo estado se llama «reportado» en la ficha y «En revisión» en la lista. | P1 en T4 | RF-09, RNF-05 | Nuevo |

Otras observaciones: P2 pidió asignaturas de Enfermería y preguntó si el administrador
puede ver quién subió un material anónimo (hoy la aplicación no lo muestra a nadie, aunque
la base de datos conserva el vínculo con la cuenta). P3 preguntó si se podrá entrar con el
correo institucional.

## Conclusión

Registrarse, encontrar un parcial y subir de forma anónima quedan validadas, y RNF-01
también. Reportar un material (RF-09) no: el sistema cumple su criterio de aceptación, pero
solo 1 de 3 estudiantes lo usó sin ayuda. Se propone corregir H-01 a H-03 y repetir la
tarea 4 con otros estudiantes. Con tres participantes, estas cifras orientan las
correcciones pero no permiten generalizar.
