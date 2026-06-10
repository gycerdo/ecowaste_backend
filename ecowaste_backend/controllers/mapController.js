const pool = require('../config/db');

// ── GET /api/map/collection-points ───────────────────────────
const getCollectionPoints = async (req, res) => {
  try {
    const { type, lat, lng, radius_km = 10 } = req.query;

    let query  = 'SELECT * FROM collection_points WHERE is_active = TRUE';
    const vals = [];

    if (type) {
      vals.push(type);
      query += ` AND type = $${vals.length}`;
    }

    // Haversine distance filter when lat/lng provided
    if (lat && lng) {
      query = `
        SELECT *,
          (6371 * acos(
            cos(radians($${vals.length + 1})) * cos(radians(latitude)) *
            cos(radians(longitude) - radians($${vals.length + 2})) +
            sin(radians($${vals.length + 1})) * sin(radians(latitude))
          )) AS distance_km
        FROM collection_points
        WHERE is_active = TRUE
        ${type ? `AND type = $${vals.length}` : ''}
        HAVING (6371 * acos(
            cos(radians($${vals.length + 1})) * cos(radians(latitude)) *
            cos(radians(longitude) - radians($${vals.length + 2})) +
            sin(radians($${vals.length + 1})) * sin(radians(latitude))
          )) < $${vals.length + 3}
        ORDER BY distance_km
      `;
      vals.push(parseFloat(lat), parseFloat(lng), parseFloat(radius_km));
    } else {
      query += ' ORDER BY name';
    }

    const result = await pool.query(query, vals);
    return res.status(200).json({ points: result.rows });
  } catch (err) {
    console.error('Map error:', err);
    return res.status(500).json({ message: 'Internal server error' });
  }
};

module.exports = { getCollectionPoints };
