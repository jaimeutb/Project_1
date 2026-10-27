"""Genera los archivos de prueba de la plataforma (PDF e imagen).

- backend/src/db/material-de-prueba/: los 5 materiales que carga `npm run datos-prueba`.
- docs/material-de-prueba/: archivos para probar la carga y la revisión con IA (RF-17):
  dos que la IA debería aprobar, uno de otra asignatura, uno que no es académico y una
  imagen.

Todo el contenido es de prueba: los parciales no son de ningún curso real.
Uso: python docs/material-de-prueba/generar.py   (requiere: pip install pymupdf pillow)
"""
import os
import pathlib

import pymupdf
from PIL import Image, ImageDraw, ImageFont

RAIZ = pathlib.Path(__file__).resolve().parents[2]
SEMILLA = RAIZ / 'backend' / 'src' / 'db' / 'material-de-prueba'
PRUEBAS = RAIZ / 'docs' / 'material-de-prueba'

CSS = """
* { font-family: sans-serif; }
body { font-size: 10.5pt; color: #1e2033; line-height: 1.45; }
.encabezado { border-bottom: 2px solid #303990; padding-bottom: 6px; margin-bottom: 10px; }
.u { color: #187943; font-size: 9pt; font-weight: bold; }
h1 { color: #1f2566; font-size: 17pt; margin: 2px 0; }
.meta { color: #5d6178; font-size: 9pt; }
h2 { color: #303990; font-size: 12pt; margin: 12px 0 4px 0; }
.ej { margin: 6px 0 2px 0; }
.sol { background: #eef5f0; padding: 6px 8px; margin: 3px 0 8px 0; font-size: 10pt; }
code, pre { font-family: monospace; font-size: 9.5pt; }
pre { background: #f2f3f8; padding: 6px; }
table { border-collapse: collapse; }
td, th { border: 1px solid #c9ccdb; padding: 3px 6px; font-size: 9.5pt; }
.pie { color: #8a8fa6; font-size: 8pt; margin-top: 14px; }
"""

PIE = '<p class="pie">Material de prueba generado para la Plataforma de Apoyo Académico (proyecto de aula). No corresponde a un examen real.</p>'


def encabezado(asignatura, titulo, meta, universidad=True):
    u = '<div class="u">UNIVERSIDAD TECNOLÓGICA DE BOLÍVAR · ' + asignatura.upper() + '</div>' if universidad else ''
    return f'<div class="encabezado">{u}<h1>{titulo}</h1><div class="meta">{meta}</div></div>'


def pdf(ruta, paginas_html):
    doc = pymupdf.open()
    for html in paginas_html:
        pagina = doc.new_page(width=595, height=842)  # A4
        pagina.insert_htmlbox(pymupdf.Rect(50, 45, 545, 800), html, css=CSS)
    doc.save(ruta, garbage=3, deflate=True)
    print('creado', ruta.relative_to(RAIZ))


def ejercicio(n, enunciado, solucion=None):
    s = f'<p class="ej"><b>{n}.</b> {enunciado}</p>'
    if solucion:
        s += f'<div class="sol"><b>Solución.</b> {solucion}</div>'
    return s


