const express = require('express');
const router = express.Router();
const auth = require('../middleware/authMiddleware');
const bookingController = require('../controllers/bookingController');

// Using explicit object reference to guarantee Express reads them as callback functions
router.get('/centers', auth, bookingController.getCenters);
router.post('/', auth, bookingController.createBooking);
router.get('/mine', auth, bookingController.getMyBookings);
router.get('/:id', auth, bookingController.getBookingById);
router.delete('/:id', auth, bookingController.cancelBooking);
router.put('/:id/complete', auth, bookingController.completeBooking);

module.exports = router;