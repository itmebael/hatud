-- =====================================================
-- SUPABASE BOOKING SYSTEM SCHEMA
-- =====================================================
-- This schema creates the necessary tables for the passenger
-- booking system with driver selection and scheduled bookings
-- =====================================================

-- =====================================================
-- 1. BOOKINGS TABLE
-- =====================================================
-- Main table to store all booking information
-- Supports both immediate and scheduled bookings
-- =====================================================

-- Drop existing table if it exists (uncomment if you want to start fresh)
-- DROP TABLE IF EXISTS bookings CASCADE;

CREATE TABLE IF NOT EXISTS bookings (
  -- Primary Key
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Passenger Information (Foreign Key to users table)
  passenger_id TEXT NOT NULL,
  passenger_name TEXT NOT NULL,
  passenger_email TEXT,
  passenger_phone TEXT,
  
  -- Driver Information (Foreign Key to users table)
  driver_id TEXT NOT NULL,
  driver_name TEXT NOT NULL,
  driver_email TEXT,
  driver_phone TEXT,
  
  -- Pickup Location
  pickup_latitude DOUBLE PRECISION NOT NULL,
  pickup_longitude DOUBLE PRECISION NOT NULL,
  pickup_address TEXT,
  
  -- Destination Location
  destination_latitude DOUBLE PRECISION,
  destination_longitude DOUBLE PRECISION,
  destination_address TEXT,
  
  -- Booking Details
  booking_type TEXT NOT NULL DEFAULT 'immediate' CHECK (booking_type IN ('immediate', 'scheduled')),
  scheduled_time TIMESTAMPTZ, -- For scheduled bookings
  booking_time TIMESTAMPTZ NOT NULL DEFAULT NOW(), -- When booking was created
  
  -- Trip Details
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'in_progress', 'completed', 'cancelled', 'driver_arrived')),
  estimated_distance_km DOUBLE PRECISION,
  estimated_duration_minutes INTEGER,
  actual_distance_km DOUBLE PRECISION,
  actual_duration_minutes INTEGER,
  
  -- Fare Information
  estimated_fare DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  final_fare DOUBLE PRECISION,
  fare_currency TEXT DEFAULT 'PHP',
  
  -- Payment Information
  payment_method TEXT,
  payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'refunded', 'failed')),
  payment_transaction_id TEXT,
  
  -- Additional Information
  special_instructions TEXT,
  number_of_passengers INTEGER DEFAULT 1,
  vehicle_type TEXT DEFAULT 'tricycle',
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  accepted_at TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  
  -- Driver Location when booking was made (for tracking)
  driver_latitude_at_booking DOUBLE PRECISION,
  driver_longitude_at_booking DOUBLE PRECISION,
  
  -- Rating and Review (filled after trip completion)
  passenger_rating INTEGER CHECK (passenger_rating >= 1 AND passenger_rating <= 5),
  driver_rating INTEGER CHECK (driver_rating >= 1 AND driver_rating <= 5),
  passenger_review TEXT,
  driver_review TEXT
);

-- =====================================================
-- 2. ADD MISSING COLUMNS (if table already exists)
-- =====================================================

-- Add passenger_email if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'bookings' AND column_name = 'passenger_email') THEN
    ALTER TABLE bookings ADD COLUMN passenger_email TEXT;
  END IF;
END $$;

-- Add driver_email if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'bookings' AND column_name = 'driver_email') THEN
    ALTER TABLE bookings ADD COLUMN driver_email TEXT;
  END IF;
END $$;

-- Add passenger_phone if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'bookings' AND column_name = 'passenger_phone') THEN
    ALTER TABLE bookings ADD COLUMN passenger_phone TEXT;
  END IF;
END $$;

-- Add driver_phone if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'bookings' AND column_name = 'driver_phone') THEN
    ALTER TABLE bookings ADD COLUMN driver_phone TEXT;
  END IF;
END $$;

-- =====================================================
-- 3. INDEXES FOR PERFORMANCE
-- =====================================================

-- Index for passenger queries
CREATE INDEX IF NOT EXISTS idx_bookings_passenger_id ON bookings(passenger_id);
CREATE INDEX IF NOT EXISTS idx_bookings_passenger_email ON bookings(passenger_email);

-- Index for driver queries
CREATE INDEX IF NOT EXISTS idx_bookings_driver_id ON bookings(driver_id);
CREATE INDEX IF NOT EXISTS idx_bookings_driver_email ON bookings(driver_email);

-- Index for status queries (most common filter)
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);

