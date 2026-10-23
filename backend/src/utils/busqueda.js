// Búsqueda de texto libre del buscador (RF-03/RF-04), con los ajustes de
// usabilidad H-01 y H-02:
//   H-01: se busca también en el nombre y el código de la asignatura, y por
//         palabras sueltas («parcial cálculo diferencial»).
//   H-02: no distingue tildes ni mayúsculas («cinematica» encuentra «cinemática»).

// Campos en los que se busca cada palabra.
const CAMPOS = ['m.titulo', 'm.descripcion', 'a.nombre', 'a.codigo'];

// Letras con tilde, diéresis, eñe o cedilla y su equivalente sin ella. Se usa
// translate() de PostgreSQL para no depender de la extensión unaccent.
const CON_TILDE = 'áàäâãéèëêíìïîóòöôõúùüûñçÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇ';
const SIN_TILDE = 'aaaaaeeeeiiiiooooouuuuncAAAAAEEEEIIIIOOOOOUUUUNC';

// Palabras que no ayudan a encontrar material: «parcial de cálculo» busca
// «parcial» y «cálculo».
const PALABRAS_VACIAS = new Set([
  'a', 'al', 'con', 'de', 'del', 'e', 'el', 'en', 'la', 'las', 'lo', 'los',
  'o', 'para', 'por', 'u', 'un', 'una', 'unas', 'unos', 'y',
]);

const MAX_PALABRAS = 10;

/** Quita tildes y pasa a minúsculas, igual que hace la consulta con cada campo. */
function normalizar(texto) {
  return String(texto).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
}

/**
 * Divide el texto buscado en palabras normalizadas, sin palabras vacías (salvo
 * que no quede otra) y con los comodines de LIKE escapados.
 */
function palabrasDeBusqueda(texto) {
  const palabras = normalizar(texto).split(/\s+/).filter(Boolean);
  const utiles = palabras.filter((p) => !PALABRAS_VACIAS.has(p));
  return (utiles.length ? utiles : palabras)
    .slice(0, MAX_PALABRAS)
    .map((p) => p.replace(/[\\%_]/g, '\\$&'));
}

/**
 * Agrega a `condiciones` y `valores` una condición por palabra: cada palabra debe
 * aparecer, sin importar tildes ni mayúsculas, en alguno de los CAMPOS.
 */
function agregarCondicionesDeTexto(texto, condiciones, valores) {
  for (const palabra of palabrasDeBusqueda(texto)) {
    valores.push(`%${palabra}%`);
    const param = `$${valores.length}`;
    const alguno = CAMPOS.map(
      (campo) => `lower(translate(${campo}, '${CON_TILDE}', '${SIN_TILDE}')) LIKE ${param}`
    );
    condiciones.push(`(${alguno.join(' OR ')})`);
  }
}

module.exports = { palabrasDeBusqueda, agregarCondicionesDeTexto };
