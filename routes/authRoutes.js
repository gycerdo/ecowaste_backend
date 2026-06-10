const express = require('express');
const router = express.Router();
const auth = require('../middleware/authMiddleware');
const authController = require('../controllers/authController');

// Clean mapping using clear object reference syntax
router.post('/register', authController.register);
router.post('/login', authController.login);
router.post('/send-otp', authController.sendOtp);
router.post('/verify-otp', authController.verifyOtp);
router.post('/resend-otp', authController.resendOtp);
router.get('/profile', auth, authController.getProfile);
router.put('/profile/phone', auth, authController.updatePhoneNumber);
router.post('/logout', auth, authController.logout);

module.exports = router;