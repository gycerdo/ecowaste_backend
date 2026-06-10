const pool = require('../config/db');

// -- 1. Get All Vehicles ------------------------------------------------------
exports.getAllVehicles = async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM vehicles ORDER BY id DESC');
    return res.status(200).json({
      success: true,
      count: result.rows.length,
      vehicles: result.rows
    });
  } catch (error) {
    console.error('Get all vehicles error:', error);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// -- 2. Create Vehicle --------------------------------------------------------
exports.createVehicle = async (req, res) => {
  try {
    const { plate_number, model, capacity } = req.body;
    if (!plate_number || !model) {
      return res.status(400).json({ success: false, message: 'Plate number and model are required' });
    }
    const result = await pool.query(
      'INSERT INTO vehicles (plate_number, model, capacity) VALUES ($1, $2, $3) RETURNING *',
      [plate_number, model, capacity || null]
    );
    return res.status(201).json({ success: true, vehicle: result.rows[0] });
  } catch (error) {
    console.error('Create vehicle error:', error);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
};
