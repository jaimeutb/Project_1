const { Router } = require('express');
const ctrl = require('../controllers/asignaturas.controller');
const iaCtrl = require('../controllers/ia.controller');
const { requiereAutenticacion, requiereRol } = require('../middleware/auth');

const router = Router();

router.get('/', requiereAutenticacion, ctrl.listar); // RF-03
router.post('/', requiereAutenticacion, requiereRol('administrador'), ctrl.crear); // RF-13
router.put('/:id', requiereAutenticacion, requiereRol('administrador'), ctrl.actualizar); // RF-13

// RF-18: simulacro de parcial con IA (cualquier usuario autenticado).
router.post('/:asignatura_id/ia/simulacro', requiereAutenticacion, iaCtrl.simulacro);

module.exports = router;
