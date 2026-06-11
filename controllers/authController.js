const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const UserModel = require('../models/userModel');
const pool = require('../config/db');
const { sendOTP, sendWelcomeNotification } = require('../services/notificationService');

// ── Helper: sign JWT ──────────────────────────────────────────
const signToken = (user) =>
  jwt.sign(
    { id: user.id, email: user.email, username: user.username },
    process.env.JWT_SECRET || 'secret',
    { expiresIn: '7d' }
  );

// ── Existing functions (unchanged) ────────────────────────────
exports.register = async (req, res) => {
  // ... your existing register code (kept as is)
};

exports.login = async (req, res) => {
  // ... your existing login code
};

exports.sendOtp = async (req, res) => {
  // ... your existing sendOtp code
};

exports.verifyOtp = async (req, res) => {
  // ... your existing verifyOtp code
};

exports.resendOtp = async (req, res) => {
  // ... your existing resendOtp code
};

exports.getProfile = async (req, res) => {
  // ... your existing getProfile code
};

exports.updatePhoneNumber = async (req, res) => {
  // ... your existing updatePhoneNumber code
};

exports.logout = async (req, res) => {
  // ... your existing logout code
};

// ═══════════════════════════════════════════════════════════════
// NEW: PASSWORD RESET FUNCTIONS
// ═══════════════════════════════════════════════════════════════

/** POST /api/auth/forgot-password */
exports.forgotPassword = async (req, res) => {
  try {
    const { phone, email } = req.body;

    if (!phone && !email) {
      return res.status(400).json({
        success: false,
        message: 'Phone number or email is required'
      });
    }

    // Check if user exists
    let user;
    if (phone) user = await UserModel.findByPhone(phone);
    else if (email) user = await UserModel.findByEmail(email.toLowerCase());

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'No account found with this phone/email'
      });
    }

    // Reuse your existing sendOtp logic
    const otpResult = await sendOTP(phone || email, null, user.full_name || 'User', phone ? 'sms' : 'email');

    return res.json({
      success: true,
      message: 'Reset code sent successfully',
      sentTo: phone || email,
      channel: phone ? 'sms' : 'email',
      otp: process.env.NODE_ENV === 'development' ? otpResult?.otp || 'Check logs' : undefined
    });
  } catch (error) {
    console.error('Forgot password error:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

/** POST /api/auth/reset-password */
exports.resetPassword = async (req, res) => {
  try {
    const { phone, email, otp, new_password, password } = req.body;
    const finalPassword = new_password || password;

    if (!otp || !finalPassword) {
      return res.status(400).json({
        success: false,
        message: 'OTP and new password are required'
      });
    }

    if (finalPassword.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters long'
      });
    }

    const identifier = phone || email;

    // Verify OTP
    const otpCheck = await pool.query(
      `SELECT id FROM otp_codes 
       WHERE (phone = $1 OR email = $2) 
       AND code = $3 
       AND used = false 
       AND expires_at > NOW()`,
      [phone, email, otp]
    );

    if (otpCheck.rows.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Invalid or expired OTP'
      });
    }

    // Hash new password
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(finalPassword, salt);

    // Update user password
    const updateResult = await pool.query(
      `UPDATE users 
       SET password_hash = $1, updated_at = NOW() 
       WHERE (phone = $2 OR email = $3)`,
      [passwordHash, phone, email]
    );

    if (updateResult.rowCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    // Mark OTP as used
    await pool.query(`UPDATE otp_codes SET used = true WHERE id = $1`, [otpCheck.rows[0].id]);

    res.json({
      success: true,
      message: 'Password reset successfully. You can now login with your new password.'
    });
  } catch (error) {
    console.error('Reset password error:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};