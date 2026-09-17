const { Router } = require('express');
const { registrar, iniciarSesion, perfil } = require('../controllers/auth.controller');
const { requiereAutenticacion } = require('../middleware/auth');

const router = Router();

router.post('/registro', registrar);       // RF-01
router.post('/login', iniciarSesion);       // RF-02
router.get('/perfil', requiereAutenticacion, perfil);

module.exports = router;
