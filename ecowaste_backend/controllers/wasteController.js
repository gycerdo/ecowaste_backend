const pool = require('../config/db');
const UserModel = require('../models/userModel');
const { sendNotification } = require('../services/notificationService');

// ── POST /api/waste/verify-ai ─────────────────────────────────
// Simulates AI waste detection (replace with real ML endpoint)
const verifyAI = async (req, res) => {
  try {
    const { image_base64 } = req.body;
    if (!image_base64) return res.status(400).json({ message: 'image_base64 required' });

    // Simulate AI detection — replace with real ML API call
    const types = ['plastic', 'paper', 'glass', 'metal', 'organic', 'hazardous'];
    const detectedType = types[Math.floor(Math.random() * types.length)];
    const confidence = (85 + Math.random() * 14).toFixed(1); // 85-99%

    return res.status(200).json({
      detected_type: detectedType,
      confidence: parseFloat(confidence),
      message: `AI detected: ${detectedType} (${confidence}% confidence)`,
    });
  } catch (err) {
    console.error('AI verify error:', err);
    return res.status(500).json({ message: 'AI verification failed' });
  }
};

// ── POST /api/waste/log ───────────────────────────────────────
const logWaste = async (req, res) => {
  try {
    const {
      waste_type, container_count, weight_kg, photo_url,
      ai_confidence, ai_detected_type, collection_point_id,
      latitude, longitude, notes,
    } = req.body;

    if (!waste_type) return res.status(400).json({ message: 'waste_type is required' });

    const result = await pool.query(
      `INSERT INTO waste_logs
        (user_id, waste_type, container_count, weight_kg, photo_url, ai_confidence, ai_detected_type,
         collection_point_id, latitude, longitude, notes)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
       RETURNING *`,
      [
        req.user.id, waste_type, container_count || 1, weight_kg || null,
        photo_url || null, ai_confidence || null, ai_detected_type || null,
        collection_point_id || null, latitude || null, longitude || null, notes || null,
      ]
    );

    let pointsEarned = 5; // Default points
    // Update user eco_points & total_kg
    if (weight_kg) {
      pointsEarned = Math.floor(parseFloat(weight_kg) * 10);
      await UserModel.updateEcoPoints(req.user.id, parseFloat(weight_kg));
    }

    // Update weekly stats
    const weekStart = getWeekStart();
    await pool.query(
      `INSERT INTO weekly_stats (user_id, week_start, kg_collected, trips_made, eco_points)
       VALUES ($1, $2, $3, 1, $4)
       ON CONFLICT (user_id, week_start) DO UPDATE
       SET kg_collected = weekly_stats.kg_collected + $3,
           trips_made   = weekly_stats.trips_made + 1,
           eco_points   = weekly_stats.eco_points + $4`,
      [req.user.id, weekStart, weight_kg || 0, pointsEarned]
    );

    // Send notification about waste log (if user has email/phone)
    const user = await UserModel.findById(req.user.id);
    if (user && (user.email || user.phone) && weight_kg) {
      await sendNotification({
        email: user.email,
        phone: user.phone,
        name: user.full_name || 'User',
        type: 'points_earned',
        data: {
          points: pointsEarned,
          activity: `Logged ${weight_kg}kg of ${waste_type} waste`,
          totalPoints: (user.eco_points || 0) + pointsEarned
        }
      }).catch(err => console.error('Waste log notification failed:', err.message));
    }

    return res.status(201).json({
      message: 'Waste logged successfully 🌿',
      log: result.rows[0],
      points_earned: pointsEarned
    });
  } catch (err) {
    console.error('Log waste error:', err);
    return res.status(500).json({ message: 'Internal server error' });
  }
};

// ── GET /api/waste/my-logs ────────────────────────────────────
const getMyLogs = async (req, res) => {
  try {
    const { limit = 20, offset = 0 } = req.query;
    const result = await pool.query(
      `SELECT wl.*, cp.name AS collection_point_name
       FROM waste_logs wl
       LEFT JOIN collection_points cp ON wl.collection_point_id = cp.id
       WHERE wl.user_id = $1
       ORDER BY wl.logged_at DESC
       LIMIT $2 OFFSET $3`,
      [req.user.id, limit, offset]
    );
    return res.status(200).json({ logs: result.rows, count: result.rowCount });
  } catch (err) {
    console.error('Get logs error:', err);
    return res.status(500).json({ message: 'Internal server error' });
  }
};

// ── GET /api/waste/stats ──────────────────────────────────────
const getWasteStats = async (req, res) => {
  try {
    const userId = req.user.id;

    // Get total waste by type
    const typeStats = await pool.query(
      `SELECT waste_type, COUNT(*) as count, SUM(weight_kg) as total_kg
       FROM waste_logs
       WHERE user_id = $1 AND weight_kg IS NOT NULL
       GROUP BY waste_type
       ORDER BY total_kg DESC`,
      [userId]
    );

    // Get monthly trends
    const monthlyTrends = await pool.query(
      `SELECT DATE_TRUNC('month', logged_at) as month, 
              COUNT(*) as logs_count, 
              SUM(weight_kg) as total_kg
       FROM waste_logs
       WHERE user_id = $1 AND weight_kg IS NOT NULL
       GROUP BY DATE_TRUNC('month', logged_at)
       ORDER BY month DESC
       LIMIT 6`,
      [userId]
    );

    return res.status(200).json({
      stats: {
        by_type: typeStats.rows,
        monthly_trends: monthlyTrends.rows,
        total_logs: typeStats.rows.reduce((sum, row) => sum + parseInt(row.count), 0),
        total_kg: typeStats.rows.reduce((sum, row) => sum + parseFloat(row.total_kg || 0), 0)
      }
    });
  } catch (err) {
    console.error('Get waste stats error:', err);
    return res.status(500).json({ message: 'Internal server error' });
  }
};

function getWeekStart() {
  const now = new Date();
  const day = now.getDay();
  const diff = now.getDate() - day + (day === 0 ? -6 : 1);
  const mon = new Date(now.setDate(diff));
  return mon.toISOString().split('T')[0];
}
module.exports = { verifyAI, logWaste, getMyLogs, getWasteStats };