-- Index for scheduled bookings
CREATE INDEX IF NOT EXISTS idx_bookings_scheduled_time ON bookings(scheduled_time) WHERE scheduled_time IS NOT NULL;

-- Index for date range queries
CREATE INDEX IF NOT EXISTS idx_bookings_created_at ON bookings(created_at DESC);

-- Index for active bookings (pending, accepted, in_progress)
CREATE INDEX IF NOT EXISTS idx_bookings_active_status ON bookings(status) WHERE status IN ('pending', 'accepted', 'in_progress', 'driver_arrived');

-- Composite index for driver status queries
CREATE INDEX IF NOT EXISTS idx_bookings_driver_status ON bookings(driver_id, status);

-- Composite index for passenger status queries
CREATE INDEX IF NOT EXISTS idx_bookings_passenger_status ON bookings(passenger_id, status);

-- =====================================================
-- 4. TRIGGER FOR UPDATED_AT TIMESTAMP
-- =====================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_bookings_updated_at
BEFORE UPDATE ON bookings
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 5. ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Passengers can view own bookings" ON bookings;
DROP POLICY IF EXISTS "Passengers can create own bookings" ON bookings;
DROP POLICY IF EXISTS "Passengers can update own pending bookings" ON bookings;
DROP POLICY IF EXISTS "Drivers can view assigned bookings" ON bookings;
DROP POLICY IF EXISTS "Drivers can update assigned bookings" ON bookings;
DROP POLICY IF EXISTS "Service role full access" ON bookings;

-- Enable RLS
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

-- Policy: Passengers can view their own bookings
CREATE POLICY "Passengers can view own bookings"
ON bookings
FOR SELECT
USING (
  passenger_email = (SELECT email FROM auth.users WHERE id = auth.uid()::text)
  OR passenger_id = auth.uid()::text
);

-- Policy: Passengers can create their own bookings
CREATE POLICY "Passengers can create own bookings"
ON bookings
FOR INSERT
WITH CHECK (
  passenger_email = (SELECT email FROM auth.users WHERE id = auth.uid()::text)
  OR passenger_id = auth.uid()::text
);

-- Policy: Passengers can update their own pending bookings
CREATE POLICY "Passengers can update own pending bookings"
ON bookings
FOR UPDATE
USING (
  (passenger_email = (SELECT email FROM auth.users WHERE id = auth.uid()::text)
   OR passenger_id = auth.uid()::text)
  AND status IN ('pending', 'accepted')
)
WITH CHECK (
  (passenger_email = (SELECT email FROM auth.users WHERE id = auth.uid()::text)
   OR passenger_id = auth.uid()::text)
);

-- Policy: Drivers can view bookings assigned to them
CREATE POLICY "Drivers can view assigned bookings"
ON bookings
FOR SELECT
USING (
  driver_email = (SELECT email FROM auth.users WHERE id = auth.uid()::text)
  OR driver_id = auth.uid()::text
);

-- Policy: Drivers can update bookings assigned to them
CREATE POLICY "Drivers can update assigned bookings"
ON bookings
FOR UPDATE
USING (
  driver_email = (SELECT email FROM auth.users WHERE id = auth.uid()::text)
  OR driver_id = auth.uid()::text
);

-- Policy: Service role can do everything (for admin operations)
CREATE POLICY "Service role full access"
ON bookings
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

-- =====================================================
-- 6. HELPER FUNCTIONS
-- =====================================================

