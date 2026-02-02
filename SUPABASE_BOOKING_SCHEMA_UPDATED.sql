-- =====================================================
-- SUPABASE BOOKING SYSTEM SCHEMA (UPDATED)
-- =====================================================
-- This schema works with your existing bookings table structure
-- Adds missing columns and features for scheduled bookings
-- =====================================================

-- =====================================================
-- 1. ADD MISSING COLUMNS TO EXISTING TABLE
-- =====================================================

-- Add passenger_email if it doesn't exist (for easier queries)
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'passenger_email') THEN
    ALTER TABLE public.bookings ADD COLUMN passenger_email TEXT;
    RAISE NOTICE 'Added passenger_email column';
  END IF;
END $$;

-- Add driver_email if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'driver_email') THEN
    ALTER TABLE public.bookings ADD COLUMN driver_email TEXT;
    RAISE NOTICE 'Added driver_email column';
  END IF;
END $$;

-- Add passenger_phone if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'passenger_phone') THEN
    ALTER TABLE public.bookings ADD COLUMN passenger_phone TEXT;
    RAISE NOTICE 'Added passenger_phone column';
  END IF;
END $$;

-- Add driver_phone if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'driver_phone') THEN
    ALTER TABLE public.bookings ADD COLUMN driver_phone TEXT;
    RAISE NOTICE 'Added driver_phone column';
  END IF;
END $$;

-- Add booking_type for immediate vs scheduled bookings
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'booking_type') THEN
    ALTER TABLE public.bookings ADD COLUMN booking_type TEXT NOT NULL DEFAULT 'immediate' 
      CHECK (booking_type IN ('immediate', 'scheduled'));
    RAISE NOTICE 'Added booking_type column';
  END IF;
END $$;

-- Add scheduled_time for scheduled bookings
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'scheduled_time') THEN
    ALTER TABLE public.bookings ADD COLUMN scheduled_time TIMESTAMPTZ;
    RAISE NOTICE 'Added scheduled_time column';
  END IF;
END $$;

-- Add booking_time (when booking was created)
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'booking_time') THEN
    ALTER TABLE public.bookings ADD COLUMN booking_time TIMESTAMPTZ NOT NULL DEFAULT NOW();
    RAISE NOTICE 'Added booking_time column';
  END IF;
END $$;

-- Add estimated_duration_minutes
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'estimated_duration_minutes') THEN
    ALTER TABLE public.bookings ADD COLUMN estimated_duration_minutes INTEGER;
    RAISE NOTICE 'Added estimated_duration_minutes column';
  END IF;
END $$;

-- Add actual_duration_minutes
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'actual_duration_minutes') THEN
    ALTER TABLE public.bookings ADD COLUMN actual_duration_minutes INTEGER;
    RAISE NOTICE 'Added actual_duration_minutes column';
  END IF;
END $$;

-- Add fare_currency
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'fare_currency') THEN
    ALTER TABLE public.bookings ADD COLUMN fare_currency TEXT DEFAULT 'PHP';
    RAISE NOTICE 'Added fare_currency column';
  END IF;
END $$;

-- Add payment_method
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'payment_method') THEN
    ALTER TABLE public.bookings ADD COLUMN payment_method TEXT;
    RAISE NOTICE 'Added payment_method column';
  END IF;
END $$;

-- Add payment_status
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'payment_status') THEN
    ALTER TABLE public.bookings ADD COLUMN payment_status TEXT DEFAULT 'pending' 
      CHECK (payment_status IN ('pending', 'paid', 'refunded', 'failed'));
    RAISE NOTICE 'Added payment_status column';
  END IF;
END $$;

-- Add payment_transaction_id
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'payment_transaction_id') THEN
    ALTER TABLE public.bookings ADD COLUMN payment_transaction_id TEXT;
    RAISE NOTICE 'Added payment_transaction_id column';
  END IF;
END $$;

-- Add special_instructions
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'special_instructions') THEN
    ALTER TABLE public.bookings ADD COLUMN special_instructions TEXT;
    RAISE NOTICE 'Added special_instructions column';
  END IF;
