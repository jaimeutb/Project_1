const { Router } = require('express');
const ctrl = require('../controllers/reportes.controller');
const { requiereAutenticacion, requiereRol } = require('../middleware/auth');

const router = Router();

// RF-10: solo el administrador revisa y gestiona los reportes.
router.get('/', requiereAutenticacion, requiereRol('administrador'), ctrl.listar);
router.patch('/:id', requiereAutenticacion, requiereRol('administrador'), ctrl.actualizarEstado);

module.exports = router;
