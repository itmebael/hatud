-- =====================================================
-- FIX BOOKING TABLE - Add Missing Columns
-- =====================================================
-- Run this if you get "column does not exist" errors
-- This will add any missing columns to the bookings table
-- =====================================================

-- Add passenger_email if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'bookings' AND column_name = 'passenger_email') THEN
    ALTER TABLE bookings ADD COLUMN passenger_email TEXT;
    RAISE NOTICE 'Added passenger_email column';
  ELSE
    RAISE NOTICE 'passenger_email column already exists';
  END IF;
END $$;

-- Add driver_email if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'bookings' AND column_name = 'driver_email') THEN
    ALTER TABLE bookings ADD COLUMN driver_email TEXT;
    RAISE NOTICE 'Added driver_email column';
  ELSE
    RAISE NOTICE 'driver_email column already exists';
  END IF;
END $$;

-- Add passenger_phone if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'bookings' AND column_name = 'passenger_phone') THEN
    ALTER TABLE bookings ADD COLUMN passenger_phone TEXT;
    RAISE NOTICE 'Added passenger_phone column';
  ELSE
    RAISE NOTICE 'passenger_phone column already exists';
  END IF;
END $$;

-- Add driver_phone if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'bookings' AND column_name = 'driver_phone') THEN
    ALTER TABLE bookings ADD COLUMN driver_phone TEXT;
    RAISE NOTICE 'Added driver_phone column';
  ELSE
    RAISE NOTICE 'driver_phone column already exists';
  END IF;
END $$;

-- Recreate indexes for email columns (drop first if they exist)
DROP INDEX IF EXISTS idx_bookings_passenger_email;
DROP INDEX IF EXISTS idx_bookings_driver_email;

CREATE INDEX IF NOT EXISTS idx_bookings_passenger_email ON bookings(passenger_email);
CREATE INDEX IF NOT EXISTS idx_bookings_driver_email ON bookings(driver_email);

-- Drop and recreate RLS policies
DROP POLICY IF EXISTS "Passengers can view own bookings" ON bookings;
DROP POLICY IF EXISTS "Passengers can create own bookings" ON bookings;
DROP POLICY IF EXISTS "Passengers can update own pending bookings" ON bookings;
DROP POLICY IF EXISTS "Drivers can view assigned bookings" ON bookings;
DROP POLICY IF EXISTS "Drivers can update assigned bookings" ON bookings;
DROP POLICY IF EXISTS "Service role full access" ON bookings;

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
-- VERIFICATION
-- =====================================================
-- Run this to verify all columns exist:
-- SELECT column_name, data_type 
-- FROM information_schema.columns 
-- WHERE table_name = 'bookings' 
-- ORDER BY ordinal_position;

