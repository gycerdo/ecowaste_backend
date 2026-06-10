const express = require('express');
const router  = express.Router();
const { getCollectionPoints } = require('../controllers/mapController');

router.get('/collection-points', getCollectionPoints);

module.exports = router;