# ---------------------------------------------------------------- semilla
def semilla():
    SEMILLA.mkdir(parents=True, exist_ok=True)

    pdf(SEMILLA / 'parcial-limites.pdf', [
        encabezado('Cálculo Diferencial (MAT101)', 'Parcial 1 – Límites y continuidad',
                   'Prof. Martínez · Periodo 2026-1 · Duración: 90 minutos · Con soluciones')
        + '<h2>Parte A. Límites</h2>'
        + ejercicio(1, 'Calcule lim<sub>x→2</sub> (x² − 4)/(x − 2).',
                    'Al reemplazar x = 2 queda 0/0. Se factoriza: x² − 4 = (x − 2)(x + 2). Se simplifica (x − 2) y queda lim<sub>x→2</sub> (x + 2) = <b>4</b>.')
        + ejercicio(2, 'Calcule lim<sub>x→0</sub> sen(3x)/x.',
                    'Se usa el límite notable lim<sub>u→0</sub> sen(u)/u = 1 con u = 3x: sen(3x)/x = 3 · sen(3x)/(3x) → 3 · 1 = <b>3</b>.')
        + ejercicio(3, 'Calcule lim<sub>x→∞</sub> (3x² + 2x)/(5x² − 1).',
                    'Se divide numerador y denominador entre x²: (3 + 2/x)/(5 − 1/x²) → <b>3/5</b>.')
        + ejercicio(4, 'Calcule lim<sub>x→0</sub> (√(x + 4) − 2)/x.',
                    'Se multiplica por el conjugado: (x + 4 − 4)/(x(√(x + 4) + 2)) = 1/(√(x + 4) + 2) → 1/(2 + 2) = <b>1/4</b>.')
        + '<h2>Parte B. Continuidad</h2>'
        + ejercicio(5, 'Determine si f es continua en x = 1, con f(x) = x² + 1 si x &lt; 1 y f(x) = 2x si x ≥ 1.',
                    'Límite por la izquierda: 1² + 1 = 2. Límite por la derecha: 2 · 1 = 2. f(1) = 2. Los tres valores coinciden: <b>f es continua en x = 1</b>.')
        + PIE,
    ])

    pdf(SEMILLA / 'taller-derivadas.pdf', [
        encabezado('Cálculo Diferencial (MAT101)', 'Taller de derivadas resuelto',
                   'Periodo 2025-2 · Reglas de derivación con el procedimiento completo')
        + ejercicio(1, 'Derive f(x) = 3x⁴ − 5x² + 7.', 'Regla de la potencia término a término: f′(x) = <b>12x³ − 10x</b>.')
        + ejercicio(2, 'Derive g(x) = x² · sen(x).', 'Regla del producto: g′(x) = 2x · sen(x) + x² · cos(x).')
        + ejercicio(3, 'Derive h(x) = (2x + 1)/(x − 3).',
                    'Regla del cociente: h′(x) = [2(x − 3) − (2x + 1) · 1]/(x − 3)² = (2x − 6 − 2x − 1)/(x − 3)² = <b>−7/(x − 3)²</b>.')
        + ejercicio(4, 'Derive k(x) = e<sup>3x²</sup>.', 'Regla de la cadena: k′(x) = e<sup>3x²</sup> · 6x = <b>6x · e<sup>3x²</sup></b>.')
        + ejercicio(5, 'Derive m(x) = ln(x² + 1).', 'Regla de la cadena: m′(x) = 1/(x² + 1) · 2x = <b>2x/(x² + 1)</b>.')
        + '<p><b>Error frecuente:</b> en el ejercicio 3, olvidar el signo menos del segundo término del numerador.</p>'
        + PIE,
    ])

    pdf(SEMILLA / 'parcial-programacion.pdf', [
        encabezado('Programación I (SIS102)', 'Parcial final de Programación I',
                   'Prof. Gómez · Periodo 2026-1 · Lenguaje: Python · Con soluciones')
        + ejercicio(1, '¿Qué imprime el siguiente código?<pre>for i in range(1, 4):\n    print(i * i)</pre>',
                    'range(1, 4) genera 1, 2 y 3; se imprime el cuadrado de cada uno: <b>1, 4 y 9</b>, uno por línea.')
        + ejercicio(2, 'Escriba la función <code>suma_pares(lista)</code> que devuelva la suma de los números pares de una lista.',
                    '<pre>def suma_pares(lista):\n    total = 0\n    for n in lista:\n        if n % 2 == 0:\n            total += n\n    return total</pre>Ejemplo: suma_pares([1, 2, 3, 4]) devuelve 6.')
        + ejercicio(3, 'Escriba la función <code>es_primo(n)</code> que indique si n es primo.',
                    '<pre>def es_primo(n):\n    if n &lt; 2:\n        return False\n    for d in range(2, int(n ** 0.5) + 1):\n        if n % d == 0:\n            return False\n    return True</pre>Basta probar divisores hasta la raíz cuadrada de n.')
        + ejercicio(4, '¿Qué imprime <code>lista = [3, 1, 2]; lista.sort(); print(lista[-1])</code>?',
                    'sort() ordena la lista en su lugar: [1, 2, 3]. El índice −1 es el último elemento: <b>3</b>.')
        + PIE,
    ])

    pdf(SEMILLA / 'quiz-cinematica.pdf', [
        encabezado('Física Mecánica (FIS201)', 'Quiz de cinemática',
                   'Prof. Rodríguez · Periodo 2025-2 · Use g = 10 m/s²')
        + ejercicio(1, 'Un auto va a 72 km/h con velocidad constante. ¿Qué distancia recorre en 15 s?',
                    '72 km/h = 20 m/s. En MRU, x = v · t = 20 · 15 = <b>300 m</b>.')
        + ejercicio(2, 'Un móvil parte del reposo con aceleración de 2 m/s². ¿Qué velocidad tiene y qué distancia recorrió a los 5 s?',
                    'v = a · t = 2 · 5 = <b>10 m/s</b>; x = ½ · a · t² = ½ · 2 · 25 = <b>25 m</b>.')
        + ejercicio(3, 'Se deja caer una piedra desde 45 m de altura. ¿Cuánto tarda en llegar al suelo y con qué velocidad?',
                    'h = ½ g t² → 45 = 5t² → t = <b>3 s</b>; v = g · t = <b>30 m/s</b>.')
        + ejercicio(4, 'Un auto frena de 20 m/s hasta detenerse en 40 m. ¿Cuál fue su aceleración?',
                    'v² = v₀² + 2a·d → 0 = 400 + 80a → a = <b>−5 m/s²</b> (el signo indica que frena).')
        + PIE,
    ])

    pdf(SEMILLA / 'ejercicios-sql.pdf', [
        encabezado('Bases de Datos (SIS401)', 'Ejercicios de SQL con solución',
                   'Periodo 2026-1 · Consultas SELECT, JOIN y GROUP BY resueltas paso a paso')
        + '<p>Tablas: <b>estudiantes</b>(id, nombre, programa) y <b>notas</b>(estudiante_id, asignatura, nota).</p>'
        + ejercicio(1, 'Liste el nombre de los estudiantes del programa «Sistemas».',
                    "<pre>SELECT nombre FROM estudiantes\nWHERE programa = 'Sistemas';</pre>")
        + ejercicio(2, 'Muestre el promedio de notas de cada estudiante, con su nombre.',
                    '<pre>SELECT e.nombre, AVG(n.nota) AS promedio\nFROM estudiantes e\nJOIN notas n ON n.estudiante_id = e.id\nGROUP BY e.id, e.nombre;</pre>')
        + ejercicio(3, 'Liste los estudiantes con promedio mayor o igual a 4.0.',
                    '<pre>SELECT e.nombre, AVG(n.nota) AS promedio\nFROM estudiantes e\nJOIN notas n ON n.estudiante_id = e.id\nGROUP BY e.id, e.nombre\nHAVING AVG(n.nota) &gt;= 4.0;</pre>HAVING filtra grupos; WHERE filtra filas antes de agrupar.')
        + ejercicio(4, 'Cuente cuántos estudiantes hay en cada programa.',
                    '<pre>SELECT programa, COUNT(*) AS total\nFROM estudiantes\nGROUP BY programa;</pre>')
        + PIE,
    ])