END $$;

-- Add number_of_passengers
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'number_of_passengers') THEN
    ALTER TABLE public.bookings ADD COLUMN number_of_passengers INTEGER DEFAULT 1;
    RAISE NOTICE 'Added number_of_passengers column';
  END IF;
END $$;

-- Add vehicle_type
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'vehicle_type') THEN
    ALTER TABLE public.bookings ADD COLUMN vehicle_type TEXT DEFAULT 'tricycle';
    RAISE NOTICE 'Added vehicle_type column';
  END IF;
END $$;

-- Add accepted_at
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'accepted_at') THEN
    ALTER TABLE public.bookings ADD COLUMN accepted_at TIMESTAMPTZ;
    RAISE NOTICE 'Added accepted_at column';
  END IF;
END $$;

-- Add started_at
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'started_at') THEN
    ALTER TABLE public.bookings ADD COLUMN started_at TIMESTAMPTZ;
    RAISE NOTICE 'Added started_at column';
  END IF;
END $$;

-- Add cancelled_at
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'cancelled_at') THEN
    ALTER TABLE public.bookings ADD COLUMN cancelled_at TIMESTAMPTZ;
    RAISE NOTICE 'Added cancelled_at column';
  END IF;
END $$;

-- Add driver_latitude_at_booking
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'driver_latitude_at_booking') THEN
    ALTER TABLE public.bookings ADD COLUMN driver_latitude_at_booking DOUBLE PRECISION;
    RAISE NOTICE 'Added driver_latitude_at_booking column';
  END IF;
END $$;

-- Add driver_longitude_at_booking
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'driver_longitude_at_booking') THEN
    ALTER TABLE public.bookings ADD COLUMN driver_longitude_at_booking DOUBLE PRECISION;
    RAISE NOTICE 'Added driver_longitude_at_booking column';
  END IF;
END $$;

-- Add passenger_rating
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'passenger_rating') THEN
    ALTER TABLE public.bookings ADD COLUMN passenger_rating INTEGER 
      CHECK (passenger_rating >= 1 AND passenger_rating <= 5);
    RAISE NOTICE 'Added passenger_rating column';
  END IF;
END $$;

-- Add driver_rating
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'driver_rating') THEN
    ALTER TABLE public.bookings ADD COLUMN driver_rating INTEGER 
      CHECK (driver_rating >= 1 AND driver_rating <= 5);
    RAISE NOTICE 'Added driver_rating column';
  END IF;
END $$;

-- Add passenger_review
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'passenger_review') THEN
    ALTER TABLE public.bookings ADD COLUMN passenger_review TEXT;
    RAISE NOTICE 'Added passenger_review column';
  END IF;
END $$;

-- Add driver_review
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'driver_review') THEN
    ALTER TABLE public.bookings ADD COLUMN driver_review TEXT;
    RAISE NOTICE 'Added driver_review column';
  END IF;
END $$;

-- Update status constraint to include new statuses
DO $$ 
BEGIN
  -- Check if we need to update the status constraint
  -- Note: This is a simplified approach. In production, you might want to drop and recreate the constraint
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints 
             WHERE table_schema = 'public' AND table_name = 'bookings' 
             AND constraint_name LIKE '%status%') THEN
    -- Constraint exists, we'll leave it as is since altering CHECK constraints is complex
    RAISE NOTICE 'Status constraint exists. Consider adding: driver_arrived, rejected to allowed values if needed.';
  END IF;
END $$;

-- =====================================================
-- 2. ADDITIONAL INDEXES FOR PERFORMANCE
-- =====================================================

-- Index for passenger_email (if column exists)
CREATE INDEX IF NOT EXISTS idx_bookings_passenger_email ON public.bookings(passenger_email) 
WHERE passenger_email IS NOT NULL;

-- Index for driver_email (if column exists)
CREATE INDEX IF NOT EXISTS idx_bookings_driver_email ON public.bookings(driver_email) 
WHERE driver_email IS NOT NULL;

