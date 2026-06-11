require('dotenv').config();
const express = require('express');
const cors = require('cors');
const os = require('os');
const morgan = require('morgan');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

// ── Routes ────────────────────────────────────────────────────
const authRoutes = require('./routes/authRoutes');
const wasteRoutes = require('./routes/wasteRoutes');
const mapRoutes = require('./routes/mapRoutes');
const vehicleRoutes = require('./routes/vehicleRoutes');
const statsRoutes = require('./routes/statsRoutes');
const bookingRoutes = require('./routes/bookingRoutes');

// ── Controllers for direct route registration ─────────────────
const authController = require('./controllers/authController');

const app = express();
const PORT = process.env.PORT || 3000;

// ════════════════════════════════════════════════════════════════
// MIDDLEWARE
// ════════════════════════════════════════════════════════════════
app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' },
}));

app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

if (process.env.NODE_ENV !== 'test') {
  app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));
}

// Rate Limiters
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  message: { success: false, message: 'Too many auth attempts. Try again in 15 minutes.' },
});

const aiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  message: { success: false, message: 'AI rate limit reached. Wait 1 minute.' },
});

app.use(globalLimiter);

// Dev Request Logger
if (process.env.NODE_ENV === 'development') {
  app.use((req, res, next) => {
    if (['POST', 'PUT', 'PATCH'].includes(req.method)) {
      const body = { ...req.body };
      if (body.image_base64) body.image_base64 = '[base64 truncated]';
      if (body.photo) body.photo = '[binary truncated]';
      console.log(`→ ${req.method} ${req.path} body:`, JSON.stringify(body).substring(0, 300));
    }
    next();
  });
}

// ════════════════════════════════════════════════════════════════
// HEALTH CHECK
// ════════════════════════════════════════════════════════════════
app.get('/', (_req, res) => {
  res.json({
    success: true,
    message: '✅ EcoWaste API is running',
    version: '2.0.0',
    environment: process.env.NODE_ENV || 'development'
  });
});

app.get('/health', (_req, res) => res.json({ status: 'ok', uptime: process.uptime() }));

// ════════════════════════════════════════════════════════════════
// TEST ENDPOINTS
// ════════════════════════════════════════════════════════════════
app.post('/api/test-sms', /* your existing test-sms code */);
app.post('/api/test-email', /* your existing test-email code */);
app.get('/api/test-sms-config', /* your existing config code */);
app.post('/api/test-notification', /* your existing notification code */);

// ════════════════════════════════════════════════════════════════
// ROUTES REGISTRATION
// ════════════════════════════════════════════════════════════════
app.use('/api/auth', authLimiter, authRoutes);

// Direct Password Reset Routes (Ensures they work)
app.post('/api/auth/forgot-password', authController.forgotPassword);
app.post('/api/auth/reset-password', authController.resetPassword);

// Other main routes
app.use('/api/waste/verify-ai', aiLimiter);
app.use('/api/waste', wasteRoutes);
app.use('/api/map', mapRoutes);
app.use('/api/vehicles', vehicleRoutes);
app.use('/api/stats', statsRoutes);
app.use('/api/bookings', bookingRoutes);

// ════════════════════════════════════════════════════════════════
// 404 & ERROR HANDLERS
// ════════════════════════════════════════════════════════════════
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Route ${req.method} ${req.path} not found`,
  });
});

app.use((err, req, res, _next) => {
  console.error('Unhandled Error:', err);
  res.status(err.status || 500).json({
    success: false,
    message: process.env.NODE_ENV === 'production'
      ? 'Internal server error'
      : err.message,
  });
});

// ════════════════════════════════════════════════════════════════
// START SERVER
// ════════════════════════════════════════════════════════════════
const server = app.listen(PORT, '0.0.0.0', () => {
  const ip = Object.values(os.networkInterfaces())
    .flat()
    .find(i => i.family === 'IPv4' && !i.internal)?.address || 'localhost';

  console.log(`\n🌿 EcoWaste API v2.0.0`);
  console.log(`ENV: ${process.env.NODE_ENV || 'development'}`);
  console.log('════════════════════════════════════════════════════');

  console.log('AUTH');
  console.log('    POST   /api/auth/register');
  console.log('    POST   /api/auth/login');
  console.log('    GET    /api/auth/profile');
  console.log('    POST   /api/auth/send-otp');
  console.log('    POST   /api/auth/verify-otp');
  console.log('    POST   /api/auth/forgot-password');   // ← Added
  console.log('    POST   /api/auth/reset-password');    // ← Added

  console.log('WASTE');
  console.log('    POST   /api/waste/log');
  console.log('    GET    /api/waste/my-logs');
  console.log('    POST   /api/waste/verify-ai');

  console.log('MAP     GET    /api/map/collection-points');
  console.log('VEHICLES GET   /api/vehicles/nearby');
  console.log('STATS    GET   /api/stats/me');
  console.log('         GET   /api/stats/leaderboard');
  console.log('BOOKINGS GET   /api/bookings/centers');
  console.log('         GET   /api/bookings/mine');
  console.log('         POST  /api/bookings');

  console.log('════════════════════════════════════════════════════');
  console.log('📱 SMS  :', process.env.MAMBO_TOKEN ? '✅ Configured' : '❌');
  console.log('📧 Email:', process.env.SMTP_USER ? '✅ Configured' : '❌');
  console.log(`\n🚀 Live at → https://ecowaste-backend-v8i9.onrender.com\n`);
});

module.exports = app;