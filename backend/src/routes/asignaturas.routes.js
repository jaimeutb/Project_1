const { Router } = require('express');
const ctrl = require('../controllers/asignaturas.controller');
const { requiereAutenticacion, requiereRol } = require('../middleware/auth');

const router = Router();

router.get('/', requiereAutenticacion, ctrl.listar); // RF-03
router.post('/', requiereAutenticacion, requiereRol('administrador'), ctrl.crear); // RF-13
router.put('/:id', requiereAutenticacion, requiereRol('administrador'), ctrl.actualizar); // RF-13

module.exports = router;