-- Index for scheduled_time (for scheduled bookings)
CREATE INDEX IF NOT EXISTS idx_bookings_scheduled_time ON public.bookings(scheduled_time) 
WHERE scheduled_time IS NOT NULL;

-- Index for created_at (for date range queries)
CREATE INDEX IF NOT EXISTS idx_bookings_created_at ON public.bookings(created_at DESC);

-- Index for active bookings (pending, accepted, in_progress)
CREATE INDEX IF NOT EXISTS idx_bookings_active_status ON public.bookings(status) 
WHERE status IN ('pending', 'accepted', 'in_progress', 'driver_arrived');

-- Composite index for passenger status queries
CREATE INDEX IF NOT EXISTS idx_bookings_passenger_status ON public.bookings(passenger_id, status);

-- Composite index for driver status queries  
CREATE INDEX IF NOT EXISTS idx_bookings_driver_status ON public.bookings(driver_id, status);

-- =====================================================
-- 3. ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Passengers can view own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Passengers can create own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Passengers can update own pending bookings" ON public.bookings;
DROP POLICY IF EXISTS "Drivers can view assigned bookings" ON public.bookings;
DROP POLICY IF EXISTS "Drivers can update assigned bookings" ON public.bookings;
DROP POLICY IF EXISTS "Service role full access" ON public.bookings;

-- Enable RLS (if not already enabled)
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- Policy: Passengers can view their own bookings
CREATE POLICY "Passengers can view own bookings"
ON public.bookings
FOR SELECT
USING (
  passenger_id = auth.uid()
  OR (passenger_email IS NOT NULL AND passenger_email = (SELECT email FROM auth.users WHERE id = auth.uid()))
);

-- Policy: Passengers can create their own bookings
CREATE POLICY "Passengers can create own bookings"
ON public.bookings
FOR INSERT
WITH CHECK (
  passenger_id = auth.uid()
  OR (passenger_email IS NOT NULL AND passenger_email = (SELECT email FROM auth.users WHERE id = auth.uid()))
);

-- Policy: Passengers can update their own pending bookings
CREATE POLICY "Passengers can update own pending bookings"
ON public.bookings
FOR UPDATE
USING (
  (passenger_id = auth.uid()
   OR (passenger_email IS NOT NULL AND passenger_email = (SELECT email FROM auth.users WHERE id = auth.uid())))
  AND status IN ('pending', 'accepted')
)
WITH CHECK (
  passenger_id = auth.uid()
  OR (passenger_email IS NOT NULL AND passenger_email = (SELECT email FROM auth.users WHERE id = auth.uid()))
);

-- Policy: Drivers can view bookings assigned to them
CREATE POLICY "Drivers can view assigned bookings"
ON public.bookings
FOR SELECT
USING (
  driver_id = auth.uid()
  OR (driver_email IS NOT NULL AND driver_email = (SELECT email FROM auth.users WHERE id = auth.uid()))
);

-- Policy: Drivers can update bookings assigned to them
CREATE POLICY "Drivers can update assigned bookings"
ON public.bookings
FOR UPDATE
USING (
  driver_id = auth.uid()
  OR (driver_email IS NOT NULL AND driver_email = (SELECT email FROM auth.users WHERE id = auth.uid()))
);

-- Policy: Service role can do everything (for admin operations)
CREATE POLICY "Service role full access"
ON public.bookings
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

-- =====================================================
-- 4. HELPER FUNCTIONS
-- =====================================================

