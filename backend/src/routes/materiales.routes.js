const { Router } = require('express');
const ctrl = require('../controllers/materiales.controller');
const valoracionesCtrl = require('../controllers/valoraciones.controller');
const reportesCtrl = require('../controllers/reportes.controller');
const { requiereAutenticacion, requiereRol } = require('../middleware/auth');
const { upload } = require('../middleware/upload');

const router = Router();

// RF-03/RF-04/RF-05: búsqueda, filtro y visualización (cualquier usuario autenticado).
router.get('/', requiereAutenticacion, ctrl.listar);
router.get('/:id', requiereAutenticacion, ctrl.obtener);

// RF-06/RF-07/RF-11: cualquier estudiante autenticado puede subir material propio.
router.post('/', requiereAutenticacion, upload.single('archivo'), ctrl.crear);

// RF-12: solo el administrador edita o elimina material.
router.put('/:id', requiereAutenticacion, requiereRol('administrador'), ctrl.actualizar);
router.delete('/:id', requiereAutenticacion, requiereRol('administrador'), ctrl.eliminar);

// RF-08: valorar un material.
router.post('/:material_id/valoraciones', requiereAutenticacion, valoracionesCtrl.crear);
router.get('/:material_id/valoraciones', requiereAutenticacion, valoracionesCtrl.listarPorMaterial);

// RF-09: reportar un material.
router.post('/:material_id/reportes', requiereAutenticacion, reportesCtrl.crear);

module.exports = router;
