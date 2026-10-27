const express = require('express');
const cors = require('cors');
const path = require('path');

const authRoutes = require('./routes/auth.routes');
const asignaturasRoutes = require('./routes/asignaturas.routes');
const materialesRoutes = require('./routes/materiales.routes');
const reportesRoutes = require('./routes/reportes.routes');
const usuariosRoutes = require('./routes/usuarios.routes');
const iaCtrl = require('./controllers/ia.controller');
const { requiereAutenticacion } = require('./middleware/auth');
const { errorHandler } = require('./middleware/errorHandler');
const { uploadsDir } = require('./middleware/upload');

const app = express();

app.use(cors());
// 1 MB: el chat del Tutor IA (RF-16) envía el historial de la conversación.
app.use(express.json({ limit: '1mb' }));

// RF-05: los archivos subidos se sirven como recursos estáticos (descarga/visualización).
app.use('/uploads', express.static(uploadsDir));

app.get('/api/salud', (req, res) => res.json({ estado: 'ok', servicio: 'plataforma-apoyo-academico-api' }));

app.use('/api/auth', authRoutes);
app.use('/api/asignaturas', asignaturasRoutes);
app.use('/api/materiales', materialesRoutes);
app.use('/api/reportes', reportesRoutes);
app.use('/api/usuarios', usuariosRoutes);
app.get('/api/ia/estado', requiereAutenticacion, iaCtrl.estado);

app.use((req, res) => res.status(404).json({ error: 'Ruta no encontrada.' }));
app.use(errorHandler);

module.exports = app;
