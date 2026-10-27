// Vista previa del material (RF-19): la primera página de un PDF, o la imagen
// misma, reducida a 600 px de ancho en JPG. Se guarda junto al archivo, en
// UPLOADS_DIR, con el sufijo «-miniatura.jpg».
const fs = require('fs');
const path = require('path');

const ANCHO = 600;

// pdf.js necesita sus fuentes estándar para dibujar los PDF que no las incluyen.
// En Windows la ruta debe ir con barras normales.
const FUENTES_PDFJS = `${path.join(path.dirname(require.resolve('pdfjs-dist/package.json')), 'standard_fonts')
  .replace(/\\/g, '/')}/`;

async function primeraPaginaDelPdf(rutaPdf) {
  const { pdf } = await import('pdf-to-img');
  const documento = await pdf(rutaPdf, { scale: 1.5, docInitParams: { standardFontDataUrl: FUENTES_PDFJS } });
  for await (const pagina of documento) return pagina;
  return null;
}

/**
 * Crea la miniatura del archivo y devuelve su ruta pública ("/uploads/..."),
 * o null si el tipo no tiene vista previa (Word, ZIP) o el archivo no se pudo leer.
 */
async function crearMiniatura(rutaArchivo) {
  const extension = path.extname(rutaArchivo).toLowerCase();
  let imagen = null;
  try {
    if (extension === '.pdf') imagen = await primeraPaginaDelPdf(rutaArchivo);
    else if (['.png', '.jpg', '.jpeg'].includes(extension)) imagen = fs.readFileSync(rutaArchivo);
    if (!imagen) return null;

    const sharp = require('sharp');
    const nombre = `${path.basename(rutaArchivo, extension)}-miniatura.jpg`;
    await sharp(imagen)
      .rotate() // respeta la orientación de las fotos tomadas con el celular
      .resize({ width: ANCHO, withoutEnlargement: true })
      .flatten({ background: '#ffffff' })
      .jpeg({ quality: 82 })
      .toFile(path.join(path.dirname(rutaArchivo), nombre));
    return `/uploads/${nombre}`;
  } catch (err) {
    // Un archivo dañado no impide publicar el material: solo se queda sin vista previa.
    console.error('No se pudo crear la miniatura de', path.basename(rutaArchivo), '-', err.message);
    return null;
  }
}

module.exports = { crearMiniatura };