-- Function to get active bookings for a passenger (by UUID)
CREATE OR REPLACE FUNCTION get_passenger_active_bookings(p_id UUID)
RETURNS TABLE (
  id UUID,
  driver_name TEXT,
  pickup_address TEXT,
  destination_address TEXT,
  status TEXT,
  scheduled_time TIMESTAMPTZ,
  estimated_fare NUMERIC,
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
  FROM public.bookings b
  WHERE b.passenger_id = p_id
    AND b.status IN ('pending', 'accepted', 'in_progress', 'driver_arrived')
  ORDER BY b.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get active bookings for a passenger (by email)
CREATE OR REPLACE FUNCTION get_passenger_active_bookings_by_email(p_email TEXT)
RETURNS TABLE (
  id UUID,
  driver_name TEXT,
  pickup_address TEXT,
  destination_address TEXT,
  status TEXT,
  scheduled_time TIMESTAMPTZ,
  estimated_fare NUMERIC,
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
  FROM public.bookings b
  WHERE b.passenger_email = p_email
    AND b.status IN ('pending', 'accepted', 'in_progress', 'driver_arrived')
  ORDER BY b.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get active bookings for a driver (by UUID)
CREATE OR REPLACE FUNCTION get_driver_active_bookings(d_id UUID)
RETURNS TABLE (
  id UUID,
  passenger_name TEXT,
  pickup_address TEXT,
  destination_address TEXT,
  status TEXT,
  scheduled_time TIMESTAMPTZ,
  estimated_fare NUMERIC,
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
  FROM public.bookings b
  WHERE b.driver_id = d_id
    AND b.status IN ('pending', 'accepted', 'in_progress', 'driver_arrived')
  ORDER BY b.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get active bookings for a driver (by email)
CREATE OR REPLACE FUNCTION get_driver_active_bookings_by_email(d_email TEXT)
RETURNS TABLE (
  id UUID,
  passenger_name TEXT,
  pickup_address TEXT,
  destination_address TEXT,
  status TEXT,
  scheduled_time TIMESTAMPTZ,
  estimated_fare NUMERIC,
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
  FROM public.bookings b
  WHERE b.driver_email = d_email
    AND b.status IN ('pending', 'accepted', 'in_progress', 'driver_arrived')
  ORDER BY b.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get booking history for a passenger (by UUID)
CREATE OR REPLACE FUNCTION get_passenger_booking_history(p_id UUID, limit_count INTEGER DEFAULT 50)
RETURNS TABLE (
  id UUID,
  driver_name TEXT,
  pickup_address TEXT,
  destination_address TEXT,
  status TEXT,
  scheduled_time TIMESTAMPTZ,
  actual_fare NUMERIC,
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
    b.actual_fare,
    b.created_at,
    b.completed_at
  FROM public.bookings b
  WHERE b.passenger_id = p_id
    AND b.status IN ('completed', 'cancelled')
  ORDER BY b.created_at DESC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- Function to get booking history for a passenger (by email)
CREATE OR REPLACE FUNCTION get_passenger_booking_history_by_email(p_email TEXT, limit_count INTEGER DEFAULT 50)
RETURNS TABLE (
  id UUID,
  driver_name TEXT,
  pickup_address TEXT,
  destination_address TEXT,
  status TEXT,
  scheduled_time TIMESTAMPTZ,
  actual_fare NUMERIC,
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
    b.actual_fare,
    b.created_at,
    b.completed_at
  FROM public.bookings b
  WHERE b.passenger_email = p_email
    AND b.status IN ('completed', 'cancelled')
  ORDER BY b.created_at DESC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 5. SAMPLE QUERIES FOR REFERENCE
-- =====================================================

-- Create a new immediate booking
/*
INSERT INTO public.bookings (
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
  'passenger-uuid-here',
  'John Doe',
  'john@example.com',
  'driver-uuid-here',
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
INSERT INTO public.bookings (
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
  'passenger-uuid-here',
  'John Doe',
  'john@example.com',
  'driver-uuid-here',
  'Driver Name',
  11.7766,
  124.8862,
  'Pickup Address',
  11.7800,
  124.8900,
  'Destination Address',
  'scheduled',
  '2024-12-25 10:00:00+00:00',
  50.00,
  'pending'
);
*/

-- Update booking status (e.g., driver accepts)
/*
UPDATE public.bookings
SET 
  status = 'accepted',
  accepted_at = NOW()
WHERE id = 'booking-uuid-here';
*/

-- Complete a booking
/*
UPDATE public.bookings
SET 
  status = 'completed',
  completed_at = NOW(),
  actual_fare = 55.00,
  distance_km = 5.2,
  actual_duration_minutes = 15
WHERE id = 'booking-uuid-here';
*/

-- =====================================================
-- END OF SCHEMA
-- =====================================================

