const express = require('express');
const router = express.Router();
const auth = require('../middleware/authMiddleware');
const vehicleController = require('../controllers/vehicleController');

// Standardized mapping using explicit object properties
router.post('/', auth, vehicleController.createVehicle || ((req, res) => res.status(501).json({ message: "Not Implemented" })));
router.get('/', vehicleController.getAllVehicles);

module.exports = router;
