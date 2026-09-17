const { Router } = require('express');
const ctrl = require('../controllers/usuarios.controller');
const { requiereAutenticacion, requiereRol } = require('../middleware/auth');

const router = Router();

// RF-13: gestión de usuarios (solo administrador).
router.get('/', requiereAutenticacion, requiereRol('administrador'), ctrl.listar);
router.patch('/:id/rol', requiereAutenticacion, requiereRol('administrador'), ctrl.actualizarRol);

module.exports = router;