-- Function to get active bookings for a passenger
CREATE OR REPLACE FUNCTION get_passenger_active_bookings(p_email TEXT)
RETURNS TABLE (
  id UUID,
  driver_name TEXT,
  pickup_address TEXT,
  destination_address TEXT,
  status TEXT,
  scheduled_time TIMESTAMPTZ,
  estimated_fare DOUBLE PRECISION,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    b.id,
    b.driver_name,
    b.pickup_address,
    b.destination_address,
    b.status,
    b.scheduled_time,
    b.estimated_fare,
    b.created_at
  FROM bookings b
  WHERE b.passenger_email = p_email
    AND b.status IN ('pending', 'accepted', 'in_progress', 'driver_arrived')
  ORDER BY b.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get active bookings for a driver
CREATE OR REPLACE FUNCTION get_driver_active_bookings(d_email TEXT)
RETURNS TABLE (
  id UUID,
  passenger_name TEXT,
  pickup_address TEXT,
  destination_address TEXT,
  status TEXT,
  scheduled_time TIMESTAMPTZ,
  estimated_fare DOUBLE PRECISION,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    b.id,
    b.passenger_name,
    b.pickup_address,
    b.destination_address,
    b.status,
    b.scheduled_time,
    b.estimated_fare,
    b.created_at
  FROM bookings b
  WHERE b.driver_email = d_email
    AND b.status IN ('pending', 'accepted', 'in_progress', 'driver_arrived')
  ORDER BY b.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get booking history for a passenger
CREATE OR REPLACE FUNCTION get_passenger_booking_history(p_email TEXT, limit_count INTEGER DEFAULT 50)
RETURNS TABLE (
  id UUID,
  driver_name TEXT,
  pickup_address TEXT,
  destination_address TEXT,
  status TEXT,
  scheduled_time TIMESTAMPTZ,
  final_fare DOUBLE PRECISION,
  created_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    b.id,
    b.driver_name,
    b.pickup_address,
    b.destination_address,
    b.status,
    b.scheduled_time,
    b.final_fare,
    b.created_at,
    b.completed_at
  FROM bookings b
  WHERE b.passenger_email = p_email
    AND b.status IN ('completed', 'cancelled')
  ORDER BY b.created_at DESC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 7. SAMPLE QUERIES FOR REFERENCE
-- =====================================================

-- Get all available drivers (from tricycle_locations table)
-- This assumes you already have a tricycle_locations table
-- SELECT * FROM tricycle_locations WHERE status = 'active';

-- Create a new immediate booking
/*
INSERT INTO bookings (
  passenger_id,
  passenger_name,
  passenger_email,
  driver_id,
  driver_name,
  pickup_latitude,
  pickup_longitude,
  pickup_address,
  destination_latitude,
  destination_longitude,
  destination_address,
  booking_type,
  estimated_fare,
  status
) VALUES (
  'passenger_user_id',
  'John Doe',
  'john@example.com',
  'driver_user_id',
  'Driver Name',
  11.7766,
  124.8862,
  'Pickup Address',
  11.7800,
  124.8900,
  'Destination Address',
  'immediate',
  50.00,
  'pending'
);
*/

-- Create a scheduled booking
/*
INSERT INTO bookings (
  passenger_id,
  passenger_name,
  passenger_email,
  driver_id,
  driver_name,
  pickup_latitude,
  pickup_longitude,
  pickup_address,
  destination_latitude,
  destination_longitude,
  destination_address,
  booking_type,
  scheduled_time,
  estimated_fare,
  status
) VALUES (
  'passenger_user_id',
  'John Doe',
  'john@example.com',
  'driver_user_id',
  'Driver Name',
  11.7766,
  124.8862,
  'Pickup Address',
  11.7800,
  124.8900,
  'Destination Address',
  'scheduled',
  '2024-12-25 10:00:00+00:00', -- Scheduled time
  50.00,
  'pending'
);
*/

-- Update booking status (e.g., driver accepts)
/*
UPDATE bookings
SET 
  status = 'accepted',
  accepted_at = NOW()
WHERE id = 'booking_uuid_here';
*/

-- Complete a booking
/*
UPDATE bookings
SET 
  status = 'completed',
  completed_at = NOW(),
  final_fare = 55.00,
  actual_distance_km = 5.2,
  actual_duration_minutes = 15
WHERE id = 'booking_uuid_here';
*/

-- =====================================================
-- 8. NOTES AND RECOMMENDATIONS
-- =====================================================

-- 1. Make sure you have a 'users' table with the following columns:
--    - id (TEXT or UUID)
--    - email (TEXT)
--    - full_name (TEXT)
--    - phone_number (TEXT)
--    - role (TEXT) - 'passenger', 'driver', 'admin'

-- 2. Make sure you have a 'tricycle_locations' table for driver locations:
--    - driver_id (TEXT)
--    - driver_name (TEXT)
--    - driver_email (TEXT)
--    - latitude (DOUBLE PRECISION)
--    - longitude (DOUBLE PRECISION)
--    - status (TEXT) - 'active', 'inactive', 'busy'

-- 3. For scheduled bookings, you may want to add a cron job or scheduled task
--    that notifies drivers X minutes before the scheduled time.

-- 4. Consider adding a 'notifications' table to track booking notifications.

-- 5. For payment integration, you may want to add a separate 'payments' table
--    with more detailed payment information.

-- 6. The RLS policies assume you're using Supabase Auth. If not, you may need
--    to adjust the policies or disable RLS and handle security in your application.

-- =====================================================
-- END OF SCHEMA
-- =====================================================

