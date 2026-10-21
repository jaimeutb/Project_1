const multer = require('multer');
const path = require('path');
const fs = require('fs');
require('dotenv').config();

const uploadsDir = path.join(__dirname, '..', '..', process.env.UPLOADS_DIR || 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// Almacenamiento local de archivos (RF-05/RF-06). En un despliegue real esto
// puede reemplazarse por almacenamiento en la nube sin cambiar los controladores,
// ya que solo se guarda la ruta pública del archivo en la base de datos.
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadsDir),
  filename: (req, file, cb) => {
    const sufijo = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    const ext = path.extname(file.originalname);
    cb(null, `${sufijo}${ext}`);
  },
});

// Tipos permitidos por extensión. Se valida la extensión porque no todos los
// clientes envían el tipo MIME real: el paquete http de Flutter manda
// "application/octet-stream" cuando no se indica otro.
const TIPOS_PERMITIDOS = {
  '.pdf': ['application/pdf'],
  '.png': ['image/png'],
  '.jpg': ['image/jpeg'],
  '.jpeg': ['image/jpeg'],
  '.docx': ['application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
  '.doc': ['application/msword'],
  '.zip': ['application/zip', 'application/x-zip-compressed'],
};
const TIPO_GENERICO = 'application/octet-stream';

const upload = multer({
  storage,
  limits: { fileSize: 25 * 1024 * 1024 }, // 25 MB
  fileFilter: (req, file, cb) => {
    const tipos = TIPOS_PERMITIDOS[path.extname(file.originalname).toLowerCase()];
    // La extensión debe estar permitida, y el tipo declarado debe coincidir con
    // ella o ser el genérico.
    if (tipos && (tipos.includes(file.mimetype) || file.mimetype === TIPO_GENERICO)) {
      return cb(null, true);
    }
    const err = new Error('Tipo de archivo no permitido (PDF, imagen, Word o ZIP).');
    err.status = 400;
    return cb(err);
  },
});

module.exports = { upload, uploadsDir };
