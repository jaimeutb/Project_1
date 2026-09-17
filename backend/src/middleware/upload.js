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

const TIPOS_PERMITIDOS = new Set([
  'application/pdf',
  'image/png',
  'image/jpeg',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/msword',
  'application/zip',
]);

const upload = multer({
  storage,
  limits: { fileSize: 25 * 1024 * 1024 }, // 25 MB
  fileFilter: (req, file, cb) => {
    if (TIPOS_PERMITIDOS.has(file.mimetype)) return cb(null, true);
    return cb(new Error('Tipo de archivo no permitido.'));
  },
});

module.exports = { upload, uploadsDir };
