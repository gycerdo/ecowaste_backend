const pool = require('../config/db');

const UserModel = {
  async createUser(fullName, username, email, phone, driverLicense, passwordHash) {
    const query = `
      INSERT INTO users (full_name, username, email, phone, driver_license, password_hash)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING id, full_name, username, email, phone, driver_license, eco_points, total_kg, created_at
    `;
    const result = await pool.query(query, [fullName, username, email, phone, driverLicense, passwordHash]);
    return result.rows[0];
  },

  async findByEmail(email) {
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    return result.rows[0] || null;
  },

  async findByUsername(username) {
    const result = await pool.query('SELECT * FROM users WHERE username = $1', [username]);
    return result.rows[0] || null;
  },

  async findByDriverLicense(license) {
    const result = await pool.query('SELECT * FROM users WHERE driver_license = $1', [license]);
    return result.rows[0] || null;
  },

  async findById(id) {
    const result = await pool.query(
      'SELECT id, full_name, username, email, phone, driver_license, eco_points, total_kg, avatar_url, created_at FROM users WHERE id = $1',
      [id]
    );
    return result.rows[0] || null;
  },

  async updateEcoPoints(userId, addKg) {
    const points = Math.floor(addKg * 10); // 10 points per kg
    await pool.query(
      'UPDATE users SET eco_points = eco_points + $1, total_kg = total_kg + $2, updated_at = NOW() WHERE id = $3',
      [points, addKg, userId]
    );
  },
};

module.exports = UserModel;
