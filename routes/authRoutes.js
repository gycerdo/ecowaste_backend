const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');

// Njia ya Usajili: POST /api/auth/register
router.post('/register', authController.register);

// Njia ya Kuingia: POST /api/auth/login
router.post('/login', authController.login);

module.exports = router;