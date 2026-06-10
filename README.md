# EcoWaste Backend API

## Setup
```bash
npm install
cp .env.example .env
# Edit .env with your Neon DATABASE_URL and JWT_SECRET
npm start
```

## Endpoints
POST   /api/auth/register
POST   /api/auth/login
POST   /api/auth/send-otp
POST   /api/auth/verify-otp
GET    /api/auth/profile
POST   /api/waste/verify-ai
POST   /api/waste/log
GET    /api/waste/my-logs
GET    /api/map/collection-points
GET    /api/vehicles/nearby
GET    /api/stats/me
GET    /api/stats/leaderboard
GET    /api/bookings/centers
POST   /api/bookings
GET    /api/bookings/my