# ---------------------------------------------------------------- pruebas de carga
def pruebas_de_carga():
    PRUEBAS.mkdir(parents=True, exist_ok=True)

    pdf(PRUEBAS / '1-aprobar-quiz-integrales.pdf', [
        encabezado('Cálculo Integral (MAT102)', 'Quiz 2 – Integrales por sustitución',
                   'Prof. Herrera · Periodo 2026-1 · Con soluciones')
        + ejercicio(1, 'Calcule ∫ 2x (x² + 1)³ dx.', 'Sea u = x² + 1, du = 2x dx: ∫ u³ du = u⁴/4 + C = <b>(x² + 1)⁴/4 + C</b>.')
        + ejercicio(2, 'Calcule ∫ cos(5x) dx.', 'Sea u = 5x, du = 5 dx: (1/5) ∫ cos(u) du = <b>sen(5x)/5 + C</b>.')
        + ejercicio(3, 'Calcule ∫ x · e<sup>x²</sup> dx.', 'Sea u = x², du = 2x dx: (1/2) ∫ e<sup>u</sup> du = <b>e<sup>x²</sup>/2 + C</b>.')
        + PIE,
    ])

    pdf(PRUEBAS / '2-aprobar-parcial-pilas-colas.pdf', [
        encabezado('Estructuras de Datos (SIS203)', 'Parcial 2 – Pilas y colas',
                   'Prof. Castro · Periodo 2026-1')
        + ejercicio(1, 'Se hacen estas operaciones sobre una pila vacía: push(4), push(7), pop(), push(2), push(9), pop(). ¿Qué elemento queda en el tope?',
                    'Después de push(4), push(7) y pop() queda [4]. Luego push(2) y push(9): [4, 2, 9]. pop() saca el 9: el tope es <b>2</b>.')
        + ejercicio(2, '¿Cuál es la diferencia entre una pila (LIFO) y una cola (FIFO)? Dé un ejemplo de uso de cada una.',
                    'En la pila sale primero el último que entró (por ejemplo, deshacer en un editor). En la cola sale primero el primero que entró (por ejemplo, la cola de impresión).')
        + ejercicio(3, 'Escriba en Python una función que use una pila para verificar si los paréntesis de una cadena están balanceados.')
        + PIE,
    ])

    pdf(PRUEBAS / '3-rechazar-otra-asignatura-quimica.pdf', [
        encabezado('Química General', 'Guía de laboratorio – Titulación ácido-base',
                   'Súbalo en «Bases de Datos» para probar que la IA detecta que no corresponde a la asignatura.', universidad=False)
        + '<h2>Objetivo</h2><p>Determinar la concentración de una solución de HCl por titulación con NaOH 0,1 M usando fenolftaleína como indicador.</p>'
        + '<h2>Procedimiento</h2><p>1. Mida 25 mL de la solución de HCl con una pipeta volumétrica.<br>2. Agregue 3 gotas de fenolftaleína.<br>3. Titule con NaOH hasta el primer color rosado permanente.<br>4. Registre el volumen gastado y calcule C<sub>HCl</sub> = (C<sub>NaOH</sub> · V<sub>NaOH</sub>)/V<sub>HCl</sub>.</p>'
        + PIE,
    ])

    pdf(PRUEBAS / '4-rechazar-no-academico-publicidad.pdf', [
        '<div style="text-align:center"><h1 style="font-size:30pt;color:#c62828">¡PROMO 2x1 EN PIZZAS!</h1>'
        '<p style="font-size:16pt">Todos los martes y jueves · Domicilios gratis en Cartagena</p>'
        '<p style="font-size:14pt">Pide ya por WhatsApp y recibe una gaseosa de regalo.</p>'
        '<p style="font-size:12pt;color:#5d6178">Archivo de prueba: la IA debería rechazarlo porque no es material académico.</p></div>',
    ])

    # Imagen: ejercicio de plano inclinado, como una foto de un tablero.
    img = Image.new('RGB', (1600, 900), (247, 247, 242))
    d = ImageDraw.Draw(img)
    try:
        f = ImageFont.truetype('arial.ttf', 34)
        fb = ImageFont.truetype('arialbd.ttf', 40)
    except OSError:
        f = fb = ImageFont.load_default()
    d.text((60, 40), 'Física Mecánica – Ejercicio de plano inclinado', font=fb, fill=(31, 37, 102))
    d.polygon([(150, 650), (750, 650), (150, 330)], outline=(30, 30, 30), width=5)
    d.rectangle([(300, 420), (390, 480)], outline=(24, 121, 67), width=6)
    d.text((620, 600), '30°', font=f, fill=(30, 30, 30))
    lineas = [
        'Un bloque de 5 kg está sobre un plano inclinado',
        'de 30° sin fricción. Use g = 10 m/s².',
        'a) Dibuje el diagrama de cuerpo libre.',
        'b) Calcule la aceleración del bloque.',
        '   a = g · sen(30°) = 10 · 0,5 = 5 m/s²',
        'c) Calcule la fuerza normal.',
        '   N = m · g · cos(30°) ≈ 43,3 N',
    ]
    for i, linea in enumerate(lineas):
        d.text((760, 170 + i * 56), linea, font=f, fill=(30, 30, 30))
    img.save(PRUEBAS / '5-aprobar-imagen-plano-inclinado.png')
    print('creado', (PRUEBAS / '5-aprobar-imagen-plano-inclinado.png').relative_to(RAIZ))


if __name__ == '__main__':
    os.chdir(RAIZ)
    semilla()
    pruebas_de_carga()
