-- =============================================================
-- EcoWaste – Civic Intelligence
-- Run this ONCE in Neon Console → SQL Editor
-- =============================================================

-- ── 1. USERS (extended from auth-server) ─────────────────────
CREATE TABLE IF NOT EXISTS users (
  id              SERIAL PRIMARY KEY,
  full_name       VARCHAR(100) NOT NULL,
  username        VARCHAR(50)  NOT NULL UNIQUE,
  email           VARCHAR(100) NOT NULL UNIQUE,
  phone           VARCHAR(20),
  driver_license  VARCHAR(50)  UNIQUE,
  password_hash   VARCHAR(255) NOT NULL,
  role            VARCHAR(20)  DEFAULT 'citizen',   -- citizen | driver | admin
  avatar_url      TEXT,
  eco_points      INTEGER      DEFAULT 0,
  total_kg        NUMERIC(10,2) DEFAULT 0,
  created_at      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- ── 2. COLLECTION POINTS (Map Screen) ────────────────────────
CREATE TABLE IF NOT EXISTS collection_points (
  id          SERIAL PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  latitude    NUMERIC(10,7) NOT NULL,
  longitude   NUMERIC(10,7) NOT NULL,
  type        VARCHAR(30)  DEFAULT 'general',  -- general | recycling | hazardous
  address     TEXT,
  is_active   BOOLEAN      DEFAULT TRUE,
  capacity_kg NUMERIC(8,2) DEFAULT 500,
  created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- ── 3. WASTE LOGS (Log Waste Entry – Screens 6 & 7) ──────────
CREATE TABLE IF NOT EXISTS waste_logs (
  id               SERIAL PRIMARY KEY,
  user_id          INTEGER REFERENCES users(id) ON DELETE CASCADE,
  waste_type       VARCHAR(50) NOT NULL,   -- plastic | paper | glass | metal | organic | hazardous
  container_count  INTEGER     DEFAULT 1,
  weight_kg        NUMERIC(8,2),
  photo_url        TEXT,
  ai_confidence    NUMERIC(5,2),           -- from Verification Screen
  ai_detected_type VARCHAR(50),
  collection_point_id INTEGER REFERENCES collection_points(id),
  latitude         NUMERIC(10,7),
  longitude        NUMERIC(10,7),
  notes            TEXT,
  status           VARCHAR(20) DEFAULT 'pending',  -- pending | verified | collected
  logged_at        TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
);

-- ── 4. VEHICLES / TRUCKS (Nearby Vehicles – Screen 9) ────────
CREATE TABLE IF NOT EXISTS vehicles (
  id            SERIAL PRIMARY KEY,
  driver_id     INTEGER REFERENCES users(id),
  plate_number  VARCHAR(20) NOT NULL UNIQUE,
  vehicle_type  VARCHAR(30) DEFAULT 'truck',
  capacity_kg   NUMERIC(8,2) DEFAULT 2000,
  latitude      NUMERIC(10,7),
  longitude     NUMERIC(10,7),
  status        VARCHAR(20) DEFAULT 'idle',  -- idle | collecting | full | offline
  eta_minutes   INTEGER,
  updated_at    TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
);

-- ── 5. RECYCLING CENTERS (Nearby Centers – Screen 10) ────────
CREATE TABLE IF NOT EXISTS recycling_centers (
  id              SERIAL PRIMARY KEY,
  name            VARCHAR(100) NOT NULL,
  address         TEXT,
  latitude        NUMERIC(10,7) NOT NULL,
  longitude       NUMERIC(10,7) NOT NULL,
  accepted_types  TEXT[],                  -- array: ['plastic','paper','glass']
  opening_hours   VARCHAR(100),
  phone           VARCHAR(30),
  is_active       BOOLEAN DEFAULT TRUE,
  rating          NUMERIC(3,1) DEFAULT 0,
  created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ── 6. BOOKINGS (Book Slot – Screen 10) ──────────────────────
CREATE TABLE IF NOT EXISTS bookings (
  id                  SERIAL PRIMARY KEY,
  user_id             INTEGER REFERENCES users(id) ON DELETE CASCADE,
  center_id           INTEGER REFERENCES recycling_centers(id),
  booking_date        DATE NOT NULL,
  time_slot           VARCHAR(30),         -- e.g. "09:00-10:00"
  waste_types         TEXT[],
  estimated_kg        NUMERIC(8,2),
  status              VARCHAR(20) DEFAULT 'confirmed',  -- confirmed | cancelled | completed
  booking_reference   VARCHAR(20) UNIQUE,
  created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ── 7. LEADERBOARD / STATS (Stats Screen – Screen 8) ─────────
CREATE TABLE IF NOT EXISTS weekly_stats (
  id          SERIAL PRIMARY KEY,
  user_id     INTEGER REFERENCES users(id) ON DELETE CASCADE,
  week_start  DATE NOT NULL,
  kg_collected NUMERIC(8,2) DEFAULT 0,
  trips_made  INTEGER DEFAULT 0,
  eco_points  INTEGER DEFAULT 0,
  rank        INTEGER,
  UNIQUE(user_id, week_start)
);

-- ── 8. SMS / OTP CODES (Login Screen – Screen 3) ─────────────
CREATE TABLE IF NOT EXISTS otp_codes (
  id          SERIAL PRIMARY KEY,
  phone       VARCHAR(20) NOT NULL,
  code        VARCHAR(6)  NOT NULL,
  expires_at  TIMESTAMP   NOT NULL,
  used        BOOLEAN     DEFAULT FALSE,
  created_at  TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
);

-- ── Indexes for performance ───────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_waste_logs_user    ON waste_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_waste_logs_date    ON waste_logs(logged_at);
CREATE INDEX IF NOT EXISTS idx_bookings_user      ON bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_weekly_stats_week  ON weekly_stats(week_start);
CREATE INDEX IF NOT EXISTS idx_vehicles_status    ON vehicles(status);

-- ── Seed: sample collection points (Dodoma, TZ) ──────────────
INSERT INTO collection_points (name, latitude, longitude, type, address) VALUES
  ('Dodoma Central Hub',    -6.1722, 35.7395, 'general',   'Makole St, Dodoma'),
  ('Kikuyu Recycling Yard', -6.1850, 35.7500, 'recycling', 'Kikuyu Rd, Dodoma'),
  ('Hospital Waste Drop',   -6.1630, 35.7340, 'hazardous', 'Near Regional Hospital')
ON CONFLICT DO NOTHING;

-- ── Seed: sample recycling centers ───────────────────────────
INSERT INTO recycling_centers (name, address, latitude, longitude, accepted_types, opening_hours, phone) VALUES
  ('GreenCycle Dodoma',  'Industrial Area, Dodoma', -6.1790, 35.7410, ARRAY['plastic','paper','glass'], 'Mon-Sat 08:00-17:00', '+255712000001'),
  ('EcoHub Tanzania',    'Uhuru St, Dodoma',        -6.1700, 35.7300, ARRAY['metal','plastic'],          'Mon-Fri 09:00-16:00', '+255712000002')
ON CONFLICT DO NOTHING;

-- Verify
SELECT 'users' AS tbl, COUNT(*) FROM users
UNION ALL SELECT 'collection_points', COUNT(*) FROM collection_points
UNION ALL SELECT 'recycling_centers', COUNT(*) FROM recycling_centers;
